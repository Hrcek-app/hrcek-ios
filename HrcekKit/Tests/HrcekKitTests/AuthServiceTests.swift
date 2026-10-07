import Foundation
import Synchronization
import Testing

@testable import HrcekKit

@Suite struct AuthServiceTests {
    let server: ServerAddress

    init() throws {
        server = try ServerAddress("https://hrcek.example.com")
    }

    static let token = Data(#"{"id":1,"name":"x","token":"hrcek_test1"}"#.utf8)

    @Test func signInExchangesThePasswordForATokenAndRemembersIt() async throws {
        let session = StubURLProtocol.session { request in
            switch request.url?.path() {
            case "/api/auth/tokens/exchange":
                let body = try request.jsonBody()
                #expect(body["identifier"] == "nina@example.com")
                #expect(body["password"] == "correct horse")
                #expect(body["name"] == "Hrček for iOS (Nina's iPhone)")
                #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
                return (201, Self.token)
            case "/api/auth/me":
                #expect(
                    request.value(forHTTPHeaderField: "Authorization") == "Bearer hrcek_test1")
                return (200, Data(#"{"email":"nina@example.com","display_name":"Nina"}"#.utf8))
            default:
                Issue.record("unexpected \(request.url?.absoluteString ?? "")")
                return (404, Data())
            }
        }
        let store = InMemoryCredentialStore()
        let auth = AuthService(
            store: store, deviceName: "Nina's iPhone", session: session, language: "en")
        let credentials = try await auth.signIn(
            server: server, email: " nina@example.com ", password: "correct horse")
        #expect(
            credentials == Credentials(server: server, token: "hrcek_test1", displayName: "Nina"))
        #expect(try store.load() == credentials)
        #expect(auth.current() == credentials)
    }

    @Test func fallsBackToTheEmailWithoutADisplayName() async throws {
        let session = StubURLProtocol.session { request in
            request.url?.path() == "/api/auth/me"
                ? (200, Data(#"{"email":"nina@example.com","display_name":null}"#.utf8))
                : (201, Self.token)
        }
        let auth = AuthService(
            store: InMemoryCredentialStore(), deviceName: "d", session: session, language: "en")
        let credentials = try await auth.signIn(
            server: server, email: "nina@example.com", password: "p")
        #expect(credentials.displayName == "nina@example.com")
    }

    @Test func aRefusedSignInStoresNothing() async throws {
        let session = StubURLProtocol.session(
            status: 401,
            json: #"{"error":{"code":"HRC-AUTH-0001","message":"Wrong.","details":{}}}"#)
        let store = InMemoryCredentialStore()
        let auth = AuthService(store: store, deviceName: "d", session: session, language: "en")
        await #expect(throws: APIError.self) {
            try await auth.signIn(server: server, email: "n@example.com", password: "nope")
        }
        #expect(try store.load() == nil)
    }

    @Test func refreshUpdatesTheDisplayName() async throws {
        let session = StubURLProtocol.session(
            status: 200, json: #"{"email":"n@example.com","display_name":"Nina N."}"#)
        let store = InMemoryCredentialStore(try sampleCredentials())
        let auth = AuthService(store: store, deviceName: "d", session: session, language: "en")
        #expect(try await auth.refresh()?.displayName == "Nina N.")
        #expect(try store.load()?.displayName == "Nina N.")
    }

    @Test func refreshWithoutCredentialsDoesNothing() async throws {
        let session = StubURLProtocol.session { _ in
            Issue.record("no request expected")
            return (500, Data())
        }
        let auth = AuthService(
            store: InMemoryCredentialStore(), deviceName: "d", session: session, language: "en")
        #expect(try await auth.refresh() == nil)
    }

    @Test func refreshDoesNotUndoASignOut() async throws {
        let asked = Mutex(false)
        let release = DispatchSemaphore(value: 0)
        let session = StubURLProtocol.session { _ in
            asked.withLock { $0 = true }
            release.wait()
            return (200, Data(#"{"email":"n@example.com","display_name":"Nina"}"#.utf8))
        }
        let store = InMemoryCredentialStore(try sampleCredentials())
        let auth = AuthService(store: store, deviceName: "d", session: session, language: "en")
        async let refreshed = auth.refresh()
        while !asked.withLock({ $0 }) { try await Task.sleep(for: .milliseconds(10)) }
        try auth.signOut()
        release.signal()
        #expect(try await refreshed == nil)
        #expect(try store.load() == nil)
    }

    @Test func signOutForgetsLocally() throws {
        let store = InMemoryCredentialStore(try sampleCredentials())
        let auth = AuthService(store: store, deviceName: "d", language: "en")
        try auth.signOut()
        #expect(try store.load() == nil)
    }
}
