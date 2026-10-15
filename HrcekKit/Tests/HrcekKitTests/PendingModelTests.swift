import Foundation
import Testing

@testable import HrcekKit

@MainActor
@Suite struct PendingModelTests {
    let queue = temporaryQueue()
    let fake = FakeHrcek()
    let service: EntryService

    init() throws { service = try fake.service() }

    func model() -> PendingModel {
        PendingModel(queue: queue) { [service] _ in service }
    }

    @Test func isTheScreenWhileSomethingWaits() throws {
        let model = model()
        model.reload()
        #expect(model.isPresented == false)
        try queue.put(try keptCopy(), picture: nil)
        model.reload()
        #expect(model.isPresented)
        #expect(model.count == 1)
    }

    @Test func staysUpOnceEmptiedUntilDismissed() throws {
        let model = model()
        let copy = try keptCopy()
        try queue.put(copy, picture: nil)
        model.reload()
        model.delete(copy)
        #expect(model.entries.isEmpty)
        #expect(model.isPresented, "the screen does not swap under the person's finger")
        model.dismiss()
        #expect(model.isPresented == false)
    }

    @Test func dismissingDoesNothingWhileSomethingWaits() throws {
        let model = model()
        try queue.put(try keptCopy(), picture: nil)
        model.reload()
        model.dismiss()
        #expect(model.isPresented)
    }

    @Test func deletesTheCopyAndItsFiles() throws {
        let model = model()
        let source = try #require(URL(string: "https://example.com/p.png"))
        let copy = try keptCopy(picture: .bytes(filename: "p", type: "image/png", source: source))
        try queue.put(copy, picture: Data([1]))
        model.reload()
        model.delete(copy)
        #expect(queue.filesOnDisk().isEmpty)
    }

    @Test func syncsAndSaysWhatHappened() async throws {
        let model = model()
        try queue.put(try keptCopy(), picture: nil)
        model.reload()
        let result = await model.sync(try sampleCredentials())
        #expect(result == SyncResult(saved: 1))
        #expect(model.summary == "1 entry saved.")
        #expect(model.entries.isEmpty)
        #expect(model.isSyncing == false)
    }

    @Test func cannotSyncSignedOut() async throws {
        let model = model()
        try queue.put(try keptCopy(), picture: nil)
        model.reload()
        #expect(model.canSync(nil) == false)
        #expect(await model.sync(nil) == nil)
        #expect(model.count == 1)
    }

    @Test func doesNotSyncWhenNothingWaitsForThisServer() async throws {
        let model = model()
        try queue.put(try keptCopy(state: .held), picture: nil)
        model.reload()
        #expect(model.canSync(try sampleCredentials()) == false)
        #expect(await model.sync(try sampleCredentials()) == nil)
    }

    @Test func saysWhichCopiesAreForAnotherServer() throws {
        let model = model()
        let elsewhere = try keptCopy(server: "https://other.example.com")
        let here = try keptCopy("https://example.com/b")
        #expect(model.isForAnotherServer(elsewhere, try sampleCredentials()))
        #expect(model.isForAnotherServer(here, try sampleCredentials()) == false)
        #expect(model.isForAnotherServer(here, nil) == false, "signed out, nothing is elsewhere")
    }

    @Test func activatingTakesDownAnEmptiedList() throws {
        let model = model()
        let copy = try keptCopy()
        try queue.put(copy, picture: nil)
        model.activate()
        #expect(model.isPresented)
        model.delete(copy)
        #expect(model.isPresented)
        model.activate()
        #expect(model.isPresented == false, "with nothing waiting, the usual screen opens")
    }

    @Test func activatingPresentsWhatWaits() throws {
        let model = model()
        model.activate()
        #expect(model.isPresented == false)
        try queue.put(try keptCopy(), picture: nil)
        model.activate()
        #expect(model.isPresented)
        #expect(model.count == 1)
    }

    @Test func dismissingForgetsTheLastSync() async throws {
        let model = model()
        let copy = try keptCopy()
        try queue.put(copy, picture: nil)
        model.reload()
        fake.state.withLock { $0.down = true }
        await model.sync(try sampleCredentials())
        #expect(model.summary == "Hrček can't be reached.")
        model.delete(copy)
        model.dismiss()
        #expect(model.summary == nil)
    }

    @Test func activatingWithNothingWaitingForgetsTheLastSync() async throws {
        let model = model()
        let copy = try keptCopy()
        try queue.put(copy, picture: nil)
        model.activate()
        fake.state.withLock { $0.down = true }
        await model.sync(try sampleCredentials())
        model.delete(copy)
        model.activate()
        #expect(model.summary == nil)
    }

    @Test func activatingKeepsTheLastSyncWhileSomethingWaits() async throws {
        let model = model()
        try queue.put(try keptCopy(), picture: nil)
        model.activate()
        fake.state.withLock { $0.down = true }
        await model.sync(try sampleCredentials())
        model.activate()
        #expect(model.summary == "Hrček can't be reached.")
    }
}
