import XCTest
#if os(iOS)
import UIKit
#endif

@MainActor
final class FRIWorkflowTests: XCTestCase {
    #if os(iOS)
    func testServiceCardFitsLandscapeViewport() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["FRI_SYNTHETIC_PREVIEW"] = "1"
        app.launchEnvironment["FRI_TEST_STORE_ID"] = UUID().uuidString
        app.launchEnvironment["FRI_WIDGET_PREVIEW"] = "1"
        app.launch()
        let toggle = app.switches["fri.widget.card.maps"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        app.buttons["Close"].firstMatch.tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        let card = app.descendants(matching: .any)["fri.serviceCard.maps"].firstMatch
        reveal(card, in: app, form: "fri.calendar.content")
        let viewport = app.descendants(matching: .any)["fri.calendar.content"].firstMatch.frame.intersection(app.frame)
        XCTAssertTrue(viewport.contains(card.frame), "The full normal-text card must fit in the landscape viewport")
        XCTAssertTrue(app.buttons["fri.serviceCard.maps.open"].isHittable)
        XCTAssertTrue(app.buttons["fri.serviceCard.maps.remove"].isHittable)
        let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        capture.name = "Service-card-full-landscape"; capture.lifetime = .keepAlways; add(capture)
    }

    func testServiceCardsOrderRoutingRemovalAndPersistence() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["FRI_SYNTHETIC_PREVIEW"] = "1"
        app.launchEnvironment["FRI_TEST_STORE_ID"] = UUID().uuidString
        app.launchEnvironment["FRI_WIDGET_PREVIEW"] = "1"
        app.launch()
        XCTAssertTrue(app.switches["fri.widget.card.upnext"].waitForExistence(timeout: 15))
        func toggle(_ key: String) {
            let control = app.switches["fri.widget.card.\(key)"]
            reveal(control, in: app, form: "fri.widget.gallery")
            control.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        toggle("upnext")
        for key in ["maps", "health", "spotify", "weather", "upnext"] { toggle(key) }
        app.buttons["Close"].firstMatch.tap()
        app.launchEnvironment.removeValue(forKey: "FRI_WIDGET_PREVIEW")
        let expected = ["fri.serviceCard.maps", "fri.serviceCard.health", "fri.serviceCard.spotify", "fri.serviceCard.weather", "fri.upNext.card"]
        func cardOrder() -> [String] {
            app.descendants(matching: .any).matching(NSPredicate(format: "identifier IN %@", expected))
                .allElementsBoundByIndex.map(\.identifier)
        }
        XCTAssertEqual(cardOrder(), expected)
        let fields = ["maps": "fri.services.maps.query", "health": "fri.services.activity.steps",
                      "spotify": "fri.services.spotify.url", "weather": "fri.services.weather.city"]
        for key in ["maps", "health", "spotify", "weather"] {
            let action = app.buttons["fri.serviceCard.\(key).open"]
            reveal(action, in: app, form: "fri.calendar.content")
            XCTAssertGreaterThanOrEqual(action.frame.height, 44)
            let remove = app.buttons["fri.serviceCard.\(key).remove"]
            XCTAssertGreaterThanOrEqual(remove.frame.width, 44)
            XCTAssertGreaterThanOrEqual(remove.frame.height, 44)
            if key == "health" {
                let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                capture.name = "Service-activity-card"; capture.lifetime = .keepAlways; add(capture)
            }
            action.tap()
            let field = app.textFields[fields[key]!]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            for other in fields.keys where other != key { XCTAssertFalse(app.textFields[fields[other]!].exists) }
            if key == "health" {
                field.tap(); field.typeText(XCUIKeyboardKey.delete.rawValue + "4321\n")
                app.buttons["Save steps"].tap()
            }
            app.buttons["Close"].firstMatch.tap()
        }
        let activitySummary = app.staticTexts["fri.serviceCard.health.summary"]
        reveal(activitySummary, in: app, form: "fri.calendar.content", upward: false)
        XCTAssertEqual(activitySummary.label.filter(\.isNumber), "4321")
        let remove = app.buttons["fri.serviceCard.health.remove"]
        reveal(remove, in: app, form: "fri.calendar.content", upward: false); remove.tap()
        XCTAssertFalse(app.buttons["fri.serviceCard.health.open"].exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["fri.actions"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["fri.serviceCard.health.open"].exists)
        app.buttons["fri.actions"].tap(); app.buttons["Add FRI widget"].tap()
        let healthToggle = app.switches["fri.widget.card.health"]
        XCTAssertTrue(healthToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(healthToggle.value as? String, "0")
        toggle("health"); app.buttons["Close"].firstMatch.tap()
        XCTAssertEqual(cardOrder(), [expected[0], expected[2], expected[3], expected[4], expected[1]])
        reveal(activitySummary, in: app, form: "fri.calendar.content")
        XCTAssertEqual(activitySummary.label.filter(\.isNumber), "4321", "Removing the card must preserve saved activity")
        app.buttons["fri.navigation.menu"].tap(); app.buttons["Services"].tap()
        XCTAssertTrue(app.textFields["fri.services.weather.city"].waitForExistence(timeout: 5))
        let steps = app.textFields["fri.services.activity.steps"]
        reveal(steps, in: app, form: "fri.services.form")
        XCTAssertEqual(steps.value as? String, "4321", "General Services must still expose all integrations")
        app.buttons["Close"].firstMatch.tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        let maps = app.buttons["fri.serviceCard.maps.open"]
        reveal(maps, in: app, form: "fri.calendar.content", upward: false)
        XCTAssertTrue(maps.isHittable && app.frame.contains(maps.frame))
        let landscape = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        landscape.name = "Service-cards-landscape"; landscape.lifetime = .keepAlways; add(landscape)
    }

    func testAppleCalendarImportWithRealEventKitStore() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FRI_EVENTKIT_TESTS"] == "1",
                          "Requires the Simulator-only CalendarFixture helper installed on a dedicated QA Simulator")
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let runID = UUID().uuidString
        let denied = ProcessInfo.processInfo.environment["FRI_EVENTKIT_DENY"] == "1"
        let fixture = XCUIApplication(bundleIdentifier: "com.fri.qa.calendarfixture")
        fixture.launchEnvironment["FRI_CALENDAR_FIXTURE_ID"] = runID
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        func answerCalendar(allowAccess: Bool = true) {
            let alert = springboard.alerts.firstMatch
            if alert.waitForExistence(timeout: 20) {
                let choices = allowAccess ? [
                    "Allow Full Access", "Allow", "Cho phép truy cập đầy đủ", "Cho phép"
                ] : ["Don't Allow", "Don’t Allow", "Không cho phép", "Từ chối"]
                let identified = alert.buttons.matching(identifier: allowAccess ? "kTCCServiceCalendar-allow-button" : "kTCCServiceCalendar-deny-button").firstMatch
                let answer = identified.exists ? identified : alert.buttons.matching(NSPredicate(format: "label IN %@", choices)).firstMatch
                XCTAssertTrue(answer.exists, alert.debugDescription)
                answer.tap()
            } else { XCTAssertTrue(allowAccess, "The denial variant requires a fresh app identity and an actual system prompt") }
        }
        let identity = XCTAttachment(string: runID)
        identity.name = "EventKit-fixture-ID"; identity.lifetime = .keepAlways; add(identity)
        if !denied {
            fixture.launch()
            XCTAssertTrue(fixture.buttons["Prepare calendar"].waitForExistence(timeout: 8))
            addTeardownBlock { @MainActor in
                fixture.launch()
                let remove = fixture.buttons["Remove calendar"]
                XCTAssertTrue(remove.waitForExistence(timeout: 8))
                remove.tap()
                let removed = fixture.staticTexts["Removed QA calendar"]
                XCTAssertTrue(removed.waitForExistence(timeout: 10), fixture.debugDescription)
                fixture.terminate()
            }
            fixture.buttons["Prepare calendar"].tap(); answerCalendar()
            XCTAssertTrue(fixture.staticTexts["Prepared four events"].waitForExistence(timeout: 10), fixture.debugDescription)
            fixture.terminate()
        }

        let app = XCUIApplication()
        app.launchEnvironment["FRI_SYNTHETIC_PREVIEW"] = "1"
        app.launchEnvironment["FRI_TEST_STORE_ID"] = runID
        app.launch()
        XCTAssertTrue(app.buttons["fri.actions"].waitForExistence(timeout: 15))
        app.buttons["fri.actions"].tap(); app.buttons["Import plans"].tap()
        let connect = app.buttons["fri.import.connectCalendar"]
        reveal(connect, in: app, form: "fri.import.form"); connect.tap(); answerCalendar(allowAccess: !denied)
        if denied {
            XCTAssertTrue(app.staticTexts["fri.import.feedback.message"].waitForExistence(timeout: 10))
            let source = app.textFields["fri.import.text"]
            reveal(source, in: app, form: "fri.import.form", upward: false)
            source.tap(); source.typeText("QA fallback 2031-06-15 15:30 30 min")
            app.buttons["fri.import.reviewText"].tap()
            XCTAssertTrue(app.buttons["fri.import.refresh"].waitForExistence(timeout: 8))
            app.buttons["fri.import.refresh"].tap()
            XCTAssertTrue(app.staticTexts["Added 1 · Needs attention 0 · Skipped 0"].waitForExistence(timeout: 8))
            return
        }
        let timed = "FRI QA timed \(runID)"
        let allDay = "FRI QA all day \(runID)"
        let skipped = "FRI QA skip \(runID)"
        // The fixture puts all three events tomorrow. Remove the all-day row so
        // the timed meeting can be applied without displacing a fixed event.
        let allDayRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", allDay)).firstMatch
        XCTAssertTrue(allDayRow.waitForExistence(timeout: 10))
        allDayRow.tap()
        app.buttons["Skip this plan"].tap()
        let skipRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", skipped)).firstMatch
        skipRow.tap(); app.buttons["Skip this plan"].tap()
        app.buttons["fri.import.refresh"].tap()
        XCTAssertTrue(app.staticTexts["Added 1 · Needs attention 0 · Skipped 0"].waitForExistence(timeout: 10))
        app.buttons["Close"].firstMatch.tap()
        let timedCard = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'fri.card.' AND label CONTAINS %@", timed)).firstMatch
        XCTAssertTrue(timedCard.waitForExistence(timeout: 8))
        XCTAssertTrue(timedCard.label.contains("QA Room") && timedCard.label.contains("09:00"))
        app.terminate(); app.launch()
        XCTAssertTrue(timedCard.waitForExistence(timeout: 15))
        app.buttons["fri.actions"].tap(); app.buttons["Import plans"].tap()
        reveal(connect, in: app, form: "fri.import.form"); connect.tap()
        let again = app.buttons["fri.import.refresh"]
        XCTAssertTrue(again.waitForExistence(timeout: 10))
        again.tap()
        XCTAssertTrue(app.staticTexts["Added 1 · Needs attention 1 · Skipped 1"].waitForExistence(timeout: 8))
        app.buttons["Close"].firstMatch.tap()
        reveal(timedCard, in: app, form: "fri.calendar.content"); timedCard.tap()
        app.buttons["fri.detail.done"].tap()
        XCTAssertEqual(app.buttons["fri.detail.done"].label, "Mark as pending")
        fixture.launch()
        fixture.buttons["Verify source unchanged"].tap()
        XCTAssertTrue(fixture.staticTexts["Source unchanged"].waitForExistence(timeout: 10), fixture.debugDescription)
        let unchanged = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        unchanged.name = "EventKit-source-unchanged"; unchanged.lifetime = .keepAlways; add(unchanged)
    }

