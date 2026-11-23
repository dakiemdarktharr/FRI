import FRICore
import FRIDesign
import MapKit
import SwiftUI

struct FRIServicesView: View {
    let calendar: FRICalendarSession
    @State private var city = ""
    @FocusState private var cityFocused: Bool
    @State private var spotify = ""
    @State private var mapQuery = ""
    @State private var steps = 0
    @State private var mapItem: MKMapItem?
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var message: String?
    @State private var weatherTask: Task<Void, Never>?
    @State private var mapTask: Task<Void, Never>?
    @State private var mapSearch: MKLocalSearch?
    @State private var weatherChoices: [WeatherLocation] = []
    @State private var loadingWeather = false
    @State private var loadingMap = false
    @State private var weatherRequest = UUID()
    @State private var mapRequest = UUID()
    @State private var weatherMessage: String?
    @State private var mapMessage: String?

    private var savedMapName: String? { calendar.state.savedMapName }
    private var savedWeather: CachedWeather? { CachedWeather(settings: calendar.state.settings) }

    var body: some View {
        FRISheetView(title: "Services") {
            Form {
                Section("Weather") {
                    Text("Open-Meteo receives the city you enter and your IP address.")
                        .friFont(.caption).foregroundStyle(.secondary)
                    TextField("City", text: $city).accessibilityIdentifier("fri.services.weather.city")
                        .focused($cityFocused)
                        .submitLabel(.search)
                        .onSubmit { searchWeather() }
                    Button("Find city") { searchWeather() }.disabled(loadingWeather || city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if loadingWeather {
                        ProgressView("Loading weather…")
                        Button("Cancel forecast request") { cancelWeather() }
                    }
                    ForEach(weatherChoices) { location in
                        Button { refreshWeather(location) } label: {
                            Label(location.label, systemImage: "mappin.and.ellipse")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .disabled(loadingWeather)
                        .accessibilityIdentifier("fri.services.weather.location.\(location.id)")
                    }
                    if let weatherMessage { Text(weatherMessage).foregroundStyle(.secondary) }
                    Text("Weather data: Open-Meteo · CC BY 4.0").friFont(.caption).foregroundStyle(.secondary)
                    if let cached = savedWeather {
                        Text(cached.summary)
                        if let location = cached.location, location.label != cached.city {
                            Text(location.label).friFont(.caption).foregroundStyle(.secondary)
                        }
                        if let conditions = cached.conditions { Text(conditions) }
                        if let range = cached.dailyRange { Text(range) }
                        if let location = cached.location {
                            Button("Refresh saved forecast") { refreshWeather(location) }.disabled(loadingWeather)
                        }
                        if let fetchedAt = cached.fetchedAt {
                            Text("Saved forecast · \(fetchedAt.formatted(date: .abbreviated, time: .shortened))")
                                .friFont(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("Saved forecast · update time unknown. Refresh to get current weather.")
                                .friFont(.caption).foregroundStyle(.secondary)
                        }
                        Button("Disconnect weather", role: .destructive) {
                            cancelWeather()
                            if calendar.change({ $0.disconnectWeather() }) { city = ""; weatherChoices = []; weatherMessage = nil }
                            else { weatherMessage = calendar.message }
                        }
                    }
                }
                Section("Maps") {
                    Text("MapKit sends the place you enter to Apple Maps.")
                        .friFont(.caption).foregroundStyle(.secondary)
                    TextField("City or place", text: $mapQuery)
                    Button("Show on map") { refreshMap() }.disabled(loadingMap || mapQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if loadingMap {
                        ProgressView("Finding place…")
                        Button("Cancel map search") { cancelMap() }
                    }
                    if let mapMessage { Text(mapMessage).foregroundStyle(.secondary) }
                    if let mapItem {
                        Map(position: $mapPosition) { Marker(item: mapItem) }.frame(height: 210)
                    }
                    if mapItem != nil || savedMapName != nil {
                        if mapItem == nil, let saved = savedMapName {
                            Text("Saved place: \(saved)").foregroundStyle(.secondary)
                        }
                        Button("Disconnect maps", role: .destructive) {
                            cancelMap()
                            if calendar.change({ $0.disconnectMaps() }) {
                                self.mapItem = nil
                                mapQuery = ""
                                mapMessage = nil
                            } else { mapMessage = calendar.message }
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
            .accessibilityIdentifier("fri.services.form")
        }
        .onAppear {
            spotify = calendar.state.settings["spotifyUrl"]?.string ?? ""
            mapQuery = savedMapName ?? ""
            city = savedWeather?.city ?? ""
            if case .object(let activity) = calendar.state.settings["activity"],
               activity["date"]?.string == CalendarClock.day(), case .number(let value) = activity["steps"],
               value.isFinite, (0...100_000).contains(value) { steps = Int(value) }
        }
        .onChange(of: city) { _, _ in
            cancelWeather()
            weatherChoices = []
            weatherMessage = nil
        }
        .onDisappear { cancelWeather(); cancelMap() }
    }

    private func cancelWeather() {
        weatherRequest = UUID()
        weatherTask?.cancel()
        loadingWeather = false
    }

    private func cancelMap() {
        mapRequest = UUID()
        mapTask?.cancel()
        mapSearch?.cancel()
        mapSearch = nil
        loadingMap = false
    }

    private func searchWeather() {
        cityFocused = false
        cancelWeather()
        let request = weatherRequest
        let query = city
        weatherChoices = []
        weatherMessage = nil
        loadingWeather = true
        weatherTask = Task {
            defer { if weatherRequest == request { loadingWeather = false } }
            do {
                let choices = try await WeatherClient().search(query)
                try Task.checkCancellation()
                guard weatherRequest == request else { return }
                weatherChoices = choices
                weatherMessage = choices.isEmpty ? "No matching city. Try a city and country name." : "Choose your city."
            } catch where !Task.isCancelled {
                if weatherRequest == request { weatherMessage = "City search unavailable. Try again later." }
            } catch {}
        }
    }

    private func refreshWeather(_ location: WeatherLocation) {
        cityFocused = false
        cancelWeather()
        let request = weatherRequest
        loadingWeather = true
        weatherMessage = nil
        weatherTask = Task {
            defer { if weatherRequest == request { loadingWeather = false } }
            do {
                let forecast = try await WeatherClient().forecast(for: location)
                try Task.checkCancellation()
                guard weatherRequest == request else { return }
                if calendar.change({ state in
                    state.settings["weather"] = forecast.setting
                    state.settings.removeValue(forKey: "appleWeatherCache")
                }) {
                    city = location.name
                    weatherChoices = []
                } else { weatherMessage = calendar.message }
            } catch where !Task.isCancelled {
                guard weatherRequest == request else { return }
                weatherMessage = savedWeather == nil ? "Forecast unavailable. Try again later." :
                    "Forecast unavailable. FRI kept the last saved forecast."
            } catch {}
        }
    }

    private func refreshMap() {
        cancelMap()
        let requestID = mapRequest
        let name = mapQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        loadingMap = true
        mapMessage = nil
        mapTask = Task {
            defer { if mapRequest == requestID { loadingMap = false; mapSearch = nil } }
            do {
                try Task.checkCancellation()
                guard mapRequest == requestID else { return }
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = name
                let search = MKLocalSearch(request: request)
                mapSearch = search
                let response = try await search.start()
                try Task.checkCancellation()
                guard mapRequest == requestID else { return }
                guard let first = response.mapItems.first else { throw URLError(.resourceUnavailable) }
                if calendar.change({ state in
                    state.settings["mapsLocation"] = .string(name)
                    state.settings.removeValue(forKey: "mapsRegion")
                }) {
                    mapItem = first
                    mapPosition = .region(response.boundingRegion)
                } else { mapMessage = calendar.message }
            } catch where !Task.isCancelled {
                if mapRequest == requestID { mapMessage = "Apple Maps could not find this place. Try another name or try again later." }
            }
            catch {}
        }
    }


}
