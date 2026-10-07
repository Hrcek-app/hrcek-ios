import XCTest

final class LaunchUITests: XCTestCase {
    @MainActor
    func testOpensOnTheSignInForm() {
        let app = launchApp()
        let title = TestLanguage.text(en: "Sign in to Hrček", sl: "Prijava v Hrček")
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 10))
    }
}
