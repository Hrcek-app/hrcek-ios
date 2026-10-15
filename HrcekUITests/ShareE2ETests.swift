import XCTest

/// The whole flow, as a person does it: sign in in the app, then share a
/// page from Safari to Hrček. Run by scripts/e2e against a real backend.
final class ShareE2ETests: XCTestCase {
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
        saveWithNotesAndATag(from: safari)
        updateTheTitleAndTags(from: safari)
    }

    @MainActor
    private func saveWithNotesAndATag(from safari: XCUIApplication) {
        openShareSheet(from: safari)
        let notes = safari.descendants(matching: .any)["notes"].firstMatch
        XCTAssertTrue(notes.waitForExistence(timeout: patience), safari.debugDescription)
        let title = safari.descendants(matching: .any)["title"].firstMatch
        XCTAssertEqual(title.value as? String, "Hrček E2E page", "the title comes from the page")
        XCTAssertTrue(
            safari.descendants(matching: .any)["selectedPicture"].waitForExistence(
                timeout: patience), "the page's picture is offered")
        offersTheLazyPicture(in: safari)
        tapWhenHittable(notes)
        notes.typeText("Kept by E2E")
        let tagField = safari.textFields["tagField"].firstMatch
        scrollToHittable(tagField, in: safari)
        tagField.tap()
        tagField.typeText("e2e\n")
        choosePriority("high", in: safari)
        save(in: safari, expecting: "saved")
    }

    /// The page's second picture is held back by a lazy loader, as on many sites.
    @MainActor
    private func offersTheLazyPicture(in safari: XCUIApplication) {
        // Change appears only when there is more than one picture to choose.
        let change = safari.descendants(matching: .any)["changePicture"].firstMatch
        XCTAssertTrue(change.waitForExistence(timeout: patience), "the lazy picture is offered")
        tapWhenHittable(change)
        XCTAssertTrue(
            safari.descendants(matching: .any)["picture-2"].waitForExistence(timeout: patience))
        safari.descendants(matching: .any)["chooserPreview"].firstMatch.tap()
    }

    @MainActor
    private func updateTheTitleAndTags(from safari: XCUIApplication) {
        openShareSheet(from: safari)
        XCTAssertTrue(
            safari.descendants(matching: .any)["alreadySaved"].waitForExistence(timeout: patience))
        // The picture saved the first time, fetched back with the token.
        XCTAssertTrue(safari.descendants(matching: .any)["selectedPicture"].exists)
        XCTAssertFalse(
            safari.staticTexts["It has a picture that cannot be shown here"].exists,
            safari.debugDescription)
        let notes = safari.descendants(matching: .any)["notes"].firstMatch
        XCTAssertEqual(notes.value as? String, "Kept by E2E")
        replaceText(
            of: safari.descendants(matching: .any)["title"].firstMatch, with: "Edited by E2E")
        // Taken off, then put back from the account's own labels.
        let chip = safari.buttons["tag-e2e"].firstMatch
        scrollToHittable(chip, in: safari)
        chip.tap()
        XCTAssertTrue(chip.waitForNonExistence(timeout: patience))
        let tagField = safari.textFields["tagField"].firstMatch
        scrollToHittable(tagField, in: safari)
        tagField.tap()
        tagField.typeText("E2")
        let suggestion = safari.buttons["suggestion-e2e"].firstMatch
        XCTAssertTrue(suggestion.waitForExistence(timeout: patience), safari.debugDescription)
        scrollToHittable(suggestion, in: safari)
        suggestion.tap()
        XCTAssertTrue(chip.waitForExistence(timeout: patience))
        save(in: safari, expecting: "updated")
    }

    /// Priority is the field every new account starts with.
    @MainActor
    private func choosePriority(_ value: String, in safari: XCUIApplication) {
        let fields = safari.descendants(matching: .any)["yourFields"].firstMatch
        scrollToHittable(fields, in: safari)
        fields.tap()
        let priority = safari.buttons["field-Priority"].firstMatch
        XCTAssertTrue(priority.waitForExistence(timeout: patience), safari.debugDescription)
        scrollToHittable(priority, in: safari)
        priority.tap()
        let option = safari.buttons[value].firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: patience), safari.debugDescription)
        option.tap()
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

    @MainActor
    private func replaceText(of field: XCUIElement, with text: String) {
        XCTAssertTrue(field.waitForExistence(timeout: patience))
        // Puts the cursor at the end, so every character can be deleted.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        let old = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count))
        field.typeText(text)
    }
}
