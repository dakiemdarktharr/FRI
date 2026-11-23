import XCTest

@MainActor
final class FRIWorkflowTests: XCTestCase {
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
                app.switches["Preview large text"].tap()
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
}
