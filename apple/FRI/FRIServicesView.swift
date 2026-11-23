import FRICore
import FRIDesign
import MapKit
import SwiftUI

struct FRIServicesView: View {
    let calendar: FRICalendarSession
    @State private var city = ""
    @State private var spotify = ""
    @State private var mapQuery = ""
    @State private var steps = 0
    @State private var mapItem: MKMapItem?
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var message: String?
    @State private var weatherTask: Task<Void, Never>?
    @State private var mapTask: Task<Void, Never>?
    @State private var loadingWeather = false
    @State private var loadingMap = false

    private var savedMapName: String? {
        if case .object(let place) = calendar.state.settings["mapsLocation"] { return place["name"]?.string }
        return calendar.state.settings["mapsLocation"]?.string
    }

    var body: some View {
        FRISheetView(title: "Services") {
            Form {
                Section("Weather") {
                    Text("Open-Meteo receives the city you enter and your IP address.")
                        .friFont(.caption).foregroundStyle(.secondary)
                    TextField("City", text: $city)
                    Button("Get forecast") { refreshWeather() }.disabled(loadingWeather || city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if loadingWeather { ProgressView("Getting forecast…") }
                    Text("Weather data: Open-Meteo · CC BY 4.0").friFont(.caption).foregroundStyle(.secondary)
                    if case .object(let cached) = calendar.state.settings["appleWeatherCache"],
                       let summary = cached["summary"]?.string, case .number(let fetchedAt) = cached["fetchedAt"] {
                        Text(summary)
                        Text(Date(timeIntervalSince1970: fetchedAt), style: .relative).friFont(.caption).foregroundStyle(.secondary)
                        Button("Disconnect weather", role: .destructive) {
                            weatherTask?.cancel()
                            calendar.updateSetting("appleWeatherCache", nil)
                            city = ""
                        }
                    }
                }
                Section("Maps") {
                    Text("MapKit sends the place you enter to Apple Maps.")
                        .friFont(.caption).foregroundStyle(.secondary)
                    TextField("City or place", text: $mapQuery)
                    Button("Show on map") { refreshMap() }.disabled(loadingMap || mapQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if loadingMap { ProgressView("Finding place…") }
                    if let mapItem {
                        Map(position: $mapPosition) { Marker(item: mapItem) }.frame(height: 210)
                    }
                    if mapItem != nil || calendar.state.settings["mapsLocation"] != nil {
                        if mapItem == nil, let saved = savedMapName {
                            Text("Saved place: \(saved)").foregroundStyle(.secondary)
                        }
                        Button("Disconnect maps", role: .destructive) {
                            mapTask?.cancel()
                            self.mapItem = nil
                            mapQuery = ""
                            calendar.updateSetting("mapsLocation", nil)
                        }
                    }
                }
                Section("Spotify") {
                    Text("Opening a public Spotify link shares the connection with Spotify.")
                        .friFont(.caption).foregroundStyle(.secondary)
                    TextField("Spotify link", text: $spotify)
                    if let url = ServiceLinks.spotify(spotify) {
                        Button("Save link") { calendar.updateSetting("spotifyUrl", .string(url.absoluteString)) }
                        Link("Open Spotify", destination: url)
                    }
                    if calendar.state.settings["spotifyUrl"] != nil {
                        Button("Disconnect Spotify", role: .destructive) {
                            calendar.updateSetting("spotifyUrl", nil)
                            spotify = ""
                        }
                    }
                }
                Section("Manual activity") {
                    Text("Steps are entered by you; FRI does not read Health data.").friFont(.caption).foregroundStyle(.secondary)
                    TextField("Steps today", value: $steps, format: .number)
                    Button("Save steps") {
                        guard (0...100_000).contains(steps) else { message = "Enter 0–100,000 steps."; return }
                        calendar.updateSetting("activity", .object(["date": .string(CalendarClock.day()), "steps": .number(Double(steps))]))
                    }
                    if calendar.state.settings["activity"] != nil {
                        Button("Clear activity", role: .destructive) { calendar.updateSetting("activity", nil); steps = 0 }
                    }
                }
                if let message { Text(message).foregroundStyle(.secondary) }
            }
            .formStyle(.grouped)
        }
        .onAppear {
            spotify = calendar.state.settings["spotifyUrl"]?.string ?? ""
            mapQuery = savedMapName ?? ""
            if case .object(let cached) = calendar.state.settings["appleWeatherCache"] { city = cached["city"]?.string ?? "" }
            if case .object(let activity) = calendar.state.settings["activity"],
               activity["date"]?.string == CalendarClock.day(), case .number(let value) = activity["steps"],
               value.isFinite, (0...100_000).contains(value) { steps = Int(value) }
        }
        .onDisappear { weatherTask?.cancel(); mapTask?.cancel() }
    }

    private func refreshWeather() {
        weatherTask?.cancel()
        let city = city.trimmingCharacters(in: .whitespacesAndNewlines)
        loadingWeather = true
        weatherTask = Task {
            defer { loadingWeather = false }
            do {
                let summary = try await FRIWeather.forecast(city: city)
                try Task.checkCancellation()
                calendar.updateSetting("appleWeatherCache", .object([
                    "summary": .string(summary),
                    "city": .string(city),
                    "fetchedAt": .number(Date.now.timeIntervalSince1970)
                ]))
                message = nil
            } catch where !Task.isCancelled {
                message = "Forecast unavailable. FRI kept the last saved forecast."
            } catch {}
        }
    }

    private func refreshMap() {
        mapTask?.cancel()
        let name = mapQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        loadingMap = true
        mapTask = Task {
            defer { loadingMap = false }
            do {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = name
                let response = try await MKLocalSearch(request: request).start()
                try Task.checkCancellation()
                guard let first = response.mapItems.first else { throw URLError(.resourceUnavailable) }
                mapItem = first
                mapPosition = .region(response.boundingRegion)
                calendar.updateSetting("mapsLocation", .string(name))
                message = nil
            } catch where !Task.isCancelled { message = "Apple Maps could not find this place." }
            catch {}
        }
    }


}

private enum FRIWeather {
    private struct City: Decodable { let name: String; let latitude: Double; let longitude: Double }
    private struct Search: Decodable { let results: [City]? }
    private struct Forecast: Decodable {
        struct Current: Decodable { let temperature_2m: Double }
        let current: Current
    }

    static func forecast(city: String) async throws -> String {
        let search: Search = try await request(host: "geocoding-api.open-meteo.com", path: "/v1/search", fields: [
            "name": String(city.prefix(120)), "count": "1"
        ])
        guard let match = search.results?.first else { throw URLError(.resourceUnavailable) }
        let forecast: Forecast = try await request(host: "api.open-meteo.com", path: "/v1/forecast", fields: [
            "latitude": String(match.latitude), "longitude": String(match.longitude), "current": "temperature_2m"
        ])
        return "\(match.name) · \(forecast.current.temperature_2m.formatted(.number.precision(.fractionLength(0)))) °C"
    }

    private static func request<T: Decodable>(host: String, path: String, fields: [String: String]) async throws -> T {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        components.queryItems = fields.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw URLError(.badURL) }
        let request = URLRequest(url: url, timeoutInterval: 12)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard data.count < 128_000, let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
