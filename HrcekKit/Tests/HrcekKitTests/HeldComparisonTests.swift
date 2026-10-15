import Foundation
import Testing

@testable import HrcekKit

/// Settling a copy Hrček already has: its entry beside the copy, then
/// Keep or Replace.
@MainActor
@Suite struct HeldComparisonTests {
    let queue = temporaryQueue()
    let fake = FakeHrcek()
    let service: EntryService

    init() throws { service = try fake.service() }

    func model() -> PendingModel {
        PendingModel(queue: queue, badge: FixedBadgeCenter(.allowed)) { [service] _ in service }
    }

    @Test func showsHrceksEntryBesideTheCopy() async throws {
        let model = model()
        let copy = try keptCopy(title: "Mine", state: .held)
        try queue.put(copy, picture: nil)
        fake.state.withLock { $0.held[copy.url] = FakeHrcek.entry(copy.url, title: "Theirs") }
        model.reload()
        await model.compare(copy, credentials: try sampleCredentials())
        guard case .shown(let theirs, _) = model.comparison else {
            Issue.record("expected Hrček's entry, got \(String(describing: model.comparison))")
            return
        }
        #expect(theirs.title == "Theirs")
        #expect(model.canKeep)
        #expect(model.canReplace)
    }

    @Test func keepIsOffUntilHrceksEntryIsShown() throws {
        let model = model()
        #expect(model.canKeep == false)
    }

    @Test func keepingHrceksDeletesTheCopy() async throws {
        let model = model()
        let copy = try keptCopy(state: .held)
        try queue.put(copy, picture: nil)
        fake.state.withLock { $0.held[copy.url] = FakeHrcek.entry(copy.url) }
        model.reload()
        await model.compare(copy, credentials: try sampleCredentials())
        model.keep(copy)
        #expect(queue.filesOnDisk().isEmpty)
        #expect(model.comparison == nil)
    }

    @Test func replacingSendsTheCopyThenDeletesIt() async throws {
        let model = model()
        let copy = try keptCopy(title: "Mine", state: .held)
        try queue.put(copy, picture: nil)
        fake.state.withLock { $0.held[copy.url] = FakeHrcek.entry(copy.url) }
        model.reload()
        await model.compare(copy, credentials: try sampleCredentials())
        #expect(await model.replace(copy, credentials: try sampleCredentials()))
        #expect(fake.state.withLock { $0.posts } == [copy.url])
        #expect(queue.filesOnDisk().isEmpty)
    }

    @Test func offersToSaveTheCopyWhenHrcekNoLongerHasIt() async throws {
        let model = model()
        let copy = try keptCopy(state: .held)
        try queue.put(copy, picture: nil)
        model.reload()
        await model.compare(copy, credentials: try sampleCredentials())
        #expect(model.comparison == .gone)
        #expect(model.canKeep == false, "keeping Hrček's would lose the only copy")
        #expect(model.canReplace)
    }

    @Test func saysWhenHrcekCannotBeAsked() async throws {
        let model = model()
        let copy = try keptCopy(state: .held)
        try queue.put(copy, picture: nil)
        fake.state.withLock { $0.down = true }
        model.reload()
        await model.compare(copy, credentials: try sampleCredentials())
        #expect(model.comparison == .unavailable("The server is having trouble. Try again later."))
        #expect(model.canKeep == false)
        #expect(model.canReplace == false)
    }

    @Test func replacingWhileHrcekIsDownKeepsTheCopy() async throws {
        let model = model()
        let copy = try keptCopy(state: .held)
        try queue.put(copy, picture: nil)
        fake.state.withLock { $0.held[copy.url] = FakeHrcek.entry(copy.url) }
        model.reload()
        await model.compare(copy, credentials: try sampleCredentials())
        fake.state.withLock { $0.down = true }
        #expect(await model.replace(copy, credentials: try sampleCredentials()) == false)
        #expect(queue.get(copy.url)?.state == .held)
        guard case .unavailable = model.comparison else {
            Issue.record("expected the comparison to say why")
            return
        }
    }

    @Test func neverReplacesOnAnotherServer() async throws {
        let model = model()
        let copy = try keptCopy(server: "https://other.example.com", state: .held)
        try queue.put(copy, picture: nil)
        model.reload()
        #expect(await model.replace(copy, credentials: try sampleCredentials()) == false)
        #expect(fake.state.withLock { $0.posts }.isEmpty)
    }

    @Test func replacingARefusedAnswerMarksTheCopy() async throws {
        let model = model()
        let copy = try keptCopy(state: .held)
        try queue.put(copy, picture: nil)
        fake.state.withLock { $0.held[copy.url] = FakeHrcek.entry(copy.url) }
        model.reload()
        await model.compare(copy, credentials: try sampleCredentials())
        fake.state.withLock { $0.refuseSaves = (422, "HRC-CORE-0002") }
        #expect(
            await model.replace(copy, credentials: try sampleCredentials()),
            "a refused copy is settled: the comparison closes and the list shows why")
        #expect(queue.get(copy.url)?.state == .refused(message: "Refused: HRC-CORE-0002"))
        #expect(model.comparison == nil)
    }

    @Test(arguments: [(500, "HRC-CORE-0001"), (429, "HRC-CORE-0004"), (401, "HRC-AUTH-0003")])
    func replacingIsNotRefusedByWhatPassesOrByTheToken(status: Int, code: String) async throws {
        let model = model()
        let copy = try keptCopy(state: .held)
        try queue.put(copy, picture: nil)
        fake.state.withLock { $0.held[copy.url] = FakeHrcek.entry(copy.url) }
        model.reload()
        await model.compare(copy, credentials: try sampleCredentials())
        fake.state.withLock { $0.refuseSaves = (status, code) }
        #expect(await model.replace(copy, credentials: try sampleCredentials()) == false)
        #expect(queue.get(copy.url)?.state == .held, "the copy still waits for the person")
        #expect(model.comparison == .unavailable("Refused: \(code)"))
    }

    @Test func choosesOnlyForTheCopyBeingCompared() async throws {
        let model = model()
        let compared = try keptCopy(state: .held)
        let other = try keptCopy("https://example.com/b", state: .held)
        try queue.put(compared, picture: nil)
        try queue.put(other, picture: nil)
        fake.state.withLock { $0.held[compared.url] = FakeHrcek.entry(compared.url) }
        model.reload()
        await model.compare(compared, credentials: try sampleCredentials())
        model.keep(other)
        #expect(await model.replace(other, credentials: try sampleCredentials()) == false)
        #expect(queue.get(other.url) != nil, "Hrček's entry for another page was never shown")
        #expect(fake.state.withLock { $0.posts }.isEmpty)
    }
}
