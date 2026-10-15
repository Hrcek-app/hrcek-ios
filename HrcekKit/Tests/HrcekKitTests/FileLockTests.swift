import Foundation
import Testing

@testable import HrcekKit

@Suite struct FileLockTests {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "lock-\(UUID().uuidString)")

    @Test func runsTheBodyWhenFree() async throws {
        let answer = try await FileLock(url).ifFree { 42 }
        #expect(answer == 42)
    }

    /// Two opens of one file conflict even in one process, which is how
    /// the app and the extension are kept apart.
    @Test func skipsTheBodyWhileAnotherHoldsIt() async throws {
        let outer = FileLock(url)
        let inner = FileLock(url)
        let answer = try await outer.ifFree { try await inner.ifFree { 1 } }
        #expect(answer == .some(nil))
    }

    @Test func isFreeAgainAfterwards() async throws {
        let lock = FileLock(url)
        _ = try await lock.ifFree { 1 }
        #expect(try await lock.ifFree { 2 } == 2)
    }

    @Test func waitsForChanges() throws {
        #expect(try FileLock(url).withLock { "done" } == "done")
    }
}
