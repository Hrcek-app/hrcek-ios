import Foundation
import Testing

@testable import HrcekKit

/// What a settled choice leaves behind: the list's line, and the picture
/// Hrček's entry was shown with.
@MainActor
@Suite struct HeldSettlingTests {
    let queue = temporaryQueue()
    let fake = FakeHrcek()
    let service: EntryService

    init() throws { service = try fake.service() }

    func model() -> PendingModel {
        PendingModel(queue: queue) { [service] _ in service }
    }

    /// Syncs a held copy, so the list says how many wait for a choice.
    func heldBySync(_ model: PendingModel, _ copy: PendingEntry) async throws {
        try queue.put(copy, picture: Data([1]))
        fake.state.withLock { $0.held[copy.url] = FakeHrcek.entry(copy.url) }
        model.reload()
        await model.sync(try sampleCredentials())
        #expect(model.summary == "1 already on Hrček; choose which to keep.")
        await model.compare(try #require(queue.get(copy.url)), credentials: try sampleCredentials())
    }

    @Test func keepingForgetsTheHeldCount() async throws {
        let model = model()
        let copy = try keptCopy()
        try await heldBySync(model, copy)
        model.keep(try #require(queue.get(copy.url)))
        #expect(model.summary == nil, "the count of held pages is no longer true")
    }

    @Test func replacingForgetsTheHeldCount() async throws {
        let model = model()
        let copy = try keptCopy()
        try await heldBySync(model, copy)
        #expect(
            await model.replace(
                try #require(queue.get(copy.url)), credentials: try sampleCredentials()))
        #expect(model.summary == nil)
    }

    @Test func replacingSaysWhenThePictureWasLeftOut() async throws {
        let model = model()
        let source = try #require(URL(string: "https://example.com/p.png"))
        let copy = try keptCopy(picture: .bytes(filename: "p", type: "image/png", source: source))
        try await heldBySync(model, copy)
        fake.state.withLock { $0.refusePictures = true }
        #expect(
            await model.replace(
                try #require(queue.get(copy.url)), credentials: try sampleCredentials()))
        let line = "The entry was saved, but the picture could not be attached:"
        #expect(model.summary == "\(line) Refused: HRC-IMAGE-0001")
    }

    @Test func refusedReplacingForgetsTheHeldCount() async throws {
        let model = model()
        let copy = try keptCopy()
        try await heldBySync(model, copy)
        fake.state.withLock { $0.refuseSaves = (422, "HRC-CORE-0002") }
        #expect(
            await model.replace(
                try #require(queue.get(copy.url)), credentials: try sampleCredentials()))
        #expect(model.summary == nil)
    }

    @Test func showsHrceksPicture() async throws {
        let model = model()
        let copy = try keptCopy(state: .held)
        try queue.put(copy, picture: nil)
        fake.state.withLock {
            $0.held[copy.url] = FakeHrcek.entry(copy.url, image: true)
            $0.heldPicture = (type: "image/png", body: Data([0x89, 0x50]))
        }
        await model.compare(copy, credentials: try sampleCredentials())
        guard case .shown(_, let picture) = model.comparison else {
            Issue.record("expected Hrček's entry, got \(String(describing: model.comparison))")
            return
        }
        #expect(picture == .shown(Data([0x89, 0x50])))
    }

    @Test func saysHrceksPictureCannotBeShownWhenTheServerWantsASignIn() async throws {
        let model = model()
        let copy = try keptCopy(state: .held)
        try queue.put(copy, picture: nil)
        fake.state.withLock {
            $0.held[copy.url] = FakeHrcek.entry(copy.url, image: true)
            // An older Hrček redirects a token to its sign-in page.
            $0.heldPicture = (type: "text/html", body: Data("<html>Sign in</html>".utf8))
        }
        await model.compare(copy, credentials: try sampleCredentials())
        guard case .shown(_, let picture) = model.comparison else {
            Issue.record("expected Hrček's entry, got \(String(describing: model.comparison))")
            return
        }
        #expect(picture == .unshowable)
    }
}
