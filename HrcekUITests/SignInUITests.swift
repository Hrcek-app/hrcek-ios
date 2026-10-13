import XCTest

final class SignInUITests: XCTestCase {
    @MainActor
    func testSignInShowsWhoIsSignedIn() {
        continueAfterFailure = false
        let app = launchApp()
        signIn(app, email: "nina@example.com")
        let signedIn = app.staticTexts["signedInAs"]
        XCTAssertTrue(signedIn.waitForExistence(timeout: 10))
        XCTAssertEqual(
            signedIn.label,
            TestLanguage.text(
                en: "Signed in as Nina on localhost", sl: "Prijavljeni ste kot Nina na localhost"))
    }

    @MainActor
    func testSignInSurvivesRelaunch() {
        continueAfterFailure = false
        let app = launchApp()
        signIn(app, email: "nina@example.com")
        XCTAssertTrue(app.staticTexts["signedInAs"].waitForExistence(timeout: 10))
        app.terminate()
        let again = launchApp(resetting: false)
        XCTAssertTrue(again.staticTexts["signedInAs"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testWrongPasswordShowsTheServersMessage() {
        let app = launchApp()
        signIn(app, email: "nina@example.com", password: "wrong")
        let error = app.staticTexts["error"]
        XCTAssertTrue(error.waitForExistence(timeout: 10))
        XCTAssertEqual(
            error.label,
            TestLanguage.text(
                en: "The email address or password is not correct.",
                sl: "E-poštni naslov ali geslo ni pravilno."))
    }

    @MainActor
    func testUnconfirmedAddressIsExplained() {
        let app = launchApp()
        signIn(app, email: "unconfirmed@example.com")
        let error = app.staticTexts["error"]
        XCTAssertTrue(error.waitForExistence(timeout: 10))
        XCTAssertEqual(
            error.label,
            TestLanguage.text(
                en: "Confirm your email address before signing in.",
                sl: "Pred prijavo potrdite svoj e-poštni naslov."))
    }

    @MainActor
    func testInsecureAddressIsRefused() {
        let app = launchApp()
        signIn(app, email: "nina@example.com", server: "http://hrcek.example.com")
        let error = app.staticTexts["error"]
        XCTAssertTrue(error.waitForExistence(timeout: 10))
        XCTAssertEqual(
            error.label,
            TestLanguage.text(
                en: "The address must start with https://.",
                sl: "Naslov se mora začeti s https://."))
    }

    @MainActor
    func testSignOutReturnsToTheForm() {
        continueAfterFailure = false
        let app = launchApp()
        signIn(app, email: "nina@example.com")
        XCTAssertTrue(app.buttons["signOut"].waitForExistence(timeout: 10))
        declineSavingThePassword(app)
        tapWhenHittable(app.buttons["signOut"])
        // The dialog exposes its button twice, nested, under one identifier.
        tapWhenHittable(app.buttons["confirmSignOut"].firstMatch)
        XCTAssertTrue(app.textFields["server"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testRevokedTokenIsNoticedOnReturning() throws {
        continueAfterFailure = false
        let app = launchApp()
        signIn(app, email: "nina@example.com")
        XCTAssertTrue(app.staticTexts["signedInAs"].waitForExistence(timeout: 10))
        declineSavingThePassword(app)
        XCUIDevice.shared.press(.home)
        try revokeTokenAtStub()
        app.activate()
        let error = app.staticTexts["error"]
        XCTAssertTrue(error.waitForExistence(timeout: 10))
        XCTAssertEqual(
            error.label,
            TestLanguage.text(
                en: "Your sign-in has expired or was revoked. Sign in again.",
                sl: "Vaša prijava je potekla ali je bila preklicana. Prijavite se znova."))
    }

    /// What removing the token on the website's clients page does.
    private func revokeTokenAtStub() throws {
        var request = URLRequest(url: try XCTUnwrap(URL(string: "\(stubServer)/stub/revoke")))
        request.httpMethod = "POST"
        let done = expectation(description: "revoked")
        URLSession.shared.dataTask(with: request) { _, _, _ in done.fulfill() }.resume()
        wait(for: [done], timeout: 5)
    }

    @MainActor
    func testSignInWithATokenMadeOnTheWebsite() {
        continueAfterFailure = false
        let app = launchApp()
        signIn(app, token: "hrcek_stub")
        XCTAssertTrue(app.staticTexts["signedInAs"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testARefusedTokenShowsTheServersMessage() {
        let app = launchApp()
        signIn(app, token: "hrcek_revoked")
        let error = app.staticTexts["error"]
        XCTAssertTrue(error.waitForExistence(timeout: 10))
        XCTAssertEqual(
            error.label,
            TestLanguage.text(
                en: "This API token is invalid or has expired.",
                sl: "Ta API-žeton ni veljaven ali je potekel."))
    }

    @MainActor
    func testChoosingALanguageChangesTheAppsWordsAndIsKept() {
        continueAfterFailure = false
        let app = launchApp()
        // The other language from the one the phone speaks in this run.
        let slovenian = TestLanguage.current == "sl"
        let other = slovenian ? "English" : "Slovenščina"
        let title = slovenian ? "Sign in to Hrček" : "Prijava v Hrček"
        let picker = app.buttons["language"].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        for _ in 0..<3 where !picker.isHittable { app.swipeUp() }
        picker.tap()
        tapWhenHittable(app.buttons[other].firstMatch)
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 10))
        // The server's messages follow at once too.
        signIn(app, email: "nina@example.com", password: "wrong")
        let error = app.staticTexts["error"]
        XCTAssertTrue(error.waitForExistence(timeout: 10))
        XCTAssertEqual(
            error.label,
            slovenian
                ? "The email address or password is not correct."
                : "E-poštni naslov ali geslo ni pravilno.")
        app.terminate()
        let again = launchApp(resetting: false)
        XCTAssertTrue(again.navigationBars[title].waitForExistence(timeout: 10))
    }
}
