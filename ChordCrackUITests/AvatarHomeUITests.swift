import XCTest

/// Design preview only. Never taps audio, signs in, uploads, or sends requests.
final class AvatarHomeUITests: XCTestCase {
    @MainActor override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }
    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<30 {
            if element.exists && element.isHittable && element.frame.midY > 44 && element.frame.midY < app.frame.maxY - 65 { return }
            if element.exists && element.frame.midY < 44 { app.swipeDown() }
            else { app.swipeUp() }
        }
        XCTFail("Could not reveal \(element)")
    }
    @MainActor private func tap(_ id: String, in app: XCUIApplication) {
        let button = app.buttons[id]
        reveal(button,in:app); button.tap()
    }
    @MainActor private func attach(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot:app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor private func journey(largeText: Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["--design-demo"]
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCTAssertTrue(app.buttons["home.daily-riff"].waitForExistence(timeout:8))
        let suffix = largeText ? "-AX5" : ""
        attach("home-primary-riff"+suffix,app:app)
        let riff = app.buttons["home.daily-riff"], daily = app.buttons["home.daily"], practice = app.buttons["practice.five-round"]
        XCTAssertTrue(daily.exists && practice.exists)
        XCTAssertGreaterThan(daily.frame.minY,riff.frame.maxY)
        XCTAssertGreaterThan(practice.frame.minY,daily.frame.minY)
        reveal(practice,in:app)
        attach("home-secondary-modes"+suffix,app:app)
        practice.tap()
        XCTAssertTrue(app.buttons["prototype.listen"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["prototype.answer.Major"].isEnabled)
        // Relaunch clears preview-only state and returns to Home without audio.
        app.terminate(); app.launch()
        tap("home.profile",in:app)
        XCTAssertTrue(app.buttons["profile.change-avatar"].waitForExistence(timeout:5))
        XCTAssertEqual(app.buttons["profile.change-avatar"].value as? String,"Your initial")
        tap("profile.change-avatar",in:app)
        XCTAssertTrue(app.buttons["avatar.save"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["avatar.save"].isEnabled)
        tap("avatar.option.guitar",in:app)
        XCTAssertEqual(app.buttons["avatar.option.guitar"].value as? String,"Selected")
        attach("avatar-picker"+suffix,app:app)
        app.buttons["avatar.cancel"].tap()
        XCTAssertEqual(app.buttons["profile.change-avatar"].value as? String,"Your initial")
        tap("profile.change-avatar",in:app)
        tap("avatar.option.headphones",in:app)
        app.buttons["avatar.save"].tap()
        XCTAssertTrue(app.buttons["profile.change-avatar"].waitForExistence(timeout:5))
        XCTAssertEqual(app.buttons["profile.change-avatar"].value as? String,"Beat Bunny")
        attach("avatar-profile"+suffix,app:app)
        app.navigationBars["Profile"].buttons["Back"].tap()
        XCTAssertTrue(app.buttons["home.profile"].waitForExistence(timeout:5))
        XCTAssertEqual(app.buttons["home.profile"].value as? String,"Beat Bunny")
        tap("home.profile",in:app)
        tap("profile.change-avatar",in:app)
        reveal(app.buttons["avatar.option.headphones"],in:app)
        XCTAssertEqual(app.buttons["avatar.option.headphones"].value as? String,"Selected")
        tap("avatar.option.initial",in:app)
        app.buttons["avatar.save"].tap()
        XCTAssertTrue(app.buttons["profile.change-avatar"].waitForExistence(timeout:5))
        XCTAssertEqual(app.buttons["profile.change-avatar"].value as? String,"Your initial")
        app.terminate()
    }
    @MainActor func testHomeAndAvatarPicker() { journey(largeText:false) }
    @MainActor func testLargeTextHomeAndAvatarPicker() { journey(largeText:true) }
}
