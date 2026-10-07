import Foundation
import HrcekKit
import Testing

@Suite struct KeychainCredentialStoreTests {
    let credentials: Credentials

    init() throws {
        credentials = Credentials(
            server: try ServerAddress("https://hrcek.example.com"), token: "hrcek_test1",
            displayName: "Nina")
    }

    @Test func savesReplacesAndDeletes() throws {
        let store = KeychainCredentialStore(
            service: "app.hrcek.tests.\(UUID().uuidString)", accessGroup: nil)
        defer { try? store.delete() }
        #expect(try store.load() == nil)
        try store.save(credentials)
        let replacement = Credentials(
            server: credentials.server, token: "hrcek_test2", displayName: "Nina")
        try store.save(replacement)
        #expect(try store.load() == replacement)
        try store.delete()
        #expect(try store.load() == nil)
    }

    @Test func deletingNothingIsFine() throws {
        let store = KeychainCredentialStore(
            service: "app.hrcek.tests.\(UUID().uuidString)", accessGroup: nil)
        try store.delete()
    }

    /// The group is what lets the share extension read what the app saved.
    @Test func sharedStoreUsesTheSharedGroup() throws {
        let group = try #require(
            Bundle.main.object(forInfoDictionaryKey: "HrcekKeychainGroup") as? String)
        #expect(group.hasSuffix(".Hrcek.shared"))
        let store = KeychainCredentialStore(
            service: "app.hrcek.tests.\(UUID().uuidString)", accessGroup: group)
        defer { try? store.delete() }
        try store.save(credentials)
        #expect(try store.load() == credentials)
    }
}
