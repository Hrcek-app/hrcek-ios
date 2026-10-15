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
}
