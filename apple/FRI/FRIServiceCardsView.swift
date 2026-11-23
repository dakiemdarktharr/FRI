import FRICore
import FRIDesign
import SwiftUI

struct FRIServiceCardsView: View {
    let calendar: FRICalendarSession
    private let services = ["weather", "maps", "spotify", "health"]

    var body: some View {
        ForEach(services.filter { calendar.state.widgets.contains(.string($0)) }, id: \.self) { service in
            Button { calendar.panel = .services } label: {
                VStack(alignment: .leading, spacing: 14) {
                    Label(title(service), systemImage: symbol(service)).friFont(.caption, weight: .semibold)
                    Text(summary(service)).friFont(.title3, weight: .medium).fixedSize(horizontal: false, vertical: true)
                    Text(detail(service)).friFont(.caption).foregroundStyle(FRIColors.muted)
                    Text("Manage").friFont(.caption, weight: .semibold).foregroundStyle(FRIColors.marsala)
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(FRISurface(glass: calendar.state.settings["glass"]?.bool != false, radius: 24))
            }.buttonStyle(.plain).accessibilityIdentifier("fri.serviceCard.\(service)")
        }
    }

    private func title(_ kind: String) -> String {
        switch kind { case "weather": "WEATHER"; case "maps": "ON THE WAY"; case "spotify": "FOCUS MUSIC"; default: "YOUR PACE" }
    }
    private func symbol(_ kind: String) -> String {
        switch kind { case "weather": "cloud.sun"; case "maps": "map"; case "spotify": "music.note"; default: "figure.walk" }
    }
    private func summary(_ kind: String) -> String {
        let settings = calendar.state.settings
        switch kind {
        case "weather":
            if let weather = CachedWeather(settings: settings) { return weather.summary }
            return "A little context before you step outside."
        case "maps":
            if let place = calendar.state.savedMapName { return place }
            return "Where are you heading?"
        case "spotify": return settings["spotifyUrl"]?.string != nil ? "Your focus soundtrack" : "A softer soundtrack."
        default:
            if case .object(let activity) = settings["activity"], activity["date"]?.string == CalendarClock.day(),
               case .number(let steps) = activity["steps"], steps.isFinite, (0...100_000).contains(steps) { return "\(Int(steps)) steps" }
            return "Make room for a little movement."
        }
    }
    private func detail(_ kind: String) -> String {
        switch kind {
        case "weather":
            if let weather = CachedWeather(settings: calendar.state.settings) {
                guard let date = weather.fetchedAt else { return "Saved forecast · update time unknown. Refresh in Services." }
                return (weather.isStale(at: .now) ? "Cached forecast · " : "Saved forecast · ") + date.formatted(date: .abbreviated, time: .shortened)
            }
            return "Choose a city to refresh with Open-Meteo."
        case "maps": return "Choose a place in Apple Maps."
        case "spotify": return "Connect a public playlist, album, track or episode."
        default: return "Manual activity · entered by you."
        }
    }
}
