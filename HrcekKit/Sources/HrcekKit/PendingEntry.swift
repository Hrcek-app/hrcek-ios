import Foundation

/// A save kept on the phone because Hrček could not take it.
public struct PendingEntry: Codable, Equatable, Sendable, Identifiable {
    public enum State: Codable, Equatable, Sendable {
        case waiting
        /// Hrček had the address by the time it was synced; a person decides.
        case held
        /// Hrček refused it, in its own words.
        case refused(message: String)
    }

    /// What sending does about the picture; none leaves Hrček's as it is.
    public enum Picture: Codable, Equatable, Sendable {
        /// Bytes kept beside the entry, read from `source`.
        case bytes(filename: String, type: String, source: URL)
        /// Only the address: the bytes could not be had.
        case address(URL)
        case remove
    }

    /// This copy: a newer one at the same address is another.
    public let id: UUID
    /// What the save would have sent, without `imageUrl`; `picture` says that.
    public let request: EntryIn
    public let picture: Picture?
    public let savedAt: Date
    /// The server it was meant for; it is never sent anywhere else.
    public let server: ServerAddress
    public var state: State

    public init(
        request: EntryIn, picture: Picture?, server: ServerAddress, savedAt: Date = .now,
        id: UUID = UUID(), state: State = .waiting
    ) {
        self.id = id
        self.request = request
        self.picture = picture
        self.savedAt = savedAt
        self.server = server
        self.state = state
    }

    public var url: String { request.url }
}

extension PendingEntry.Picture {
    /// The picture a choice in the form amounts to, and its bytes. Read once
    /// here, so a kept copy and a direct save carry the same picture.
    /// Unchanged on a kept copy is that copy's picture.
    static func chosen(
        _ choice: PictureChoice, kept: PendingEntry?, queue: PendingQueue, pages: PageAccess
    ) async -> (Self?, Data?) {
        switch choice {
        case .unchanged:
            guard let kept else { return (nil, nil) }
            return (kept.picture, queue.pictureData(of: kept))
        case .remove:
            return (.remove, nil)
        case .address(let url):
            guard let bytes = await pages.bytes(url) else { return (.address(url), nil) }
            return (.bytes(filename: bytes.filename, type: bytes.type, source: url), bytes.data)
        }
    }
}
