import XCTest

@MainActor
final class FRIWorkflowTests: XCTestCase {
    #if os(iOS)
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
        for _ in 0..<6 {
            var visible = scroll.frame.intersection(app.frame).insetBy(dx: 0, dy: 12)
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
        query.typeText(String(name))
        let result = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "fri.search.result.", String(name)
        )).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 8))
        result.tap()
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

    func testTextImportRequiresExplicitDateAndReviewsOnlyAcceptedPlans() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["FRI_SYNTHETIC_PREVIEW"] = "1"
        app.launchEnvironment["FRI_TEST_STORE_ID"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["fri.calendar.content"].waitForExistence(timeout: 15))
        #if os(macOS)
        app.menuBars.menuBarItems["File"].click()
        app.menuItems["Import Plans…"].click()
        #else
        app.buttons["fri.actions"].tap()
        app.buttons["Import plans"].tap()
        #endif
        let source = app.textFields["fri.import.text"]
        XCTAssertTrue(source.waitForExistence(timeout: 8))
        source.tap()
        source.typeText("QA text import 15:30")
        app.buttons["fri.import.reviewText"].tap()
        XCTAssertTrue(app.buttons["Use today"].waitForExistence(timeout: 5))
        reveal(app.buttons["fri.import.accept"], in: app, form: "fri.import.form")
        app.buttons["fri.import.accept"].tap()
        XCTAssertTrue(app.staticTexts["Enter a name and choose a date."].waitForExistence(timeout: 5))
        reveal(app.buttons["Use today"], in: app, form: "fri.import.form", upward: false)
        app.buttons["Use today"].tap()
        reveal(app.buttons["fri.import.accept"], in: app, form: "fri.import.form")
        app.buttons["fri.import.accept"].tap()
        let duration = app.textFields["fri.editor.missingDuration"]
        XCTAssertTrue(duration.waitForExistence(timeout: 8))
        duration.tap()
        duration.typeText("45")
        app.buttons["fri.editor.continue"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "QA text import")).firstMatch.waitForExistence(timeout: 8))
    }
}
