import Foundation
import Synchronization
import Testing

@testable import HrcekKit

@MainActor
@Suite struct SessionModelTests {
    nonisolated static let signInReplies: StubURLProtocol.Handler = { request in
        request.url?.path() == "/api/auth/me"
            ? (200, Data(#"{"email":"nina@example.com","display_name":"Nina"}"#.utf8))
            : (201, Data(#"{"id":1,"name":"x","token":"hrcek_test1"}"#.utf8))
    }

    func model(
        _ session: URLSession, stored: Credentials? = nil
    ) -> (SessionModel, InMemoryCredentialStore) {
        let store = InMemoryCredentialStore(stored)
        let auth = AuthService(store: store, deviceName: "d", session: session, language: "en")
        return (SessionModel(auth: auth), store)
    }

    func fill(_ model: SessionModel, server: String = "hrcek.example.com", password: String = "x") {
        model.serverText = server
        model.email = "nina@example.com"
        model.password = password
    }

    @Test func startsSignedInWhenCredentialsAreStored() throws {
        let stored = try sampleCredentials()
        let (model, _) = model(StubURLProtocol.session(status: 500, json: "{}"), stored: stored)
        #expect(model.credentials == stored)
    }

    @Test func signsInAndForgetsThePassword() async {
        let (model, store) = model(StubURLProtocol.session(Self.signInReplies))
        fill(model, password: "correct horse")
        #expect(model.canSignIn)
        await model.signIn()
        #expect(model.credentials?.displayName == "Nina")
        #expect(model.password.isEmpty)
        #expect(model.errorMessage == nil)
        #expect((try? store.load()) != nil)
    }

    @Test func showsTheServersRefusal() async {
        let (model, _) = model(
            StubURLProtocol.session(
                status: 401,
                json: #"""
                    {"error":{"code":"HRC-AUTH-0001","message":"Wrong password.","details":{}}}
                    """#))
        fill(model)
        await model.signIn()
        #expect(model.credentials == nil)
        #expect(model.errorMessage == "Wrong password.")
        #expect(model.password == "x")
    }

    @Test func refusesAnInsecureAddressWithoutCallingTheServer() async {
        let (model, _) = model(
            StubURLProtocol.session { _ in
                Issue.record("no request expected")
                return (500, Data())
            })
        fill(model, server: "http://hrcek.example.com")
        await model.signIn()
        #expect(model.errorMessage == "The address must start with https://.")
    }

    @Test func cannotSignInWithMissingFields() {
        let (model, _) = model(StubURLProtocol.session(status: 500, json: "{}"))
        fill(model, password: " ")
        #expect(!model.canSignIn)
    }

    @Test func cannotSignInWhileWorking() async {
        let calls = Mutex(0)
        let (model, _) = model(
            StubURLProtocol.session { request in
                if request.url?.path() == "/api/auth/tokens/exchange" {
                    calls.withLock { $0 += 1 }
                }
                return try Self.signInReplies(request)
            })
        fill(model)
        async let first: Void = model.signIn()
        async let second: Void = model.signIn()
        _ = await (first, second)
        #expect(calls.withLock { $0 } == 1)
    }

    @Test func signOutForgets() throws {
        let (model, store) = model(
            StubURLProtocol.session(status: 500, json: "{}"), stored: try sampleCredentials())
        model.signOut()
        #expect(model.credentials == nil)
        #expect(try store.load() == nil)
    }

    @Test func revokedTokenSignsOut() async throws {
        let (model, store) = model(
            StubURLProtocol.session(
                status: 401,
                json: #"""
                    {"error":{"code":"HRC-AUTH-0004","message":"Invalid token.","details":{}}}
                    """#),
            stored: try sampleCredentials())
        await model.refresh()
        #expect(model.credentials == nil)
        #expect(try store.load() == nil)
        #expect(model.errorMessage == "Your sign-in has expired or was revoked. Sign in again.")
    }

    @Test func staysSignedInWhileOffline() async throws {
        let (model, _) = model(
            StubURLProtocol.session { _ in throw URLError(.notConnectedToInternet) },
            stored: try sampleCredentials())
        await model.refresh()
        #expect(model.credentials != nil)
        #expect(model.errorMessage == nil)
    }
}
