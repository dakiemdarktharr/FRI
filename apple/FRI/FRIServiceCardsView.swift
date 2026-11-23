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
                    Label(title(service), systemImage: symbol(service)).font(.caption.weight(.semibold))
                    Text(summary(service)).font(.title3.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                    Text(detail(service)).font(.caption).foregroundStyle(FRIColors.muted)
                    Text("Manage").font(.caption.weight(.semibold)).foregroundStyle(FRIColors.marsala)
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
            if case .object(let weather) = settings["appleWeatherCache"], let summary = weather["summary"]?.string { return summary }
            if case .object(let weather) = settings["weather"], let city = weather["city"]?.string,
               case .number(let temperature) = weather["temperature"], temperature.isFinite {
                return "\(city) · \(temperature.formatted(.number.precision(.fractionLength(0)))) °C"
            }
            return "A little context before you step outside."
        case "maps":
            if let place = settings["mapsLocation"]?.string { return place }
            if case .object(let place) = settings["mapsLocation"], let name = place["name"]?.string { return name }
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
            if case .object(let weather) = calendar.state.settings["appleWeatherCache"],
               case .number(let fetchedAt) = weather["fetchedAt"], fetchedAt.isFinite {
                return "Saved forecast · " + Date(timeIntervalSince1970: fetchedAt).formatted(date: .abbreviated, time: .shortened)
            }
            return "Choose a city to refresh with Open-Meteo."
        case "maps": return "Choose a place in Apple Maps."
        case "spotify": return "Connect a public playlist, album, track or episode."
        default: return "Manual activity · entered by you."
        }
    }
}
