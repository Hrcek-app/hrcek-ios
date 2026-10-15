import Foundation
import Testing

@testable import HrcekKit

// A copy kept at an address Hrček already holds an entry for.
extension ShareModelOfflineTests {
    @Test func opensOnAHeldCopyWhenHrcekCannotBeReached() async throws {
        try queue.put(
            try keptCopy(url, title: "Mine", notes: "Edited", state: .held), picture: nil)
        fake.state.withLock { $0.down = true }
        let model = try model()
        await model.start(page)
        #expect(model.isOffline)
        #expect(model.keptCopy != nil, "Hrček's entry cannot be shown; the copy can")
        #expect(model.heldCopy == nil)
        #expect(model.draft.title == "Mine")
        #expect(model.draft.notes == "Edited")
        #expect(await model.save())
        let kept = try #require(queue.get(url))
        #expect(kept.request.notes == "Edited", "the person's edits survive")
        #expect(kept.state == .waiting, "its sync looks first, and holds it again if need be")
    }

    @Test func worksAgainstHrcekWhenTheCopyIsHeld() async throws {
        try queue.put(try keptCopy(url, title: "Mine", state: .held), picture: nil)
        fake.state.withLock { $0.held[url] = FakeHrcek.entry(url, title: "Theirs") }
        let model = try model()
        await model.start(page)
        #expect(model.heldCopy != nil)
        #expect(model.keptCopy == nil)
        #expect(model.draft.title == "Theirs", "Hrček's entry, not the copy")
        #expect(await model.save())
        #expect(queue.count() == 0, "saving here replaces the held copy")
    }

    // Kept offline, then saved on Hrček from elsewhere before it synced:
    // its sync would hold it, so the sheet must not guess either.
    @Test(arguments: [PendingEntry.State.waiting, .refused(message: "Too long.")])
    func worksAgainstHrcekWhenACopyWaitsForAnEntryItHolds(
        _ state: PendingEntry.State
    ) async throws {
        let copy = try keptCopy(url, title: "Mine", notes: "Phone", state: state)
        try queue.put(copy, picture: nil)
        fake.state.withLock {
            $0.held[url] = FakeHrcek.entry(url, title: "Theirs", notes: "Laptop")
        }
        let model = try model()
        await model.start(page)
        #expect(model.draft.title == "Theirs", "Hrček's entry, not the copy")
        #expect(model.draft.notes == "Laptop")
        #expect(model.heldCopy == copy)
        #expect(model.keptCopy == nil)
        #expect(model.message == nil)
    }

    @Test func savingOverHrceksEntryReplacesTheWaitingCopy() async throws {
        let copy = try keptCopy(url, title: "Mine", notes: "Phone")
        try queue.put(copy, picture: nil)
        fake.state.withLock {
            $0.held[url] = FakeHrcek.entry(url, title: "Theirs", notes: "Laptop")
        }
        let model = try model()
        await model.start(page)
        model.draft.notes = "Both"
        #expect(await model.save())
        let saved = fake.state.withLock { $0.held[url] } ?? ""
        #expect(saved.contains(#""title":"Theirs""#))
        #expect(saved.contains(#""notes":"Both""#))
        #expect(queue.filesOnDisk().isEmpty, "saving here replaces the copy")
    }

    @Test func savingOverHrceksEntryKeepsANewerCopy() async throws {
        try queue.put(try keptCopy(url, title: "Mine"), picture: nil)
        fake.state.withLock { $0.held[url] = FakeHrcek.entry(url) }
        let model = try model()
        await model.start(page)
        // Meanwhile another share kept a newer copy of the same page.
        let newer = try keptCopy(url, title: "Newer")
        try queue.put(newer, picture: nil)
        #expect(await model.save())
        #expect(queue.get(url) == newer, "only the copy shown is removed")
    }
}
