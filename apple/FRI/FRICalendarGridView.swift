import FRICore
import FRIDesign
import SwiftUI

struct FRICalendarGridView: View {
    let mode: FRICalendarSession.CalendarView
    @Binding var cursor: Date
    let tasks: [Appointment]
    let select: (String) -> Void
    let showMonth: (Date) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    private let clock = CalendarClock.local

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ViewThatFits(in: .horizontal) {
                HStack { heading; Spacer(minLength: 12); paging }
                VStack(alignment: .leading, spacing: 8) { heading; paging }
            }
            if mode == .month { month }
            else { year }
        }
    }

    private var heading: some View {
        Text(cursor, format: mode == .year ? .dateTime.year() : .dateTime.month(.wide).year())
            .friFont(.title2, weight: .medium).fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader).accessibilityIdentifier("fri.calendar.heading")
            .accessibilityValue(String(CalendarClock.day(cursor).prefix(mode == .year ? 4 : 7)))
    }

    private var paging: some View {
        HStack(spacing: 4) {
            pageButton(-1, symbol: "chevron.left")
            pageButton(1, symbol: "chevron.right")
        }.fixedSize()
    }

    private func pageButton(_ direction: Int, symbol: String) -> some View {
        Button { move(direction) } label: {
            Image(systemName: symbol).frame(width: 44, height: 44).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .background(FRIColors.control, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel("\(direction < 0 ? "Previous" : "Next") \(mode == .year ? "year" : "month")")
            .accessibilityIdentifier(direction < 0 ? "fri.calendar.previous" : "fri.calendar.next")
    }

    private func gridStart(for month: Date) -> Date {
        let start = clock.dateInterval(of: .month, for: month)?.start ?? month
        let shift = (clock.component(.weekday, from: start) - clock.firstWeekday + 7) % 7
        return clock.date(byAdding: .day, value: -shift, to: start) ?? start
    }

    private var month: some View {
        let columns = Array(repeating: GridItem(.flexible(minimum: 22), spacing: 5), count: 7)
        let counts = Dictionary(grouping: tasks, by: \.date)
        let startGrid = gridStart(for: cursor)
        let symbols = clock.veryShortStandaloneWeekdaySymbols

        return LazyVGrid(columns: columns, spacing: 5) {
            ForEach(0..<7) { index in
                Text(symbols[(clock.firstWeekday - 1 + index) % 7])
                    .friFont(.caption, weight: .medium).foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            ForEach(0..<42) { index in
                if let date = clock.date(byAdding: .day, value: index, to: startGrid) {
                    let key = CalendarClock.day(date)
                    let items = counts[key] ?? []
                    Button { select(key) } label: {
                        VStack(spacing: 8) {
                            Text(date, format: .dateTime.day()).friFont(.body).monospacedDigit()
                                .lineLimit(1).minimumScaleFactor(0.8)
                            HStack(spacing: 3) {
                                ForEach(0..<min(items.count, 3), id: \.self) { _ in
                                    Circle().frame(width: 4, height: 4)
                                }
                            }.frame(height: 4).accessibilityHidden(true)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .frame(minHeight: 44).aspectRatio(1, contentMode: .fit)
                        .foregroundStyle(clock.isDateInToday(date) ? FRIColors.cream : FRIColors.ink)
                        .background(clock.isDateInToday(date) ? FRIColors.marsala : FRIColors.cream, in: RoundedRectangle(cornerRadius: 15))
                        .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(FRIColors.line))
                    }
                    .buttonStyle(.plain)
                    .opacity(clock.isDate(date, equalTo: cursor, toGranularity: .month) ? 1 : 0.48)
                    .accessibilityLabel("\(date.formatted(date: .complete, time: .omitted)), \(items.count) appointments")
                    .accessibilityIdentifier("fri.calendar.day.\(key)")
                    .help(items.isEmpty ? "No appointments" : items.prefix(5).map(\.title).joined(separator: "\n"))
                }
            }
        }
    }

    private var year: some View {
        ViewThatFits(in: .horizontal) {
            yearGrid(columns: 3).frame(minWidth: minimumMonthWidth * 3 + 24)
            yearGrid(columns: 2).frame(minWidth: minimumMonthWidth * 2 + 12)
            yearGrid(columns: 1)
        }
    }

    private var minimumMonthWidth: CGFloat { typeSize >= .xxxLarge ? 210 : 150 }

    private func yearGrid(columns: Int) -> some View {
        let start = clock.dateInterval(of: .year, for: cursor)?.start ?? cursor
        let counts = Dictionary(grouping: tasks, by: { $0.date.prefix(7) })
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columns), spacing: 12) {
            ForEach(0..<12) { index in
                if let month = clock.date(byAdding: .month, value: index, to: start) {
                    let count = counts[CalendarClock.day(month).prefix(7)]?.count ?? 0
                    Button { showMonth(month) } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(month, format: .dateTime.month(.wide)).friFont(.subheadline, weight: .medium)
                                .fixedSize(horizontal: false, vertical: true)
                            miniMonth(month)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(15).aspectRatio(1, contentMode: .fit).frame(minHeight: minimumMonthWidth)
                        .foregroundStyle(FRIColors.cream)
                        .background(FRIColors.sidebar.opacity(0.8), in: RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(FRIColors.cream.opacity(0.18)))
                    }.buttonStyle(.plain)
                        .accessibilityLabel("\(month.formatted(.dateTime.month(.wide).year())), \(count) appointments")
                        .accessibilityIdentifier("fri.calendar.month.\(CalendarClock.day(month).prefix(7))")
                }
            }
        }
    }

    private func miniMonth(_ month: Date) -> some View {
        let start = gridStart(for: month)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 3), count: 7), spacing: 3) {
            ForEach(0..<42) { index in
                if let date = clock.date(byAdding: .day, value: index, to: start) {
                    Text(date, format: .dateTime.day()).friFont(.caption2).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.8).frame(maxWidth: .infinity)
                        .background(clock.isDateInToday(date) ? FRIColors.marsala : .clear, in: RoundedRectangle(cornerRadius: 3))
                        .opacity(clock.isDate(date, equalTo: month, toGranularity: .month) ? 1 : 0.25)
                }
            }
        }.accessibilityHidden(true)
    }

    private func move(_ value: Int) {
        cursor = clock.date(byAdding: mode == .year ? .year : .month, value: value, to: cursor) ?? cursor
    }
}
