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
        notes.typeText("Kept while Hrček was down")
        tapWhenHittable(safari.buttons["save"].firstMatch)
        let kept = safari.descendants(matching: .any)["kept"]
        XCTAssertTrue(kept.waitForExistence(timeout: patience), safari.debugDescription)
        XCTAssertTrue(kept.waitForNonExistence(timeout: patience))

        // Hrček is back, and the person opens the app.
        try await setOutage(false, server: server)
        app.activate()
        // Becoming active syncs; the list then has nothing left.
        XCTAssertTrue(
            app.descendants(matching: .any)["nothingWaiting"].waitForExistence(timeout: patience),
            app.debugDescription)
    }
}
