import Foundation
import Synchronization
import Testing

@testable import HrcekKit

/// A fake Hrček holding at most one entry, counting what it is asked.
final class FakeEntries: Sendable {
    struct State {
        var held: String?
        var posts: [Data] = []
        var lookups = 0
        var failLookups = 0
        var refuse: (Int, String)?
        /// A failure waiting will not fix, so nothing is kept for later.
        var untrusted = false
    }

    let state: Mutex<State>

    init(held: String? = nil) {
        state = Mutex(State(held: held))
    }

    static func entry(title: String = "Held", notes: String = "Kept", tags: String = #"["x"]"#)
        -> String
    {
        #"""
        {"id":1,"url":"https://example.com/a","title":"\#(title)","notes":"\#(notes)",
         "tags":\#(tags),"fields":{},"image":null}
        """#
    }

    func firstPost() throws -> [String: Any] {
        try URLRequest.jsonObject(state.withLock { $0.posts.first } ?? Data("{}".utf8))
    }

    func handle(_ request: URLRequest) throws -> (Int, Data) {
        try state.withLock { state in
            if state.untrusted { throw URLError(.serverCertificateUntrusted) }
            if let (status, code) = state.refuse {
                return (
                    status,
                    Data(#"{"error":{"code":"\#(code)","message":"No.","details":{}}}"#.utf8)
                )
            }
            if request.url?.path() == "/api/fields/" {
                return (200, Data(#"{"items":[],"count":0}"#.utf8))
            }
            if request.url?.path() == "/api/entries/lookup" {
                state.lookups += 1
                if state.failLookups > 0 {
                    state.failLookups -= 1
                    // Not an outage, which would keep the entry for later.
                    return (500, Data("<html>trouble</html>".utf8))
                }
                guard let held = state.held else {
                    return (
                        404,
                        Data(
                            #"{"error":{"code":"HRC-CORE-0003","message":"No.","details":{}}}"#.utf8
                        )
                    )
                }
                return (200, Data(held.utf8))
            }
            state.posts.append(request.bodyData)
            let created = state.held == nil
            state.held = Self.entry()
            return (created ? 201 : 200, Data(Self.entry().utf8))
        }
    }
}

@MainActor
@Suite struct ShareModelTests {
    let page: SharedPage

    init() throws {
        page = SharedPage(url: try #require(URL(string: "https://example.com/a")), title: "A")
    }

    func model(_ fake: FakeEntries, stored: Credentials?) -> (ShareModel, InMemoryCredentialStore) {
        let store = InMemoryCredentialStore(stored)
        let session = StubURLProtocol.session { try fake.handle($0) }
        let model = ShareModel(store: store, queue: temporaryQueue(), pages: .offline) {
            EntryService(credentials: $0, language: "en", session: session)
        }
        return (model, store)
    }

    @Test func offersThePageWhenItIsNotHeld() async throws {
        let (model, _) = model(FakeEntries(), stored: try sampleCredentials())
        await model.start(page)
        #expect(model.phase == .editing)
        #expect(model.isExisting == false)
        #expect(model.draft.title == "A")
    }

    @Test func fillsTheFormWithTheEntryHeld() async throws {
        let (model, _) = model(
            FakeEntries(held: FakeEntries.entry()), stored: try sampleCredentials())
        await model.start(page)
        #expect(model.phase == .editing)
        #expect(model.isExisting)
        #expect(model.draft.title == "Held")
        #expect(model.draft.notes == "Kept")
        #expect(model.draft.tags == ["x"])
    }

    @Test func savesANewPage() async throws {
        let fake = FakeEntries()
        let (model, _) = model(fake, stored: try sampleCredentials())
        await model.start(page)
        model.draft.notes = "Mine"
        #expect(await model.save())
        #expect(model.phase == .saved(created: true))
        #expect(try fake.firstPost()["notes"] as? String == "Mine")
    }

    @Test func updatesAnEntryHeld() async throws {
        let (model, _) = model(
            FakeEntries(held: FakeEntries.entry()), stored: try sampleCredentials())
        await model.start(page)
        #expect(await model.save())
        #expect(model.phase == .saved(created: false))
    }

    @Test func keepsATagTypedButNotYetAdded() async throws {
        let fake = FakeEntries()
        let (model, _) = model(fake, stored: try sampleCredentials())
        await model.start(page)
        model.tagText = "typed"
        _ = await model.save()
        #expect(try fake.firstPost()["tags"] as? [String] == ["typed"])
    }

    @Test func addsEveryTagBeforeAComma() async throws {
        let (model, _) = model(FakeEntries(), stored: try sampleCredentials())
        await model.start(page)
        model.tagText = "one, two,"
        model.commitTagText()
        #expect(model.draft.tags == ["one", "two"])
        #expect(model.tagText.isEmpty)
    }

    @Test func asksToSignInWhenSignedOut() async {
        let fake = FakeEntries()
        let (model, _) = model(fake, stored: nil)
        await model.start(page)
        #expect(model.phase == .signedOut)
        #expect(fake.state.withLock { $0.lookups } == 0)
    }

    @Test func aRevokedTokenSignsOutBeforeTheFormOpens() async throws {
        let fake = FakeEntries()
        fake.state.withLock { $0.refuse = (401, "HRC-AUTH-0004") }
        let (model, store) = model(fake, stored: try sampleCredentials())
        await model.start(page)
        #expect(model.phase == .revoked)
        #expect(try store.load() == nil)
    }

    @Test func aTokenRevokedWhileEditingSignsOut() async throws {
        let fake = FakeEntries()
        let (model, store) = model(fake, stored: try sampleCredentials())
        await model.start(page)
        fake.state.withLock { $0.refuse = (401, "HRC-AUTH-0004") }
        #expect(await model.save() == false)
        #expect(model.phase == .revoked)
        #expect(try store.load() == nil)
    }

    @Test func aFailedSaveKeepsTheFormAndSaysWhy() async throws {
        let fake = FakeEntries()
        let (model, _) = model(fake, stored: try sampleCredentials())
        await model.start(page)
        model.draft.notes = "Typed"
        fake.state.withLock { $0.untrusted = true }
        #expect(await model.save() == false)
        #expect(model.phase == .editing)
        #expect(model.draft.notes == "Typed")
        #expect(model.message == "Can't make a secure connection to the server.")
    }

    @Test func looksAgainBeforeWritingWhenTheFirstLookFailed() async throws {
        let fake = FakeEntries(held: FakeEntries.entry())
        fake.state.withLock { $0.failLookups = 1 }
        let (model, _) = model(fake, stored: try sampleCredentials())
        await model.start(page)
        #expect(model.phase == .editing)
        #expect(model.isExisting == false)
        #expect(model.message == "The server is having trouble. Try again later.")

        #expect(await model.save() == false)
        #expect(fake.state.withLock { $0.posts.count } == 0, "must not replace what it never saw")
        #expect(model.isExisting)
        #expect(model.draft.notes == "Kept")
        #expect(
            model.message
                == "This page is already saved. Check what it holds, then save again.")

        #expect(await model.save())
        #expect(model.phase == .saved(created: false))
    }

    @Test func explainsWhenThereIsNothingToSave() async throws {
        let (model, _) = model(FakeEntries(), stored: try sampleCredentials())
        await model.start(nil)
        #expect(model.phase == .unavailable("There's no web address to save here."))
    }
}
