import XCTest

/// An outage as a person meets it: share while Hrček is down, then open
/// the app once it is back. Run by scripts/e2e through its proxy.
final class OfflineE2ETests: XCTestCase {
    @MainActor
    func testKeepsAPageSharedDuringAnOutageAndSendsItLater() async throws {
        continueAfterFailure = false
        let env = ProcessInfo.processInfo.environment
        let server = try XCTUnwrap(env["HRCEK_E2E_SERVER"], "run through scripts/e2e")
        let page = try XCTUnwrap(env["HRCEK_E2E_OFFLINE_PAGE"].flatMap(URL.init(string:)))

        let app = launchApp()
        signIn(
            app, email: try XCTUnwrap(env["HRCEK_E2E_EMAIL"]),
            password: try XCTUnwrap(env["HRCEK_E2E_PASSWORD"]), server: server)
        XCTAssertTrue(app.staticTexts["signedInAs"].waitForExistence(timeout: patience))
        declineSavingThePassword(app)

        try await setOutage(true, server: server)
        keepFromSafari(page, notes: "Kept while Hrček was down")

        // Hrček is back, and the person opens the app.
        try await setOutage(false, server: server)
        app.activate()
        // Becoming active syncs; the list then has nothing left.
        XCTAssertTrue(
            app.descendants(matching: .any)["nothingWaiting"].waitForExistence(timeout: patience),
            app.debugDescription)
    }

    /// Pages kept while Hrček was down, then saved to it from elsewhere:
    /// the person keeps Hrček's entry for one and their own for the other.
    @MainActor
    func testSettlesPagesHrcekAlreadyHas() async throws {
        continueAfterFailure = false
        let env = ProcessInfo.processInfo.environment
        let server = try XCTUnwrap(env["HRCEK_E2E_SERVER"], "run through scripts/e2e")
        let email = try XCTUnwrap(env["HRCEK_E2E_EMAIL"])
        let password = try XCTUnwrap(env["HRCEK_E2E_PASSWORD"])
        let keepPage = try XCTUnwrap(env["HRCEK_E2E_KEEP_PAGE"].flatMap(URL.init(string:)))
        let replacePage = try XCTUnwrap(env["HRCEK_E2E_REPLACE_PAGE"].flatMap(URL.init(string:)))

        let app = launchApp()
        signIn(app, email: email, password: password, server: server)
        XCTAssertTrue(app.staticTexts["signedInAs"].waitForExistence(timeout: patience))
        declineSavingThePassword(app)

        try await setOutage(true, server: server)
        keepFromSafari(keepPage, notes: "Mine, kept offline")
        keepFromSafari(replacePage, notes: "Mine, kept offline")
        try await setOutage(false, server: server)
        for page in [keepPage, replacePage] {
            try await saveDirectly(
                url: page.absoluteString, title: "From elsewhere", server: server, email: email,
                password: password)
        }

        app.activate()
        // Both pages share Safari's title; the older, the keep page, is first.
        // A held row is a link, so a button.
        let rows = app.buttons.matching(identifier: "pending-Hrček E2E page")
        let held = TestLanguage.text(
            en: "Hrček already has this page.", sl: "Hrček to stran že ima.")
        // The sync on becoming active finds both on Hrček and holds them.
        waitFor(
            rows.matching(NSPredicate(format: "label CONTAINS %@", held)), "count == 2", in: app)
        choose("keepTheirs", for: rows.element(boundBy: 0), in: app)
        waitFor(rows, "count == 1", in: app)
        choose("replaceWithMine", for: rows.element(boundBy: 0), in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["nothingWaiting"].waitForExistence(timeout: patience),
            app.debugDescription)
    }

    /// Opens a held row's comparison and taps a choice once Hrček's entry
    /// has let it be made.
    @MainActor
    private func choose(_ choice: String, for row: XCUIElement, in app: XCUIApplication) {
        tapWhenHittable(row)
        let button = app.buttons[choice]
        waitFor(button, "enabled == true", in: app)
        tapWhenHittable(button)
    }

    @MainActor
    private func waitFor(_ object: Any, _ format: String, in app: XCUIApplication) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: format), object: object)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: patience), .completed,
            app.debugDescription)
    }

    /// Shares a page from Safari while Hrček is down, and keeps it.
    @MainActor
    private func keepFromSafari(_ page: URL, notes text: String) {
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.terminate()
        XCUIDevice.shared.system.open(page)
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: patience))
        XCTAssertTrue(
            safari.staticTexts["Hrček E2E page"].waitForExistence(timeout: patience),
            "page did not load:\n\(safari.debugDescription)")
        openShareSheet(from: safari)
        XCTAssertTrue(
            safari.descendants(matching: .any)["offlineNote"].waitForExistence(timeout: patience),
            safari.debugDescription)
        let notes = safari.descendants(matching: .any)["notes"].firstMatch
        tapWhenHittable(notes)
        notes.typeText(text)
        tapWhenHittable(safari.buttons["save"].firstMatch)
        let kept = safari.descendants(matching: .any)["kept"]
        XCTAssertTrue(kept.waitForExistence(timeout: patience), safari.debugDescription)
        XCTAssertTrue(kept.waitForNonExistence(timeout: patience))
    }
}
