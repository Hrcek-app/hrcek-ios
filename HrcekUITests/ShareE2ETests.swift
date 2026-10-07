import XCTest

/// The whole flow, as a person does it: sign in in the app, then share a
/// page from Safari to Hrček. Run by scripts/e2e against a real backend.
final class ShareE2ETests: XCTestCase {
    /// A freshly booted CI simulator can take most of a minute per step.
    private let patience: TimeInterval = 60

    @MainActor
    func testSharingAPageFromSafariSavesItOnce() throws {
        continueAfterFailure = false
        let env = ProcessInfo.processInfo.environment
        let server = try XCTUnwrap(env["HRCEK_E2E_SERVER"], "run through scripts/e2e")
        let page = try XCTUnwrap(env["HRCEK_E2E_PAGE"].flatMap(URL.init(string:)))

        let app = launchApp()
        signIn(
            app, email: try XCTUnwrap(env["HRCEK_E2E_EMAIL"]),
            password: try XCTUnwrap(env["HRCEK_E2E_PASSWORD"]), server: server)
        XCTAssertTrue(app.staticTexts["signedInAs"].waitForExistence(timeout: patience))
        declineSavingThePassword(app)

        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.terminate()
        XCUIDevice.shared.system.open(page)
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: patience))
        XCTAssertTrue(
            safari.staticTexts["Hrček E2E page"].waitForExistence(timeout: patience),
            "page did not load:\n\(safari.debugDescription)")
        // Sharing the same open page twice, as a person would.
        share(from: safari, expecting: "saved")
        share(from: safari, expecting: "alreadySaved")
    }

    @MainActor
    private func share(from safari: XCUIApplication, expecting identifier: String) {
        // Safari keeps Share in the page menu.
        tapWhenHittable(safari.buttons["MoreMenuButton"])
        let shareItem = safari.buttons["ShareButton"].firstMatch
        if !shareItem.waitForExistence(timeout: patience) { record(safari, "menu-\(identifier)") }
        tapWhenHittable(shareItem)
        let hrcek = safari.cells["Hrček"].firstMatch
        if !hrcek.waitForExistence(timeout: patience) { record(safari, "sheet-\(identifier)") }
        tapWhenHittable(hrcek)
        let outcome = safari.descendants(matching: .any)[identifier]
        XCTAssertTrue(
            outcome.waitForExistence(timeout: patience),
            "expected \(identifier):\n\(safari.debugDescription)")
        // The sheet closes itself after a save.
        XCTAssertTrue(outcome.waitForNonExistence(timeout: patience))
    }

    /// Keeps what Safari showed, for working out why a step failed.
    @MainActor
    private func record(_ app: XCUIApplication, _ name: String) {
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "\(name)-tree"
        tree.lifetime = .keepAlways
        add(tree)
        let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screen.name = "\(name)-screen"
        screen.lifetime = .keepAlways
        add(screen)
    }
}
