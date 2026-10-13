import HrcekKit
import SwiftUI

@main
struct HrcekApp: App {
    @State private var session: SessionModel
    @State private var language: LanguageModel

    init() {
        let version =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        Log.app.info("Launched version \(version ?? "unknown", privacy: .public)")
        #if DEBUG
            // UI tests start every case signed out.
            if ProcessInfo.processInfo.arguments.contains("-HrcekResetState") {
                try? KeychainCredentialStore.shared.delete()
                try? KeychainLanguageStore.shared.save(nil)
            }
        #endif
        // First, so everything after speaks the chosen language.
        _language = State(initialValue: LanguageModel(store: KeychainLanguageStore.shared))
        _session = State(initialValue: SessionModel(auth: .live()))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(language)
                .environment(\.locale, language.locale)
        }
    }
}
