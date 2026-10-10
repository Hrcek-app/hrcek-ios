import Foundation
import Testing

@Suite struct AppIconTests {
    /// The asset catalog's icon only reaches the home screen if the build
    /// names it in the app's Info.plist.
    @Test func appDeclaresItsIcon() throws {
        let icons = try #require(
            Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any])
        let primary = try #require(icons["CFBundlePrimaryIcon"] as? [String: Any])
        #expect(primary["CFBundleIconName"] as? String == "AppIcon")
    }
}
