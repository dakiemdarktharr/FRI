import Foundation

/// Tracks the rolling set of appointments handed to the notification system.
/// Near-term fallback fire dates move with `now`; they must not cause repeat alerts.
public struct ReminderSchedule {
    private var starts: [String: Date]?
    private var retryAfter: Date?

    public init() {}

    public mutating func update(for tasks: [Appointment], now: Date = .now,
                                calendar: Calendar = CalendarClock.local, force: Bool = false) -> [ReminderPlan]? {
        let plans = ReminderPlan.upcoming(tasks, now: now, calendar: calendar)
        let desired = Dictionary(plans.map { ($0.identifier, $0.startsAt) }, uniquingKeysWith: { first, _ in first })
        guard force || desired != starts else { return nil }
        // Disabling reminders must clear the queue even during a failed-add backoff.
        if !force, !plans.isEmpty, let retryAfter, now < retryAfter { return nil }
        starts = desired
        retryAfter = nil
        return plans
    }

    public mutating func retryAfterFailure(at now: Date = .now) {
        starts = nil
        retryAfter = now.addingTimeInterval(60)
    }
}
