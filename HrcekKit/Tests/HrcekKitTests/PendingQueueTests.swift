import Foundation
import Testing

@testable import HrcekKit

@Suite struct PendingQueueTests {
    @Test func keepsAndReadsBackACopy() throws {
        let queue = temporaryQueue()
        let copy = try keptCopy(notes: "Mine", tags: ["x"])
        try queue.put(copy, picture: nil)
        #expect(queue.get(copy.url) == copy)
        #expect(queue.count() == 1)
    }

    @Test func oneCopyPerAddressHoweverWritten() throws {
        let queue = temporaryQueue()
        try queue.put(try keptCopy("https://example.com/a", title: "Old"), picture: nil)
        let newer = try keptCopy("  HTTPS://Example.COM/a ", title: "New")
        try queue.put(newer, picture: nil)
        #expect(queue.list() == [newer])
        #expect(queue.get("https://example.com/a")?.request.title == "New")
    }

    @Test func listsOldestFirst() throws {
        let queue = temporaryQueue()
        let later = try keptCopy("https://example.com/b", savedAt: .now)
        let earlier = try keptCopy(
            "https://example.com/a", savedAt: .now.addingTimeInterval(-60))
        try queue.put(later, picture: nil)
        try queue.put(earlier, picture: nil)
        #expect(queue.list().map(\.url) == [earlier.url, later.url])
    }

    @Test func refusesANewAddressBeyondTheLimit() throws {
        let queue = temporaryQueue()
        for index in 0..<PendingQueue.limit {
            try queue.put(try keptCopy("https://example.com/\(index)"), picture: nil)
        }
        #expect(throws: PendingQueue.Failure.full) {
            try queue.put(try keptCopy("https://example.com/one-more"), picture: nil)
        }
        // Replacing a copy already kept is not a new one.
        try queue.put(try keptCopy("https://example.com/0", title: "Again"), picture: nil)
        #expect(queue.count() == PendingQueue.limit)
    }

    @Test func keepsThePicturesBytes() throws {
        let queue = temporaryQueue()
        let source = try #require(URL(string: "https://example.com/p.png"))
        let copy = try keptCopy(
            picture: .bytes(filename: "p.png", type: "image/png", source: source))
        try queue.put(copy, picture: Data([1, 2, 3]))
        #expect(queue.pictureData(of: copy) == Data([1, 2, 3]))
    }

    @Test func removesOnlyTheCopyNamed() throws {
        let queue = temporaryQueue()
        let old = try keptCopy(title: "Old")
        try queue.put(old, picture: nil)
        let newer = try keptCopy(title: "New")
        try queue.put(newer, picture: nil)
        try queue.remove(old.url, id: old.id)
        #expect(queue.get(old.url) == newer, "a newer copy kept meanwhile stays")
        try queue.remove(newer.url, id: newer.id)
        #expect(queue.get(newer.url) == nil)
    }

    @Test func marksOnlyTheCopyNamed() throws {
        let queue = temporaryQueue()
        let copy = try keptCopy()
        try queue.put(copy, picture: nil)
        try queue.mark(copy.url, id: UUID(), .held)
        #expect(queue.get(copy.url)?.state == .waiting)
        try queue.mark(copy.url, id: copy.id, .refused(message: "No."))
        #expect(queue.get(copy.url)?.state == .refused(message: "No."))
    }

    @Test func storageHoldsOnlyWhatIsListed() throws {
        let queue = temporaryQueue()
        let source = try #require(URL(string: "https://example.com/p.png"))
        let withPicture = try keptCopy(
            "https://example.com/a",
            picture: .bytes(filename: "p.png", type: "image/png", source: source))
        let plain = try keptCopy("https://example.com/b")
        try queue.put(withPicture, picture: Data([1]))
        try queue.put(plain, picture: nil)
        #expect(queue.filesOnDisk() == queue.expectedFiles(for: [withPicture, plain]))

        // Replaced by a copy without bytes: the old picture goes too.
        let replacement = try keptCopy("https://example.com/a", title: "No picture")
        try queue.put(replacement, picture: nil)
        #expect(queue.filesOnDisk() == queue.expectedFiles(for: [replacement, plain]))

        try queue.remove(replacement.url, id: replacement.id)
        try queue.remove(plain.url, id: plain.id)
        #expect(queue.filesOnDisk().isEmpty)
    }

    @Test func skipsAnUnreadableCopy() throws {
        let queue = temporaryQueue()
        let good = try keptCopy("https://example.com/good")
        try queue.put(good, picture: nil)
        let broken = queue.directory.appending(path: "broken")
        try FileManager.default.createDirectory(at: broken, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: broken.appending(path: "entry.json"))
        #expect(queue.list() == [good])
    }

    @Test func sweepsWhatAnInterruptedWriteLeft() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "pending-\(UUID().uuidString)")
        let first = PendingQueue(directory: directory)
        let good = try keptCopy()
        try first.put(good, picture: nil)
        // A write killed before its move, and a directory with no entry.
        let stale = first.directory.appending(path: ".incoming/\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: stale, withIntermediateDirectories: true)
        try Data([1]).write(to: stale.appending(path: "picture"))
        let empty = first.directory.appending(path: "empty")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)

        let reopened = PendingQueue(directory: directory, now: .now.addingTimeInterval(120))
        #expect(reopened.filesOnDisk() == reopened.expectedFiles(for: [good]))
    }

    /// A read that fails is not a copy that is broken: the person's only
    /// copy stays for a later look.
    @Test func keepsACopyItCouldNotRead() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "pending-\(UUID().uuidString)")
        let first = PendingQueue(directory: directory)
        // entry.json is a directory, so reading it fails without being bad JSON.
        let unreadable = first.directory.appending(path: "unreadable/entry.json")
        try FileManager.default.createDirectory(
            at: unreadable, withIntermediateDirectories: true)
        _ = PendingQueue(directory: directory)
        #expect(FileManager.default.fileExists(atPath: unreadable.path(percentEncoded: false)))
    }

    @Test func leavesAWriteStillInProgress() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "pending-\(UUID().uuidString)")
        let first = PendingQueue(directory: directory)
        let fresh = first.directory.appending(path: ".incoming/\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: fresh, withIntermediateDirectories: true)
        try Data([1]).write(to: fresh.appending(path: "picture"))
        let reopened = PendingQueue(directory: directory)
        #expect(!reopened.filesOnDisk().isEmpty, "another process may be writing it")
    }

    @Test func announcesChanges() async throws {
        let queue = temporaryQueue()
        var changes = PendingQueue.changes().makeAsyncIterator()
        try queue.put(try keptCopy(), picture: nil)
        let heard: Void? = await changes.next()
        #expect(heard != nil)
    }
}
