import FRICore
import SwiftUI

struct FRICalendarGridView: View {
    let mode: FRICalendarSession.CalendarView
    @Binding var cursor: Date
    let tasks: [Appointment]
    let select: (String) -> Void
    let showMonth: (Date) -> Void

    private let clock = CalendarClock.local

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(cursor, format: mode == .year ? .dateTime.year() : .dateTime.month(.wide).year())
                    .font(.largeTitle.weight(.bold)).accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Previous", systemImage: "chevron.left") { move(-1) }.labelStyle(.iconOnly)
                Button("Next", systemImage: "chevron.right") { move(1) }.labelStyle(.iconOnly)
            }
            if mode == .month { month }
            else { year }
        }
    }

    private var month: some View {
        let columns = Array(repeating: GridItem(.flexible(minimum: 22), spacing: 5), count: 7)
        let counts = Dictionary(grouping: tasks, by: \.date)
        let start = clock.dateInterval(of: .month, for: cursor)?.start ?? cursor
        let shift = (clock.component(.weekday, from: start) - clock.firstWeekday + 7) % 7
        let startGrid = clock.date(byAdding: .day, value: -shift, to: start) ?? start
        let symbols = clock.veryShortStandaloneWeekdaySymbols

        return LazyVGrid(columns: columns, spacing: 5) {
            ForEach(0..<7) { index in
                Text(symbols[(clock.firstWeekday - 1 + index) % 7])
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            ForEach(0..<42) { index in
                if let date = clock.date(byAdding: .day, value: index, to: startGrid) {
                    let key = CalendarClock.day(date)
                    let items = counts[key] ?? []
                    Button { select(key) } label: {
                        VStack(spacing: 1) {
                            Text(date, format: .dateTime.day()).font(.body.monospacedDigit())
                            if !items.isEmpty {
                                Text(items.count, format: .number).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(.primary.opacity(clock.isDateInToday(date) ? 0.20 : 0.06), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .opacity(clock.isDate(date, equalTo: cursor, toGranularity: .month) ? 1 : 0.48)
                    .accessibilityLabel("\(date.formatted(date: .complete, time: .omitted)), \(items.count) appointments")
                    .help(items.isEmpty ? "No appointments" : items.prefix(5).map(\.title).joined(separator: "\n"))
                }
            }
        }
    }

    private var year: some View {
        let start = clock.dateInterval(of: .year, for: cursor)?.start ?? cursor
        let counts = Dictionary(grouping: tasks, by: { $0.date.prefix(7) })
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 114), spacing: 10)], spacing: 10) {
            ForEach(0..<12) { index in
                if let month = clock.date(byAdding: .month, value: index, to: start) {
                    let count = counts[CalendarClock.day(month).prefix(7)]?.count ?? 0
                    Button { showMonth(month) } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(month, format: .dateTime.month(.wide)).font(.headline)
                            if count > 0 { Text("\(count) plans").font(.caption).foregroundStyle(.secondary) }
                        }
                        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading).padding(10)
                        .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func move(_ value: Int) {
        cursor = clock.date(byAdding: mode == .year ? .year : .month, value: value, to: cursor) ?? cursor
    }
}
