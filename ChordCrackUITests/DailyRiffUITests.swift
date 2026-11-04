import XCTest

/// No Listen, reference or replay controls are tapped. Audio transitions are covered
/// by scripts/verify-daily-riff with a silent player substitute.
final class DailyRiffUITests: XCTestCase {
    @MainActor override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<20 {
            if element.exists && element.isHittable && element.frame.midY < app.frame.maxY - 70 && element.frame.midY > 100 { return }
            if element.exists && element.frame.midY < 100 { app.swipeDown() }
            else { app.swipeUp() }
        }
        XCTFail("Could not reveal \(element)")
    }
    @MainActor private func tap(_ id: String, in app: XCUIApplication) {
        let button = app.buttons[id]
        reveal(button, in: app); button.tap()
    }
    @MainActor private func attach(_ name: String, _ app: XCUIApplication) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name; image.lifetime = .keepAlways; add(image)
    }
    @MainActor private func open(largeText: Bool = false, recap: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--design-demo"]
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        if recap { app.launchArguments += ["--daily-riff-recap"] }
        app.launch()
        XCTAssertTrue(app.buttons["home.daily-riff"].waitForExistence(timeout: 8))
        attach(largeText ? "riff-home-AX5" : "riff-home", app)
        tap("home.daily-riff", in: app)
        XCTAssertTrue(app.buttons["riff.close"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor func testSilentJourneyResumeAndShare() { checkJourney(largeText: false) }
    @MainActor func testLargeTextSilentJourney() { checkJourney(largeText: true) }

    @MainActor private func checkJourney(largeText: Bool) {
        let app = open(largeText: largeText)
        let suffix = largeText ? "-AX5" : ""
        XCTAssertFalse(app.buttons["riff.answer.0"].isEnabled)
        attach("riff-quality" + suffix, app)
        tap("riff.skip", in: app)
        XCTAssertTrue(app.staticTexts["riff.feedback"].waitForExistence(timeout: 3))
        app.buttons["riff.close"].tap()
        tap("home.daily-riff", in: app)
        XCTAssertTrue(app.staticTexts["riff.feedback"].waitForExistence(timeout: 3))
        attach("riff-feedback" + suffix, app)
        tap("riff.next", in: app)
        XCTAssertEqual(app.staticTexts["riff.round"].label, "Puzzle 2 of 3 · Match")
        XCTAssertFalse(app.buttons["riff.answer.0"].isEnabled)
        XCTAssertTrue(app.buttons["riff.reference.0"].exists)
        attach("riff-match" + suffix, app)
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(app.buttons["riff.resume"].waitForExistence(timeout: 5))
        tap("riff.resume", in: app)
        XCTAssertFalse(app.buttons["riff.answer.0"].isEnabled)
        tap("riff.skip", in: app); tap("riff.next", in: app)
        XCTAssertEqual(app.staticTexts["riff.round"].label, "Puzzle 3 of 3 · Switch")
        attach("riff-switch" + suffix, app)
        tap("riff.skip", in: app); tap("riff.next", in: app)
        XCTAssertTrue(app.buttons["riff.share"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["riff.score"].label, "0 of 3 correct")
        attach("riff-recap" + suffix, app)
        app.buttons["riff.close"].tap()
        tap("home.daily-riff", in: app)
        XCTAssertTrue(app.buttons["riff.share"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["riff.listen"].exists)
        tap("riff.share", in: app)
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.cells["Copy"].exists)
        attach("riff-share-sheet" + suffix, app)
        if app.buttons["header.closeButton"].exists {
            app.buttons["header.closeButton"].tap()
        } else {
            // iPad presents a popover with an outside dismissal region.
            app.otherElements["PopoverDismissRegion"]
                .coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.1)).tap()
        }
        XCTAssertTrue(app.buttons["riff.share"].waitForExistence(timeout: 3))
        app.terminate()
    }

    @MainActor func testColorfulResultFixtureStaysSilent() {
        let app = open(recap: true)
        XCTAssertTrue(app.buttons["riff.share"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["riff.score"].label, "2 of 3 correct")
        attach("riff-two-of-three", app)
        app.terminate()
    }

    @MainActor func testHomeKeepsBothPracticeModes() {
        let app = open()
        app.buttons["riff.close"].tap()
        XCTAssertTrue(app.buttons["home.daily"].exists)
        tap("practice.five-round", in: app)
        XCTAssertTrue(app.buttons["prototype.listen"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["prototype.answer.Major"].isEnabled)
        app.terminate()
    }
}
