import CryptoKit
import Foundation
import notify

/// Saves kept until Hrček can take them, as files in the container app
/// and extension share. One directory per address, named by its hash,
/// holding `entry.json` and, when there are bytes, `picture`. Nothing of
/// an entry outlives its place here.
public final class PendingQueue: Sendable {
    public enum Failure: Error, Equatable { case full }

    public static let limit = 100
    /// Posted after every change, so an open app hears the extension's.
    static let changed = "app.hrcek.pending.changed"

    let directory: URL
    private let incoming: URL
    private let lock: FileLock
    /// Held while syncing; see `PendingSync.run`.
    public let syncLock: FileLock

    public init(directory: URL, now: Date = .now) {
        self.directory = directory
        incoming = directory.appending(path: ".incoming")
        lock = FileLock(directory.appending(path: ".lock"))
        syncLock = FileLock(directory.appending(path: ".sync-lock"))
        do {
            try FileManager.default.createDirectory(
                at: incoming, withIntermediateDirectories: true)
            // A kept save is the person's and this phone's; restoring it
            // onto another phone would send it twice.
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var url = directory
            try url.setResourceValues(values)
            try lock.withLock { sweep(now: now) }
        } catch {
            Log.app.error("Queue not opened: \(Log.summary(of: error), privacy: .public)")
        }
    }

    /// The queue in the App Group container. Should the container be
    /// missing — a build without the entitlement — saves stay with the
    /// app alone, which is better than losing them.
    public static let shared: PendingQueue = {
        let group = Bundle.main.object(forInfoDictionaryKey: "HrcekAppGroup") as? String
        let container = group.flatMap {
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0)
        }
        if container == nil { Log.app.fault("No App Group container; queue is not shared") }
        let base = container ?? URL.applicationSupportDirectory
        return PendingQueue(directory: base.appending(path: "Pending"))
    }()

    // MARK: Reading

    public func get(_ url: String) -> PendingEntry? {
        (try? lock.withLock { read(Self.key(for: url)) }) ?? nil
    }

    /// Oldest first, which is the order they are sent in.
    public func list() -> [PendingEntry] {
        let entries = (try? lock.withLock { keys().compactMap(read) }) ?? []
        return entries.sorted { $0.savedAt < $1.savedAt }
    }

    public func count() -> Int { list().count }

    public func pictureData(of entry: PendingEntry) -> Data? {
        guard case .bytes = entry.picture else { return nil }
        return try? Data(
            contentsOf: directory.appending(path: "\(Self.key(for: entry.url))/picture"))
    }

    // MARK: Changing

    /// Keeps `entry`, replacing any copy at its address.
    public func put(_ entry: PendingEntry, picture: Data?) throws {
        let key = Self.key(for: entry.url)
        try lock.withLock {
            let target = directory.appending(path: key)
            let exists = FileManager.default.fileExists(atPath: target.path(percentEncoded: false))
            if !exists, keys().count >= Self.limit { throw Failure.full }
            // Built aside and moved in, so no reader ever sees half an entry.
            let staging = incoming.appending(path: UUID().uuidString)
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
            try JSONEncoder().encode(entry).write(to: staging.appending(path: "entry.json"))
            if case .bytes = entry.picture, let picture {
                try picture.write(to: staging.appending(path: "picture"))
            }
            if exists { try FileManager.default.removeItem(at: target) }
            try FileManager.default.moveItem(at: staging, to: target)
        }
        Self.announce()
    }

    /// Deletes this copy and its picture; a newer copy at the address stays.
    public func remove(_ url: String, id: UUID) throws {
        let key = Self.key(for: url)
        try lock.withLock {
            guard read(key)?.id == id else { return }
            try FileManager.default.removeItem(at: directory.appending(path: key))
        }
        Self.announce()
    }

    public func mark(_ url: String, id: UUID, _ state: PendingEntry.State) throws {
        let key = Self.key(for: url)
        try lock.withLock {
            guard var entry = read(key), entry.id == id else { return }
            entry.state = state
            try JSONEncoder().encode(entry).write(
                to: directory.appending(path: "\(key)/entry.json"), options: .atomic)
        }
        Self.announce()
    }

    // MARK: Changes from either process

    private static let delivery = DispatchQueue(label: "app.hrcek.pending.changes")

    public static func changes() -> AsyncStream<Void> {
        AsyncStream { continuation in
            var token: Int32 = 0
            notify_register_dispatch(changed, &token, delivery) { _ in continuation.yield() }
            let registered = token
            continuation.onTermination = { _ in notify_cancel(registered) }
        }
    }

    private static func announce() { notify_post(changed) }

    // MARK: Keys and files

    /// As the server matches addresses: trimmed, scheme and host lowercased.
    static func normalized(_ url: String) -> String {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var parts = URLComponents(string: trimmed) else { return trimmed }
        parts.scheme = parts.scheme?.lowercased()
        parts.host = parts.host?.lowercased()
        return parts.string ?? trimmed
    }

    /// A file name for an address: addresses hold characters file names cannot.
    static func key(for url: String) -> String {
        SHA256.hash(data: Data(normalized(url).utf8))
            .map { String(format: "%02x", $0) }.joined()
    }

    private func keys() -> [String] {
        let names =
            (try? FileManager.default.contentsOfDirectory(
                atPath: directory.path(percentEncoded: false))) ?? []
        return names.filter { !$0.hasPrefix(".") }
    }

    private func read(_ key: String) -> PendingEntry? {
        let file = directory.appending(path: "\(key)/entry.json")
        guard let data = try? Data(contentsOf: file) else { return nil }
        do {
            return try JSONDecoder().decode(PendingEntry.self, from: data)
        } catch {
            Log.app.error("Unreadable kept entry: \(Log.summary(of: error), privacy: .public)")
            return nil
        }
    }

    /// Deletes what an interrupted write or a broken entry left behind. A
    /// staging directory younger than a minute may still be being written
    /// by the other process, so it stays.
    private func sweep(now: Date) {
        let manager = FileManager.default
        let staged =
            (try? manager.contentsOfDirectory(
                at: incoming, includingPropertiesForKeys: [.creationDateKey])) ?? []
        for url in staged {
            let created = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate
            if let created, now.timeIntervalSince(created) < 60 { continue }
            try? manager.removeItem(at: url)
        }
        for key in keys() where isBroken(key) {
            try? manager.removeItem(at: directory.appending(path: key))
        }
    }

    /// Whether an entry is beyond reading, as opposed to not read just
    /// now: only a missing file or one that is not an entry is broken. A
    /// failed read may pass, and the person's only copy is not for deleting.
    private func isBroken(_ key: String) -> Bool {
        let file = directory.appending(path: "\(key)/entry.json")
        guard FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) else {
            return true
        }
        guard let data = try? Data(contentsOf: file) else { return false }
        return (try? JSONDecoder().decode(PendingEntry.self, from: data)) == nil
    }
}
