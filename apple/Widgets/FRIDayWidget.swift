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
    let date: Date
    let snapshot: WidgetSnapshot
}

struct FRIDayProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> FRIDayEntry {
        FRIDayEntry(date: .now, snapshot: WidgetSnapshot(state: .widgetSample, day: .now, now: .now))
    }

    func snapshot(for configuration: FRIDayConfiguration, in context: Context) async -> FRIDayEntry {
        if context.isPreview { return placeholder(in: context) }
        return entries(configuration).first ?? FRIDayEntry(date: .now, snapshot: WidgetSnapshot(day: .now, locked: true))
    }

    func timeline(for configuration: FRIDayConfiguration, in context: Context) async -> Timeline<FRIDayEntry> {
        let entries = entries(configuration)
        let calendar = CalendarClock.local
        let nextDay = calendar.dateInterval(of: .day, for: .now)?.end ?? .now.addingTimeInterval(3600)
        let retry = Date.now.addingTimeInterval(900)
        let refresh = entries.first?.snapshot.locked == true ? retry : min(nextDay, entries.last?.date ?? nextDay)
        let nextRefresh = entries.count > 1 ? refresh : (entries.first?.snapshot.locked == true ? retry : nextDay)
        return Timeline(entries: entries, policy: .after(nextRefresh))
    }

    private func entries(_ settings: FRIDayConfiguration) -> [FRIDayEntry] {
        let now = Date.now
        let day = settings.selectedDate ?? now
        guard let revision = try? CalendarStore.shared().read() else {
            return [FRIDayEntry(date: now, snapshot: WidgetSnapshot(day: day, locked: true))]
        }
        return WidgetSnapshot.refreshDates(state: revision.state, day: day, now: now).map { moment in
            FRIDayEntry(date: moment, snapshot: WidgetSnapshot(
                state: revision.state, day: day, now: moment, showServices: settings.showServices
            ))
        }
    }
}

struct FRIDayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FRIDayEntry

    var body: some View {
        FRIWidgetContent(snapshot: entry.snapshot, family: family) {
            if let next = entry.snapshot.tasks.first {
                Button(intent: FRICompleteTaskIntent(taskID: next.id)) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Complete \(next.title)")
            }
        }
        .widgetURL(URL(string: "fri://day/\(CalendarClock.day(entry.snapshot.day))"))
        .containerBackground(.background, for: .widget)
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

#Preview("Small · long title", as: .systemSmall) {
    FRIDayWidget()
} timeline: {
    FRIDayEntry(date: .now, snapshot: WidgetSnapshot(state: .widgetSample, day: .now, now: .now))
}

#Preview("Medium", as: .systemMedium) {
    FRIDayWidget()
} timeline: {
    FRIDayEntry(date: .now, snapshot: WidgetSnapshot(state: .widgetSample, day: .now, now: .now))
}

#Preview("Large", as: .systemLarge) {
    FRIDayWidget()
} timeline: {
    FRIDayEntry(date: .now, snapshot: WidgetSnapshot(state: .widgetSample, day: .now, now: .now))
}

#Preview("Extra large", as: .systemExtraLarge) {
    FRIDayWidget()
} timeline: {
    FRIDayEntry(date: .now, snapshot: WidgetSnapshot(state: .widgetSample, day: .now, now: .now))
}

#Preview("Empty and locked", as: .systemSmall) {
    FRIDayWidget()
} timeline: {
    FRIDayEntry(date: .now, snapshot: WidgetSnapshot(day: .now))
    FRIDayEntry(date: .now.addingTimeInterval(60), snapshot: WidgetSnapshot(day: .now, locked: true))
}
