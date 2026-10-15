import Foundation
import Testing

@testable import HrcekKit

/// The count of waiting pages on the app icon, and asking for it.
@MainActor
@Suite struct BadgeTests {
    let queue = temporaryQueue()
    let fake = FakeHrcek()
    let service: EntryService
    let badge = FixedBadgeCenter(.undetermined)

    init() throws { service = try fake.service() }

    func model() -> PendingModel {
        PendingModel(queue: queue, badge: badge) { [service] _ in service }
    }

    @Test func asksForTheBadgeOnlyWhenSomethingWaitsAndNobodyAnswered() async throws {
        let model = model()
        await model.refreshBadge()
        #expect(model.needsBadgePermission == false)
        try queue.put(try keptCopy(), picture: nil)
        model.reload()
        await model.badgeRefreshed()
        #expect(model.needsBadgePermission)
    }

    @Test func setsTheBadgeToTheCount() async throws {
        let model = model()
        try queue.put(try keptCopy(), picture: nil)
        try queue.put(try keptCopy("https://example.com/b"), picture: nil)
        model.reload()
        await model.badgeRefreshed()
        #expect(badge.counts.withLock { $0.last } == 2)
    }

    @Test func clearsTheBadgeAtZero() async throws {
        let model = model()
        model.reload()
        await model.badgeRefreshed()
        #expect(badge.counts.withLock { $0.last } == 0)
    }

    @Test func asksOnceAndRemembersARefusal() async throws {
        let refusing = FixedBadgeCenter(.undetermined, grants: false)
        let model = PendingModel(queue: queue, badge: refusing) { [service] _ in service }
        try queue.put(try keptCopy(), picture: nil)
        model.reload()
        await model.askForBadge()
        #expect(model.needsBadgePermission == false)
        #expect(model.badgeDenied)
        await model.askForBadge()
        model.reload()
        await model.badgeRefreshed()
        #expect(model.needsBadgePermission == false)
        #expect(refusing.requests.withLock { $0 } == 1, "iOS's question is asked once")
    }

    @Test func notNowDoesNotAskAgainThisLaunch() async throws {
        let model = model()
        try queue.put(try keptCopy(), picture: nil)
        model.reload()
        await model.badgeRefreshed()
        model.declineBadgeForNow()
        model.reload()
        await model.badgeRefreshed()
        #expect(model.needsBadgePermission == false)
    }

    /// Every change to the queue passes through a reload: a sync, a
    /// deletion, a settled copy, or the share extension keeping a page.
    @Test func everyReloadBringsTheBadgeUpToDate() async throws {
        let model = model()
        let copy = try keptCopy()
        try queue.put(copy, picture: nil)
        model.reload()
        await model.badgeRefreshed()
        #expect(badge.counts.withLock { $0.last } == 1)
        #expect(model.needsBadgePermission)
        model.delete(copy)
        await model.badgeRefreshed()
        #expect(badge.counts.withLock { $0.last } == 0)
    }

    @Test func aSyncClearsTheBadge() async throws {
        let model = model()
        try queue.put(try keptCopy(), picture: nil)
        model.reload()
        await model.sync(try sampleCredentials())
        await model.badgeRefreshed()
        #expect(badge.counts.withLock { $0.last } == 0)
    }

    /// The sync on opening often empties the list while the explanation is
    /// up; it stays until the person answers.
    @Test func theExplanationStaysUntilAnswered() async throws {
        let model = model()
        try queue.put(try keptCopy(), picture: nil)
        model.reload()
        await model.badgeRefreshed()
        #expect(model.needsBadgePermission)
        await model.sync(try sampleCredentials())
        #expect(model.entries.isEmpty)
        await model.badgeRefreshed()
        #expect(model.needsBadgePermission, "emptied under the person, it stays")
        model.declineBadgeForNow()
        #expect(model.needsBadgePermission == false)
    }

    @Test func theExplanationGoesOnceIOSHasAnAnswer() async throws {
        let model = model()
        try queue.put(try keptCopy(), picture: nil)
        model.reload()
        await model.badgeRefreshed()
        #expect(model.needsBadgePermission)
        // Answered elsewhere, in Settings say.
        _ = await badge.request()
        model.reload()
        await model.badgeRefreshed()
        #expect(model.needsBadgePermission == false)
    }

    /// Syncs and Replace run with background time that ends when they
    /// return; the icon must be right by then.
    @Test func aSyncLeavesTheBadgeRightWhenItReturns() async throws {
        let model = model()
        try queue.put(try keptCopy(), picture: nil)
        model.reload()
        await model.sync(try sampleCredentials())
        #expect(badge.counts.withLock { $0.last } == 0)
    }

    @Test func aReplaceLeavesTheBadgeRightWhenItReturns() async throws {
        let model = model()
        let copy = try keptCopy()
        try queue.put(copy, picture: nil)
        fake.state.withLock { $0.held[copy.url] = FakeHrcek.entry(copy.url) }
        model.reload()
        await model.sync(try sampleCredentials())
        let held = try #require(queue.get(copy.url))
        await model.compare(held, credentials: try sampleCredentials())
        #expect(await model.replace(held, credentials: try sampleCredentials()))
        #expect(badge.counts.withLock { $0.last } == 0)
    }
}
