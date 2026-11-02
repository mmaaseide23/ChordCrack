import XCTest

final class FiveRoundPracticeUITests: XCTestCase {
    @MainActor override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }
    @MainActor private func launch(largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--design-demo", "--practice-prototype"]
        if largeText { app.launchArguments += ["--prototype-reduce-motion", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCTAssertTrue(app.buttons["prototype.listen"].waitForExistence(timeout: 6))
        return app
    }
    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<16 {
            // Hittable can be true while the default tap's center is beneath
            // the demo footer or offscreen at accessibility text sizes.
            if element.exists && element.isHittable && element.frame.midY < app.frame.maxY - 130 { return }
            app.swipeUp(velocity: .slow)
        }
        XCTFail("Expected visible prototype control")
    }
    @MainActor private func waitEnabled(_ element: XCUIElement) {
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: element)
        waitForExpectations(timeout: 7)
    }
    @MainActor private func attach(_ name: String, _ app: XCUIApplication) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways
        add(a)
    }
    @MainActor private func listenAndAnswer(_ name: String, _ app: XCUIApplication) {
        let play = app.buttons["prototype.listen"]
        reveal(play, in: app); play.tap()
        let answer = app.buttons["prototype.answer.\(name)"]
        waitEnabled(answer); reveal(answer, in: app); answer.tap()
        XCTAssertTrue(app.otherElements["prototype.feedback"].exists || app.staticTexts["prototype.feedback"].exists)
    }

    @MainActor func testFiveRoundsComparisonRecapAndRepeat() {
        let app = launch()
        attach("prototype-listen", app)
        XCTAssertFalse(app.buttons["prototype.answer.Major"].isEnabled)
        listenAndAnswer("Minor", app)
        attach("prototype-mistake", app)
        let guess = app.buttons["prototype.replay.guess"]
        reveal(guess, in: app); guess.tap(); waitEnabled(guess)
        guess.tap(); waitEnabled(guess) // Optional replay is repeatable.
        let actual = app.buttons["prototype.replay.correct"]
        actual.tap()
        let next = app.buttons["prototype.next"]
        reveal(next, in: app); next.tap() // Interrupt comparison with Next.
        for choice in ["Minor", "Major", "Minor", "Minor"] {
            listenAndAnswer(choice, app)
            if choice == "Major" { attach("prototype-correct", app) }
            reveal(next, in: app); next.tap()
        }
        XCTAssertTrue(app.staticTexts["prototype.recap"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["4 of 5 recognized · 80 points"].exists)
        attach("prototype-recap", app)
        let restart = app.buttons["prototype.restart"]
        reveal(restart, in: app); restart.tap()
        XCTAssertEqual(app.staticTexts["prototype.score"].label, "0 pts")
        listenAndAnswer("Major", app)
        XCTAssertEqual(app.staticTexts["prototype.score"].label, "20 pts")
    }

    @MainActor func testInterruptedListenAndSessionOptions() {
        let app = launch()
        app.buttons["prototype.listen"].tap()
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["prototype.resume"].waitForExistence(timeout: 4))
        attach("prototype-paused", app)
        app.buttons["prototype.resume"].tap()
        XCTAssertFalse(app.buttons["prototype.answer.Major"].isEnabled)
        app.buttons["prototype.options"].tap()
        let sound = app.switches["prototype.sound"]
        XCTAssertTrue(sound.waitForExistence(timeout: 3))
        sound.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(sound.value as? String, "0")
        let haptics = app.switches["prototype.haptics"]
        haptics.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(haptics.value as? String, "0")
        attach("prototype-options", app)
        app.buttons["Done"].tap()
        app.buttons["prototype.resume"].tap()
        XCTAssertFalse(app.buttons["prototype.listen"].isEnabled)
        app.buttons["prototype.options"].tap()
        app.switches["prototype.sound"].coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(app.switches["prototype.sound"].value as? String, "1")
        app.buttons["Done"].tap()
        app.buttons["prototype.resume"].tap()
        listenAndAnswer("Major", app)
        app.buttons["prototype.pause"].tap(); app.buttons["prototype.resume"].tap()
        XCTAssertTrue(app.buttons["prototype.replay.correct"].exists)
    }

    @MainActor func testLargeTextReduceMotionComparison() {
        let app = launch(largeText: true)
        attach("prototype-AX-listen", app)
        listenAndAnswer("Minor", app)
        attach("prototype-AX-mistake", app)
        let guess = app.buttons["prototype.replay.guess"]
        reveal(guess, in: app); guess.tap(); waitEnabled(guess)
        let actual = app.buttons["prototype.replay.correct"]
        reveal(actual, in: app); actual.tap(); waitEnabled(actual)
        attach("prototype-AX-comparison", app)
        let next = app.buttons["prototype.next"]
        reveal(next, in: app); next.tap()
        XCTAssertEqual(app.staticTexts["prototype.round"].label, "Round 2 of 5")
    }
    @MainActor func testDemoEntryAndClosePreserveHome() {
        let app = XCUIApplication()
        app.launchArguments = ["--design-demo"]
        app.launch()
        XCTAssertTrue(app.staticTexts["design-preview-banner"].waitForExistence(timeout: 5))
        let entry = app.buttons["practice.five-round"]
        reveal(entry, in: app); entry.tap()
        XCTAssertTrue(app.buttons["prototype.listen"].waitForExistence(timeout: 4))
        app.buttons["prototype.close"].tap()
        XCTAssertTrue(app.buttons["home.daily"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["design-preview-banner"].exists)
        reveal(entry, in: app); entry.tap()
        XCTAssertTrue(app.buttons["prototype.listen"].waitForExistence(timeout: 4))
        XCTAssertEqual(app.staticTexts["prototype.score"].label, "0 pts")
    }

    // This test never taps Listen, an answer or a replay control.
    @MainActor func testHomePracticeEntryOptionsAndInterruptionStaySilent() {
        checkHomePracticeEntryOptionsAndInterruption(largeText: false)
    }

    @MainActor func testLargeTextHomePracticeEntryStaysSilent() {
        checkHomePracticeEntryOptionsAndInterruption(largeText: true)
    }

    @MainActor private func checkHomePracticeEntryOptionsAndInterruption(largeText: Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["--design-demo"]
        if largeText { app.launchArguments += ["--prototype-reduce-motion", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        let entry = app.buttons["practice.five-round"]
        XCTAssertTrue(entry.waitForExistence(timeout: 6))
        reveal(entry, in: app); attach("home-five-round-entry", app); entry.tap()
        XCTAssertTrue(app.buttons["prototype.listen"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.buttons["prototype.answer.Major"].isEnabled)
        attach("release-practice-idle", app)
        app.buttons["prototype.options"].tap()
        let sound = app.switches["prototype.sound"]
        XCTAssertTrue(sound.waitForExistence(timeout: 3))
        sound.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(sound.value as? String, "0")
        attach("release-practice-options", app)
        app.buttons["Done"].tap()
        reveal(app.buttons["prototype.resume"], in: app); app.buttons["prototype.resume"].tap()
        XCTAssertFalse(app.buttons["prototype.listen"].isEnabled)
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["prototype.resume"].waitForExistence(timeout: 4))
        reveal(app.buttons["prototype.resume"], in: app); app.buttons["prototype.resume"].tap()
        XCTAssertFalse(app.buttons["prototype.answer.Major"].isEnabled)
        app.buttons["prototype.close"].tap()
        reveal(entry, in: app); entry.tap()
        XCTAssertTrue(app.buttons["prototype.listen"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["prototype.listen"].isEnabled)
        XCTAssertEqual(app.staticTexts["prototype.score"].label, "0 pts")
        app.terminate()
    }

}
