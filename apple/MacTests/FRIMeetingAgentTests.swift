import AppKit
import XCTest
@testable import FRIMac

@MainActor
final class FRIMeetingAgentTests: XCTestCase {
    func testDraftPanelWhileTyping() throws {
        let suite = "FRI-meeting-test-" + UUID().uuidString
        let prefs = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { prefs.removePersistentDomain(forName: suite) }
        let agent = FRIMeetingAgent(preferences: prefs)
        defer { agent.dismiss() }
        func panels() -> [NSWindow] {
            NSApp.windows.filter { $0.isVisible && $0.title == "FRI · Gợi ý khi đang soạn" }
        }
        let draft = ["title":"Cuộc hẹn", "timeHint":"9h", "location":"trạm"]
        agent.updateDraft(draft)
        let panel = try XCTUnwrap(panels().first)
        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
        agent.updateDraft(draft)
        XCTAssertEqual(panels().count, 1)
        agent.dismiss()
        agent.updateDraft(draft)
        XCTAssertTrue(panels().isEmpty)
        agent.updateDraft(draft.merging(["timeHint":"10h"]) { _, new in new })
        XCTAssertEqual(panels().count, 1)
        agent.updateDraft(nil)
        XCTAssertTrue(panels().isEmpty)
    }

    func testRecentlySentInvitationKeepsOneVisibleSuggestionAfterComposerClears() throws {
        let suite = "FRI-send-test-" + UUID().uuidString
        let prefs = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { prefs.removePersistentDomain(forName: suite) }
        let agent = FRIMeetingAgent(preferences: prefs)
        defer { agent.dismiss() }
        let draft = ["title":"Cuộc hẹn", "location":"trạm", "relativeTime":"Lát nữa"]
        let sent = draft.merging(["origin":"sentInvitation"]) { _, new in new }
        agent.updateDraft(draft)
        let original = try XCTUnwrap(NSApp.windows.first { $0.isVisible && $0.title == "FRI · Gợi ý khi đang soạn" })
        agent.applyConversation(sent, composerCleared: true)
        XCTAssertTrue(original.isVisible)
        XCTAssertEqual(original.title, "FRI · Nhắc kèo")
        agent.dismiss()
        agent.applyConversation(sent, composerCleared: true)
        let panels = NSApp.windows.filter { $0.isVisible && $0.title == "FRI · Nhắc kèo" }
        XCTAssertEqual(panels.count, 1)
    }

    func testVisibleSuggestionDismissalAndCalendarReview() async throws {
        let testID = UUID().uuidString
        let suite = "FRI-meeting-test-" + testID
        let prefs = try XCTUnwrap(UserDefaults(suiteName: suite))
        let oldPreview = ProcessInfo.processInfo.environment["FRI_SYNTHETIC_PREVIEW"]
        let oldID = ProcessInfo.processInfo.environment["FRI_TEST_STORE_ID"]
        setenv("FRI_SYNTHETIC_PREVIEW", "1", 1)
        setenv("FRI_TEST_STORE_ID", testID, 1)
        defer {
            if let oldPreview { setenv("FRI_SYNTHETIC_PREVIEW", oldPreview, 1) } else { unsetenv("FRI_SYNTHETIC_PREVIEW") }
            if let oldID { setenv("FRI_TEST_STORE_ID", oldID, 1) } else { unsetenv("FRI_TEST_STORE_ID") }
            prefs.removePersistentDomain(forName: suite)
        }
        let calendar = FRICalendarSession()
        calendar.open()
        for _ in 0..<100 where !calendar.ready { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertTrue(calendar.synthetic && calendar.ready)
        let original = calendar.state
        let agent = FRIMeetingAgent(preferences: prefs)
        agent.attach(calendar)
        XCTAssertFalse(agent.enabled)
        func panel() -> NSWindow? { NSApp.windows.first { $0.title == "FRI · Nhắc kèo" && $0.isVisible } }
        agent.tryExample()
        XCTAssertNotNil(panel())
        XCTAssertEqual(calendar.state, original)
        agent.dismiss()
        XCTAssertNil(panel())
        XCTAssertEqual(calendar.state, original)
        agent.tryExample()
        agent.review()
        XCTAssertNil(panel())
        XCTAssertEqual(calendar.panel, .draft)
        let draft = try XCTUnwrap(calendar.state.drafts.first { $0.id == calendar.draftStartingID })
        XCTAssertEqual(draft.title, "Họp")
        XCTAssertEqual(draft.time, "19:00")
        XCTAssertEqual(calendar.state.tasks, original.tasks)
        var confirmed = draft
        confirmed.duration = 30
        XCTAssertTrue(calendar.save([confirmed], allowOverlap: true))
        XCTAssertTrue(calendar.state.tasks.contains { $0.id == draft.id })
        let existingTasks = calendar.state.tasks
        agent.updateDraft(["title":"Cuộc hẹn", "timeHint":"9h", "location":"trạm"])
        XCTAssertEqual(calendar.state.tasks, existingTasks)
        agent.review()
        let unsent = try XCTUnwrap(calendar.state.drafts.first { $0.id == calendar.draftStartingID })
        XCTAssertEqual(unsent.location, "trạm")
        XCTAssertEqual(unsent.date, "")
        XCTAssertEqual(unsent.time, "")
        XCTAssertTrue(unsent.notes.contains("9h"))
        XCTAssertEqual(calendar.state.tasks, existingTasks)
        XCTAssertFalse(agent.enabled)
    }
}
