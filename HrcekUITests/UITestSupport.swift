import XCTest

/// The language a test-plan configuration runs in, set through the
/// `HRCEK_TEST_LANGUAGE` environment variable.
enum TestLanguage {
    static var current: String {
        ProcessInfo.processInfo.environment["HRCEK_TEST_LANGUAGE"] ?? "en"
    }

    /// The text a person sees in the current language. Keeping both here
    /// makes a missing translation fail the Slovenian run.
    static func text(en: String, sl: String) -> String {
        current == "sl" ? sl : en
    }
}

extension XCTestCase {
    @MainActor
    func launchApp(resetting: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        let locale = TestLanguage.current == "sl" ? "sl_SI" : "en_GB"
        app.launchArguments += [
            "-AppleLanguages", "(\(TestLanguage.current))", "-AppleLocale", locale,
        ]
        if resetting { app.launchArguments.append("-HrcekResetState") }
        app.launch()
        return app
    }
}

/// The fake Hrček that `scripts/test-app` starts.
let stubServer =
    "http://localhost:\(ProcessInfo.processInfo.environment["HRCEK_STUB_PORT"] ?? "8765")"

/// Fills in and submits the sign-in form, the way a person would.
@MainActor
func signIn(
    _ app: XCUIApplication, email: String, password: String = "correct horse",
    server: String = stubServer
) {
    let field = app.textFields["server"]
    XCTAssertTrue(field.waitForExistence(timeout: 10))
    field.tap()
    field.typeText(server)
    app.textFields["email"].tap()
    app.textFields["email"].typeText(email)
    app.secureTextFields["password"].tap()
    app.secureTextFields["password"].typeText(password)
    app.buttons["signIn"].tap()
}

/// iOS offers to save the password after a sign-in; a person would decline.
@MainActor
func declineSavingThePassword(_ app: XCUIApplication) {
    let notNow = app.buttons["Not Now"]
    if notNow.waitForExistence(timeout: 3) {
        notNow.tap()
        XCTAssertTrue(notNow.waitForNonExistence(timeout: 5))
    }
}

/// Taps once the element can take the tap: a sheet that is still going
/// away swallows taps without failing them.
@MainActor
func tapWhenHittable(_ element: XCUIElement) {
    let hittable = XCTNSPredicateExpectation(
        predicate: NSPredicate(format: "hittable == true"), object: element)
    XCTAssertEqual(XCTWaiter.wait(for: [hittable], timeout: 10), .completed)
    element.tap()
}
