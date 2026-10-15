import Foundation
import Observation

/// The list of saves kept for later, and whether the app opens on it.
@MainActor
@Observable
public final class PendingModel {
    public private(set) var entries: [PendingEntry] = []
    /// Whether the list is the app's screen. It stays up once emptied,
    /// until the person is done with it.
    public private(set) var isPresented = false
    public private(set) var isSyncing = false
    /// What the last sync did, in one line.
    public private(set) var summary: String?
    /// Whether to explain, then ask for, the badge now.
    public internal(set) var needsBadgePermission = false
    /// The person said no; settings says how to change that.
    public internal(set) var badgeDenied = false
    var askedThisLaunch = false
    var badgeRefresh: Task<Void, Never>?

    private let queue: PendingQueue
    let badge: any BadgeCenter
    private let makeService: @Sendable (Credentials) -> EntryService

    public init(
        queue: PendingQueue,
        badge: any BadgeCenter,
        makeService: @escaping @Sendable (Credentials) -> EntryService = {
            EntryService(credentials: $0)
        }
    ) {
        self.queue = queue
        self.badge = badge
        self.makeService = makeService
    }

    public var count: Int { entries.count }

    /// Reads the queue again: the share extension may have changed it.
    /// Every change to the queue comes through here, so the badge does too.
    public func reload() {
        entries = queue.list()
        if !entries.isEmpty { isPresented = true }
        scheduleBadgeRefresh()
    }

    /// Decides the screen as the app comes to the front, before it syncs:
    /// with nothing waiting, the usual screen opens, not an emptied list.
    public func activate() {
        reload()
        if entries.isEmpty { takeDown() }
    }

    public func dismiss() {
        if entries.isEmpty { takeDown() }
    }

    /// The last sync's line goes with the list, so it is never shown later
    /// as if it were news.
    private func takeDown() {
        isPresented = false
        summary = nil
    }

    public func canSync(_ credentials: Credentials?) -> Bool {
        guard let credentials, !isSyncing else { return false }
        return entries.contains { $0.server == credentials.server && $0.state == .waiting }
    }

    /// Sends what waits for the signed-in server. Nil when there was
    /// nothing to send or nobody to send it as.
    @discardableResult
    public func sync(_ credentials: Credentials?) async -> SyncResult? {
        guard let credentials, canSync(credentials) else { return nil }
        isSyncing = true
        defer { isSyncing = false }
        let result = await PendingSync.run(
            queue: queue, service: makeService(credentials), server: credentials.server)
        if let line = result.summary { summary = line }
        reload()
        await badgeRefreshed()
        return result
    }

    public func delete(_ entry: PendingEntry) {
        do {
            try queue.remove(entry.url, id: entry.id)
        } catch {
            Log.app.error("Not deleted: \(Log.summary(of: error), privacy: .public)")
        }
        reload()
    }

    public func isForAnotherServer(_ entry: PendingEntry, _ credentials: Credentials?) -> Bool {
        guard let credentials else { return false }
        return entry.server != credentials.server
    }

    // MARK: Settling a held copy

    /// Hrček's entry beside a held copy, as far as it could be had.
    public enum Comparison: Equatable, Sendable {
        case loading
        case shown(EntryOut, HeldPicture?)
        /// Hrček no longer has the address; the copy may simply be saved.
        case gone
        case unavailable(String)
    }

    public private(set) var comparison: Comparison?
    /// The copy `comparison` is about. A comparison left before its answer
    /// came, or one about another copy, must not decide for this one.
    private var compared: UUID?

    public func compare(_ entry: PendingEntry, credentials: Credentials) async {
        compared = entry.id
        comparison = .loading
        let service = makeService(credentials)
        let answer: Comparison
        do {
            if let theirs = try await service.lookup(entry.url) {
                var picture: HeldPicture?
                if let image = theirs.image {
                    picture =
                        (try? await service.picture(image)).map(HeldPicture.shown) ?? .unshowable
                }
                answer = .shown(theirs, picture)
            } else {
                answer = .gone
            }
        } catch {
            answer = .unavailable(UserFacingError.message(for: error))
        }
        if compared == entry.id { comparison = answer }
    }

    /// Only once Hrček's entry is shown: keeping it deletes the only copy
    /// of the person's version.
    public var canKeep: Bool {
        if case .shown = comparison { true } else { false }
    }

    public var canReplace: Bool {
        switch comparison {
        case .shown, .gone: true
        default: false
        }
    }

    public func keep(_ entry: PendingEntry) {
        guard canKeep, compared == entry.id else { return }
        delete(entry)
        settled(trouble: nil)
    }

    /// Sends the copy over Hrček's entry, the way a sync would have, and
    /// forgets it. Only a held copy, and only to its own server: the list
    /// may be stale about either. True once the copy is settled: saved, or
    /// refused and back on the list with Hrček's reason; false while it
    /// still waits for a choice.
    public func replace(_ entry: PendingEntry, credentials: Credentials) async -> Bool {
        guard entry.server == credentials.server, canReplace, compared == entry.id,
            let current = queue.get(entry.url), current.id == entry.id, current.state == .held
        else { return false }
        do {
            let (_, trouble) = try await PendingSync.send(
                current, picture: queue.pictureData(of: current),
                service: makeService(credentials))
            try? queue.remove(current.url, id: current.id)
            settled(trouble: trouble)
            await badgeRefreshed()
            return true
        } catch {
            if let message = Self.refusal(error) {
                try? queue.mark(current.url, id: current.id, .refused(message: message))
                settled(trouble: nil)
                await badgeRefreshed()
                return true
            }
            if compared == entry.id {
                comparison = .unavailable(UserFacingError.message(for: error))
            }
            return false
        }
    }

    /// A choice made. The last sync's line counted the held copies, which
    /// is no longer true; only what this choice could not do is news.
    private func settled(trouble: String?) {
        summary = trouble
        endComparison()
        reload()
    }

    public func endComparison() {
        compared = nil
        comparison = nil
    }

    /// Hrček's words when it refused the entry itself, as a sync reads a
    /// refusal: not when it could not be reached, had trouble of its own,
    /// asked to slow down, or refused the token.
    private static func refusal(_ error: any Error) -> String? {
        guard let error = error as? APIError, !error.isUnavailable,
            case .server(let status, let code, let message) = error,
            status < 500, status != 429, !["HRC-AUTH-0003", "HRC-AUTH-0004"].contains(code)
        else { return nil }
        return message
    }
}
