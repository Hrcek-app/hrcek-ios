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

    private let queue: PendingQueue
    private let makeService: @Sendable (Credentials) -> EntryService

    public init(
        queue: PendingQueue,
        makeService: @escaping @Sendable (Credentials) -> EntryService = {
            EntryService(credentials: $0)
        }
    ) {
        self.queue = queue
        self.makeService = makeService
    }

    public var count: Int { entries.count }

    /// Reads the queue again: the share extension may have changed it.
    public func reload() {
        entries = queue.list()
        if !entries.isEmpty { isPresented = true }
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
}
