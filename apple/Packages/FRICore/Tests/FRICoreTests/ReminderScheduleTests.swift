import Foundation
import Testing
@testable import FRICore

struct ReminderScheduleTests {
    @Test func unchangedCalendarReplenishesQueueAsAppointmentsPass() throws {
        let calendar = CalendarClock.local
        let day = try #require(CalendarClock.date("2026-11-24"))
        let now = try #require(calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day))
        let tasks = (0..<50).map { index in
            var task = Appointment()
            task.id = "rolling-\(index)"; task.title = "Appointment \(index)"
            task.date = "2026-11-24"; task.time = CalendarClock.time(540 + index * 10); task.duration = 10
            return task
        }
        var schedule = ReminderSchedule()
        let firstUpdate = schedule.update(for: tasks, now: now)
        let first = try #require(firstUpdate)
        #expect(first.count == 48 && first.last?.taskID == "rolling-47")
        #expect(schedule.update(for: tasks, now: now.addingTimeInterval(60)) == nil)
        // Entering the five-minute window changes fallback fire dates, not appointment identity.
        #expect(schedule.update(for: tasks, now: now.addingTimeInterval(56 * 60)) == nil)
        let replenishedUpdate = schedule.update(for: tasks, now: now.addingTimeInterval(61 * 60))
        let replenished = try #require(replenishedUpdate)
        #expect(replenished.count == 48)
        #expect(replenished.first?.taskID == "rolling-1" && replenished.last?.taskID == "rolling-48")
        let laterUpdate = schedule.update(for: tasks, now: now.addingTimeInterval(71 * 60))
        let later = try #require(laterUpdate)
        #expect(later.count == 48 && later.last?.taskID == "rolling-49")
        var completed = tasks
        completed[2].done = true
        #expect(schedule.update(for: completed, now: now.addingTimeInterval(71 * 60))?.count == 47)
        #expect(schedule.update(for: [], now: now)?.isEmpty == true)
        #expect(schedule.update(for: [], now: now) == nil)
    }

    @Test func reschedulingTimeZoneResumeAndFailureRetry() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = try #require(CalendarClock.date("2026-11-23", calendar: calendar))
        var task = Appointment()
        task.date = "2026-11-24"; task.title = "Private title"; task.time = "10:00"; task.duration = 30
        var schedule = ReminderSchedule()
        let initial = try #require(schedule.update(for: [task], now: now, calendar: calendar)?.first)
        task.title = "Edited title"
        #expect(schedule.update(for: [task], now: now, calendar: calendar) == nil)
        task.time = "11:00"
        let moved = try #require(schedule.update(for: [task], now: now, calendar: calendar)?.first)
        #expect(moved.startsAt.timeIntervalSince(initial.startsAt) == 3600)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 3600))
        let zoned = try #require(schedule.update(for: [task], now: now, calendar: calendar)?.first)
        #expect(zoned.startsAt == initial.startsAt)
        #expect(schedule.update(for: [task], now: now, calendar: calendar, force: true) != nil)
        schedule.retryAfterFailure(at: now)
        #expect(schedule.update(for: [task], now: now.addingTimeInterval(59), calendar: calendar) == nil)
        #expect(schedule.update(for: [task], now: now.addingTimeInterval(60), calendar: calendar) != nil)
        schedule.retryAfterFailure(at: now)
        #expect(schedule.update(for: [], now: now, calendar: calendar)?.isEmpty == true)
        schedule.retryAfterFailure(at: now)
        #expect(schedule.update(for: [task], now: now, calendar: calendar, force: true) != nil)
    }
}
