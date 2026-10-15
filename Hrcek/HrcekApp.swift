import HrcekKit
import SwiftUI

@main
struct HrcekApp: App {
    @State private var session: SessionModel
    @State private var language: LanguageModel
    @State private var pending = PendingModel(queue: .shared)

    init() {
        let version =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        Log.app.info("Launched version \(version ?? "unknown", privacy: .public)")
        #if DEBUG
            // UI tests start every case signed out, with nothing kept.
            if ProcessInfo.processInfo.arguments.contains("-HrcekResetState") {
                try? KeychainCredentialStore.shared.delete()
                try? KeychainLanguageStore.shared.save(nil)
                for entry in PendingQueue.shared.list() {
                    try? PendingQueue.shared.remove(entry.url, id: entry.id)
                }
            }
            // UI tests start with pages already kept: `-HrcekSeedPending 2`.
            let defaults = UserDefaults.standard
            let seeded = defaults.integer(forKey: "HrcekSeedPending")
            if seeded > 0,
                let server = try? ServerAddress(
                    defaults.string(forKey: "HrcekSeedServer") ?? "http://localhost:8765")
            {
                for index in 1...seeded {
                    let url = "https://example.com/seeded-\(index)"
                    try? PendingQueue.shared.put(
                        PendingEntry(
                            request: EntryIn(
                                url: url, title: "Seeded \(index)", notes: "", tags: ["seed"]),
                            picture: nil, server: server,
                            savedAt: .now.addingTimeInterval(Double(index))),
                        picture: nil)
                }
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
                .environment(pending)
                .environment(\.locale, language.locale)
        }
    }
}
