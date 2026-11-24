import FRICore
import FRIDesign
import MapKit
import SwiftUI

struct FRIServicesView: View {
    let calendar: FRICalendarSession
    let service: FRIService?
    @Environment(\.dynamicTypeSize) private var readingSize
    @State private var city = ""
    @FocusState private var cityFocused: Bool
    @State private var spotify = ""
    @State private var spotifyPresented = false
    @State private var spotifyMessage: String?
    @FocusState private var spotifyFocused: Bool
    @State private var mapQuery = ""
    @FocusState private var mapFocused: Bool
    @State private var stepsText = "0"
    @FocusState private var stepsFocused: Bool
    @State private var mapItem: MKMapItem?
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var activityMessage: String?
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
        FRISheetView(title: service?.panelTitle ?? "Services") {
            Form {
                if service == nil || service == .weather {
                    Section("Weather") {
                        Text("Open-Meteo receives the city you enter and your IP address.")
                            .friFont(.caption).foregroundStyle(.secondary)
                        Text("Saved locations refresh every 30 minutes while FRI is running. On iOS, refresh resumes when you open the app.")
                            .friFont(.caption).foregroundStyle(.secondary)
                        serviceField("City") {
                            TextField("City", text: $city).accessibilityIdentifier("fri.services.weather.city")
                                .focused($cityFocused)
                                .submitLabel(.search)
                                .onSubmit { searchWeather() }
                        }
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
                }
                if service == nil || service == .maps {
                    Section("Maps") {
                        Text("MapKit sends the place you enter to Apple Maps.")
                            .friFont(.caption).foregroundStyle(.secondary)
                        serviceField("City or place") {
                            TextField("City or place", text: $mapQuery)
                                .accessibilityIdentifier("fri.services.maps.query")
                                .focused($mapFocused)
                                .submitLabel(.search)
                                .onSubmit { refreshMap() }
                        }
                        Button("Show on map") { refreshMap() }.disabled(loadingMap || mapQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        if loadingMap {
                            ProgressView("Finding place…")
                            Button("Cancel map search") { cancelMap() }
                        }
                        if let mapMessage { Text(mapMessage).foregroundStyle(.secondary) }
                        if let mapItem {
                            Map(position: $mapPosition) { Marker(item: mapItem) }.frame(height: 210)
                                .accessibilityIdentifier("fri.services.maps.preview")
                        }
                        if mapItem != nil || savedMapName != nil {
                            if let saved = savedMapName {
                                Text("Saved place: \(saved)").foregroundStyle(.secondary)
                                    .accessibilityIdentifier("fri.services.maps.saved")
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
                }
                if service == nil || service == .spotify {
                    Section("Spotify") {
                        Text("Spotify receives your IP address and playback activity when you open the player. FRI sends no calendar details. Full playback depends on your Spotify account.")
                            .friFont(.caption).foregroundStyle(.secondary)
                        serviceField("Spotify link") {
                            TextField("Spotify link", text: $spotify)
                                .focused($spotifyFocused)
                                .accessibilityIdentifier("fri.services.spotify.url")
                                .onSubmit { openSpotify() }
                        }
                        Button("Open player") { openSpotify() }
                            .accessibilityIdentifier("fri.services.spotify.open")
                        if let spotifyMessage { Text(spotifyMessage).foregroundStyle(.secondary) }
                        if calendar.state.settings["spotifyUrl"] != nil {
                            Button("Disconnect Spotify", role: .destructive) { disconnectSpotify() }
                        }
                    }
                }
                if service == nil || service == .health {
                    Section("Manual activity") {
                        Text("Steps are entered by you; FRI does not read Health data.").friFont(.caption).foregroundStyle(.secondary)
                        serviceField("Steps today") {
                            TextField("Steps today", text: $stepsText)
                                .accessibilityIdentifier("fri.services.activity.steps")
                                .focused($stepsFocused)
                                .submitLabel(.done)
                                .onSubmit { stepsFocused = false }
                        }
                        if let activityMessage {
                            Text(activityMessage).foregroundStyle(.secondary)
                                .accessibilityIdentifier("fri.services.activity.message")
                        }
                        Button("Save steps") { saveSteps() }
                        if calendar.state.settings["activity"] != nil {
                            Button("Clear activity", role: .destructive) {
                                stepsFocused = false
                                if calendar.change({ $0.settings.removeValue(forKey: "activity") }) {
                                    stepsText = "0"
                                    activityMessage = nil
                                } else { activityMessage = calendar.message }
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .accessibilityIdentifier("fri.services.form")
        }
        #if os(iOS)
        .sheet(isPresented: $spotifyPresented, onDismiss: { calendar.spotifyPlayer.close() }) {
            FRISpotifyPlayerView(player: calendar.spotifyPlayer,
                onClose: { spotifyPresented = false }, onDisconnect: { disconnectSpotify() })
                .environment(\.dynamicTypeSize, readingSize)
        }
        #endif
        .onAppear {
            calendar.cancelAutomaticWeather()
            spotify = calendar.state.settings["spotifyUrl"]?.string ?? ""
            mapQuery = savedMapName ?? ""
            city = savedWeather?.city ?? ""
            if case .object(let activity) = calendar.state.settings["activity"],
               activity["date"]?.string == CalendarClock.day(), case .number(let value) = activity["steps"],
               value.isFinite, (0...100_000).contains(value) { stepsText = String(Int(value)) }
        }
        .onChange(of: calendar.state.settings["spotifyUrl"]?.string) { _, saved in
            spotify = saved ?? ""
            if saved == nil { spotifyPresented = false }
        }
        .onChange(of: city) { _, _ in
            cancelWeather()
            weatherChoices = []
            weatherMessage = nil
        }
        .onChange(of: stepsText) { _, _ in activityMessage = nil }
        .onChange(of: mapQuery) { _, _ in
            cancelMap()
            mapMessage = nil
        }
        .onChange(of: activityMessage) { _, message in
            if let message { AccessibilityNotification.Announcement(message).post() }
        }
        .onDisappear { cancelWeather(); cancelMap() }
    }

    private func serviceField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).friFont(.caption).foregroundStyle(.secondary)
            content()
        }
    }

    private func saveSteps() {
        stepsFocused = false
        guard let steps = ManualActivity.steps(from: stepsText) else {
            activityMessage = "Enter a whole number from 0 to 100,000."
            return
        }
        if calendar.change({
            $0.settings["activity"] = .object(["date": .string(CalendarClock.day()), "steps": .number(Double(steps))])
        }) {
            activityMessage = "Saved \(steps.formatted()) steps."
        } else { activityMessage = calendar.message }
    }

    private func openSpotify() {
        spotifyFocused = false
        guard let url = ServiceLinks.spotify(spotify) else {
            spotifyMessage = "Use a Spotify playlist, album, track or episode link."
            return
        }
        guard calendar.change({ $0.settings["spotifyUrl"] = .string(url.absoluteString) }) else {
            spotifyMessage = calendar.message
            return
        }
        spotify = url.absoluteString
        spotifyMessage = nil
        calendar.spotifyPlayer.open(url)
        #if os(macOS)
        calendar.spotifyPlayer.present { [weak calendar] in
            guard let calendar, calendar.change({ $0.settings.removeValue(forKey: "spotifyUrl") }) else { return }
            calendar.spotifyPlayer.close()
        }
        #else
        spotifyPresented = true
        #endif
    }

    private func disconnectSpotify() {
        guard calendar.change({ $0.settings.removeValue(forKey: "spotifyUrl") }) else {
            spotifyMessage = calendar.message
            return
        }
        calendar.spotifyPlayer.close()
        spotifyPresented = false
        spotify = ""
        spotifyMessage = nil
    }

    private func cancelWeather() {
        calendar.cancelAutomaticWeather()
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
        let expected = WeatherCacheRevision(settings: calendar.state.settings)
        weatherTask = Task {
            defer { if weatherRequest == request { loadingWeather = false } }
            do {
                let forecast = try await WeatherClient().forecast(for: location)
                try Task.checkCancellation()
                guard weatherRequest == request else { return }
                if calendar.change({ state in
                    try state.applyWeather(forecast, replacing: expected)
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
        mapFocused = false
        cancelMap()
        let requestID = mapRequest
        let submittedQuery = mapQuery
        let name = mapQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        loadingMap = true
        mapMessage = nil
        mapTask = Task {
            defer { if mapRequest == requestID { loadingMap = false; mapSearch = nil } }
            do {
                try Task.checkCancellation()
                guard mapRequest == requestID, mapQuery == submittedQuery else { return }
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = name
                let search = MKLocalSearch(request: request)
                mapSearch = search
                let response = try await search.start()
                try Task.checkCancellation()
                guard mapRequest == requestID, mapQuery == submittedQuery else { return }
                guard let first = response.mapItems.first else { throw URLError(.resourceUnavailable) }
                if calendar.change({ state in
                    state.settings["mapsLocation"] = .string(name)
                    state.settings.removeValue(forKey: "mapsRegion")
                }) {
                    mapItem = first
                    mapPosition = .region(response.boundingRegion)
                } else { mapMessage = calendar.message }
            } catch where !Task.isCancelled {
                if mapRequest == requestID, mapQuery == submittedQuery {
                    mapMessage = "Apple Maps could not find this place. Try another name or try again later."
                }
            }
            catch {}
        }
    }


}
