import Foundation
import Testing
@testable import FRICore

struct ReminderReceiptsTests {
    @Test func dismissalRelaunchAndExpiry() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = ReminderPlan(taskID: "private-task-id", startsAt: now.addingTimeInterval(180), firesAt: now.addingTimeInterval(1))
        var history = ReminderReceipts()
        #expect(!history.hasElapsed(plan, now: now))
        history.record(plan, firesAt: plan.firesAt)
        #expect(!history.hasElapsed(plan, now: now))
        let data = try JSONEncoder().encode(history)
        #expect(!String(decoding: data, as: UTF8.self).contains(plan.taskID))
        var reopened = try JSONDecoder().decode(ReminderReceipts.self, from: data)
        #expect(reopened.hasElapsed(plan, now: now.addingTimeInterval(2)))
        reopened.retain([], now: now.addingTimeInterval(2))
        #expect(reopened.hasElapsed(plan, now: now.addingTimeInterval(3)))
        reopened.retain([], now: plan.startsAt)
        #expect(!reopened.hasElapsed(plan, now: plan.startsAt))
    }

    @Test func cancellationAndRescheduleRemainEligible() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = ReminderPlan(taskID: "task", startsAt: now.addingTimeInterval(600), firesAt: now.addingTimeInterval(300))
        var history = ReminderReceipts()
        history.record(plan, firesAt: plan.firesAt)
        history.retain([], now: now.addingTimeInterval(1))
        #expect(!history.hasElapsed(plan, now: now.addingTimeInterval(301)))
        history.record(plan, firesAt: plan.firesAt)
        let moved = ReminderPlan(taskID: plan.taskID, startsAt: now.addingTimeInterval(900), firesAt: now.addingTimeInterval(600))
        #expect(!history.hasElapsed(moved, now: now.addingTimeInterval(301)))
        history.retain([moved], now: now.addingTimeInterval(1))
        #expect(!history.hasElapsed(plan, now: now.addingTimeInterval(301)))
        history.record(moved, firesAt: moved.firesAt)
        #expect(history.hasElapsed(moved, now: now.addingTimeInterval(601)))
    }
}
