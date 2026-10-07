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
