import Foundation
import Synchronization
import Testing

@testable import HrcekKit

@Suite struct EntryServiceTests {
    static let notFound = Data(
        #"{"error":{"code":"HRC-CORE-0003","message":"No.","details":{}}}"#.utf8)
    static let entry = Data(
        #"""
        {"id":1,"url":"https://example.com/a","title":"A","notes":"N","tags":["t"],
         "fields":{"Priority":"high"},"image":{"url":"/entries/1/image/","width":10,"height":20},
         "created_at":"2026-10-13T10:00:00Z","updated_at":"2026-10-13T10:00:00Z"}
        """#.utf8)

    func service(_ handler: @escaping StubURLProtocol.Handler) throws -> EntryService {
        EntryService(
            credentials: try sampleCredentials(), language: "en",
            session: StubURLProtocol.session(handler))
    }

    @Test func findsTheEntryHeldAtAnAddress() async throws {
        let service = try service { request in
            #expect(request.url?.path() == "/api/entries/lookup")
            let body = try request.jsonObject()
            #expect(body["url"] as? String == "https://example.com/a")
            return (200, Self.entry)
        }
        let found = try await service.lookup("https://example.com/a")
        #expect(found?.notes == "N")
        #expect(found?.tags == ["t"])
        #expect(found?.fields == ["Priority": "high"])
        #expect(found?.image == ImageOut(url: "/entries/1/image/", width: 10, height: 20))
    }

    @Test func answersNothingForAnAddressNotHeld() async throws {
        let service = try service { _ in (404, Self.notFound) }
        #expect(try await service.lookup("https://example.com/a") == nil)
    }

    @Test func passesOtherLookupFailuresOn() async throws {
        let service = try service { _ in throw URLError(.timedOut) }
        await #expect(throws: APIError.transport(.timedOut)) {
            try await service.lookup("https://example.com/a")
        }
    }

    @Test func tellsCreatedFromUpdated() async throws {
        let status = Mutex(201)
        let service = try service { _ in (status.withLock { $0 }, Self.entry) }
        let request = EntryDraft(url: "https://example.com/a").request()
        #expect(try await service.save(request).created)
        status.withLock { $0 = 200 }
        #expect(try await service.save(request).created == false)
    }

    @Test func postsTheWholeEntryButNotWhatItLeavesAlone() async throws {
        let posted = Mutex(Data())
        let service = try service { request in
            let body = request.bodyData
            posted.withLock { $0 = body }
            return (201, Self.entry)
        }
        var draft = EntryDraft(url: "https://example.com/a")
        draft.title = "A"
        draft.addTag("t")
        _ = try await service.save(draft.request())
        let body = try URLRequest.jsonObject(posted.withLock { $0 })
        #expect(body["title"] as? String == "A")
        #expect(body["notes"] as? String == "")
        #expect(body["tags"] as? [String] == ["t"])
        // Omitted, both mean "leave as it is" to the server.
        #expect(body["fields"] == nil)
        #expect(body["image_url"] == nil)
    }
}
