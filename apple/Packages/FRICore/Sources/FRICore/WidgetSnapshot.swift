import Foundation

/// A bounded, read-only projection shared by the widget and its in-app preview.
public struct WidgetSnapshot: Sendable {
    public struct Task: Identifiable, Sendable {
        public let id: String
        public let title: String
        public let time: String
    }

    public let day: Date
    public var tasks: [Task] = []
    public var total = 0
    public var completed = 0
    public var service: String?
    public var locked = false

    public init(day: Date, locked: Bool = false) {
        self.day = day
        self.locked = locked
    }

    public init(state: CalendarState, day: Date, now: Date, showServices: Bool = true) {
        self.day = day
        let appointments = state.tasks(on: CalendarClock.day(day))
        total = appointments.count
        completed = appointments.filter(\.done).count
        let pending = appointments.filter { !$0.done }
        let parts = CalendarClock.local.dateComponents([.hour, .minute], from: now)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        let ordered: [Appointment]
        if CalendarClock.local.isDate(day, inSameDayAs: now) {
            let active = pending.filter { (CalendarClock.minutes($0.time) ?? 0) <= minute && ($0.endMinute ?? (CalendarClock.minutes($0.time) ?? 0)) > minute }
            let upcoming = pending.filter { (CalendarClock.minutes($0.time) ?? 0) > minute }
            let remaining = pending.filter { (CalendarClock.minutes($0.time) ?? 0) <= minute && ($0.endMinute ?? (CalendarClock.minutes($0.time) ?? 0)) <= minute }
            ordered = active + upcoming + remaining
        } else {
            ordered = pending
        }
        tasks = ordered.prefix(5).map { Task(id: $0.id, title: $0.title, time: $0.time) }
        guard showServices else { return }
        if case .object(let activity) = state.settings["activity"],
           activity["date"]?.string == CalendarClock.day(day), case .number(let steps) = activity["steps"],
           steps.isFinite, (0...100_000).contains(steps) {
            service = "\(Int(steps)) steps"
        } else if case .object(let weather) = state.settings["appleWeatherCache"],
                  let summary = weather["summary"]?.string,
                  case .number(let timestamp) = weather["fetchedAt"] {
            service = summary + (now.timeIntervalSince1970 - timestamp >= 3600 ? " · cached" : "")
        }
    }

    /// Start and end boundaries keep the next task correct without a polling timer.
    public static func refreshDates(state: CalendarState, day: Date, now: Date) -> [Date] {
        let calendar = CalendarClock.local
        guard calendar.isDate(day, inSameDayAs: now) else { return [now] }
        let boundaries = state.tasks(on: CalendarClock.day(day)).filter { !$0.done }.flatMap { task in
            [CalendarClock.minutes(task.time), task.endMinute].compactMap { minute -> Date? in
                guard let minute, minute < 1440,
                      let date = calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day),
                      date > now else { return nil }
                return date
            }
        }
        return [now] + Set(boundaries).sorted().prefix(30)
    }
}
