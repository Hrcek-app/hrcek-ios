import Foundation
import Synchronization
import Testing

@testable import HrcekKit

@MainActor
@Suite struct ShareModelTests {
    nonisolated static let notFound = Data(
        #"{"error":{"code":"HRC-CORE-0003","message":"No.","details":{}}}"#.utf8)
    nonisolated static let created = Data(
        #"{"id":1,"url":"https://example.com/a","title":"A"}"#.utf8)

    let page: SharedPage

    init() throws {
        page = SharedPage(url: try #require(URL(string: "https://example.com/a")), title: "A")
    }

    func model(
        _ handler: @escaping StubURLProtocol.Handler, stored: Credentials?
    ) -> (ShareModel, InMemoryCredentialStore) {
        let store = InMemoryCredentialStore(stored)
        let session = StubURLProtocol.session(handler)
        let model = ShareModel(store: store) {
            EntrySaver(credentials: $0, language: "en", session: session)
        }
        return (model, store)
    }

    @Test func savesAPage() async throws {
        let (model, _) = model(
            { request in
                request.url?.path() == "/api/entries/lookup"
                    ? (404, Self.notFound) : (201, Self.created)
            }, stored: try sampleCredentials())
        await model.save(page)
        #expect(model.state == .saved)
    }

    @Test func reportsAPageAlreadySaved() async throws {
        let (model, _) = model({ _ in (200, Self.created) }, stored: try sampleCredentials())
        await model.save(page)
        #expect(model.state == .alreadySaved)
    }

    @Test func asksToSignInWhenSignedOut() async {
        let (model, _) = model(
            { _ in
                Issue.record("no request expected")
                return (500, Data())
            }, stored: nil)
        await model.save(page)
        #expect(model.state == .signedOut)
    }

    @Test func revokedTokenAsksToSignIn() async throws {
        let (model, store) = model(
            { _ in
                (
                    401,
                    Data(
                        #"{"error":{"code":"HRC-AUTH-0004","message":"Invalid.","details":{}}}"#
                            .utf8)
                )
            }, stored: try sampleCredentials())
        await model.save(page)
        #expect(model.state == .signedOut)
        #expect(try store.load() == nil)
    }

    @Test func offlineShowsMessageAndCanRetry() async throws {
        let online = Mutex(false)
        let (model, _) = model(
            { request in
                guard online.withLock({ $0 }) else { throw URLError(.notConnectedToInternet) }
                return request.url?.path() == "/api/entries/lookup"
                    ? (404, Self.notFound) : (201, Self.created)
            }, stored: try sampleCredentials())
        await model.save(page)
        #expect(model.state == .failed("You're offline. Connect to the internet and try again."))
        online.withLock { $0 = true }
        await model.retry()
        #expect(model.state == .saved)
    }

    @Test func explainsWhenNothingCouldBeSaved() async throws {
        let (model, _) = model({ _ in (500, Data()) }, stored: try sampleCredentials())
        await model.save(nil)
        #expect(model.state == .failed("There's no web address to save here."))
    }
}
