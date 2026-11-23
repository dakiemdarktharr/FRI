import AppIntents
import FRICore
import SwiftUI
import WidgetKit

struct FRIDayConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "FRI day"
    static let description = IntentDescription("Show today or select a calendar date.")

    @Parameter(title: "Date")
    var selectedDate: Date?

    @Parameter(title: "Show services", default: true)
    var showServices: Bool
}

struct FRIDayEntry: TimelineEntry {
    struct Task: Identifiable {
        let id: String
        let title: String
        let time: String
    }

    let date: Date
    let day: Date
    var tasks: [Task] = []
    var total = 0
    var completed = 0
    var service: String?
    var locked = false
}

struct FRIDayProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> FRIDayEntry {
        FRIDayEntry(date: .now, day: .now, tasks: [.init(id: "preview", title: "An hour to read", time: "09:00")], total: 3, completed: 1)
    }

    func snapshot(for configuration: FRIDayConfiguration, in context: Context) async -> FRIDayEntry {
        if context.isPreview { return placeholder(in: context) }
        return entries(configuration).first ?? FRIDayEntry(date: .now, day: .now, locked: true)
    }

    func timeline(for configuration: FRIDayConfiguration, in context: Context) async -> Timeline<FRIDayEntry> {
        let entries = entries(configuration)
        let calendar = CalendarClock.local
        let nextDay = calendar.dateInterval(of: .day, for: .now)?.end ?? .now.addingTimeInterval(3600)
        let retry = Date.now.addingTimeInterval(900)
        let refresh = entries.first?.locked == true ? retry : nextDay
        return Timeline(entries: entries, policy: .after(refresh))
    }

    private func entries(_ settings: FRIDayConfiguration) -> [FRIDayEntry] {
        let now = Date.now
        let calendar = CalendarClock.local
        let day = settings.selectedDate ?? now
        guard let revision = try? CalendarStore.shared().read() else {
            return [FRIDayEntry(date: now, day: day, locked: true)]
        }
        let tasks = revision.state.tasks(on: CalendarClock.day(day))
        let completed = tasks.filter(\.done).count
        let pending = tasks.filter { !$0.done }
        let isToday = calendar.isDate(day, inSameDayAs: now)
        let cutoffs = isToday ? pending.compactMap { task -> Date? in
            guard let end = task.endMinute, end < 1440,
                  let boundary = calendar.date(bySettingHour: end / 60, minute: end % 60, second: 0, of: now),
                  boundary > now else { return nil }
            return boundary
        } : []
        let moments = [now] + Set(cutoffs).sorted().prefix(30)
        return moments.map { moment in
            let parts = calendar.dateComponents([.hour, .minute], from: moment)
            let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            let ordered = isToday ? pending.filter { ($0.endMinute ?? 0) > minute } + pending.filter { ($0.endMinute ?? 0) <= minute } : pending
            var service: String?
            if settings.showServices {
                if case .object(let activity) = revision.state.settings["activity"],
                   activity["date"]?.string == CalendarClock.day(day), case .number(let steps) = activity["steps"],
                   steps.isFinite, steps >= 0, steps <= 100_000 {
                    service = "\(Int(steps)) steps"
                } else if case .object(let weather) = revision.state.settings["appleWeatherCache"],
                          let summary = weather["summary"]?.string,
                          case .number(let timestamp) = weather["fetchedAt"] {
                    let suffix = moment.timeIntervalSince1970 - timestamp >= 3600 ? " · cached" : ""
                    service = summary + suffix
                }
            }
            return FRIDayEntry(date: moment, day: day, tasks: ordered.prefix(4).map {
                .init(id: $0.id, title: $0.title, time: $0.time)
            }, total: tasks.count, completed: completed, service: service)
        }
    }
}

struct FRIDayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FRIDayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if entry.locked {
                Label("Calendar unavailable", systemImage: "lock")
                    .font(.headline)
                Text("Unlock and open FRI to check your calendar.")
                    .font(.caption)
            } else if let next = entry.tasks.first {
                HStack(alignment: .top, spacing: 5) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(next.title).font(.headline).lineLimit(2).privacySensitive()
                        Text(next.time).font(.caption).monospacedDigit().privacySensitive()
                    }
                    Spacer(minLength: 0)
                    Button(intent: FRICompleteTaskIntent(taskID: next.id)) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Done")
                    .privacySensitive()
                }
            } else {
                Text(entry.total == 0 ? "A fresh day." : "Your day is clear.").font(.headline)
            }
            Spacer(minLength: 4)
            Text(entry.day, format: .dateTime.weekday(.wide)).font(.subheadline.weight(.semibold))
            Text(entry.day, format: .dateTime.month(.abbreviated).day()).font(.caption)
            if !entry.locked, entry.total > 0 {
                ProgressView(value: Double(entry.completed), total: Double(entry.total))
                    .accessibilityLabel("\(entry.completed) of \(entry.total) appointments done")
                    .privacySensitive()
            }
            if family != .systemSmall, let service = entry.service {
                Text(service).font(.caption2).foregroundStyle(.secondary).lineLimit(1).privacySensitive()
            }
            if family == .systemLarge || family == .systemExtraLarge {
                ForEach(entry.tasks.dropFirst()) { task in
                    Text("\(task.time)  \(task.title)").font(.caption).lineLimit(1).privacySensitive()
                }
            }
        }
        .widgetURL(URL(string: "fri://day/\(CalendarClock.day(entry.day))"))
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct FRIDayWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "FRIDayWidget", intent: FRIDayConfiguration.self, provider: FRIDayProvider()) { entry in
            FRIDayWidgetView(entry: entry)
        }
        .configurationDisplayName("FRI Day")
        .description("Your next appointment and today's progress.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

@main
struct FRIWidgets: WidgetBundle {
    var body: some Widget { FRIDayWidget() }
}
