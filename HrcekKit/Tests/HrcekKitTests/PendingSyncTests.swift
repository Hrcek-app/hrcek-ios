import Foundation
import Synchronization
import Testing

@testable import HrcekKit

@Suite struct PendingSyncTests {
    let server: ServerAddress

    init() throws { server = try sampleCredentials().server }

    func run(_ queue: PendingQueue, _ fake: FakeHrcek) async throws -> SyncResult {
        await PendingSync.run(queue: queue, service: try fake.service(), server: server)
    }

    @Test func sendsWaitingCopiesOldestFirstAndForgetsThem() async throws {
        let queue = temporaryQueue()
        let fake = FakeHrcek()
        try queue.put(try keptCopy("https://example.com/b", savedAt: .now), picture: nil)
        try queue.put(
            try keptCopy("https://example.com/a", savedAt: .now.addingTimeInterval(-9)),
            picture: nil)
        let result = try await run(queue, fake)
        #expect(result == SyncResult(saved: 2))
        #expect(
            fake.state.withLock { $0.posts } == ["https://example.com/a", "https://example.com/b"])
        #expect(queue.filesOnDisk().isEmpty, "nothing of a synced entry stays")
    }

    @Test func uploadsTheKeptBytesAfterTheEntry() async throws {
        let queue = temporaryQueue()
        let fake = FakeHrcek()
        let source = try #require(URL(string: "https://example.com/p.png"))
        try queue.put(
            try keptCopy(picture: .bytes(filename: "p.png", type: "image/png", source: source)),
            picture: Data([1, 2]))
        _ = try await run(queue, fake)
        #expect(fake.state.withLock { $0.uploads } == 1)
    }

    @Test func holdsACopyHrcekAlreadyHasDifferently() async throws {
        let queue = temporaryQueue()
        let fake = FakeHrcek()
        let copy = try keptCopy(title: "Mine")
        fake.state.withLock { $0.held[copy.url] = FakeHrcek.entry(copy.url, title: "Theirs") }
        try queue.put(copy, picture: nil)
        let result = try await run(queue, fake)
        #expect(result == SyncResult(held: 1))
        #expect(queue.get(copy.url)?.state == .held)
        #expect(fake.state.withLock { $0.posts }.isEmpty, "nothing is sent over theirs")
    }

    @Test func removesACopyHrcekAlreadyHasVerbatim() async throws {
        let queue = temporaryQueue()
        let fake = FakeHrcek()
        let copy = try keptCopy(title: "Mine", notes: "N", tags: ["a", "B"])
        // As if an earlier sync was cut off after Hrček took it.
        fake.state.withLock {
            $0.held[copy.url] = FakeHrcek.entry(
                copy.url, title: "Mine", notes: "N", tags: ["b", "a"])
        }
        try queue.put(copy, picture: nil)
        #expect(try await run(queue, fake) == SyncResult(saved: 1))
        #expect(queue.filesOnDisk().isEmpty)
    }

    @Test func stopsWhenHrcekIsDownAndKeepsEverything() async throws {
        let queue = temporaryQueue()
        let fake = FakeHrcek()
        fake.state.withLock { $0.down = true }
        try queue.put(try keptCopy(), picture: nil)
        #expect(try await run(queue, fake) == SyncResult(stopped: .unavailable))
        #expect(queue.get("https://example.com/a")?.state == .waiting)
    }

    @Test func stopsWhenHrcekGoesDownMidway() async throws {
        let queue = temporaryQueue()
        let fake = FakeHrcek()
        fake.state.withLock { $0.downAfterPosts = 1 }
        try queue.put(
            try keptCopy("https://example.com/a", savedAt: .now.addingTimeInterval(-9)),
            picture: nil)
        try queue.put(try keptCopy("https://example.com/b"), picture: nil)
        #expect(try await run(queue, fake) == SyncResult(saved: 1, stopped: .unavailable))
        #expect(queue.list().map(\.url) == ["https://example.com/b"])
        #expect(queue.list().first?.state == .waiting)
    }

    @Test func stopsWhenTheTokenIsRefused() async throws {
        let queue = temporaryQueue()
        let fake = FakeHrcek()
        fake.state.withLock { $0.refuseLookups = (401, "HRC-AUTH-0004") }
        try queue.put(try keptCopy(), picture: nil)
        #expect(try await run(queue, fake) == SyncResult(stopped: .unauthorized))
        #expect(queue.count() == 1)
    }

    @Test func stopsWhenALookupFailsOtherwise() async throws {
        let queue = temporaryQueue()
        let fake = FakeHrcek()
        fake.state.withLock { $0.refuseLookups = (500, "HRC-CORE-0001") }
        try queue.put(try keptCopy(), picture: nil)
        #expect(try await run(queue, fake) == SyncResult(stopped: .failed))
        #expect(queue.get("https://example.com/a")?.state == .waiting)
    }

    @Test func marksARefusedCopyWithHrceksWordsAndGoesOn() async throws {
        let queue = temporaryQueue()
        let fake = FakeHrcek()
        fake.state.withLock { $0.refuseSaves = (422, "HRC-CORE-0002") }
        try queue.put(try keptCopy(), picture: nil)
        #expect(try await run(queue, fake) == SyncResult(refused: 1))
        #expect(
            queue.get("https://example.com/a")?.state == .refused(message: "Refused: HRC-CORE-0002")
        )
    }

    @Test(arguments: [(500, "HRC-CORE-0001"), (429, "HRC-CORE-0003")])
    func keepsACopyWaitingWhenHrcekFailsTransiently(status: Int, code: String) async throws {
        let queue = temporaryQueue()
        let fake = FakeHrcek()
        fake.state.withLock { $0.refuseSaves = (status, code) }
        try queue.put(try keptCopy(), picture: nil)
        #expect(try await run(queue, fake) == SyncResult(stopped: .failed))
        #expect(queue.get("https://example.com/a")?.state == .waiting)
    }

    @Test func neverRetriesHeldOrRefusedCopies() async throws {
        let queue = temporaryQueue()
        let fake = FakeHrcek()
        try queue.put(try keptCopy("https://example.com/a", state: .held), picture: nil)
        try queue.put(
            try keptCopy("https://example.com/b", state: .refused(message: "No.")), picture: nil)
        #expect(try await run(queue, fake) == SyncResult())
        #expect(fake.state.withLock { $0.posts }.isEmpty)
    }

    @Test func leavesCopiesForAnotherServer() async throws {
        let queue = temporaryQueue()
        let fake = FakeHrcek()
        try queue.put(try keptCopy(server: "https://other.example.com"), picture: nil)
        #expect(try await run(queue, fake) == SyncResult())
        #expect(queue.count() == 1)
    }

    @Test func countsAPictureRefusalAsSaved() async throws {
        let queue = temporaryQueue()
        let fake = FakeHrcek()
        fake.state.withLock { $0.refusePictures = true }
        let source = try #require(URL(string: "https://example.com/p.png"))
        try queue.put(
            try keptCopy(
                title: "Pictured",
                picture: .bytes(filename: "p.png", type: "image/png", source: source)),
            picture: Data([1]))
        #expect(try await run(queue, fake) == SyncResult(saved: 1, withoutPicture: ["Pictured"]))
        #expect(queue.count() == 0)
    }

    @Test func doesNothingWhileAnotherSyncRuns() async throws {
        let queue = temporaryQueue()
        let fake = FakeHrcek()
        try queue.put(try keptCopy(), picture: nil)
        let inner = try await FileLock(queue.directory.appending(path: ".sync-lock")).ifFree {
            await PendingSync.run(queue: queue, service: try fake.service(), server: server)
        }
        #expect(inner == SyncResult(stopped: .busy))
        #expect(queue.count() == 1)
    }

    /// The list is read once; a copy replaced or deleted after that is
    /// not the one listed, and is left alone.
    @Test func leavesACopyChangedMeanwhile() async throws {
        let queue = temporaryQueue()
        let fake = FakeHrcek()
        try queue.put(
            try keptCopy("https://example.com/a", savedAt: .now.addingTimeInterval(-9)),
            picture: nil)
        let listed = try keptCopy("https://example.com/b", title: "Listed")
        try queue.put(listed, picture: nil)
        let newer = try keptCopy("https://example.com/b", title: "Newer")
        // While /a is being handled, another share keeps a newer copy of /b.
        let service = EntryService(
            credentials: try sampleCredentials(), language: "en",
            session: StubURLProtocol.session { request in
                if request.url?.path() == "/api/entries/lookup",
                    try request.jsonObject()["url"] as? String == "https://example.com/a"
                {
                    try queue.put(newer, picture: nil)
                }
                return try fake.handle(request)
            })
        let result = await PendingSync.run(queue: queue, service: service, server: server)
        #expect(result == SyncResult(saved: 1))
        #expect(fake.state.withLock { $0.posts } == ["https://example.com/a"])
        #expect(queue.get("https://example.com/b") == newer, "for the next sync")
    }

    @Test func reportsAnInterruptionAsSuch() async throws {
        let queue = temporaryQueue()
        let fake = FakeHrcek()
        try queue.put(try keptCopy(), picture: nil)
        let task = Task { try await run(queue, fake) }
        task.cancel()
        let result = try await task.value
        // Cancelled before or after the copy went: never both, never neither.
        #expect(result.stopped == .interrupted || result == SyncResult(saved: 1))
        #expect(queue.count() + result.saved == 1, "nothing lost, nothing doubled")
    }

    @Test func sendsTheAddressWhenThereWereNoBytes() async throws {
        let queue = temporaryQueue()
        let fake = FakeHrcek()
        let source = try #require(URL(string: "https://example.com/p.png"))
        try queue.put(try keptCopy(picture: .address(source)), picture: nil)
        let captured = Mutex<[Data]>([])
        let service = EntryService(
            credentials: try sampleCredentials(), language: "en",
            session: StubURLProtocol.session { request in
                if request.url?.path() == "/api/entries/" {
                    captured.withLock { $0.append(request.bodyData) }
                }
                return try fake.handle(request)
            })
        _ = await PendingSync.run(queue: queue, service: service, server: server)
        let bodies = try captured.withLock { $0 }.map(URLRequest.jsonObject)
        #expect(bodies.first?["image_url"] as? String == "https://example.com/p.png")
    }
}
