import XCTest

/// The whole flow, as a person does it: sign in in the app, then share a
/// page from Safari to Hrček. Run by scripts/e2e against a real backend.
final class ShareE2ETests: XCTestCase {
    /// A freshly booted CI simulator can take most of a minute per step.
    private let patience: TimeInterval = 60

    @MainActor
    func testSharingAPageFromSafariSavesItThenUpdatesIt() throws {
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
        openShareSheet(from: safari)
        let notes = safari.descendants(matching: .any)["notes"].firstMatch
        XCTAssertTrue(notes.waitForExistence(timeout: patience), safari.debugDescription)
        tapWhenHittable(notes)
        notes.typeText("Kept by E2E")
        let tagField = safari.textFields["tagField"].firstMatch
        scrollToHittable(tagField, in: safari)
        tagField.tap()
        tagField.typeText("e2e\n")
        save(in: safari, expecting: "saved")

        openShareSheet(from: safari)
        XCTAssertTrue(
            safari.descendants(matching: .any)["alreadySaved"].waitForExistence(timeout: patience))
        XCTAssertEqual(notes.value as? String, "Kept by E2E")
        replaceText(
            of: safari.descendants(matching: .any)["title"].firstMatch, with: "Edited by E2E")
        save(in: safari, expecting: "updated")
    }

    @MainActor
    private func save(in safari: XCUIApplication, expecting identifier: String) {
        tapWhenHittable(safari.buttons["save"].firstMatch)
        let outcome = safari.descendants(matching: .any)[identifier]
        XCTAssertTrue(
            outcome.waitForExistence(timeout: patience),
            "expected \(identifier):\n\(safari.debugDescription)")
        // The sheet closes itself after a save.
        XCTAssertTrue(outcome.waitForNonExistence(timeout: patience))
    }

    /// The keyboard covers the lower half of the form, as it would for a person.
    @MainActor
    private func scrollToHittable(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<4 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }

    @MainActor
    private func replaceText(of field: XCUIElement, with text: String) {
        XCTAssertTrue(field.waitForExistence(timeout: patience))
        // Puts the cursor at the end, so every character can be deleted.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        let old = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count))
        field.typeText(text)
    }

    @MainActor
    private func openShareSheet(from safari: XCUIApplication) {
        // Safari keeps Share in the page menu.
        tapWhenHittable(safari.buttons["MoreMenuButton"])
        let shareItem = safari.buttons["ShareButton"].firstMatch
        if !shareItem.waitForExistence(timeout: patience) { record(safari, "menu") }
        tapWhenHittable(shareItem)
        let hrcek = safari.cells["Hrček"].firstMatch
        if !hrcek.waitForExistence(timeout: patience) { record(safari, "sheet") }
        tapWhenHittable(hrcek)
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
