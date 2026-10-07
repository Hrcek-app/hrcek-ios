import Foundation
import Synchronization
import Testing

@testable import HrcekKit

@Suite struct EntrySaverTests {
    static let notFound = Data(
        #"{"error":{"code":"HRC-CORE-0003","message":"No.","details":{}}}"#.utf8)
    static let created = Data(#"{"id":1,"url":"https://example.com/a","title":"A"}"#.utf8)

    let page: URL

    init() throws {
        page = try #require(URL(string: "https://example.com/a"))
    }

    @Test func savesAnAddressThatIsNotSavedYet() async throws {
        let posted = Mutex<[String: String]?>(nil)
        let session = StubURLProtocol.session { request in
            if request.url?.path() == "/api/entries/lookup" { return (404, Self.notFound) }
            let body = try request.jsonBody()
            posted.withLock { $0 = body }
            return (201, Self.created)
        }
        let saver = EntrySaver(
            credentials: try sampleCredentials(), language: "en", session: session)
        #expect(try await saver.save(url: page, title: "A") == .saved)
        #expect(posted.withLock { $0 } == ["url": "https://example.com/a", "title": "A"])
    }

    @Test func leavesASavedAddressAlone() async throws {
        let session = StubURLProtocol.session { request in
            #expect(
                request.url?.path() == "/api/entries/lookup",
                "must not post over an existing entry")
            return (200, Data(#"{"id":1,"url":"https://example.com/a","title":"Old"}"#.utf8))
        }
        let saver = EntrySaver(
            credentials: try sampleCredentials(), language: "en", session: session)
        #expect(try await saver.save(url: page, title: "New") == .alreadySaved)
    }

    @Test func writesNothingWhenTheLookupFails() async throws {
        let session = StubURLProtocol.session { request in
            #expect(request.url?.path() == "/api/entries/lookup")
            throw URLError(.timedOut)
        }
        let saver = EntrySaver(
            credentials: try sampleCredentials(), language: "en", session: session)
        await #expect(throws: APIError.transport(.timedOut)) {
            try await saver.save(url: page, title: nil)
        }
    }

    @Test func sendsAnEmptyTitleWhenThereIsNone() async throws {
        let posted = Mutex<[String: String]?>(nil)
        let session = StubURLProtocol.session { request in
            if request.url?.path() == "/api/entries/lookup" { return (404, Self.notFound) }
            let body = try request.jsonBody()
            posted.withLock { $0 = body }
            return (201, Self.created)
        }
        let saver = EntrySaver(
            credentials: try sampleCredentials(), language: "en", session: session)
        _ = try await saver.save(url: page, title: nil)
        #expect(posted.withLock { $0?["title"] } == "")
    }
}