    func testManualActivityRejectsInvalidInputAndPersists() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["FRI_SYNTHETIC_PREVIEW"] = "1"
        app.launchEnvironment["FRI_TEST_STORE_ID"] = UUID().uuidString
        app.launch()
        if ProcessInfo.processInfo.environment["FRI_SERVICE_LARGE_TEXT"] == "1" {
            XCTAssertTrue(app.buttons["fri.navigation.menu"].waitForExistence(timeout: 15))
            app.buttons["fri.navigation.menu"].tap(); app.buttons["Settings"].tap()
            let larger = app.switches["fri.settings.largeText"]
            reveal(larger, in: app, form: "fri.settings.form")
            if larger.value as? String != "1" {
                larger.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            }
            app.buttons["Close"].firstMatch.tap()
        }
        func openServices() {
            XCTAssertTrue(app.buttons["fri.navigation.menu"].waitForExistence(timeout: 15))
            app.buttons["fri.navigation.menu"].tap(); app.buttons["Services"].tap()
        }
        openServices()
        let steps = app.textFields["fri.services.activity.steps"]
        let save = app.buttons["Save steps"]
        func enter(_ value: String) {
            reveal(steps, in: app, form: "fri.services.form")
            steps.tap()
            let previous = steps.value as? String ?? ""
            let count = previous == "Steps today" ? 0 : previous.count
            steps.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: count) + value + "\n")
            reveal(save, in: app, form: "fri.services.form"); save.tap()
        }
        func reopen() {
            app.buttons["Close"].firstMatch.tap(); openServices()
            reveal(steps, in: app, form: "fri.services.form")
        }
        enter("4321"); reopen()
        XCTAssertEqual((steps.value as? String)?.filter(\.isNumber), "4321")
        let error = app.staticTexts["Enter a whole number from 0 to 100,000."]
        for invalid in ["abc", "", "-1", "1.5", "100001"] {
            enter(invalid)
            XCTAssertTrue(error.waitForExistence(timeout: 3), "Invalid input must not silently save the previous number: \(invalid)")
            reveal(error, in: app, form: "fri.services.form")
            XCTAssertTrue(error.isHittable && app.frame.contains(error.frame))
        }
        let evidence = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        evidence.name = "Activity-invalid-input"; evidence.lifetime = .keepAlways; add(evidence)
        reopen()
        XCTAssertEqual((steps.value as? String)?.filter(\.isNumber), "4321")
        enter("0"); reopen()
        XCTAssertEqual(steps.value as? String, "0")
        enter("100000")
        app.buttons["Close"].firstMatch.tap(); app.terminate(); app.launch(); openServices()
        reveal(steps, in: app, form: "fri.services.form")
        XCTAssertEqual((steps.value as? String)?.filter(\.isNumber), "100000")
        XCTAssertTrue(app.staticTexts["Steps today"].exists, "A filled field must retain its visible label")
        let clear = app.buttons["Clear activity"]
        reveal(clear, in: app, form: "fri.services.form"); clear.tap(); reopen()
        XCTAssertEqual(steps.value as? String, "0")
        XCTAssertFalse(clear.exists)
    }

    func testSidebarGradientMotionAndPause() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["FRI_SYNTHETIC_PREVIEW"] = "1"
        app.launchEnvironment["FRI_TEST_STORE_ID"] = UUID().uuidString
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launch()
        XCTAssertTrue(app.buttons["fri.new"].waitForExistence(timeout: 15))
        guard app.frame.width >= 1000 else { throw XCTSkip("Requires a wide iPad sidebar") }
        let settings = app.buttons["fri.sidebar.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 8))
        settings.tap()
        let sidebarMode = app.buttons["fri.settings.sidebar"]
        sidebarMode.tap()
        app.buttons["Moving gradient"].tap()
        app.buttons["Close"].firstMatch.tap()
        func setMotion(_ enabled: Bool) {
            settings.tap()
            let motion = app.switches["Gentle motion"]
            reveal(motion, in: app, form: "fri.settings.form")
            if (motion.value as? String == "1") != enabled {
                motion.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            }
            app.buttons["Close"].firstMatch.tap()
        }
        func edgePixels() throws -> Data {
            let screenshot = XCUIScreen.main.screenshot().image
            let oriented = UIGraphicsImageRenderer(size: screenshot.size).image { _ in
                screenshot.draw(in: CGRect(origin: .zero, size: screenshot.size))
            }
            let cg = try XCTUnwrap(oriented.cgImage)
            let scale = CGFloat(cg.width) / app.frame.width
            // The sidebar's inner left edge has no text, clock or controls.
            let rect = CGRect(x: 4, y: 100, width: 8, height: app.frame.height - 200)
                .applying(CGAffineTransform(scaleX: scale, y: scale)).integral
            let crop = UIImage(cgImage: try XCTUnwrap(cg.cropping(to: rect)))
            let attachment = XCTAttachment(image: crop)
            attachment.name = "Sidebar-edge"; attachment.lifetime = .keepAlways; add(attachment)
            return try XCTUnwrap(crop.pngData())
        }
        setMotion(false)
        Thread.sleep(forTimeInterval: 1)
        let still = try edgePixels()
        Thread.sleep(forTimeInterval: 2)
        XCTAssertEqual(still, try edgePixels(), "Gentle motion off must keep the Metal image stationary")
        let paused = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        paused.name = "Sidebar-native-gradient-paused"; paused.lifetime = .keepAlways; add(paused)
        setMotion(true)
        let moving = try edgePixels()
        Thread.sleep(forTimeInterval: 3)
        XCTAssertNotEqual(moving, try edgePixels(), "The native GPU gradient must actually animate")
        setMotion(false)
        Thread.sleep(forTimeInterval: 20)
        setMotion(true)
        let restarted = try edgePixels()
        func decodedPixels(_ data: Data) throws -> Data {
            let image = try XCTUnwrap(UIImage(data: data)?.cgImage)
            return try XCTUnwrap(image.dataProvider?.data) as Data
        }
        let firstPixels = try decodedPixels(moving), secondPixels = try decodedPixels(restarted)
        XCTAssertEqual(firstPixels.count, secondPixels.count)
        let meanDifference = zip(firstPixels, secondPixels).reduce(0.0) {
            $0 + abs(Double($1.0) - Double($1.1))
        } / Double(firstPixels.count)
        let metric = XCTAttachment(string: "Mean byte difference after motion restart: \(meanDifference)")
        metric.name = "Sidebar-motion-restart"; metric.lifetime = .keepAlways; add(metric)
        // Both captures follow the same Settings interaction. Allow minor frame-phase variation;
        // a new desktop ShaderGradient starts its animation clock again when motion is enabled.
        XCTAssertLessThan(meanDifference, 2, "Re-enabling motion must restart the same visual sequence")
        setMotion(false)
    }

    func testCompactDayHeadingAndActions() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["FRI_SYNTHETIC_PREVIEW"] = "1"
        app.launchEnvironment["FRI_TEST_STORE_ID"] = UUID().uuidString
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launch()
        XCTAssertTrue(app.buttons["fri.new"].waitForExistence(timeout: 15))
        let day = app.buttons["Open month calendar"]
        let selector = app.buttons["fri.view.selector"]
        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
            XCUIDevice.shared.orientation = orientation
            XCTAssertTrue(day.waitForExistence(timeout: 8))
            XCTAssertLessThan(day.frame.height, 150)
            XCTAssertTrue(selector.isHittable)
            selector.tap()
            app.buttons["Week"].tap()
            XCTAssertTrue(app.buttons["fri.calendar.next"].waitForExistence(timeout: 8))
            selector.tap()
            app.buttons["Feed"].tap()
        }
    }

    func testFeedCardDetailsAndCompletion() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["FRI_SYNTHETIC_PREVIEW"] = "1"
        app.launchEnvironment["FRI_TEST_STORE_ID"] = UUID().uuidString
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.buttons["fri.new"].waitForExistence(timeout: 15))
        for (name, time, duration) in [("Morning walk", "09:00", "30"), ("Project review", "10:00", "60"), ("Afternoon workshop", "13:00", "120")] {
            app.buttons["fri.new"].tap(); app.buttons["Schedule"].tap()
            let title = app.textFields["fri.editor.title"]
            XCTAssertTrue(title.waitForExistence(timeout: 8)); title.tap(); title.typeText(name + "\n")
            let start = app.textFields["fri.editor.time"]
            start.tap(); start.typeText(time + "\n")
            let length = app.textFields["fri.editor.duration"]
            length.tap(); length.typeText(duration + "\n")
            let save = app.buttons["fri.editor.submit"]
            reveal(save, in: app, form: "fri.editor.form"); save.tap()
            XCTAssertTrue(app.buttons["fri.new"].waitForExistence(timeout: 8))
        }
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "fri.card."))
        XCTAssertEqual(cards.count, 3)
        let first = cards.matching(NSPredicate(format: "label CONTAINS %@", "Morning walk")).firstMatch
        let id = first.identifier.replacingOccurrences(of: "fri.card.", with: "")
        let done = app.buttons["fri.done." + id]
        func revealCard() {
            reveal(first, in: app, form: "fri.calendar.content")
            reveal(done, in: app, form: "fri.calendar.content")
            let viewport = app.scrollViews["fri.calendar.content"].frame.intersection(app.frame)
            XCTAssertTrue(viewport.contains(first.frame.union(done.frame)), "The title, location and completion control must fit together")
        }
        revealCard()
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "Feed-portrait"; shot.lifetime = .keepAlways; add(shot)
        // Open from the empty middle of the card, away from all text.
        first.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.45)).tap()
        XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 8))
        app.buttons["Close"].firstMatch.tap()
        reveal(done, in: app, form: "fri.calendar.content")
        XCTAssertGreaterThanOrEqual(done.frame.width, 44)
        XCTAssertGreaterThanOrEqual(done.frame.height, 44)
        XCTAssertGreaterThan(done.frame.midX, first.frame.midX)
        done.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.15)).tap()
        XCTAssertEqual(done.label, "Mark as pending")
        XCTAssertFalse(app.buttons["Edit"].exists, "Completion must not open appointment details")
        let completed = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        completed.name = "Feed-completed"; completed.lifetime = .keepAlways; add(completed)
        app.terminate(); app.launch()
        XCTAssertTrue(done.waitForExistence(timeout: 15))
        XCTAssertEqual(done.label, "Mark as pending")
        app.buttons["fri.navigation.menu"].tap(); app.buttons["Settings"].tap()
        let theme = app.buttons["fri.settings.theme"]
        reveal(theme, in: app, form: "fri.settings.form"); theme.tap()
        app.buttons["Dark"].tap()
        let larger = app.switches["fri.settings.largeText"]
        reveal(larger, in: app, form: "fri.settings.form")
        larger.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        app.buttons["Close"].firstMatch.tap()
        revealCard()
        XCTAssertTrue(first.isHittable && done.isHittable)
        let large = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        large.name = "Feed-dark-larger-text"; large.lifetime = .keepAlways; add(large)
    }

    func testToolbarHitAreasAndNavigation() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["FRI_SYNTHETIC_PREVIEW"] = "1"
        app.launchEnvironment["FRI_TEST_STORE_ID"] = UUID().uuidString
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launch()
        XCTAssertTrue(app.buttons["fri.new"].waitForExistence(timeout: 15))
        func cornerTap(_ button: XCUIElement) {
            XCTAssertTrue(button.waitForExistence(timeout: 8))
            XCTAssertGreaterThanOrEqual(button.frame.width, 44)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            button.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.15)).tap()
        }
        let before = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        before.name = "Toolbar-landscape"; before.lifetime = .keepAlways; add(before)
        cornerTap(app.buttons["fri.search"])
        XCTAssertTrue(app.textFields["Search appointments"].waitForExistence(timeout: 8))
        app.buttons["Close"].firstMatch.tap()
        cornerTap(app.buttons["fri.actions"])
        app.buttons["Find time for a task"].tap()
        XCTAssertTrue(app.textFields["fri.planner.title"].waitForExistence(timeout: 8))
        app.buttons["Close"].firstMatch.tap()
        // Landscape iPhone safe-area insets can keep the workspace compact even
        // when the full screen is wider than the sidebar breakpoint.
        if app.buttons["fri.navigation.menu"].exists {
            cornerTap(app.buttons["fri.navigation.menu"])
            app.buttons["fri.navigation.feed"].tap()
        } else {
            cornerTap(app.buttons["Sidebar"])
            XCTAssertFalse(app.buttons["fri.sidebar.settings"].exists)
            cornerTap(app.buttons["Sidebar"])
            XCTAssertTrue(app.buttons["fri.sidebar.settings"].waitForExistence(timeout: 8))
            cornerTap(app.buttons["Search appointments"])
            XCTAssertTrue(app.textFields["Search appointments"].waitForExistence(timeout: 8))
            app.buttons["Close"].firstMatch.tap()
        }
        XCUIDevice.shared.orientation = .portrait
        cornerTap(app.buttons["fri.navigation.menu"])
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["fri.settings.sidebar"].waitForExistence(timeout: 8))
        app.buttons["Close"].firstMatch.tap()
        let after = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        after.name = "Toolbar-portrait"; after.lifetime = .keepAlways; add(after)
    }

    func testLocalReminderDeliveryAndDisable() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FRI_NOTIFICATION_TESTS"] == "1",
                          "Opt in on a dedicated Simulator: this test allows FRI notifications and waits for a real local delivery.")
        continueAfterFailure = false
        let foreground = ProcessInfo.processInfo.environment["FRI_NOTIFICATION_FOREGROUND"] == "1"
        let dismissAndRelaunch = ProcessInfo.processInfo.environment["FRI_NOTIFICATION_DISMISS"] == "1"
        let cancellation = ProcessInfo.processInfo.environment["FRI_NOTIFICATION_CANCEL"] ?? ""
        XCTAssertTrue(["", "disable", "complete"].contains(cancellation))
        XCTAssertTrue(cancellation.isEmpty || !foreground, "Pending cancellation requires a future delivery time")
        let app = XCUIApplication()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        app.launchEnvironment["FRI_SYNTHETIC_PREVIEW"] = "1"
        app.launchEnvironment["FRI_TEST_STORE_ID"] = UUID().uuidString
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.buttons["fri.new"].waitForExistence(timeout: 15))
        func settings() {
            app.buttons["fri.navigation.menu"].tap(); app.buttons["Settings"].tap()
        }
        settings()
        let reminders = app.switches["Appointment reminders"]
        reveal(reminders, in: app, form: "fri.settings.form")
        reminders.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let allow = springboard.alerts.buttons.matching(NSPredicate(format: "label IN %@", ["Allow", "Cho phép"])).firstMatch
        if allow.waitForExistence(timeout: 5) { allow.tap() }
        expectation(for: NSPredicate(format: "value == '1'"), evaluatedWith: reminders)
        waitForExpectations(timeout: 10)
        app.buttons["Close"].firstMatch.tap()
        app.buttons["fri.new"].tap(); app.buttons["Schedule"].tap()
        let title = app.textFields["fri.editor.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        title.tap(); title.typeText("Private reminder QA\n")
        let start = Date.now.addingTimeInterval(Double(foreground ? 3 : 7) * 60)
        let components = Calendar.current.dateComponents([.hour, .minute], from: start)
        let time = String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
        let field = app.textFields["fri.editor.time"]
        field.tap(); field.typeText(time + "\n")
        let duration = app.textFields["fri.editor.duration"]
        duration.tap(); duration.typeText("10\n")
        let save = app.buttons["fri.editor.submit"]
        reveal(save, in: app, form: "fri.editor.form"); save.tap()
        XCTAssertTrue(app.buttons["fri.new"].waitForExistence(timeout: 8))
        let body = "You have an appointment soon. Open FRI to view it."
        let appointmentStart = try XCTUnwrap(Calendar.current.dateInterval(of: .minute, for: start)?.start)
        XCTAssertGreaterThan(appointmentStart.timeIntervalSinceNow, 25,
                             "The fixture appointment must still be in the future after UI entry")
        let notice = springboard.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", body)).firstMatch
        if !cancellation.isEmpty {
            let delivery = try XCTUnwrap(Calendar.current.dateInterval(of: .minute, for: start)?.start).addingTimeInterval(-300)
            XCTAssertGreaterThan(delivery.timeIntervalSinceNow, 10, "The cancellation must happen before the reminder is due")
            if cancellation == "disable" {
                settings()
                reveal(reminders, in: app, form: "fri.settings.form")
                reminders.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
                expectation(for: NSPredicate(format: "value == '0'"), evaluatedWith: reminders)
                waitForExpectations(timeout: 8)
                app.buttons["Close"].firstMatch.tap()
            } else {
                let done = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "fri.done.")).firstMatch
                reveal(done, in: app, form: "fri.calendar.content"); done.tap()
                XCTAssertEqual(done.label, "Mark as pending")
            }
            XCTAssertGreaterThan(delivery.timeIntervalSinceNow, 0)
            XCUIDevice.shared.press(.home)
            XCTAssertFalse(notice.waitForExistence(timeout: max(1, delivery.timeIntervalSinceNow + 20)),
                           "The canceled appointment must not notify at its original delivery time")
            XCTAssertGreaterThan(Date.now, delivery)
            let top = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.01))
            let bottom = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.8))
            top.press(forDuration: 0.1, thenDragTo: bottom)
            XCTAssertFalse(notice.exists)
            let canceled = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            canceled.name = "Pending-reminder-canceled-" + cancellation; canceled.lifetime = .keepAlways; add(canceled)
            app.activate()
            XCTAssertTrue(app.buttons["fri.new"].waitForExistence(timeout: 8))
            settings()
            reveal(reminders, in: app, form: "fri.settings.form")
            if cancellation == "complete" {
                XCTAssertEqual(reminders.value as? String, "1", "Completing one task must not disable all reminders")
                reminders.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            }
            expectation(for: NSPredicate(format: "value == '0'"), evaluatedWith: reminders)
            waitForExpectations(timeout: 8)
            return
        }
        if !foreground { XCUIDevice.shared.press(.home) }
        XCTAssertTrue(notice.waitForExistence(timeout: foreground ? 20 : 140), "A real scheduled notification must appear in the tested app state")
        XCTAssertFalse(notice.label.contains("Private reminder QA"))
        if !foreground {
            let top = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.01))
            let bottom = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.8))
            top.press(forDuration: 0.1, thenDragTo: bottom)
            XCTAssertTrue(notice.waitForExistence(timeout: 8))
        } else {
            // Let the system banner finish its entrance before saving visual evidence.
            Thread.sleep(forTimeInterval: 1)
        }
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = foreground ? "System-foreground-reminder-delivered" : "System-local-reminder-delivered"
        shot.lifetime = .keepAlways; add(shot)
        if dismissAndRelaunch {
            app.terminate()
            XCUIDevice.shared.press(.home)
            let top = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.01))
            let bottom = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.8))
            top.press(forDuration: 0.1, thenDragTo: bottom)
            XCTAssertTrue(notice.waitForExistence(timeout: 8))
            notice.swipeLeft()
            // A full swipe can clear immediately; a partial swipe exposes Clear.
            if notice.exists {
                let clear = springboard.buttons.matching(NSPredicate(format: "label IN %@", ["Clear", "Xóa"])).firstMatch
                XCTAssertTrue(clear.waitForExistence(timeout: 8), springboard.debugDescription)
                clear.tap()
            }
            expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: notice)
            waitForExpectations(timeout: 8)
            app.launch()
            XCTAssertTrue(app.buttons["fri.new"].waitForExistence(timeout: 15))
            XCTAssertFalse(notice.waitForExistence(timeout: 20), "A dismissed reminder must not be scheduled again on relaunch")
            XCTAssertGreaterThan(appointmentStart, .now, "Check suppression while the original appointment is still upcoming")
        }
        app.activate()
        XCTAssertTrue(app.buttons["fri.new"].waitForExistence(timeout: 8))
        settings()
        reveal(reminders, in: app, form: "fri.settings.form")
        reminders.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        expectation(for: NSPredicate(format: "value == '0'"), evaluatedWith: reminders)
        waitForExpectations(timeout: 8)
        app.buttons["Close"].firstMatch.tap()
        XCUIDevice.shared.press(.home)
        let top = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.01))
        let bottom = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.8))
        top.press(forDuration: 0.1, thenDragTo: bottom)
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: notice)
        waitForExpectations(timeout: 10)
        let cleared = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        cleared.name = "System-reminder-cleared-after-disable"; cleared.lifetime = .keepAlways; add(cleared)
        app.activate(); app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["fri.new"].waitForExistence(timeout: 15))
        settings()
        reveal(reminders, in: app, form: "fri.settings.form")
        XCTAssertEqual(reminders.value as? String, "0")
    }

    func testSidebarPhotoBackupAndReplacement() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FRI_PHOTO_PICKER_TESTS"] == "1",
                          "Prepare synthetic Files fixtures using apple/Tools/PrepareSidebarPhotoFixtures.py and enable FRI_PHOTO_PICKER_TESTS.")
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["FRI_SYNTHETIC_PREVIEW"] = "1"
        app.launchEnvironment["FRI_TEST_STORE_ID"] = UUID().uuidString
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launch()
        XCTAssertTrue(app.buttons["fri.new"].waitForExistence(timeout: 15))
        guard app.frame.width >= 1000 else { throw XCTSkip("Photo rendering inspection requires the wide iPad sidebar") }
        func folder() {
            XCTAssertTrue(app.otherElements["Browse View (Picker)"].waitForExistence(timeout: 10))
            if app.cells.matching(NSPredicate(format: "label BEGINSWITH %@", "sidebar-desktop-backup")).firstMatch.exists { return }
            let local = app.cells.matching(NSPredicate(format: "label IN %@", ["Trên iPad", "On My iPad"])).firstMatch
            XCTAssertTrue(local.waitForExistence(timeout: 5)); local.tap()
            let photos = app.cells.matching(NSPredicate(format: "label BEGINSWITH %@", "FRI QA Photos")).firstMatch
            XCTAssertTrue(photos.waitForExistence(timeout: 8)); photos.doubleTap()
        }
        func selectFile(_ name: String) {
            folder()
            let file = app.cells.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
            XCTAssertTrue(file.waitForExistence(timeout: 8)); file.tap()
        }
        func screenshot(_ name: String) {
            XCTAssertTrue(app.buttons["fri.sidebar.settings"].waitForExistence(timeout: 8))
            let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            shot.name = name; shot.lifetime = .keepAlways; add(shot)
        }
        app.buttons["fri.actions"].tap(); app.buttons["Restore backup"].tap()
        selectFile("sidebar-desktop-backup")
        XCTAssertTrue(app.alerts["Restore calendar?"].waitForExistence(timeout: 8))
        app.alerts.buttons["Restore"].tap()
        app.buttons["fri.sidebar.settings"].tap()
        XCTAssertTrue(app.buttons["Remove sidebar photo"].waitForExistence(timeout: 8))
        app.buttons["Close"].firstMatch.tap()
        screenshot("Sidebar-desktop-photo")
        app.terminate(); app.launch()
        screenshot("Sidebar-desktop-photo-reopened")
        app.buttons["fri.sidebar.settings"].tap()
        let remove = app.buttons["Remove sidebar photo"]
        XCTAssertTrue(remove.waitForExistence(timeout: 8))
        app.buttons["Choose sidebar photo…"].tap()
        selectFile("sidebar-bands")
        XCTAssertTrue(remove.waitForExistence(timeout: 8))
        app.buttons["Close"].firstMatch.tap()
        screenshot("Sidebar-native-photo")
        app.buttons["fri.actions"].tap(); app.buttons["Export backup"].tap()
        folder()
        let filename = app.textFields["DOCPicker.filenameTextField"]
        XCTAssertTrue(filename.waitForExistence(timeout: 8)); filename.tap()
        let exportName = "sidebar-native-export-" + UUID().uuidString
        filename.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (filename.value as? String ?? "").count) + exportName)
        app.buttons["DOCPicker.actionButton"].tap()
        XCTAssertTrue(app.buttons["fri.sidebar.settings"].waitForExistence(timeout: 8))
        app.buttons["fri.sidebar.settings"].tap()
        XCTAssertTrue(remove.waitForExistence(timeout: 8)); remove.tap()
        XCTAssertFalse(remove.exists)
        app.buttons["Close"].firstMatch.tap()
        app.terminate(); app.launch()
        screenshot("Sidebar-photo-removed")
        app.buttons["fri.sidebar.settings"].tap()
        XCTAssertTrue(app.buttons["Choose sidebar photo…"].waitForExistence(timeout: 8))
        XCTAssertFalse(remove.exists)
        print("SIDEBAR_EXPORTED_FILE " + exportName + ".json")
    }

    func testAvailabilityFileWorkflow() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FRI_AVAILABILITY_PICKER_TESTS"] == "1",
                          "Prepare today's synthetic Files fixtures using apple/Tools/PrepareAvailabilityFixtures.py and enable FRI_AVAILABILITY_PICKER_TESTS.")
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["FRI_SYNTHETIC_PREVIEW"] = "1"
        app.launchEnvironment["FRI_TEST_STORE_ID"] = UUID().uuidString
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.buttons["fri.actions"].waitForExistence(timeout: 15))
        app.buttons["fri.new"].tap(); app.buttons["Schedule"].tap()
        let title = app.textFields["fri.editor.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8)); title.tap(); title.typeText("Private availability fixture\n")
        let time = app.textFields["fri.editor.time"]
        time.tap(); time.typeText("09:00\n")
        let duration = app.textFields["fri.editor.duration"]
        duration.tap(); duration.typeText("60\n")
        let submit = app.buttons["fri.editor.submit"]
        reveal(submit, in: app, form: "fri.editor.form"); submit.tap()
        XCTAssertTrue(app.buttons["fri.actions"].waitForExistence(timeout: 8))
        func openAvailability() {
            app.buttons["fri.actions"].tap(); app.buttons["Find time together"].tap()
            XCTAssertTrue(app.buttons["Compare a free-time file"].waitForExistence(timeout: 8))
        }
        func cancelPicker() {
            if app.buttons["Cancel"].exists {
                app.buttons["Cancel"].tap()
            } else {
                app.buttons["TopOverflowBarButtonItem"].tap()
                let cancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["Cancel", "Hủy"])).firstMatch
                XCTAssertTrue(cancel.waitForExistence(timeout: 5)); cancel.tap()
            }
            let dismissed = NSPredicate(format: "exists == false")
            expectation(for: dismissed, evaluatedWith: app.otherElements["Browse View (Picker)"])
            waitForExpectations(timeout: 8)
        }
        func openFixtureFolder() {
            // Files remembers the last folder; no navigation is needed if already there.
            if app.cells.matching(NSPredicate(format: "label BEGINSWITH %@", "matching.json")).firstMatch.exists { return }
            let local = app.cells.matching(NSPredicate(format: "label IN %@", ["Trên iPad", "Trên iPhone", "On My iPad", "On My iPhone"])).firstMatch
            if !local.exists {
                let browse = app.buttons.matching(NSPredicate(format: "label IN %@", ["Browse", "Duyệt"])).firstMatch
                XCTAssertTrue(browse.waitForExistence(timeout: 5)); browse.tap()
            }
            XCTAssertTrue(local.waitForExistence(timeout: 5)); local.tap()
            let folder = app.cells.matching(NSPredicate(format: "label BEGINSWITH %@", "FRI QA Availability")).firstMatch
            XCTAssertTrue(folder.waitForExistence(timeout: 8)); folder.doubleTap()
        }
        func compare(_ name: String) {
            openAvailability(); app.buttons["Compare a free-time file"].tap()
            XCTAssertTrue(app.otherElements["Browse View (Picker)"].waitForExistence(timeout: 10))
            openFixtureFolder()
            let file = app.cells.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
            XCTAssertTrue(file.waitForExistence(timeout: 10)); file.tap()
        }
        compare("matching")
        XCTAssertTrue(app.staticTexts["Shared free time"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts.matching(identifier: "10:00–10:30").count, 1)
        XCTAssertFalse(app.staticTexts["11:00–11:25"].exists)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "Availability-shared-window"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["Close"].tap()
        compare("no-match")
        XCTAssertTrue(app.staticTexts["No shared slots of at least 30 minutes."].waitForExistence(timeout: 10))
        app.buttons["Close"].tap()
        for (name, message) in [
            ("invalid", "Choose a valid FRI free-time file. Calendar backups cannot be compared here."),
            ("oversized", "Choose a free-time file no larger than 1 MB.")
        ] {
            compare(name)
            XCTAssertTrue(app.staticTexts[message].waitForExistence(timeout: 10))
            app.buttons["Dismiss"].tap()
            XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Private availability fixture")).firstMatch.exists)
        }
        openAvailability(); app.buttons["Compare a free-time file"].tap()
        XCTAssertTrue(app.otherElements["Browse View (Picker)"].waitForExistence(timeout: 10)); cancelPicker()
        XCTAssertTrue(app.buttons["fri.actions"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["Dismiss"].exists)
        openAvailability(); app.buttons["Export my free time"].tap()
        XCTAssertTrue(app.otherElements["Browse View (Picker)"].waitForExistence(timeout: 10))
        cancelPicker()
        XCTAssertFalse(app.buttons["Dismiss"].exists)
        openAvailability(); app.buttons["Export my free time"].tap()
        XCTAssertTrue(app.otherElements["Browse View (Picker)"].waitForExistence(timeout: 10))
        openFixtureFolder()
        let filename = app.textFields["DOCPicker.filenameTextField"]
        XCTAssertTrue(filename.waitForExistence(timeout: 8)); filename.tap()
        let exportName = "availability-export-" + UUID().uuidString
        filename.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (filename.value as? String ?? "").count) + exportName)
        app.buttons["DOCPicker.actionButton"].tap()
        XCTAssertTrue(app.buttons["fri.actions"].waitForExistence(timeout: 8))
        compare(exportName)
        XCTAssertTrue(app.staticTexts["Shared free time"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["10:00–18:00"].exists)
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Private availability fixture")).firstMatch.exists)
        print("AVAILABILITY_EXPORTED_FILE " + exportName + ".json")
    }

    func testPlannerValidationAndReviewHandoff() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["FRI_SYNTHETIC_PREVIEW"] = "1"
        app.launchEnvironment["FRI_TEST_STORE_ID"] = UUID().uuidString
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launch()
        XCTAssertTrue(app.buttons["fri.new"].waitForExistence(timeout: 15))
        app.buttons["fri.new"].tap(); app.buttons["Schedule"].tap()
        let editorTitle = app.textFields["fri.editor.title"]
        XCTAssertTrue(editorTitle.waitForExistence(timeout: 8))
        editorTitle.tap(); editorTitle.typeText("Unrelated saved draft")
        app.buttons["Close"].firstMatch.tap()
        app.buttons["fri.actions"].tap(); app.buttons["Find time for a task"].tap()
        let find = app.buttons["fri.planner.find"]
        XCTAssertTrue(find.waitForExistence(timeout: 8))
        find.tap()
        XCTAssertTrue(app.staticTexts["fri.planner.result"].label.contains("Enter a task name"))
        let title = app.textFields["fri.planner.title"]
        title.tap(); title.typeText("Write the project report\n")
        let deadline = app.textFields["fri.planner.deadline"]
        func replace(_ field: XCUIElement, with value: String) {
            reveal(field, in: app, form: "fri.planner.form")
            field.tap()
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (field.value as? String ?? "").count) + value + "\n")
        }
        replace(deadline, with: "09:00")
        reveal(find, in: app, form: "fri.planner.form"); find.tap()
        XCTAssertTrue(app.staticTexts["fri.planner.result"].label.contains("after 09:00"))
        replace(deadline, with: "09:30")
        reveal(find, in: app, form: "fri.planner.form"); find.tap()
        XCTAssertEqual(app.staticTexts["fri.planner.result"].label, "You need 30 more free minutes.")
        replace(app.textFields["fri.planner.duration"], with: "30")
        reveal(find, in: app, form: "fri.planner.form"); find.tap()
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Write the project report")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 8), "A complete proposal must save through the review flow, not open a blank editor")
        reveal(card, in: app, form: "fri.calendar.content")
        XCTAssertTrue(card.label.contains("09:00"))
        XCTAssertTrue(card.label.contains("30 min"))
        let savedShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        savedShot.name = "Planner-saved-proposal"; savedShot.lifetime = .keepAlways; add(savedShot)
        app.terminate(); app.launch()
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        app.buttons["fri.new"].tap(); app.buttons["Resume drafts"].tap()
        let unrelated = app.buttons["Unrelated saved draft"]
        reveal(unrelated, in: app, form: "fri.editor.form")
        XCTAssertTrue(unrelated.exists)
        XCTAssertFalse(app.buttons["Write the project report"].exists)
    }

    func testPlannerDateSelection() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["FRI_SYNTHETIC_PREVIEW"] = "1"
        app.launchEnvironment["FRI_TEST_STORE_ID"] = UUID().uuidString
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.buttons["fri.actions"].waitForExistence(timeout: 15))
        app.buttons["fri.actions"].tap(); app.buttons["Find time for a task"].tap()
        let picker = app.datePickers["fri.planner.date"]
        XCTAssertTrue(picker.waitForExistence(timeout: 8))
        let gregorian = Calendar(identifier: .gregorian)
        let day = gregorian.component(.day, from: Date()) == 15 ? 16 : 15
        var components = gregorian.dateComponents([.year, .month], from: Date())
        components.day = day
        let chosenDate = try XCTUnwrap(gregorian.date(from: components))
        let month = DateFormatter(); month.locale = Locale(identifier: "en_GB"); month.dateFormat = "MMMM"
        picker.tap()
        let choice = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", ", \(day) \(month.string(from: chosenDate))")).firstMatch
        XCTAssertTrue(choice.waitForExistence(timeout: 5)); choice.tap()
        let dismiss = app.buttons["PopoverDismissRegion"]
        if dismiss.exists { dismiss.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap() }
        let title = app.textFields["fri.planner.title"]
        title.tap(); title.typeText("Plan on another date\n")
        let find = app.buttons["fri.planner.find"]
        reveal(find, in: app, form: "fri.planner.form"); find.tap()
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Plan on another date")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        let key = DateFormatter(); key.locale = Locale(identifier: "en_US_POSIX"); key.dateFormat = "yyyy-MM-dd"
        XCTAssertTrue(app.buttons["fri.tab.\(key.string(from: chosenDate))"].isSelected)
        app.buttons["fri.actions"].tap(); app.buttons["Find time for a task"].tap()
        XCTAssertTrue(picker.waitForExistence(timeout: 8))
        picker.tap()
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        XCTAssertTrue(choice.isSelected, "Planner must default to the active calendar day")
        if dismiss.exists { dismiss.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap() }
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "Planner-selected-day"; shot.lifetime = .keepAlways; add(shot)
    }

    func testYearMonthNavigationAndLeapDay() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["FRI_SYNTHETIC_PREVIEW"] = "1"
        app.launchEnvironment["FRI_TEST_STORE_ID"] = UUID().uuidString
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launch()
        XCTAssertTrue(app.buttons["fri.new"].waitForExistence(timeout: 15))
        app.buttons["fri.navigation.menu"].tap()
        app.buttons["fri.navigation.year"].tap()
        let heading = app.staticTexts["fri.calendar.heading"]
        let currentYear = Calendar(identifier: .gregorian).component(.year, from: Date())
        XCTAssertEqual(heading.value as? String, String(currentYear))
        let next = app.buttons["fri.calendar.next"]
        let previous = app.buttons["fri.calendar.previous"]
        reveal(next, in: app, form: "fri.calendar.content")
        XCTAssertGreaterThanOrEqual(next.frame.height, 44)
        XCTAssertGreaterThanOrEqual(previous.frame.width, 44)
        next.tap()
        XCTAssertEqual(heading.value as? String, String(currentYear + 1))
        previous.tap()
        XCTAssertEqual(heading.value as? String, String(currentYear))
        let yearShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        yearShot.name = "Year-mini-calendars"; yearShot.lifetime = .keepAlways; add(yearShot)
        var leapYear = currentYear
        while !(leapYear % 4 == 0 && (leapYear % 100 != 0 || leapYear % 400 == 0)) {
            next.tap()
            leapYear += 1
        }
        let february = app.buttons["fri.calendar.month.\(leapYear)-02"]
        reveal(february, in: app, form: "fri.calendar.content")
        february.tap()
        XCTAssertEqual(heading.value as? String, "\(leapYear)-02")
        // LazyVGrid exposes only instantiated rows. Inspect both ends of the
        // month before asserting all six weeks, independent of scroll position.
        let dayButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "fri.calendar.day."))
        var observedDays = Set(dayButtons.allElementsBoundByIndex.map(\.identifier))
        let gregorian = Calendar(identifier: .gregorian)
        let firstOfFebruary = try XCTUnwrap(gregorian.date(from: DateComponents(year: leapYear, month: 2, day: 1, hour: 12)))
        let firstGridDay = try XCTUnwrap(gregorian.date(byAdding: .day, value: 1 - gregorian.component(.weekday, from: firstOfFebruary), to: firstOfFebruary))
        let lastGridDay = try XCTUnwrap(gregorian.date(byAdding: .day, value: 41, to: firstGridDay))
        let dateKey = DateFormatter()
        dateKey.calendar = gregorian
        dateKey.locale = Locale(identifier: "en_US_POSIX")
        dateKey.dateFormat = "yyyy-MM-dd"
        let lastDay = app.buttons["fri.calendar.day.\(dateKey.string(from: lastGridDay))"]
        reveal(lastDay, in: app, form: "fri.calendar.content")
        observedDays.formUnion(dayButtons.allElementsBoundByIndex.map(\.identifier))
        let firstDay = app.buttons["fri.calendar.day.\(dateKey.string(from: firstGridDay))"]
        reveal(firstDay, in: app, form: "fri.calendar.content", upward: false)
        observedDays.formUnion(dayButtons.allElementsBoundByIndex.map(\.identifier))
        XCTAssertEqual(observedDays.count, 42)
        let leapDay = app.buttons["fri.calendar.day.\(leapYear)-02-29"]
        reveal(leapDay, in: app, form: "fri.calendar.content")
        XCTAssertGreaterThanOrEqual(leapDay.frame.height, 44)
        XCTAssertEqual(leapDay.frame.width, leapDay.frame.height, accuracy: 2)
        let monthShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        monthShot.name = "Month-leap-day"; monthShot.lifetime = .keepAlways; add(monthShot)
        leapDay.tap()
        XCTAssertTrue(app.buttons["fri.tab.\(leapYear)-02-29"].isSelected)
        let openMonth = app.buttons["Open month calendar"]
        reveal(openMonth, in: app, form: "fri.calendar.content", upward: false)
        openMonth.tap()
        reveal(next, in: app, form: "fri.calendar.content")
        next.tap()
        XCTAssertEqual(heading.value as? String, "\(leapYear)-03")
        let marchLast = app.buttons["fri.calendar.day.\(leapYear)-03-31"]
        reveal(marchLast, in: app, form: "fri.calendar.content")
        marchLast.tap()
        reveal(openMonth, in: app, form: "fri.calendar.content", upward: false)
        openMonth.tap()
        reveal(previous, in: app, form: "fri.calendar.content")
        previous.tap()
        XCTAssertEqual(heading.value as? String, "\(leapYear)-02", "Paging from March 31 must reach February")

        app.buttons["fri.navigation.menu"].tap()
        app.buttons["Settings"].tap()
        let larger = app.switches["fri.settings.largeText"]
        reveal(larger, in: app, form: "fri.settings.form")
        larger.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        reveal(larger, in: app, form: "fri.settings.form")
        XCTAssertEqual(larger.value as? String, "1")
        app.buttons["Close"].firstMatch.tap()
        app.buttons["fri.navigation.menu"].tap()
        app.buttons["fri.navigation.year"].tap()
        let january = app.buttons["fri.calendar.month.\(leapYear)-01"]
        reveal(january, in: app, form: "fri.calendar.content", upward: false)
        XCTAssertTrue(app.frame.contains(january.frame))
        XCTAssertEqual(january.frame.width, january.frame.height, accuracy: 2)
        let largeShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        largeShot.name = "Year-larger-text-portrait"; largeShot.lifetime = .keepAlways; add(largeShot)
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertEqual(heading.value as? String, String(leapYear))
        reveal(january, in: app, form: "fri.calendar.content", upward: false)
        let landscapeShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        landscapeShot.name = "Year-larger-text-landscape"; landscapeShot.lifetime = .keepAlways; add(landscapeShot)
        let viewport = app.scrollViews["fri.calendar.content"].frame.intersection(app.frame)
        XCTAssertTrue(viewport.contains(january.frame), "Complete month tile \(january.frame) must fit in the visible calendar \(viewport)")
        january.tap()
        XCTAssertEqual(heading.value as? String, "\(leapYear)-01")
    }

    func testSidebarAndUpNextWithLargerText() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["FRI_SYNTHETIC_PREVIEW"] = "1"
        app.launchEnvironment["FRI_TEST_STORE_ID"] = UUID().uuidString
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launch()
        XCTAssertTrue(app.buttons["fri.new"].waitForExistence(timeout: 15))
        guard app.frame.width >= 1000 else { throw XCTSkip("Wide sidebar layout requires an iPad landscape destination") }
        let settings = app.buttons["fri.sidebar.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 8))
        let google = app.buttons["fri.sidebar.google"]
        reveal(google, in: app, form: "fri.sidebar.content")
        let ordinaryHeight = google.frame.height
        settings.tap()
        let larger = app.switches["fri.settings.largeText"]
        reveal(larger, in: app, form: "fri.settings.form")
        larger.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        reveal(larger, in: app, form: "fri.settings.form")
        XCTAssertEqual(larger.value as? String, "1")
        app.buttons["Close"].firstMatch.tap()
        XCTAssertTrue(settings.isHittable)
        XCTAssertTrue(app.frame.contains(settings.frame))
        XCTAssertGreaterThanOrEqual(settings.frame.height, 44)
        XCTAssertGreaterThanOrEqual(app.buttons["fri.sidebar.services"].frame.height, 44)
        reveal(google, in: app, form: "fri.sidebar.content")
        XCTAssertGreaterThan(google.frame.height, ordinaryHeight * 1.25, "Quick-link text must wrap instead of truncating")
        let music = app.buttons["fri.sidebar.music"]
        reveal(music, in: app, form: "fri.sidebar.content")
        XCTAssertTrue(settings.isHittable, "Settings must remain available while the sidebar scrolls")
        music.tap()
        XCTAssertTrue(app.buttons["Close"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Services"].firstMatch.exists)
        app.buttons["Close"].firstMatch.tap()
        let empty = app.staticTexts["fri.upNext.emptyMessage"]
        reveal(empty, in: app, form: "fri.calendar.content")
        XCTAssertGreaterThan(empty.frame.height, 60, "The narrow Up next card must show the complete multiline message")
        XCTAssertTrue(app.frame.contains(empty.frame))
        let upcoming = app.buttons["fri.upNext.toggle"]
        reveal(upcoming, in: app, form: "fri.calendar.content")
        let remaining = app.staticTexts["fri.upNext.remaining"]
        XCTAssertGreaterThanOrEqual(upcoming.frame.height, 44)
        XCTAssertGreaterThanOrEqual(upcoming.frame.minY, remaining.frame.maxY,
                                    "The narrow card footer must stack rather than truncate its labels")
        let beforeToggle = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        beforeToggle.name = "Up-next-before-toggle"; beforeToggle.lifetime = .keepAlways; add(beforeToggle)
        upcoming.tap()
        XCTAssertEqual(upcoming.value as? String, "Expanded")
        upcoming.tap()
        XCTAssertEqual(upcoming.value as? String, "Collapsed")
        let card = app.descendants(matching: .any)["fri.upNext.card"].firstMatch
        XCTAssertTrue(card.frame.contains(upcoming.frame), "The footer must remain inside the Up next card")
        XCTAssertTrue(card.frame.contains(empty.frame), "The complete description must remain inside the card")
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "Sidebar-and-Up-next-larger-text"; shot.lifetime = .keepAlways; add(shot)
        settings.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()
        reveal(larger, in: app, form: "fri.settings.form")
        XCTAssertEqual(larger.value as? String, "1")
    }

    func testDayConversationWithLargerTextAndKeyboard() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["FRI_SYNTHETIC_PREVIEW"] = "1"
        app.launchEnvironment["FRI_TEST_STORE_ID"] = UUID().uuidString
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launch()
        XCTAssertTrue(app.buttons["fri.new"].waitForExistence(timeout: 15))
        app.buttons["fri.navigation.menu"].tap(); app.buttons["Settings"].tap()
        let larger = app.switches["fri.settings.largeText"]
        reveal(larger, in: app, form: "fri.settings.form")
        larger.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        reveal(larger, in: app, form: "fri.settings.form")
        XCTAssertEqual(larger.value as? String, "1")
        app.buttons["Close"].firstMatch.tap()
        let talk = app.buttons["Talk to Day"]
        reveal(talk, in: app, form: "fri.calendar.content"); talk.tap()
        let field = app.textFields["fri.day.message"]
        reveal(field, in: app, form: "fri.day.content")
        XCTAssertGreaterThanOrEqual(field.frame.height, 44)
        field.tap(); field.typeText("Room to breathe\n")
        let firstMessage = app.staticTexts["Room to breathe"]
        reveal(firstMessage, in: app, form: "fri.day.content", upward: false)
        XCTAssertTrue(firstMessage.exists)
        let portrait = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        portrait.name = "Day-larger-text-portrait"; portrait.lifetime = .keepAlways; add(portrait)
        XCUIDevice.shared.orientation = .landscapeLeft
        reveal(field, in: app, form: "fri.day.content")
        field.tap(); field.typeText("Another calm thought\n")
        let secondMessage = app.staticTexts["Another calm thought"]
        reveal(secondMessage, in: app, form: "fri.day.content", upward: false)
        XCTAssertTrue(secondMessage.exists)
        XCTAssertTrue(secondMessage.isHittable)
        XCTAssertTrue(app.scrollViews["fri.day.content"].frame.intersection(app.frame).contains(secondMessage.frame))
        let landscape = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        landscape.name = "Day-larger-text-landscape"; landscape.lifetime = .keepAlways; add(landscape)
        app.buttons["Close"].firstMatch.tap()
        reveal(talk, in: app, form: "fri.calendar.content"); talk.tap()
        reveal(secondMessage, in: app, form: "fri.day.content")
        XCTAssertTrue(secondMessage.waitForExistence(timeout: 8))
        reveal(field, in: app, form: "fri.day.content")
        XCTAssertFalse(app.buttons["fri.day.send"].isEnabled)
    }

    func testDayDraftHandoffAndRotation() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["FRI_SYNTHETIC_PREVIEW"] = "1"
        app.launchEnvironment["FRI_TEST_STORE_ID"] = UUID().uuidString
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launch()
        XCTAssertTrue(app.buttons["fri.new"].waitForExistence(timeout: 15))
        app.buttons["fri.new"].tap(); app.buttons["Schedule"].tap()
        let title = app.textFields["fri.editor.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        title.tap(); title.typeText("Keep separate from Day")
        app.buttons["Close"].firstMatch.tap()
        let talk = app.buttons["Talk to Day"]
        reveal(talk, in: app, form: "fri.calendar.content")
        talk.tap()
        let greeting = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Hi, I’m Day.")).firstMatch
        XCTAssertTrue(greeting.waitForExistence(timeout: 8))
        let upcoming = app.buttons["What’s coming up?"]
        reveal(upcoming, in: app, form: "fri.day.content")
        XCTAssertGreaterThanOrEqual(upcoming.frame.height, 44)
        upcoming.tap()
        let reply = app.staticTexts["You have a little breathing room. There are no unfinished plans on this day."]
        XCTAssertTrue(reply.waitForExistence(timeout: 5))
        app.buttons["Close"].firstMatch.tap()
        reveal(talk, in: app, form: "fri.calendar.content")
        talk.tap()
        XCTAssertTrue(reply.waitForExistence(timeout: 8), "Closing Day must retain the conversation for this app session")
        let conversation = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        conversation.name = "Day-conversation-portrait"; conversation.lifetime = .keepAlways; add(conversation)
        XCTAssertTrue(app.buttons["Make time for a walk"].waitForExistence(timeout: 8))
        reveal(app.buttons["Make time for a walk"], in: app, form: "fri.day.content")
        app.buttons["Make time for a walk"].tap()
        reveal(app.buttons["fri.day.create"], in: app, form: "fri.day.content", upward: false)
        app.buttons["fri.day.create"].tap()
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        XCTAssertEqual(title.value as? String, "A little walk", "Day must open the suggested draft, not a blank composition")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertEqual(title.value as? String, "A little walk")
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "Day-draft-landscape"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["Close"].firstMatch.tap()
        app.buttons["fri.new"].tap(); app.buttons["Resume drafts"].tap()
        let saved = app.buttons["A little walk"]
        reveal(saved, in: app, form: "fri.editor.form")
        XCTAssertEqual(app.buttons.matching(identifier: "A little walk").count, 1)
        // The whole selection row must respond, including the space after its title.
        saved.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)).tap()
        reveal(title, in: app, form: "fri.editor.form", upward: false)
        XCTAssertEqual(title.value as? String, "A little walk")
        let time = app.textFields["fri.editor.time"]
        reveal(time, in: app, form: "fri.editor.form")
        time.tap(); time.typeText("09:30\n")
        let duration = app.textFields["fri.editor.duration"]
        reveal(duration, in: app, form: "fri.editor.form")
        duration.tap(); duration.typeText("25\n")
        let done = app.buttons["fri.editor.submit"]
        reveal(done, in: app, form: "fri.editor.form"); done.tap()
        XCTAssertTrue(app.buttons["fri.new"].waitForExistence(timeout: 10))
        let walk = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "A little walk")).firstMatch
        XCTAssertTrue(walk.waitForExistence(timeout: 8))
        let calendarShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        calendarShot.name = "Day-plan-landscape"; calendarShot.lifetime = .keepAlways; add(calendarShot)
        app.buttons["fri.new"].tap(); app.buttons["Resume drafts"].tap()
        let unrelated = app.buttons["Keep separate from Day"]
        reveal(unrelated, in: app, form: "fri.editor.form")
        XCTAssertTrue(unrelated.exists)
        XCTAssertFalse(app.buttons["A little walk"].exists)
    }

    func testSpotifyEmbeddedPlayerAndDisconnect() throws {
        guard ProcessInfo.processInfo.environment["FRI_SPOTIFY_NETWORK_TEST"] == "1" else {
            throw XCTSkip("Opt-in live Spotify embed; no account sign-in or paid subscription is used.")
        }
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["FRI_SYNTHETIC_PREVIEW"] = "1"
        app.launchEnvironment["FRI_TEST_STORE_ID"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["fri.new"].waitForExistence(timeout: 15))
        app.buttons["fri.navigation.menu"].tap()
        app.buttons["Services"].tap()
        let field = app.textFields["fri.services.spotify.url"]
        reveal(field, in: app, form: "fri.services.form")
        field.tap()
        field.typeText("https://example.com/track/abc")
        let open = app.buttons["fri.services.spotify.open"]
        reveal(open, in: app, form: "fri.services.form")
        open.tap()
        XCTAssertTrue(app.staticTexts["Use a Spotify playlist, album, track or episode link."].waitForExistence(timeout: 5))
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "https://example.com/track/abc".count))
        field.typeText("https://open.spotify.com/episode/7makk4oTQel546B0PZlDM5?si=qa")
        reveal(open, in: app, form: "fri.services.form")
        open.tap()
        let close = app.buttons["fri.spotify.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        let episode = app.webViews.links.matching(NSPredicate(format: "label == %@", "My Path to Spotify: Women in Engineering")).firstMatch
        XCTAssertTrue(episode.waitForExistence(timeout: 30), app.debugDescription)
        XCTAssertFalse(app.staticTexts["fri.spotify.error"].exists)
        XCTAssertGreaterThanOrEqual(app.webViews.firstMatch.frame.width, 280)
        app.buttons["fri.spotify.reload"].tap()
        XCTAssertTrue(episode.waitForExistence(timeout: 30))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Spotify-embedded-episode-iOS"; shot.lifetime = .keepAlways; add(shot)
        close.tap()
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        app.buttons["Close"].firstMatch.tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["fri.new"].waitForExistence(timeout: 15))
        app.buttons["fri.navigation.menu"].tap(); app.buttons["Services"].tap()
        reveal(field, in: app, form: "fri.services.form")
        XCTAssertEqual(field.value as? String, "https://open.spotify.com/episode/7makk4oTQel546B0PZlDM5")
        reveal(open, in: app, form: "fri.services.form"); open.tap()
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        app.buttons["fri.spotify.disconnect"].tap()
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Disconnect Spotify"].exists)
        XCTAssertEqual(field.value as? String, "Spotify link")
        app.buttons["Close"].firstMatch.tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["fri.new"].waitForExistence(timeout: 15))
        app.buttons["fri.navigation.menu"].tap(); app.buttons["Services"].tap()
        reveal(field, in: app, form: "fri.services.form")
        XCTAssertEqual(field.value as? String, "Spotify link")
        XCTAssertFalse(app.buttons["Disconnect Spotify"].exists)
    }

    func testWeatherCityChoiceRefreshAndPersistence() throws {
        guard ProcessInfo.processInfo.environment["FRI_WEATHER_NETWORK_TEST"] == "1" else {
            throw XCTSkip("Opt-in live Open-Meteo interaction; offline behavior is covered by core transport tests.")
        }
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["FRI_SYNTHETIC_PREVIEW"] = "1"
        app.launchEnvironment["FRI_TEST_STORE_ID"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["fri.new"].waitForExistence(timeout: 15))
        app.buttons["fri.navigation.menu"].tap()
        app.buttons["Services"].tap()
        let city = app.textFields["fri.services.weather.city"]
        XCTAssertTrue(city.waitForExistence(timeout: 5))
        city.tap()
        city.typeText("Paris")
        app.buttons["Find city"].tap()
        let texas = app.buttons["fri.services.weather.location.4717560"]
        XCTAssertTrue(texas.waitForExistence(timeout: 20))
        reveal(texas, in: app, form: "fri.services.form")
        texas.tap()
        let refresh = app.buttons["Refresh saved forecast"]
        XCTAssertTrue(refresh.waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Paris, Texas, United States"].exists)
        let range = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "High ")).firstMatch
        reveal(range, in: app, form: "fri.services.form")
        XCTAssertTrue(range.exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Weather-chosen-city-iOS"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["Close"].firstMatch.tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["fri.new"].waitForExistence(timeout: 15))
        app.buttons["fri.navigation.menu"].tap()
        app.buttons["Services"].tap()
        XCTAssertTrue(refresh.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Paris, Texas, United States"].exists)
        reveal(refresh, in: app, form: "fri.services.form")
        refresh.tap()
        XCTAssertTrue(refresh.waitForExistence(timeout: 20))
        // Wait for the button to re-enable after the asynchronous refresh.
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: refresh)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 20), .completed)
        XCTAssertFalse(app.staticTexts["Forecast unavailable. FRI kept the last saved forecast."].exists)
        let disconnect = app.buttons["Disconnect weather"]
        reveal(disconnect, in: app, form: "fri.services.form")
        disconnect.tap()
        XCTAssertFalse(refresh.exists)
        app.buttons["Close"].firstMatch.tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["fri.new"].waitForExistence(timeout: 15))
        app.buttons["fri.navigation.menu"].tap()
        app.buttons["Services"].tap()
        XCTAssertTrue(city.waitForExistence(timeout: 5))
        XCTAssertFalse(disconnect.exists)
        XCTAssertFalse(refresh.exists)
    }

    func testMapsSearchDraftPersistenceAndDisconnect() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FRI_MAPS_NETWORK_TEST"] == "1",
                          "Opt-in live Apple Maps interaction on a QA Simulator")
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["FRI_SYNTHETIC_PREVIEW"] = "1"
        app.launchEnvironment["FRI_TEST_STORE_ID"] = UUID().uuidString
        app.launch()
        func openServices() {
            XCTAssertTrue(app.buttons["fri.new"].waitForExistence(timeout: 15))
            app.buttons["fri.navigation.menu"].tap(); app.buttons["Services"].tap()
        }
        openServices()
        let field = app.textFields["fri.services.maps.query"]
        let search = app.buttons["Show on map"]
        let saved = app.staticTexts["fri.services.maps.saved"]
        func enter(_ value: String) {
            reveal(field, in: app, form: "fri.services.form", upward: false)
            field.tap()
            let old = field.value as? String ?? ""
            if old != "City or place" { field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count)) }
            field.typeText(value)
        }
        func requireSaved(_ value: String) {
            reveal(saved, in: app, form: "fri.services.form")
            let expected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Saved place: \(value)"), object: saved)
            XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 30), .completed)
            reveal(saved, in: app, form: "fri.services.form")
            XCTAssertTrue(saved.isHittable)
        }
        reveal(search, in: app, form: "fri.services.form")
        XCTAssertFalse(search.isEnabled)
        enter("New York\n")
        requireSaved("New York")
        let map = app.descendants(matching: .any).matching(identifier: "fri.services.maps.preview").firstMatch
        reveal(map, in: app, form: "fri.services.form", upward: false)
        XCTAssertTrue(map.exists && map.isHittable)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Maps-saved-place"; screenshot.lifetime = .keepAlways; add(screenshot)
        enter("Unsubmitted place")
        XCTAssertEqual(saved.label, "Saved place: New York", "Editing a draft must retain the previously saved place")
        app.buttons["Close"].firstMatch.tap(); openServices()
        reveal(field, in: app, form: "fri.services.form")
        XCTAssertEqual(field.value as? String, "New York")
        enter("Tokyo\n"); requireSaved("Tokyo")
        app.buttons["Close"].firstMatch.tap(); app.terminate(); app.launch(); openServices()
        reveal(field, in: app, form: "fri.services.form")
        XCTAssertEqual(field.value as? String, "Tokyo")
        requireSaved("Tokyo")
        let disconnect = app.buttons["Disconnect maps"]
        reveal(disconnect, in: app, form: "fri.services.form"); disconnect.tap()
        XCTAssertFalse(saved.exists)
        reveal(field, in: app, form: "fri.services.form", upward: false)
        XCTAssertEqual(field.value as? String, "City or place")
        XCTAssertFalse(search.isEnabled)
        app.buttons["Close"].firstMatch.tap(); app.terminate(); app.launch(); openServices()
        reveal(field, in: app, form: "fri.services.form")
        XCTAssertEqual(field.value as? String, "City or place")
        XCTAssertFalse(saved.exists)
        XCTAssertFalse(disconnect.exists)
    }

    func testLargerTextReachesEditorAndRestoresLook() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["FRI_SYNTHETIC_PREVIEW"] = "1"
        app.launchEnvironment["FRI_TEST_STORE_ID"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["fri.new"].waitForExistence(timeout: 15))
        let month = app.buttons["Open month calendar"]
        XCTAssertFalse((month.value as? String ?? "").isEmpty, "The selected date must be available to assistive technology")
        app.buttons["fri.new"].tap()
        app.buttons["Schedule"].tap()
        let title = app.textFields["fri.editor.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        let ordinaryHeight = title.frame.height
        app.buttons["Close"].firstMatch.tap()

        app.buttons["fri.navigation.menu"].tap()
        app.buttons["Settings"].tap()
        let larger = app.switches["fri.settings.largeText"]
        reveal(larger, in: app, form: "fri.settings.form")
        larger.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        reveal(larger, in: app, form: "fri.settings.form")
        XCTAssertEqual(larger.value as? String, "1")
        app.buttons["Close"].firstMatch.tap()
        app.buttons["fri.new"].tap()
        app.buttons["One-time deadline"].tap()
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(title.frame.height, ordinaryHeight * 1.1,
                             "Larger text must apply inside presented editors")
        title.tap()
        title.typeText("Readable deadline")
        reveal(app.buttons["fri.editor.submit"], in: app, form: "fri.editor.form")
        app.buttons["fri.editor.submit"].tap()
        let time = app.textFields["fri.editor.missingTime"]
        XCTAssertTrue(time.waitForExistence(timeout: 5))
        time.tap()
        time.typeText("17:30")
        app.buttons["fri.editor.continue"].tap()
        XCTAssertTrue(app.buttons["fri.new"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Calendar-with-larger-text"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.buttons["fri.navigation.menu"].tap()
        app.buttons["Settings"].tap()
        reveal(app.buttons["Restore look"], in: app, form: "fri.settings.form")
        app.buttons["Restore look"].tap()
        reveal(larger, in: app, form: "fri.settings.form", upward: false)
        XCTAssertEqual(larger.value as? String, "0")
        app.buttons["Close"].firstMatch.tap()
        app.buttons["fri.new"].tap()
        app.buttons["Schedule"].tap()
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.frame.height, ordinaryHeight, accuracy: 1)
    }
    #endif

    private func reveal(_ element: XCUIElement, in app: XCUIApplication, form: String, upward: Bool = true) {
        let scroll = app.descendants(matching: .any)[form].firstMatch
        for _ in 0..<(form == "fri.calendar.content" ? 12 : 6) {
            var visible = scroll.frame.intersection(app.frame).insetBy(dx: 0, dy: form == "fri.calendar.content" ? 4 : 12)
            if form == "fri.import.form" || form == "fri.services.form" || form == "fri.widget.gallery" {
                let feedback = app.descendants(matching: .any)["fri.import.feedback"].firstMatch
                if feedback.exists {
                    visible.size.height = max(0, min(visible.maxY, feedback.frame.minY - 8) - visible.minY)
                }
                let navigation = app.navigationBars.firstMatch
                if navigation.exists && navigation.frame.intersects(visible) {
                    let bottom = visible.maxY
                    visible.origin.y = max(visible.minY, navigation.frame.maxY + 8)
                    visible.size.height = max(0, bottom - visible.minY)
                }
            }
            if app.keyboards.firstMatch.exists {
                visible.size.height = max(0, min(visible.maxY, app.keyboards.firstMatch.frame.minY - 100) - visible.minY)
            }
            // A partially visible row can be hittable while its switch is below
            // the viewport. Reveal the complete control before interacting.
            if element.exists && element.isHittable && visible.contains(element.frame) { return }
            #if os(iOS)
            if app.keyboards.firstMatch.exists {
                // The form's AX frame can extend behind the keyboard. Start the
                // gesture in its visible content, as a person scrolling would.
                let top = scroll.frame.minY + 30
                // Keyboard AX bounds exclude the prediction/accessory strip.
                let bottom = min(scroll.frame.maxY - 30, app.keyboards.firstMatch.frame.minY - 100)
                let origin = scroll.coordinate(withNormalizedOffset: .zero)
                let from = origin.withOffset(CGVector(dx: scroll.frame.width / 2, dy: (upward ? bottom : top) - scroll.frame.minY))
                let to = origin.withOffset(CGVector(dx: scroll.frame.width / 2, dy: (upward ? top : bottom) - scroll.frame.minY))
                from.press(forDuration: 0.05, thenDragTo: to)
            } else if form == "fri.calendar.content" || form == "fri.services.form" || form == "fri.widget.gallery" || (form == "fri.import.form" && element.exists) {
                // Calendar tiles can be partly visible at the edge. Short drags avoid
                // flinging past an entire row; reverse when the target is above us.
                let target = element.exists ? element.frame : .null
                let towardsBottom = target.isNull ? upward : target.maxY > visible.maxY
                let origin = scroll.coordinate(withNormalizedOffset: .zero)
                let startY = towardsBottom ? visible.maxY - 24 : visible.minY + 24
                let overflow = target.isNull ? visible.height : (towardsBottom ? target.maxY - visible.maxY : visible.minY - target.minY)
                let delta = min(visible.height * 0.3, max(20, overflow + 4)) * (towardsBottom ? -1 : 1)
                // Use the Services form margin so dragging does not pan the embedded map.
                let dragX = form == "fri.services.form" ? 12.0 : scroll.frame.width / 2
                let from = origin.withOffset(CGVector(dx: dragX, dy: startY - scroll.frame.minY))
                let to = origin.withOffset(CGVector(dx: dragX, dy: startY + delta - scroll.frame.minY))
                from.press(forDuration: 0.1, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.2)
            } else if upward { scroll.swipeUp() } else { scroll.swipeDown() }
            #else
            if upward { scroll.swipeUp() } else { scroll.swipeDown() }
            #endif
        }
        XCTAssertTrue(element.exists && element.isHittable, "Control must be reachable by scrolling: \(element)")
    }

    func testWidgetAutoFitAtEverySize() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["FRI_SYNTHETIC_PREVIEW"] = "1"
        app.launchEnvironment["FRI_TEST_STORE_ID"] = UUID().uuidString
        app.launchEnvironment["FRI_WIDGET_PREVIEW"] = "1"
        app.launch()
        #if os(macOS)
        XCTAssertTrue(app.radioButtons["Small"].waitForExistence(timeout: 15))
        #else
        let sizes = app.segmentedControls["fri.widget.size"]
        XCTAssertTrue(sizes.waitForExistence(timeout: 15))
        #endif
        for largeText in [false, true] {
            if largeText {
                #if os(macOS)
                app.checkBoxes["Preview large text"].click()
                #else
                let toggle = app.switches["Preview large text"]
                toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
                XCTAssertEqual(toggle.value as? String, "1")
                #endif
            }
            for size in ["Small", "Medium", "Large"] {
                #if os(macOS)
                app.radioButtons[size].click()
                #else
                sizes.buttons[size].tap()
                #endif
                let title = app.staticTexts["fri.widget.title"].firstMatch
                let done = app.descendants(matching: .any)["fri.widget.done"].firstMatch
                let preview = app.descendants(matching: .any)["fri.widget.preview"].firstMatch
                XCTAssertTrue(title.waitForExistence(timeout: 3))
                XCTAssertTrue(done.exists)
                let bounds = preview.frame.insetBy(dx: -1, dy: -1)
                XCTAssertTrue(bounds.contains(title.frame), "Title must fit \(size), large text: \(largeText)")
                XCTAssertTrue(bounds.contains(done.frame), "Done must fit \(size), large text: \(largeText)")
                let attachment = XCTAttachment(screenshot: app.screenshot())
                attachment.name = "Widget-\(size)-largeText-\(largeText)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    func testDeadlineClarificationAndPersistence() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["FRI_SYNTHETIC_PREVIEW"] = "1"
        app.launchEnvironment["FRI_TEST_STORE_ID"] = UUID().uuidString
        app.launch()
        let canvas = app.descendants(matching: .any)["fri.calendar.content"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 15))
        #if os(macOS)
        app.typeKey("n", modifierFlags: .command)
        #else
        app.buttons["fri.new"].tap()
        app.buttons["Schedule"].tap()
        #endif
        let unrelatedDraft = app.textFields["fri.editor.title"]
        XCTAssertTrue(unrelatedDraft.waitForExistence(timeout: 8))
        unrelatedDraft.tap()
        unrelatedDraft.typeText("Unrelated saved draft")
        app.buttons["Close"].firstMatch.tap()
        let name = "Deadline " + UUID().uuidString.prefix(8)
        #if os(macOS)
        app.typeKey("n", modifierFlags: [.command, .shift])
        #else
        app.buttons["fri.new"].tap()
        app.buttons["One-time deadline"].tap()
        #endif
        let title = app.textFields["fri.editor.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        title.tap()
        title.typeText(String(name))
        reveal(app.buttons["fri.editor.submit"], in: app, form: "fri.editor.form")
        app.buttons["fri.editor.submit"].tap()
        let time = app.textFields["fri.editor.missingTime"]
        XCTAssertTrue(time.waitForExistence(timeout: 8))
        time.tap()
        time.typeText("16:20")
        app.buttons["fri.editor.continue"].tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(canvas.waitForExistence(timeout: 15))
        #if os(macOS)
        app.typeKey("f", modifierFlags: .command)
        #else
        app.buttons["fri.search"].tap()
        #endif
        let query = app.textFields["fri.search.field"]
        XCTAssertTrue(query.waitForExistence(timeout: 8))
        query.tap()
        let absent = "No matching appointment 9127"
        query.typeText(absent)
        XCTAssertTrue(app.staticTexts["No appointments found"].waitForExistence(timeout: 5))
        query.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: absent.count))
        query.typeText(String(name))
        let result = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "fri.search.result.", String(name)
        )).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["No appointments found"].exists)
        query.typeText("\n")
        let done = app.buttons["fri.detail.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 8))
        XCTAssertEqual(done.label, "Done")
        done.tap()
        XCTAssertEqual(done.label, "Mark as pending")
        done.tap()
        XCTAssertEqual(done.label, "Done")
        app.buttons["Close"].firstMatch.tap()
        #if os(macOS)
        app.menuButtons["fri.new"].click()
        app.menuItems["Collection"].click()
        #else
        app.buttons["fri.new"].tap()
        app.buttons["Collection"].tap()
        #endif
        let collectionName = app.textFields["fri.collection.name"]
        XCTAssertTrue(collectionName.waitForExistence(timeout: 5))
        collectionName.tap()
        collectionName.typeText("Work review")
        app.buttons["Create collection"].tap()
        #if os(macOS)
        app.menuButtons["fri.collections"].click()
        app.menuItems["Work review"].click()
        #else
        app.buttons["fri.collections"].tap()
        app.buttons["Work review"].firstMatch.tap()
        #endif
        XCTAssertTrue(app.staticTexts["No appointments match this view."].waitForExistence(timeout: 5))
        app.buttons["Show all plans"].tap()
        XCTAssertFalse(app.staticTexts["No appointments match this view."].exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(canvas.waitForExistence(timeout: 15))
        #if os(macOS)
        app.menuButtons["fri.collections"].click()
        XCTAssertTrue(app.menuItems["Work review"].waitForExistence(timeout: 5))
        #else
        app.buttons["fri.collections"].tap()
        XCTAssertTrue(app.buttons["Work review"].firstMatch.waitForExistence(timeout: 5))
        #endif
    }

    func testPublicCalendarLinkReviewPersistenceAndDuplicate() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FRI_IMPORT_NETWORK_TESTS"] == "1",
                          "Opt in to a real public HTTPS calendar request")
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["FRI_SYNTHETIC_PREVIEW"] = "1"
        app.launchEnvironment["FRI_TEST_STORE_ID"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["fri.calendar.content"].waitForExistence(timeout: 15))
        #if os(iOS)
        let largerText = ProcessInfo.processInfo.environment["FRI_IMPORT_LARGE_TEXT"] == "1"
        defer { XCUIDevice.shared.orientation = .portrait }
        if largerText {
            app.buttons["fri.navigation.menu"].tap(); app.buttons["Settings"].tap()
            let larger = app.switches["fri.settings.largeText"]
            reveal(larger, in: app, form: "fri.settings.form")
            if larger.value as? String != "1" {
                larger.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            }
            app.buttons["Close"].firstMatch.tap()
        }
        #endif
        func openImport() {
            #if os(macOS)
            app.menuBars.menuBarItems["File"].click()
            app.menuItems["Add a source…"].click()
            #else
            app.buttons["fri.actions"].tap()
            app.buttons["Import plans"].tap()
            #endif
            XCTAssertTrue(app.textFields["fri.import.link"].waitForExistence(timeout: 8))
        }
        func read(_ url: String) {
            let field = app.textFields["fri.import.link"]
            reveal(field, in: app, form: "fri.import.form")
            field.tap(); field.typeText(url + "\n")
            let read = app.buttons["fri.import.readLink"]
            reveal(read, in: app, form: "fri.import.form"); read.tap()
        }
        openImport()
        reveal(app.buttons["fri.import.readLink"], in: app, form: "fri.import.form")
        XCTAssertFalse(app.buttons["fri.import.readLink"].isEnabled)
        read("https://127.0.0.1/calendar.ics")
        let rejection = app.staticTexts["FRI cannot read links on private or local networks."]
        XCTAssertTrue(rejection.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["fri.import.refresh"].exists)
        app.buttons["Close"].firstMatch.tap()

        // Windows 0.7 skips elapsed occurrences. This pinned public fixture
        // ended in 2012 and must never add anything to today's calendar.
        openImport()
        read("https://raw.githubusercontent.com/kewisch/ical.js/4b28e296c6f2e9742fcde82fd2cde39b9ad382da/samples/minimal.ics")
        XCTAssertTrue(app.staticTexts["No plans found in this source."].waitForExistence(timeout: 40))
        app.buttons["Close"].firstMatch.tap()
        app.buttons["fri.sources.refresh"].tap()
        XCTAssertTrue(app.staticTexts["Added 0 · Needs attention 0 · Skipped 0"].waitForExistence(timeout: 8))

    }

    func testPreparedSourceSurvivesRelaunchAndRefreshHoldsOverlap() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["FRI_SYNTHETIC_PREVIEW"] = "1"
        app.launchEnvironment["FRI_TEST_STORE_ID"] = UUID().uuidString
        app.launch()
        func openSources() {
            #if os(macOS)
            app.buttons["fri.sources"].click()
            #else
            app.buttons["fri.actions"].tap()
            app.buttons["Import plans"].tap()
            #endif
        }
        let day = Date.now.addingTimeInterval(86400).formatted(.iso8601.year().month().day().dateSeparator(.dash))
        XCTAssertTrue(app.buttons["fri.sources.refresh"].waitForExistence(timeout: 20))
        openSources()
        let text = app.descendants(matching: .any)["fri.import.text"].firstMatch
        text.tap()
        text.typeText("QA Physics \(day) 09:00 60 min\nQA Overlap \(day) 09:30 30 min")
        app.buttons["fri.import.reviewText"].tap()
        XCTAssertTrue(app.buttons["fri.import.refresh"].waitForExistence(timeout: 10))
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["fri.sources.refresh"].waitForExistence(timeout: 15))
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'fri.card.' AND label CONTAINS 'QA Physics'")).firstMatch
        XCTAssertFalse(card.exists)
        app.buttons["fri.sources.refresh"].tap()
        XCTAssertTrue(app.staticTexts["Added 1 · Needs attention 1 · Skipped 0"].waitForExistence(timeout: 10))
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        app.buttons["fri.sources.refresh"].tap()
        XCTAssertTrue(app.staticTexts["Added 0 · Needs attention 1 · Skipped 0"].waitForExistence(timeout: 10))
    }
}
