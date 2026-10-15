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
    func launchApp(resetting: Bool = true, seeding pending: Int = 0) -> XCUIApplication {
        let app = XCUIApplication()
        let locale = TestLanguage.current == "sl" ? "sl_SI" : "en_GB"
        app.launchArguments += [
            "-AppleLanguages", "(\(TestLanguage.current))", "-AppleLocale", locale,
        ]
        if resetting { app.launchArguments.append("-HrcekResetState") }
        if pending > 0 {
            app.launchArguments += [
                "-HrcekSeedPending", "\(pending)", "-HrcekSeedServer", stubServer,
            ]
        }
        app.launch()
        return app
    }
}

/// How long a step may take: a freshly booted CI simulator can take most
/// of a minute per step.
let patience: TimeInterval = 60

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

/// Signs in by pasting a token, the way a person would.
@MainActor
func signIn(_ app: XCUIApplication, token: String, server: String = stubServer) {
    let field = app.textFields["server"]
    XCTAssertTrue(field.waitForExistence(timeout: 10))
    field.tap()
    field.typeText(server)
    // The second segment, whatever the language calls it.
    app.segmentedControls["method"].buttons.element(boundBy: 1).tap()
    app.secureTextFields["token"].tap()
    app.secureTextFields["token"].typeText(token)
    app.buttons["signIn"].tap()
}

/// iOS offers to save the password after a sign-in; a person would decline.
@MainActor
func declineSavingThePassword(_ app: XCUIApplication) {
    let notNow = app.buttons["Not Now"]
    // A tap while the prompt is still sliding in is lost, so try again.
    for _ in 0..<3 where notNow.waitForExistence(timeout: 3) {
        tapWhenHittable(notNow)
        if notNow.waitForNonExistence(timeout: 3) { return }
    }
    XCTAssertFalse(notNow.exists, "the save-password prompt would not go away")
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

/// Tells scripts/e2e-proxy to play an outage, or to end it.
func setOutage(_ down: Bool, server: String) async throws {
    let url = try XCTUnwrap(URL(string: server + (down ? "/proxy/outage" : "/proxy/restore")))
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    let (_, response) = try await URLSession.shared.data(for: request)
    XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
}

/// Sharing from Safari, for the end-to-end tests.
extension XCTestCase {
    /// The keyboard covers the lower half of the form, as it would for a person.
    @MainActor
    func scrollToHittable(_ element: XCUIElement, in app: XCUIApplication) {
        // isHittable can be true for an element still under the keyboard.
        func covered() -> Bool {
            let keyboard = app.keyboards.firstMatch
            let bottom =
                keyboard.exists ? keyboard.frame.minY : app.windows.firstMatch.frame.maxY
            return !element.isHittable || element.frame.maxY > bottom
        }
        for _ in 0..<6 where covered() { app.swipeUp() }
        XCTAssertFalse(covered(), app.debugDescription)
        // A tap while the form still glides after a swipe lands elsewhere.
        var frame = CGRect.null
        for _ in 0..<10 where element.frame != frame {
            frame = element.frame
            Thread.sleep(forTimeInterval: 0.3)
        }
    }

    @MainActor
    func openShareSheet(from safari: XCUIApplication) {
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
    func record(_ app: XCUIApplication, _ name: String) {
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
