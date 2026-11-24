import CryptoKit
import Foundation
import Testing
@testable import FRICore

private let refreshTime = Date(timeIntervalSince1970: 1_795_440_000)
private let refreshLocation = WeatherLocation(name: "Hanoi", latitude: 21.0245, longitude: 105.8412)
private let refreshedForecast = WeatherForecast(location: refreshLocation, temperature: 23, code: 3,
    high: 28, low: 20, time: "2026-11-23T00:00", timezone: "Asia/Bangkok", fetchedAt: refreshTime)

private func refreshSettings(age: TimeInterval) -> [String: JSONValue] {
    guard case .object(var value) = refreshedForecast.setting else { return [:] }
    value["fetchedAt"] = .number(refreshTime.addingTimeInterval(-age).timeIntervalSince1970 * 1000)
    return ["weather": .object(value)]
}

@Test @MainActor func automaticWeatherHonorsFreshnessRetryAndOptOut() async throws {
    let updater = WeatherAutoRefresh()
    var commits = 0
    let commit: @MainActor (WeatherForecast, WeatherCacheRevision) throws -> Void = { _, _ in commits += 1 }
    let fetch: @Sendable (WeatherLocation) async throws -> WeatherForecast = { location in
        #expect(location == refreshLocation)
        return refreshedForecast
    }
    #expect(updater.refreshIfNeeded(settings: [:], now: refreshTime, fetch: fetch, commit: commit) == nil)
    #expect(updater.refreshIfNeeded(settings: ["appleWeatherCache": .object(["city": .string("Hanoi"), "summary": .string("old")])],
                                   now: refreshTime, fetch: fetch, commit: commit) == nil)
    #expect(updater.refreshIfNeeded(settings: refreshSettings(age: 1799), now: refreshTime, fetch: fetch, commit: commit) == nil)
    let firstCandidate = updater.refreshIfNeeded(settings: refreshSettings(age: 1800), now: refreshTime, fetch: fetch, commit: commit)
    let first = try #require(firstCandidate)
    await first.value
    #expect(commits == 1)
    #expect(updater.refreshIfNeeded(settings: refreshSettings(age: 1800), now: refreshTime.addingTimeInterval(299), fetch: fetch, commit: commit) == nil)
    let retryCandidate = updater.refreshIfNeeded(settings: refreshSettings(age: 1800), now: refreshTime.addingTimeInterval(300),
        fetch: { _ in throw URLError(.notConnectedToInternet) }, commit: commit)
    let retry = try #require(retryCandidate)
    await retry.value
    #expect(commits == 1)
    #expect(updater.refreshIfNeeded(settings: refreshSettings(age: 1800), now: refreshTime.addingTimeInterval(599), fetch: fetch, commit: commit) == nil)
    let recoveredCandidate = updater.refreshIfNeeded(settings: refreshSettings(age: 1800), now: refreshTime.addingTimeInterval(600), fetch: fetch, commit: commit)
    let recovered = try #require(recoveredCandidate)
    await recovered.value
    #expect(commits == 2)
}

private actor RefreshGate {
    private var result: CheckedContinuation<Void, Never>?
    private var arrival: CheckedContinuation<Void, Never>?
    private var arrived = false
    func hold() async {
        await withCheckedContinuation {
            result = $0; arrived = true
            arrival?.resume(); arrival = nil
        }
    }
    func waitForArrival() async {
        if arrived { return }
        await withCheckedContinuation { arrival = $0 }
    }
    func release() { result?.resume(); result = nil }
}

@Test @MainActor func automaticWeatherCancellationCannotCommitOrClearANewerRequest() async throws {
    let updater = WeatherAutoRefresh()
    let oldGate = RefreshGate(), newGate = RefreshGate()
    var committed: [String] = []
    let oldCandidate = updater.refreshIfNeeded(settings: refreshSettings(age: 3600), now: refreshTime,
        fetch: { _ in await oldGate.hold(); return refreshedForecast }, commit: { _, _ in committed.append("old") })
    let old = try #require(oldCandidate)
    await oldGate.waitForArrival()
    #expect(updater.refreshIfNeeded(settings: refreshSettings(age: 3600), now: refreshTime.addingTimeInterval(301), commit: { _, _ in
        Issue.record("An in-flight request must prevent overlapping automatic requests")
    }) == nil)
    updater.cancel()
    let newerCandidate = updater.refreshIfNeeded(settings: refreshSettings(age: 3600), now: refreshTime.addingTimeInterval(301),
        fetch: { _ in await newGate.hold(); return refreshedForecast }, commit: { _, _ in committed.append("new") })
    let newer = try #require(newerCandidate)
    await newGate.waitForArrival()
    await oldGate.release()
    await old.value
    #expect(committed.isEmpty)
    #expect(updater.refreshIfNeeded(settings: refreshSettings(age: 3600), now: refreshTime.addingTimeInterval(700), commit: { _, _ in
        Issue.record("Old cleanup must not clear the newer request")
    }) == nil)
    await newGate.release()
    await newer.value
    #expect(committed == ["new"])
}

@Test(arguments: ["disconnect", "new-city", "manual-refresh", "appointment"])
@MainActor func automaticWeatherChecksLatestEncryptedStore(change: String) async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let key = SymmetricKey(size: .bits256)
    let store = CalendarStore(directory: directory) { _ in key }
    let initial = try store.update { $0.settings = refreshSettings(age: 3600) }
    let gate = RefreshGate()
    let updater = WeatherAutoRefresh()
    let requestCandidate = updater.refreshIfNeeded(settings: initial.state.settings, now: refreshTime,
        fetch: { _ in await gate.hold(); return refreshedForecast }, commit: { forecast, expected in
            try store.update { try $0.applyWeather(forecast, replacing: expected) }
        })
    let request = try #require(requestCandidate)
    await gate.waitForArrival()
    let changed = try store.update { state in
        switch change {
        case "disconnect": state.disconnectWeather()
        case "new-city":
            state.settings["weather"] = .object(["city": .string("Paris"), "temperature": .number(10),
                "latitude": .number(33.66), "longitude": .number(-95.55), "fetchedAt": .number(refreshTime.timeIntervalSince1970 * 1000)])
        case "manual-refresh": state.settings["weather"] = refreshedForecast.setting
        default:
            var appointment = Appointment()
            appointment.title = "Concurrent plan"; appointment.date = "2026-11-23"
            appointment.time = "10:00"; appointment.duration = 30
            state.tasks.append(appointment)
        }
    }
    await gate.release()
    await request.value
    let final = try store.read()
    if change == "appointment" {
        #expect(final.state.tasks == changed.state.tasks)
        #expect(final.state.settings["weather"] == refreshedForecast.setting)
        #expect(final.revision == changed.revision + 1)
    } else {
        #expect(final.state == changed.state)
        #expect(final.revision == changed.revision)
    }
}
