import Foundation

/// Compare only Weather, so a concurrent appointment edit never blocks a refresh.
public struct WeatherCacheRevision: Equatable, Sendable {
    private let weather: JSONValue?
    private let legacy: JSONValue?

    public init(settings: [String: JSONValue]) {
        weather = settings["weather"]
        legacy = settings["appleWeatherCache"]
    }
}

public enum WeatherRefreshError: LocalizedError {
    case superseded
    public var errorDescription: String? { "Weather changed while this request was running. Please refresh again." }
}

public extension CalendarState {
    /// Call inside CalendarStore.update, while its cross-process lock is held.
    mutating func applyWeather(_ forecast: WeatherForecast, replacing expected: WeatherCacheRevision) throws {
        guard WeatherCacheRevision(settings: settings) == expected else { throw WeatherRefreshError.superseded }
        settings["weather"] = forecast.setting
        settings.removeValue(forKey: "appleWeatherCache")
    }
}

/// One request at a time, matching desktop's 30-minute freshness / 5-minute retry policy.
/// The session owns the timer; this coordinator never keeps an app alive in the background.
@MainActor
public final class WeatherAutoRefresh {
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private var lastAttempt: Date?
    private var lastLocation: WeatherLocation?

    public init() {}

    public func cancel() {
        generation = UUID()
        task?.cancel()
        task = nil
    }

    @discardableResult
    public func refreshIfNeeded(
        settings: [String: JSONValue], now: Date = .now,
        fetch: @escaping @Sendable (WeatherLocation) async throws -> WeatherForecast = { try await WeatherClient().forecast(for: $0) },
        commit: @escaping @MainActor (WeatherForecast, WeatherCacheRevision) throws -> Void
    ) -> Task<Void, Never>? {
        guard task == nil, let cache = CachedWeather(settings: settings), let location = cache.location else { return nil }
        if let fetchedAt = cache.fetchedAt {
            let age = now.timeIntervalSince(fetchedAt)
            guard age >= 1800 || age < -300 else { return nil }
        }
        if lastLocation == location, let lastAttempt {
            let sinceAttempt = now.timeIntervalSince(lastAttempt)
            guard sinceAttempt >= 300 || sinceAttempt < 0 else { return nil }
        }
        lastAttempt = now
        lastLocation = location
        let expected = WeatherCacheRevision(settings: settings)
        let request = UUID()
        generation = request
        let work = Task { [weak self] in
            defer { if self?.generation == request { self?.task = nil } }
            do {
                let forecast = try await fetch(location)
                try Task.checkCancellation()
                guard self?.generation == request else { return }
                try commit(forecast, expected)
            } catch {
                // Automatic failures keep the last saved reading; its timestamp stays visible.
                // The next eligible tick retries without interrupting calendar work.
            }
        }
        task = work
        return work
    }
}
