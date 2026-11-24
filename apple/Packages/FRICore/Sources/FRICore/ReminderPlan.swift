import Foundation

public struct ReminderPlan: Equatable, Sendable {
    public let taskID: String
    public let startsAt: Date
    public let firesAt: Date
    public var identifier: String { "fri.appointment.\(taskID)" }

    /// Match desktop's five-minute heads-up, including plans created inside that window.
    public static func upcoming(_ tasks: [Appointment], now: Date = .now,
                                calendar: Calendar = CalendarClock.local) -> [Self] {
        tasks.compactMap { item -> Self? in
            guard !item.done, let minute = CalendarClock.minutes(item.time),
                  let day = CalendarClock.date(item.date, calendar: calendar),
                  let start = calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0,
                                            of: day, matchingPolicy: .strict, repeatedTimePolicy: .first),
                  calendar.isDate(start, inSameDayAs: day), start > now else { return nil }
            return Self(taskID: item.id, startsAt: start, firesAt: max(start.addingTimeInterval(-300), now.addingTimeInterval(1)))
        }.sorted { ($0.startsAt, $0.taskID) < ($1.startsAt, $1.taskID) }.prefix(48).map { $0 }
    }
}
