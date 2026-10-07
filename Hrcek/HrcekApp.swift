import HrcekKit
import SwiftUI

@main
struct HrcekApp: App {
    init() {
        let version =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        Log.app.info("Launched version \(version ?? "unknown", privacy: .public)")
    }

    var body: some Scene {
        WindowGroup { RootView() }
    }
}
