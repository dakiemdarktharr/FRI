import Foundation
import Testing
@testable import FRICore

private let weatherResponse = #"{"current":{"temperature_2m":23.5,"weather_code":3,"time":"2026-11-23T23:45"},"daily":{"temperature_2m_max":[28.2],"temperature_2m_min":[20.1]},"timezone":"Asia/Bangkok"}"#
private let weatherLocation = WeatherLocation(name: "Hà Nội", country: "Vietnam", admin1: "Hanoi", latitude: 21.0245, longitude: 105.8412)

private func reply(_ request: URLRequest, _ body: String, status: Int = 200) -> (Data, URLResponse) {
    (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
}

@Test func weatherSearchEncodesNamesAndReturnsDistinctValidChoices() async throws {
    let client = WeatherClient { request in
        let url = try #require(request.url)
        #expect(url.host == "geocoding-api.open-meteo.com")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        #expect(items.first { $0.name == "name" }?.value == "Hà Nội & city=Paris")
        #expect(items.first { $0.name == "count" }?.value == "5")
        return reply(request, #"{"results":[{"id":1,"name":"Hanoi","country":"Vietnam","admin1":"Hanoi","latitude":21,"longitude":105},{"id":2,"name":"Hanoi","country":"Other","latitude":22,"longitude":106},{"id":2,"name":"Duplicate","latitude":22,"longitude":106},{"id":3,"name":"Invalid","latitude":95,"longitude":106}]}"#)
    }
    let choices = try await client.search("  Hà Nội & city=Paris  ")
    #expect(choices.map(\.id) == [1, 2])
    #expect(choices[0].label == "Hanoi, Vietnam")
    #expect(choices[1].label == "Hanoi, Other")
    #expect(try await client.search(" ").isEmpty)
}

@Test func weatherForecastUsesChosenCoordinatesAndDesktopCacheFormat() async throws {
    let client = WeatherClient { request in
        let url = try #require(request.url)
        #expect(url.host == "api.open-meteo.com")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        #expect(items.first { $0.name == "latitude" }?.value == "21.0245")
        #expect(items.first { $0.name == "longitude" }?.value == "105.8412")
        #expect(items.first { $0.name == "daily" }?.value == "temperature_2m_max,temperature_2m_min")
        #expect(items.first { $0.name == "timezone" }?.value == "auto")
        return reply(request, weatherResponse)
    }
    let forecast = try await client.forecast(for: weatherLocation)
    var state = CalendarState()
    state.settings["weather"] = forecast.setting
    let restored = try JSONDecoder().decode(CalendarState.self, from: JSONEncoder().encode(state))
    let cache = try #require(CachedWeather(settings: restored.settings))
    #expect(cache.city == "Hà Nội")
    #expect(cache.location == weatherLocation)
    #expect(cache.conditions == "Overcast")
    #expect(cache.dailyRange == "High 28° · Low 20°")
    #expect(abs(try #require(cache.fetchedAt).timeIntervalSince(forecast.fetchedAt)) < 0.001)
    #expect(!cache.isStale(at: .now))
}

@Test(arguments: ["offline", "http", "malformed", "null", "inverted", "oversized"])
func weatherRejectsUnavailableOrInvalidResponses(failure: String) async {
    let client = WeatherClient { request in
        switch failure {
        case "offline": throw URLError(.notConnectedToInternet)
        case "http": return reply(request, weatherResponse, status: 503)
        case "malformed": return reply(request, "not JSON")
        case "null": return reply(request, weatherResponse.replacingOccurrences(of: "[28.2]", with: "[null]"))
        case "inverted": return reply(request, weatherResponse.replacingOccurrences(of: "[28.2]", with: "[10]"))
        default: return reply(request, String(repeating: " ", count: 128_000) + weatherResponse)
        }
    }
    await #expect(throws: (any Error).self) { try await client.forecast(for: weatherLocation) }
}

private actor WeatherGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var started: CheckedContinuation<Void, Never>?
    private var isWaiting = false

    func hold() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            isWaiting = true
            started?.resume()
            started = nil
        }
    }
    func waitUntilStarted() async {
        if isWaiting { return }
        await withCheckedContinuation { started = $0 }
    }
    func release() { continuation?.resume(); continuation = nil }
}

@Test func canceledWeatherRejectsEvenATransportThatReturnsLate() async throws {
    let gate = WeatherGate()
    let client = WeatherClient { request in
        await gate.hold() // Deliberately ignores cancellation, like a late callback.
        return reply(request, weatherResponse)
    }
    let task = Task { try await client.forecast(for: weatherLocation) }
    await gate.waitUntilStarted()
    task.cancel()
    await gate.release()
    do {
        _ = try await task.value
        Issue.record("Canceled forecast must not become a saved reading")
    } catch { #expect(error is CancellationError) }
}

@Test func weatherDoesNotSendInvalidCoordinates() async {
    let client = WeatherClient { request in
        Issue.record("Invalid coordinates must not reach the network")
        return reply(request, weatherResponse)
    }
    await #expect(throws: URLError.self) {
        try await client.forecast(for: WeatherLocation(name: "Bad", latitude: .nan, longitude: 20))
    }
}
