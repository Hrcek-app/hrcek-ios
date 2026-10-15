import Foundation
import Synchronization

@testable import HrcekKit

/// A queue of its own in a fresh temporary directory, so tests run in
/// parallel without meeting.
func temporaryQueue(now: Date = .now) -> PendingQueue {
    PendingQueue(
        directory: FileManager.default.temporaryDirectory
            .appending(path: "pending-\(UUID().uuidString)"),
        now: now)
}

func keptCopy(
    _ url: String = "https://example.com/a", title: String = "A", notes: String = "",
    tags: [String] = [], picture: PendingEntry.Picture? = nil,
    server: String = "https://hrcek.example.com", savedAt: Date = .now,
    state: PendingEntry.State = .waiting
) throws -> PendingEntry {
    PendingEntry(
        request: EntryIn(url: url, title: title, notes: notes, tags: tags),
        picture: picture, server: try ServerAddress(server), savedAt: savedAt,
        state: state)
}

/// A fake Hrček with entries by address, which can be told to be down,
/// to refuse, or to fail a lookup. Used by the sync, share sheet and
/// waiting-list tests alike.
final class FakeHrcek: Sendable {
    struct State {
        var held: [String: String] = [:]
        var posts: [String] = []
        var uploads = 0
        var down = false
        var downAfterPosts: Int?
        var refuseSaves: (Int, String)?
        var refuseLookups: (Int, String)?
        var refusePictures = false
        /// What Hrček answers for an entry's picture: the bytes, or the
        /// sign-in page an older Hrček gives a token.
        var heldPicture: (type: String, body: Data)?
    }

    let state = Mutex(State())

    static func entry(
        _ url: String, title: String = "Theirs", notes: String = "", tags: [String] = [],
        image: Bool = false
    ) -> String {
        let tagList = tags.map { "\"\($0)\"" }.joined(separator: ",")
        let picture = image ? #"{"url":"/entries/7/image/","width":1,"height":1}"# : "null"
        return #"""
            {"id":7,"url":"\#(url)","title":"\#(title)","notes":"\#(notes)",\#
            "tags":[\#(tagList)],"fields":{},"image":\#(picture)}
            """#
    }

    func service() throws -> EntryService {
        EntryService(
            credentials: try sampleCredentials(), language: "en",
            session: StubURLProtocol.typedSession { try self.reply($0) })
    }

    /// `handle`, and the entry's picture, whose content type matters.
    func reply(_ request: URLRequest) throws -> StubURLProtocol.Reply {
        let picture = state.withLock { $0.down ? nil : $0.heldPicture }
        if request.url?.path().hasSuffix("/image/") == true, let picture {
            return StubURLProtocol.Reply(status: 200, body: picture.body, type: picture.type)
        }
        let (status, body) = try handle(request)
        return StubURLProtocol.Reply(status: status, body: body)
    }

    private func envelope(_ code: String) -> Data {
        Data(#"{"error":{"code":"\#(code)","message":"Refused: \#(code)","details":{}}}"#.utf8)
    }

    func handle(_ request: URLRequest) throws -> (Int, Data) {
        try state.withLock { state in
            // A reverse proxy in front of a stopped Hrček: no envelope.
            if state.down { return (503, Data("<html>down</html>".utf8)) }
            let path = request.url?.path() ?? ""
            if path.hasSuffix("/image") {
                if state.refusePictures { return (422, envelope("HRC-IMAGE-0001")) }
                state.uploads += 1
                return (200, Data(Self.entry("x").utf8))
            }
            guard path == "/api/entries/lookup" || path == "/api/entries/" else {
                return (404, notFound)
            }
            let body = try request.jsonObject()
            if path == "/api/entries/lookup" { return lookup(body, &state) }
            return save(body, &state)
        }
    }

    private func lookup(_ body: [String: Any], _ state: inout State) -> (Int, Data) {
        if let (status, code) = state.refuseLookups { return (status, envelope(code)) }
        guard let held = state.held[body["url"] as? String ?? ""] else { return (404, notFound) }
        return (200, Data(held.utf8))
    }

    private func save(_ body: [String: Any], _ state: inout State) -> (Int, Data) {
        if let (status, code) = state.refuseSaves { return (status, envelope(code)) }
        let url = body["url"] as? String ?? ""
        state.posts.append(url)
        if let limit = state.downAfterPosts, state.posts.count >= limit { state.down = true }
        let saved = Self.entry(
            url, title: body["title"] as? String ?? "", notes: body["notes"] as? String ?? "",
            tags: body["tags"] as? [String] ?? [])
        state.held[url] = saved
        return (201, Data(saved.utf8))
    }
}

extension PendingQueue {
    /// Every file under the queue's directory, relative to it, except the
    /// two locks: what a person's storage actually holds.
    func filesOnDisk() -> Set<String> {
        // Relative paths from the directory itself: the temporary directory
        // is a symlink, and absolute spellings of it differ.
        let base = directory.path(percentEncoded: false)
        let paths = (try? FileManager.default.subpathsOfDirectory(atPath: base)) ?? []
        return Set(
            paths.filter { path in
                var isDirectory: ObjCBool = false
                FileManager.default.fileExists(atPath: base + "/" + path, isDirectory: &isDirectory)
                return !isDirectory.boolValue && path != ".lock" && path != ".sync-lock"
            })
    }

    /// What `filesOnDisk` must be for exactly these entries.
    func expectedFiles(for entries: [PendingEntry]) -> Set<String> {
        var files = Set<String>()
        for entry in entries {
            let key = PendingQueue.key(for: entry.url)
            files.insert("\(key)/entry.json")
            if case .bytes = entry.picture { files.insert("\(key)/picture") }
        }
        return files
    }
}
