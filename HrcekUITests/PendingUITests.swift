import XCTest

final class PendingUITests: XCTestCase {
    @MainActor
    func testOpensOnWhatIsWaiting() {
        let app = launchApp(seeding: 2)
        let title = TestLanguage.text(en: "Waiting to sync", sl: "Čaka na sinhronizacijo")
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["pending-Seeded 1"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["pending-Seeded 2"].exists)
        XCTAssertTrue(app.buttons["signInToSync"].exists, "signed out, it says how to sync")
    }

    @MainActor
    func testSettingsSayHowManyWait() {
        let app = launchApp(seeding: 2)
        app.buttons["settings"].tap()
        let count = app.descendants(matching: .any)["pendingCount"]
        XCTAssertTrue(count.waitForExistence(timeout: 10))
        XCTAssertEqual(
            count.label,
            TestLanguage.text(
                en: "2 pages waiting to sync", sl: "2 strani čakata na sinhronizacijo"))
        XCTAssertTrue(app.textFields["server"].exists, "signed out, settings is the sign-in")
    }

    @MainActor
    func testDeletesOnlyAfterConfirming() {
        let app = launchApp(seeding: 2)
        let row = app.descendants(matching: .any)["pending-Seeded 1"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.swipeLeft()
        app.buttons["delete"].firstMatch.tap()
        app.buttons["confirmDelete"].firstMatch.tap()
        XCTAssertTrue(row.waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["pending-Seeded 2"].exists)
    }

    @MainActor
    func testSyncsOnceSignedInThenReturnsToTheUsualScreen() {
        let app = launchApp(seeding: 1)
        app.buttons["settings"].tap()
        signIn(app, email: "nina@example.com")
        declineSavingThePassword(app)
        tapWhenHittable(app.buttons["closeSettings"])
        // Signing in sends what waits; the emptied list says how it went.
        XCTAssertTrue(
            app.descendants(matching: .any)["nothingWaiting"].waitForExistence(timeout: 10),
            app.debugDescription)
        let summary = app.descendants(matching: .any)["syncSummary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertEqual(
            summary.label, TestLanguage.text(en: "1 entry saved.", sl: "Shranjen je 1 vnos."))
        tapWhenHittable(app.buttons["done"])
        XCTAssertTrue(app.staticTexts["signedInAs"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testExplainsBeforeAskingForTheBadge() {
        let app = launchApp(seeding: 1, badge: "undetermined")
        XCTAssertTrue(app.staticTexts["badgeExplanation"].waitForExistence(timeout: 10))
        app.buttons["badgeContinue"].tap()
        XCTAssertTrue(app.staticTexts["badgeExplanation"].waitForNonExistence(timeout: 10))
    }

    @MainActor
    func testSaysHowToTurnTheBadgeOnWhenRefused() {
        let app = launchApp(seeding: 1, badge: "denied")
        app.buttons["settings"].tap()
        XCTAssertTrue(
            app.links["openSettings"].waitForExistence(timeout: 10)
                || app.buttons["openSettings"].waitForExistence(timeout: 1))
    }

    @MainActor
    func testDoesNotAskWhenNothingWaits() {
        let app = launchApp(badge: "undetermined")
        let title = TestLanguage.text(en: "Sign in to Hrček", sl: "Prijava v Hrček")
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["badgeExplanation"].exists)
    }

    /// iOS's own alerts, Notification Centre and Control Centre make the
    /// app inactive for a moment; that is not coming back to it.
    @MainActor
    func testAMomentAwayKeepsTheEmptiedList() {
        let app = emptiedBySigningIn()
        // Control Centre over the app, then away again. (Notification
        // Centre can send the app to the background.)
        let corner = app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.0))
        corner.press(
            forDuration: 0.1,
            thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.6)))
        sleep(1)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)).press(
            forDuration: 0.1,
            thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)))
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        sleep(2)
        XCTAssertTrue(
            app.descendants(matching: .any)["nothingWaiting"].exists, app.debugDescription)
        XCTAssertEqual(
            app.descendants(matching: .any)["syncSummary"].label,
            TestLanguage.text(en: "1 entry saved.", sl: "Shranjen je 1 vnos."))
    }

    /// Coming back from the home screen is coming back: an emptied list
    /// gives way to the usual screen.
    @MainActor
    func testComingBackLeavesAnEmptiedList() {
        let app = emptiedBySigningIn()
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(
            app.wait(for: .runningBackgroundSuspended, timeout: 10)
                || app.wait(for: .runningBackground, timeout: 1))
        app.activate()
        XCTAssertTrue(app.staticTexts["signedInAs"].waitForExistence(timeout: 10))
    }

    /// Signs in from the list's settings, which sends the seeded page and
    /// leaves the list empty with what the sync did.
    @MainActor
    private func emptiedBySigningIn() -> XCUIApplication {
        let app = launchApp(seeding: 1)
        app.buttons["settings"].tap()
        signIn(app, email: "nina@example.com")
        declineSavingThePassword(app)
        tapWhenHittable(app.buttons["closeSettings"])
        XCTAssertTrue(
            app.descendants(matching: .any)["syncSummary"].waitForExistence(timeout: 10),
            app.debugDescription)
        return app
    }
}
