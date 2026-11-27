import FRICore
import AppKit
import Carbon
import XCTest
@testable import FRIMac

@MainActor
final class FRIMeetingAgentTests: XCTestCase {
    func testBuild7FixtureSurvivesUpgrade() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FRI_UPGRADE_PROFILE"] != nil, "Requires an existing isolated profile written by native build 7")
        let profile = try XCTUnwrap(ProcessInfo.processInfo.environment["FRI_UPGRADE_PROFILE"].flatMap(UUID.init(uuidString:)))
        let originalID = ProcessInfo.processInfo.environment["FRI_TEST_STORE_ID"]
        let originalPreview = ProcessInfo.processInfo.environment["FRI_SYNTHETIC_PREVIEW"]
        setenv("FRI_TEST_STORE_ID", profile.uuidString, 1)
        setenv("FRI_SYNTHETIC_PREVIEW", "1", 1)
        defer {
            if let originalID { setenv("FRI_TEST_STORE_ID", originalID, 1) } else { unsetenv("FRI_TEST_STORE_ID") }
            if let originalPreview { setenv("FRI_SYNTHETIC_PREVIEW", originalPreview, 1) } else { unsetenv("FRI_SYNTHETIC_PREVIEW") }
        }
        let session = FRICalendarSession()
        session.open()
        for _ in 0..<100 where !session.ready { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertTrue(session.ready && session.synthetic)
        let appointment = try XCTUnwrap(session.state.tasks.first { $0.id == "upgrade-build7-plan" })
        XCTAssertEqual(appointment.title, "Đồ án · QA")
        XCTAssertTrue(appointment.done)
        XCTAssertEqual(session.state.drafts.first { $0.id == "upgrade-build7-draft" }?.time, "13:37")
        XCTAssertEqual(session.state.settings["theme"]?.string, "dark")
        XCTAssertEqual(session.state.sourceLibrary.last?.label, "QA nguồn cũ")
        XCTAssertEqual(session.state.importQueue.last?.label, "QA inbox")
    }

    func testRememberedSourceSleepsOutsideChatAndSurvivesPauseAndRelaunch() throws {
        let domain = "FRI-background-test-" + UUID().uuidString
        let prefs = try XCTUnwrap(UserDefaults(suiteName: domain))
        defer { prefs.removePersistentDomain(forName: domain) }
        prefs.set(["com.vng.zalo"], forKey: "meeting.nativeApps")
        prefs.set(true, forKey: "meeting.enabled")
        let agent = FRIMeetingAgent(preferences: prefs)
        agent.attach(FRICalendarSession())
        XCTAssertTrue(agent.enabled)
        XCTAssertFalse(agent.hasSamplingTask)
        agent.pause()
        XCTAssertTrue(agent.hasSources)
        XCTAssertFalse(agent.enabled)
        let next = FRIMeetingAgent(preferences: prefs)
        next.attach(FRICalendarSession())
        XCTAssertFalse(next.enabled)
        next.resume()
        XCTAssertTrue(next.enabled)
        XCTAssertFalse(next.hasSamplingTask)
        next.shutdown()
        let restored = FRIMeetingAgent(preferences: prefs)
        restored.attach(FRICalendarSession())
        XCTAssertTrue(restored.enabled)
        restored.stop()
        XCTAssertFalse(FRIMeetingAgent(preferences: prefs).hasSources)
    }

    func testRememberedBrowserRequiresExactChatOriginAndUsesURLProperty() throws {
        let zalo = try XCTUnwrap(MeetingWebSource(browser: "com.google.chrome", service: .zalo))
        let messenger = try XCTUnwrap(MeetingWebSource(browser: "com.apple.safari", service: .messenger))
        XCTAssertNil(MeetingWebSource(browser: "org.example.other", service: .zalo))
        XCTAssertNotNil(zalo.chatRoute("https://chat.zalo.me/"))
        for url in ["https://chat.zalo.me.example.org/", "http://chat.zalo.me/", "https://chat.zalo.me@other.test/",
                    "https://chat.zalo.me:8443/", "https://chat.zalo.me/login", "https://accounts.zalo.me/"] {
            XCTAssertNil(zalo.chatRoute(url), url)
        }
        XCTAssertNotEqual(messenger.chatRoute("https://www.messenger.com/t/1"), messenger.chatRoute("https://www.messenger.com/t/2"))
        XCTAssertNotNil(messenger.chatRoute("https://www.facebook.com/messages/e2ee/t/1"))
        for url in ["https://www.facebook.com/", "https://www.facebook.com/messages-pay/", "https://www.messenger.com/settings", "https://chat.zalo.me/"] {
            XCTAssertNil(messenger.chatRoute(url), url)
        }
        for (source, expected) in [(zalo, OSType(0x55524C20)), (messenger, OSType(0x7055524C))] {
            let event = try XCTUnwrap(MeetingBrowserReader.urlRequest(source, pid: ProcessInfo.processInfo.processIdentifier))
            XCTAssertEqual(event.eventID, AEEventID(kAEGetData))
            let object = try XCTUnwrap(event.paramDescriptor(forKeyword: keyDirectObject))
            XCTAssertEqual(object.descriptorType, typeObjectSpecifier)
            XCTAssertEqual(object.forKeyword(AEKeyword(keyAEKeyData))?.typeCodeValue, expected)
        }
    }

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
