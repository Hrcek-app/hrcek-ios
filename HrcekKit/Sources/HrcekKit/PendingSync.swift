import Foundation

/// What a sync did, for one line of text.
public struct SyncResult: Equatable, Sendable {
    public enum Stop: Equatable, Sendable {
        /// Hrček did not answer.
        case unavailable
        /// The token was refused.
        case unauthorized
        /// A lookup failed some other way; it says nothing about the entry.
        case failed
        /// Another sync was running, in this process or the other.
        case busy
        /// Cut short by whoever asked, such as the share sheet's time limit.
        case interrupted
    }

    public var saved = 0
    public var held = 0
    public var refused = 0
    /// Titles, or addresses when untitled, saved without their picture.
    public var withoutPicture: [String] = []
    public var stopped: Stop?

    public init(
        saved: Int = 0, held: Int = 0, refused: Int = 0, withoutPicture: [String] = [],
        stopped: Stop? = nil
    ) {
        self.saved = saved
        self.held = held
        self.refused = refused
        self.withoutPicture = withoutPicture
        self.stopped = stopped
    }
}

public enum PendingSync {
    /// Looks before writing, copy by copy, oldest first. Hrček holding the
    /// address already is not this routine's to settle: the copy is held
    /// for a person. Only waiting copies meant for `server` are touched,
    /// each read again before it is handled. The first sign of an outage,
    /// a refused token or a failed lookup ends the run with everything
    /// after it as it was.
    ///
    /// Holds a lock file in the shared container while it talks to the
    /// network, and iOS ends a process suspended with such a lock held.
    /// Callers must therefore run a sync under a background-time assertion
    /// (`UIApplication.beginBackgroundTask` in the app,
    /// `ProcessInfo.performExpiringActivity` in the extension) and cancel
    /// it when the assertion expires: the run then ends with
    /// `.interrupted` and releases the lock.
    public static func run(
        queue: PendingQueue, service: EntryService, server: ServerAddress
    ) async -> SyncResult {
        do {
            let result = try await queue.syncLock.ifFree {
                await handle(queue: queue, service: service, server: server)
            }
            return result ?? SyncResult(stopped: .busy)
        } catch {
            Log.app.error("Sync not run: \(Log.summary(of: error), privacy: .public)")
            return SyncResult(stopped: .failed)
        }
    }

    /// `run`, given up after `limit` or when the caller is cancelled. Either
    /// way the run is cancelled, ends its request, reports `.interrupted`
    /// and releases the lock.
    public static func run(
        queue: PendingQueue, service: EntryService, server: ServerAddress,
        within limit: Duration
    ) async -> SyncResult {
        let work = Task { await run(queue: queue, service: service, server: server) }
        // Not a task group: a group waits for every child, and the point is
        // to stop waiting.
        let timer = Task {
            try? await Task.sleep(for: limit)
            work.cancel()
        }
        defer { timer.cancel() }
        // An unstructured task does not inherit its caller's cancellation.
        return await withTaskCancellationHandler {
            await work.value
        } onCancel: {
            work.cancel()
        }
    }

    private static func handle(
        queue: PendingQueue, service: EntryService, server: ServerAddress
    ) async -> SyncResult {
        var result = SyncResult()
        for listed in queue.list() where listed.server == server && listed.state == .waiting {
            // The list is a snapshot: the copy may have been deleted, or a
            // newer one kept, since it was read.
            guard let entry = queue.get(listed.url), entry.id == listed.id,
                entry.state == .waiting
            else { continue }
            if let stop = await settle(entry, queue: queue, service: service, into: &result) {
                result.stopped = stop
                break
            }
        }
        Log.app.info(
            "Synced: \(result.saved) saved, \(result.held) held, \(result.refused) refused")
        return result
    }

    /// Handles one copy; a returned stop ends the run.
    private static func settle(
        _ entry: PendingEntry, queue: PendingQueue, service: EntryService,
        into result: inout SyncResult
    ) async -> SyncResult.Stop? {
        let existing: EntryOut?
        do {
            existing = try await service.lookup(entry.url)
        } catch {
            return stop(for: error) ?? .failed
        }
        if let existing {
            if alreadySent(existing, entry.request) {
                // An earlier run was cut off after Hrček took it.
                try? queue.remove(entry.url, id: entry.id)
                result.saved += 1
            } else {
                try? queue.mark(entry.url, id: entry.id, .held)
                result.held += 1
            }
            return nil
        }
        do {
            let (_, trouble) = try await send(
                entry, picture: queue.pictureData(of: entry), service: service)
            try? queue.remove(entry.url, id: entry.id)
            result.saved += 1
            if trouble != nil {
                result.withoutPicture.append(
                    entry.request.title.isEmpty ? entry.url : entry.request.title)
            }
        } catch {
            if let stop = stop(for: error) { return stop }
            // A server's own trouble, or a request to slow down, passes with
            // time; only a refusal that would be repeated needs a person.
            guard case .server(let status, _, let message) = error as? APIError,
                status < 500, status != 429
            else { return .failed }
            try? queue.mark(entry.url, id: entry.id, .refused(message: message))
            result.refused += 1
        }
        return nil
    }

    /// Sends one copy the way the share sheet sends an entry: bytes
    /// uploaded after it, else the address as `image_url`, and a picture
    /// never failing the entry. Throws what the entry's own save throws.
    public static func send(
        _ entry: PendingEntry, picture data: Data?, service: EntryService
    ) async throws -> (created: Bool, trouble: String?) {
        let choice: PictureChoice
        var bytes: PictureBytes?
        switch entry.picture {
        case .bytes(let filename, let type, let source):
            choice = .address(source)
            bytes = data.map { PictureBytes(data: $0, type: type, filename: filename) }
        case .address(let url):
            choice = .address(url)
        case .remove:
            choice = .remove
        case nil:
            choice = .unchanged
        }
        let kept = bytes
        let pages = PageAccess(pictures: { _ in [] }, bytes: { _ in kept })
        return try await PictureSaver(service: service, pages: pages)
            .save(entry.request, choice: choice)
    }

    /// Whether Hrček's entry is this copy already: what a person typed is
    /// the same, tags in any order or case, as the server keeps them.
    public static func alreadySent(_ held: EntryOut, _ request: EntryIn) -> Bool {
        held.title == request.title && held.notes == request.notes
            && Set(held.tags.map { $0.lowercased() }) == Set(request.tags.map { $0.lowercased() })
    }

    private static func stop(for error: any Error) -> SyncResult.Stop? {
        if Task.isCancelled || error is CancellationError { return .interrupted }
        guard let error = error as? APIError else { return nil }
        if error.isUnavailable { return .unavailable }
        if ["HRC-AUTH-0003", "HRC-AUTH-0004"].contains(error.code) { return .unauthorized }
        return nil
    }
}
