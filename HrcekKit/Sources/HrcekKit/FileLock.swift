import Foundation

/// An advisory lock on a file, which holds across processes: the app and
/// the share extension both change the queue, and both sync it.
public struct FileLock: Sendable {
    let url: URL

    public init(_ url: URL) {
        self.url = url
    }

    /// Waits for the lock. For changes to the queue, which are quick.
    public func withLock<T>(_ body: () throws -> T) throws -> T {
        let descriptor = try open()
        defer { close(descriptor) }
        flock(descriptor, LOCK_EX)
        defer { flock(descriptor, LOCK_UN) }
        return try body()
    }

    /// Runs `body` only when nobody holds the lock; nil means somebody
    /// did. For syncing: a second sync at once would only race the first.
    public func ifFree<T: Sendable>(_ body: () async throws -> T) async throws -> T? {
        let descriptor = try open()
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else { return nil }
        defer { flock(descriptor, LOCK_UN) }
        return try await body()
    }

    private func open() throws -> Int32 {
        let descriptor = Darwin.open(url.path(percentEncoded: false), O_RDWR | O_CREAT, 0o600)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        return descriptor
    }
}
