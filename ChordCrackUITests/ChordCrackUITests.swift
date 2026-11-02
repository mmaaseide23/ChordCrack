import XCTest

/// Uses only DEBUG fixtures and synthesized tones. It never signs in or reaches a backend.
final class ChordCrackUITests: XCTestCase {
    @MainActor override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor private func launchDemo(empty: Bool = false, largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--design-demo"] + (empty ? ["--design-empty"] : []) + (largeText ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] : [])
        app.launch()
        XCTAssertTrue(app.staticTexts["design-preview-banner"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        let practiceIDs = ["home.Power Chords", "home.Barre Chords", "home.Blues Chords", "home.Extended Chords", "home.Progressions", "home.Mixed Mode", "home.library"]
        let carousel = app.scrollViews["home.practice-carousel"]
        if element.exists && practiceIDs.contains(element.identifier) && carousel.exists {
            // Offscreen carousel children have no activation point; scroll by frame first.
            for _ in 0..<12 {
                if carousel.frame.intersection(app.frame.insetBy(dx: 0, dy: 80)).height >= 150 { break }
                app.swipeUp(velocity: .slow)
            }
            for _ in 0..<20 {
                let viewport = carousel.frame.intersection(app.frame.insetBy(dx: 10, dy: 80))
                let targetFrame = element.frame
                if targetFrame.minX >= viewport.minX && targetFrame.maxX <= viewport.maxX { break }
                let direction: CGFloat = targetFrame.midX < viewport.midX ? 1 : -1
                let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: viewport.midX, dy: viewport.midY))
                let end = start.withOffset(CGVector(dx: direction * 120, dy: 0))
                start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
            }
        } else {
            for _ in 0..<24 {
                if element.exists && element.frame.intersects(app.frame) && element.isHittable { break }
                app.swipeUp(velocity: .slow)
            }
        }
        XCTAssertTrue(element.isHittable)
    }

    @MainActor private func attach(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor func testDailyListeningAnswerAndPause() {
        let app = launchDemo()
        app.buttons["home.daily"].tap()
        XCTAssertTrue(app.buttons["game.listen"].waitForExistence(timeout: 3))
        app.buttons["game.listen"].tap()
        let answer = app.buttons["answer.A"]
        reveal(answer, in: app)
        answer.tap()
        XCTAssertTrue(app.staticTexts["Round 2 of 5"].waitForExistence(timeout: 5))
        for _ in 0..<4 where !app.buttons["game.pause"].isHittable { app.swipeDown() }
        app.buttons["game.pause"].tap()
        XCTAssertTrue(app.buttons["Resume Game"].waitForExistence(timeout: 3))
        attach("daily-pause", app: app)
    }

    @MainActor func testLibrarySearchRecoveryAndReplay() {
        let app = launchDemo()
        let library = app.buttons["home.library"]
        reveal(library, in: app)
        library.tap()
        let search = app.textFields["library.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap()
        search.typeText("zzzz")
        XCTAssertTrue(app.staticTexts["No matching chords"].waitForExistence(timeout: 2))
        app.buttons["library.clear"].tap()
        let chord = app.buttons["library.chord.A"]
        reveal(chord, in: app)
        chord.tap()
        let play = app.buttons["detail.play.Full Chord"]
        reveal(play, in: app)
        play.tap()
        XCTAssertTrue(play.waitForExistence(timeout: 2))
        let enabled = NSPredicate(format: "enabled == true")
        expectation(for: enabled, evaluatedWith: play)
        waitForExpectations(timeout: 8)
        play.tap()
        attach("library-detail", app: app)
    }

    @MainActor func testPracticeDestinationsRemainReachable() {
        for title in ["Power Chords", "Barre Chords", "Blues Chords", "Extended Chords", "Progressions", "Mixed Mode"] {
            let app = launchDemo()
            let mode = app.buttons["home.\(title)"]
            reveal(mode, in: app)
            mode.tap()
            XCTAssertTrue(app.buttons["game.pause"].waitForExistence(timeout: 3))
            attach("practice-\(title)", app: app)
            app.terminate()
        }
    }

    @MainActor func testEmptyProgressOffersDailySession() {
        let app = launchDemo(empty: true)
        XCTAssertTrue(app.staticTexts["Start with your first Daily Challenge below!"].exists)
        XCTAssertTrue(app.buttons["home.daily"].isHittable)
        attach("empty-home", app: app)
    }
    @MainActor func testDesignReviewScreens() {
        var app = launchDemo()
        attach("review-home", app: app)
        app.buttons["home.daily"].tap()
        XCTAssertTrue(app.buttons["game.listen"].waitForExistence(timeout: 5))
        attach("review-daily", app: app)
        app.terminate()
        app = launchDemo()
        reveal(app.buttons["home.Power Chords"], in: app)
        attach("review-practice-colors", app: app)
        reveal(app.buttons["home.library"], in: app)
        attach("review-home-practice", app: app)
        app.buttons["home.library"].tap()
        XCTAssertTrue(app.textFields["library.search"].waitForExistence(timeout: 5))
        attach("review-library", app: app)
        app.buttons["library.chord.A"].tap()
        XCTAssertTrue(app.buttons["detail.play.Full Chord"].waitForExistence(timeout: 5))
        attach("review-detail", app: app)
    }

    @MainActor func testLargeTextDesignReview() {
        let app = XCUIApplication()
        app.launchArguments = ["--design-demo", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.staticTexts["design-preview-banner"].waitForExistence(timeout: 5))
        attach("review-large-text-home", app: app)
        reveal(app.buttons["home.daily"], in: app)
        app.buttons["home.daily"].tap()
        XCTAssertTrue(app.buttons["game.listen"].waitForExistence(timeout: 5))
        attach("review-large-text-daily", app: app)
        reveal(app.buttons["game.listen"], in: app)
        XCTAssertTrue(app.buttons["game.listen"].isHittable)
        attach("review-large-text-listen", app: app)
    }

    @MainActor func testLargeTextPracticeAndLibrary() {
        var app = launchDemo(largeText: true)
        reveal(app.buttons["home.dashboard"], in: app)
        attach("review-large-text-progress", app: app)
        reveal(app.buttons["home.Power Chords"], in: app)
        attach("review-large-text-practice-card", app: app)
        app.buttons["home.Power Chords"].tap()
        XCTAssertTrue(app.buttons["game.listen"].waitForExistence(timeout: 5))
        attach("review-large-text-power", app: app)
        app.terminate()
        app = launchDemo(largeText: true)
        reveal(app.buttons["home.library"], in: app)
        app.buttons["home.library"].tap()
        XCTAssertTrue(app.buttons["library.chord.A"].waitForExistence(timeout: 5))
        reveal(app.buttons["library.chord.A"], in: app)
        app.buttons["library.chord.A"].tap()
        XCTAssertTrue(app.navigationBars["A"].waitForExistence(timeout: 5))
        attach("review-large-text-detail", app: app)
        reveal(app.buttons["detail.play.Full Chord"], in: app)
        app.swipeUp(velocity: .slow)
        attach("review-large-text-reference-audio", app: app)
    }

}
