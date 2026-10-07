import XCTest

final class LaunchUITests: XCTestCase {
    @MainActor
    func testShowsIntroductionInTheDeviceLanguage() {
        continueAfterFailure = false
        let app = launchApp()
        let expected = TestLanguage.text(
            en: "Save pages to Hrček with your browser's Share button.",
            sl: "Strani shranite v Hrček z gumbom Deli v brskalniku.")
        XCTAssertTrue(app.staticTexts["introduction"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["introduction"].label, expected)
    }
}
