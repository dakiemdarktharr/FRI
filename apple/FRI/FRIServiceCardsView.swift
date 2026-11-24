import FRICore
import FRIDesign
import SwiftUI

enum FRIService: String {
    case weather, maps, spotify, health

    var panelTitle: String {
        switch self {
        case .weather: "Weather"
        case .maps: "Explore with Maps"
        case .spotify: "Listen with Spotify"
        case .health: "Your activity"
        }
    }

    var name: String { self == .health ? "activity" : rawValue }
}

struct FRIServiceCardsView: View {
    let calendar: FRICalendarSession
    let service: FRIService

    private var weather: CachedWeather? { CachedWeather(settings: calendar.state.settings) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text(service.rawValue.uppercased()).friFont(.caption2, weight: .semibold).tracking(1.6)
                Spacer(minLength: 0)
                Button {
                    _ = calendar.change { $0.widgets.removeAll { $0 == .string(service.rawValue) } }
                } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .medium))
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(FRIColors.ink)
                .background(FRIColors.control, in: RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("Remove \(service.name) widget")
                .accessibilityIdentifier("fri.serviceCard.\(service.rawValue).remove")
            }
            Text(summary).friFont(.title3, weight: .medium).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("fri.serviceCard.\(service.rawValue).summary")
            if service == .weather, let weather {
                if let location = weather.location, location.label != weather.city {
                    Text(location.label).friFont(.caption)
                }
                if let range = weather.dailyRange { Text(range).friFont(.caption) }
            }
            Text(detail).friFont(.caption).foregroundStyle(FRIColors.muted)
                .fixedSize(horizontal: false, vertical: true)
            Button { calendar.showService(service) } label: {
                Text(actionTitle).friFont(.caption, weight: .semibold)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .frame(minHeight: 44, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(FRIColors.ink)
            .background(FRIColors.control, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("fri.serviceCard.\(service.rawValue).open")
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .modifier(FRISurface(glass: calendar.state.settings["glass"]?.bool != false, radius: 26))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fri.serviceCard.\(service.rawValue)")
    }

    private var summary: String {
        switch service {
        case .weather: return weather?.summary ?? "Weather"
        case .maps: return "Explore"
        case .spotify: return "Your music"
        case .health:
            if case .object(let activity) = calendar.state.settings["activity"], activity["date"]?.string == CalendarClock.day(),
               case .number(let steps) = activity["steps"], steps.isFinite, (0...100_000).contains(steps) {
                return Int(steps).formatted()
            }
            return "Activity"
        }
    }

    private var actionTitle: String {
        switch service {
        case .weather: weather == nil ? "Choose city" : "Refresh or change city"
        case .maps: "Open Maps"
        case .spotify: "Open Spotify"
        case .health: "Update steps"
        }
    }

    private var detail: String {
        switch service {
        case .weather:
            if let weather {
                let stamp = weather.fetchedAt.map { date in
                    (weather.isStale(at: .now) ? "Saved forecast · " : "Updated ") + date.formatted(date: .abbreviated, time: .shortened)
                } ?? "Saved forecast · update time unknown. Refresh in Services."
                return stamp + "\nOpen-Meteo · CC BY 4.0"
            }
            return "Choose a city for its forecast."
        case .maps: return "Restaurants and places in an area you choose."
        case .spotify: return calendar.state.settings["spotifyUrl"]?.string != nil ? "Open your Spotify player." : "Bring a playlist into your day."
        case .health: return "Steps · manual entry"
        }
    }
}
