import Foundation
import Testing

@testable import HrcekKit

func sampleCredentials(token: String = "hrcek_test1") throws -> Credentials {
    Credentials(
        server: try ServerAddress("https://hrcek.example.com"), token: token,
        displayName: "Nina")
}

@Suite struct InMemoryCredentialStoreTests {
    @Test func savesLoadsAndDeletes() throws {
        let store = InMemoryCredentialStore()
        #expect(try store.load() == nil)
        let credentials = try sampleCredentials()
        try store.save(credentials)
        #expect(try store.load() == credentials)
        try store.delete()
        #expect(try store.load() == nil)
    }

    @Test func neverPrintsTheToken() throws {
        #expect(!String(describing: try sampleCredentials()).contains("hrcek_test1"))
    }
}
