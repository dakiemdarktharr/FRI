import FRICore
import FRIDesign
import SwiftUI
import WidgetKit

/// The same adaptive content is rendered by WidgetKit and the size preview.
struct FRIWidgetContent<Completion: View>: View {
    let snapshot: WidgetSnapshot
    let family: WidgetFamily
    var tint = Color(red: 149 / 255, green: 82 / 255, blue: 81 / 255)
    var secondaryColor: Color = .secondary
    @ViewBuilder let completion: () -> Completion
    @Environment(\.dynamicTypeSize) private var typeSize

    private var expanded: Bool { family == .systemLarge || family == .systemExtraLarge }

    var body: some View {
        GeometryReader { geometry in
            ViewThatFits(in: .vertical) {
                if expanded {
                    VStack(alignment: .leading, spacing: 14) {
                        summary(wide: geometry.size.width >= 280 && !typeSize.isAccessibilitySize)
                        if let service = snapshot.service, !snapshot.locked {
                            Text(service).friFont(.caption).foregroundStyle(secondaryColor)
                                .lineLimit(2).privacySensitive()
                        }
                        if snapshot.tasks.count > 1 {
                            Divider()
                            Text("Also today").friFont(.caption, weight: .semibold).foregroundStyle(secondaryColor)
                            ForEach(snapshot.tasks.dropFirst()) { task in
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Text(task.time).monospacedDigit().foregroundStyle(secondaryColor)
                                    Text(task.title).frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .friFont(.caption).lineLimit(2).privacySensitive()
                            }
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                summary(wide: geometry.size.width >= 280 && !typeSize.isAccessibilitySize)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 8) {
                    task(compact: false)
                    date(compact: true)
                }
                .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 8) {
                    task(compact: true)
                    date(compact: true)
                }
                .fixedSize(horizontal: false, vertical: true)
                task(compact: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .tint(tint)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fri.widget.content")
    }

    @ViewBuilder
    private func summary(wide: Bool) -> some View {
        if wide {
            HStack(alignment: .top, spacing: 18) {
                task(compact: false).frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 10) {
                    date(compact: false)
                    progress
                }
                .frame(width: 105)
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                task(compact: false)
                date(compact: true)
                progress
            }
        }
    }

    private func task(compact: Bool) -> some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(alignment: .leading, spacing: 4) {
                if snapshot.locked {
                    Label("Calendar unavailable", systemImage: "lock")
                        .friFont(.headline).lineLimit(2).minimumScaleFactor(0.85)
                    Text("Open FRI to access your calendar.")
                        .friFont(.caption).foregroundStyle(secondaryColor).lineLimit(3)
                } else if let next = snapshot.tasks.first {
                    Text(next.title)
                        .friFont(.headline).lineLimit(compact ? 2 : 3).minimumScaleFactor(0.85)
                        .privacySensitive().accessibilityIdentifier("fri.widget.title")
                    Text(next.time).friFont(.caption).monospacedDigit().privacySensitive()
                } else {
                    Text(snapshot.total == 0 ? "A fresh day." : "Your day is clear.")
                        .friFont(.headline).lineLimit(2).minimumScaleFactor(0.85)
                        .accessibilityIdentifier("fri.widget.empty")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !snapshot.locked, !snapshot.tasks.isEmpty {
                completion()
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("fri.widget.done")
                    .privacySensitive()
            }
        }
    }

    private func date(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(snapshot.day, format: .dateTime.weekday(compact ? .abbreviated : .wide))
                .friFont(.subheadline, weight: .semibold).lineLimit(1).minimumScaleFactor(0.85)
                .widgetAccentable()
            Text(snapshot.day, format: .dateTime.month(.abbreviated).day())
                .friFont(.caption).foregroundStyle(secondaryColor).lineLimit(1)
        }
    }

    @ViewBuilder
    private var progress: some View {
        if !snapshot.locked, snapshot.total > 0 {
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: Double(snapshot.completed), total: Double(snapshot.total))
                Text("\(snapshot.completed) of \(snapshot.total) done")
                    .friFont(.caption2).foregroundStyle(secondaryColor).lineLimit(1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(snapshot.completed) of \(snapshot.total) appointments done")
            .privacySensitive()
        }
    }
}

extension CalendarState {
    /// Gallery examples never read or write the user's calendar.
    static var widgetSample: CalendarState {
        var state = CalendarState()
        state.tasks = ["Review the weekly plan and prepare notes for tomorrow", "An hour to read", "A walk outside"].enumerated().map { index, title in
            var task = Appointment()
            task.id = "widget-example-\(index)"
            task.title = title
            task.time = CalendarClock.time((index + 9) * 60)
            task.duration = 45
            return task
        }
        return state
    }
}
