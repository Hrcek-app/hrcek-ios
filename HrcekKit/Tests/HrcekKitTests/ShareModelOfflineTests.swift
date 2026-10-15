import Foundation
import Testing

@testable import HrcekKit

@MainActor
@Suite struct ShareModelOfflineTests {
    let page: SharedPage
    let url = "https://example.com/a"
    let queue = temporaryQueue()
    let fake = FakeHrcek()

    init() throws {
        page = SharedPage(url: try #require(URL(string: url)), title: "A")
    }

    func model(pages: PageAccess = .offline, session: URLSession? = nil) throws -> ShareModel {
        let fake = fake
        let session = session ?? StubURLProtocol.session { try fake.handle($0) }
        return ShareModel(
            store: InMemoryCredentialStore(try sampleCredentials()), queue: queue, pages: pages
        ) { EntryService(credentials: $0, language: "en", session: session) }
    }

    @Test func offersToSaveForLaterWhenHrcekCannotBeReached() async throws {
        fake.state.withLock { $0.down = true }
        let model = try model()
        await model.start(page)
        #expect(model.phase == .editing)
        #expect(model.isOffline)
        #expect(model.message == nil, "the offline note replaces the error")
        #expect(model.draft.title == "A")
    }

    @Test func treatsNoConnectionAsUnreachable() async throws {
        let offline = StubURLProtocol.session { _ in throw URLError(.notConnectedToInternet) }
        let model = try model(session: offline)
        await model.start(page)
        #expect(model.isOffline)
    }

    @Test func keepsTheEntryInsteadOfSendingIt() async throws {
        fake.state.withLock { $0.down = true }
        let model = try model()
        await model.start(page)
        model.draft.notes = "Mine"
        #expect(await model.save())
        #expect(model.phase == .kept)
        let kept = try #require(queue.get(url))
        #expect(kept.request.notes == "Mine")
        #expect(kept.server == (try sampleCredentials()).server)
        #expect(kept.state == .waiting)
    }

    @Test func keepsTheEntryWhenTheSaveFindsHrcekDown() async throws {
        let model = try model()
        await model.start(page)
        fake.state.withLock { $0.down = true }
        #expect(await model.save())
        #expect(model.phase == .kept)
        #expect(queue.count() == 1)
    }

    @Test func keepsTheEntryWhenTheSecondLookFindsHrcekDown() async throws {
        fake.state.withLock { $0.refuseLookups = (500, "HRC-CORE-0001") }
        let model = try model()
        await model.start(page)
        #expect(model.isOffline == false, "a failed lookup is not an outage")
        fake.state.withLock { $0.down = true }
        #expect(await model.save())
        #expect(model.phase == .kept)
        #expect(queue.count() == 1)
    }

    @Test func doesNotKeepWhatHrcekRefused() async throws {
        let model = try model()
        await model.start(page)
        fake.state.withLock { $0.refuseSaves = (422, "HRC-CORE-0002") }
        #expect(await model.save() == false)
        #expect(model.phase == .editing)
        #expect(model.message == "Refused: HRC-CORE-0002")
        #expect(queue.count() == 0)
    }

    @Test func keepsThePicturesBytes() async throws {
        fake.state.withLock { $0.down = true }
        let picture = try #require(URL(string: "https://example.com/p.png"))
        let pages = PageAccess(
            pictures: { _ in [picture] },
            bytes: { _ in PictureBytes(data: Data([9]), type: "image/png", filename: "p.png") })
        let model = try model(pages: pages)
        await model.start(SharedPage(url: page.url, title: "A", pictures: [picture]))
        #expect(await model.save())
        let kept = try #require(queue.get(url))
        #expect(kept.picture == .bytes(filename: "p.png", type: "image/png", source: picture))
        #expect(queue.pictureData(of: kept) == Data([9]))
    }

    @Test func refusesWhenTheQueueIsFull() async throws {
        for index in 0..<PendingQueue.limit {
            try queue.put(try keptCopy("https://example.com/\(index)"), picture: nil)
        }
        fake.state.withLock { $0.down = true }
        let model = try model()
        await model.start(
            SharedPage(url: try #require(URL(string: "https://example.com/new")), title: "N"))
        model.draft.notes = "Typed"
        #expect(await model.save() == false)
        #expect(model.phase == .editing)
        #expect(model.draft.notes == "Typed")
        #expect(
            model.message
                == "100 entries are already waiting to be saved. Sync or delete some first.")
    }

    @Test func opensOnAWaitingCopy() async throws {
        try queue.put(try keptCopy(url, title: "Kept", notes: "K"), picture: nil)
        let model = try model()
        await model.start(page)
        #expect(model.keptCopy != nil)
        #expect(model.draft.title == "Kept")
        #expect(model.draft.notes == "K")
    }

    @Test func showsWhyACopyWasRefused() async throws {
        try queue.put(try keptCopy(url, state: .refused(message: "Too long.")), picture: nil)
        let model = try model()
        await model.start(page)
        #expect(model.keptCopy != nil)
        #expect(model.message == "Too long.")
    }

    @Test func ignoresACopyForAnotherServer() async throws {
        try queue.put(
            try keptCopy(url, title: "Elsewhere", server: "https://other.example.com"),
            picture: nil)
        let model = try model()
        await model.start(page)
        #expect(model.keptCopy == nil)
        #expect(model.draft.title == "A")
    }

    @Test func sendingTheCopyOnlineForgetsIt() async throws {
        try queue.put(try keptCopy(url, title: "Kept"), picture: nil)
        let model = try model()
        await model.start(page)
        #expect(await model.save())
        #expect(model.phase == .saved(created: true))
        #expect(fake.state.withLock { $0.posts } == [url])
        #expect(fake.state.withLock { $0.held[url] }?.contains(#""title":"Kept""#) == true)
        #expect(queue.filesOnDisk().isEmpty)
    }

    @Test func removesOnlyTheCopyItShowed() async throws {
        try queue.put(try keptCopy(url, title: "Shown"), picture: nil)
        let model = try model()
        await model.start(page)
        // Meanwhile another share kept a newer copy of the same page.
        let newer = try keptCopy(url, title: "Newer")
        try queue.put(newer, picture: nil)
        #expect(await model.save())
        #expect(queue.get(url) == newer)
    }

    @Test func keepingAgainReplacesTheCopy() async throws {
        try queue.put(try keptCopy(url, title: "Old"), picture: nil)
        fake.state.withLock { $0.down = true }
        let model = try model()
        await model.start(page)
        model.draft.title = "New"
        #expect(await model.save())
        #expect(queue.list().map(\.request.title) == ["New"])
    }

    @Test func keepsTheCopysPictureWhenLeftAsItWas() async throws {
        let source = try #require(URL(string: "https://example.com/p.png"))
        try queue.put(
            try keptCopy(
                url, picture: .bytes(filename: "p.png", type: "image/png", source: source)),
            picture: Data([5]))
        fake.state.withLock { $0.down = true }
        let model = try model()
        await model.start(page)
        #expect(await model.save())
        let kept = try #require(queue.get(url))
        #expect(queue.pictureData(of: kept) == Data([5]))
    }
}

// After a save: sending what else waits.
extension ShareModelOfflineTests {
    @Test func sendsWhatElseWaitsAfterASave() async throws {
        try queue.put(try keptCopy("https://example.com/other", title: "Other"), picture: nil)
        let model = try model()
        await model.start(page)
        #expect(await model.save())
        await model.syncWaiting()
        #expect(queue.count() == 0)
        #expect(model.syncSummary == "1 entry saved.")
        #expect(model.syncingCount == nil)
    }

    @Test func doesNotSyncWhenNothingWaits() async throws {
        let model = try model()
        await model.start(page)
        #expect(await model.save())
        await model.syncWaiting()
        #expect(model.syncSummary == nil)
    }

    @Test func givesUpOnASlowSyncInTime() async throws {
        try queue.put(try keptCopy("https://example.com/other"), picture: nil)
        let model = try model(session: slowToLookUpTheOther())
        await model.start(page)
        #expect(await model.save())
        let started = ContinuousClock.now
        await model.syncWaiting(within: .milliseconds(200))
        #expect(started.duration(to: .now) < .seconds(2))
        #expect(queue.count() == 1, "cut short, the copy stays")
        #expect(model.syncSummary == "Not finished. The rest will be sent later.")
    }

    @Test func stopsWhenWhoeverAskedGivesUp() async throws {
        try queue.put(try keptCopy("https://example.com/other"), picture: nil)
        let model = try model(session: slowToLookUpTheOther())
        await model.start(page)
        #expect(await model.save())
        let started = ContinuousClock.now
        // As iOS ends the share sheet's time: the caller is cancelled, not the limit reached.
        let sync = Task { await model.syncWaiting() }
        try await Task.sleep(for: .milliseconds(200))
        sync.cancel()
        await sync.value
        #expect(started.duration(to: .now) < .seconds(2))
        #expect(queue.count() == 1, "cut short, the copy stays")
        #expect(model.syncSummary == "Not finished. The rest will be sent later.")
    }

    /// The fake Hrček, taking two seconds to look up the other page.
    private func slowToLookUpTheOther() -> URLSession {
        let fake = fake
        return StubURLProtocol.session { request in
            if request.url?.path() == "/api/entries/lookup",
                try request.jsonObject()["url"] as? String == "https://example.com/other"
            {
                Thread.sleep(forTimeInterval: 2)
            }
            return try fake.handle(request)
        }
    }
}
