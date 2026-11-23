import Foundation

/// Reads both Apple and desktop 0.5 cache formats without inventing freshness.
public struct CachedWeather: Sendable {
    public let city: String
    public let summary: String
    public let fetchedAt: Date?

    public init?(settings: [String: JSONValue]) {
        if case .object(let cache) = settings["appleWeatherCache"],
           let summary = cache["summary"]?.string, !summary.isEmpty {
            self.city = cache["city"]?.string ?? ""
            self.summary = summary
            self.fetchedAt = Self.timestamp(cache["fetchedAt"], divisor: 1)
        } else if case .object(let cache) = settings["weather"],
                  let city = cache["city"]?.string, !city.isEmpty,
                  case .number(let temperature) = cache["temperature"], temperature.isFinite {
            self.city = city
            self.summary = "\(city) · \(temperature.formatted(.number.precision(.fractionLength(0)))) °C"
            self.fetchedAt = Self.timestamp(cache["fetchedAt"], divisor: 1000)
        } else { return nil }
    }

    public func isStale(at now: Date) -> Bool {
        guard let fetchedAt else { return true }
        let age = now.timeIntervalSince(fetchedAt)
        return age >= 3600 || age < -300
    }

    private static func timestamp(_ value: JSONValue?, divisor: Double) -> Date? {
        guard case .number(let number) = value, number.isFinite, number > 0,
              number / divisor < 253_402_300_800 else { return nil }
        return Date(timeIntervalSince1970: number / divisor)
    }
}

public extension CalendarState {
    mutating func disconnectWeather() {
        settings.removeValue(forKey: "appleWeatherCache")
        settings.removeValue(forKey: "weather")
    }

    mutating func disconnectMaps() {
        settings.removeValue(forKey: "mapsLocation")
        settings.removeValue(forKey: "mapsRegion")
    }

    var savedMapName: String? {
        if case .object(let place) = settings["mapsLocation"], let name = place["name"]?.string { return name }
        return settings["mapsLocation"]?.string ?? settings["mapsRegion"]?.string
    }
}
