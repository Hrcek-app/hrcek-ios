import Foundation

public struct TokenExchangeIn: Encodable, Sendable {
    public let name: String
    public let identifier: String
    public let password: String
}

public struct TokenOut: Decodable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let token: String
}

public struct UserOut: Decodable, Equatable, Sendable {
    public let email: String
    public let displayName: String?
}

public struct LookupIn: Encodable, Sendable {
    public let url: String
}

/// An entry to save. Posting replaces what the server holds, except that
/// `fields` and `imageUrl` change nothing when left out.
public struct EntryIn: Encodable, Sendable {
    public let url: String
    public let title: String
    public let notes: String
    public let tags: [String]
    public let fields: [String: String]?
    public let imageUrl: String?

    public init(
        url: String, title: String, notes: String, tags: [String],
        fields: [String: String]? = nil, imageUrl: String? = nil
    ) {
        self.url = url
        self.title = title
        self.notes = notes
        self.tags = tags
        self.fields = fields
        self.imageUrl = imageUrl
    }
}

/// The picture an entry holds. `url` is server-relative and answers only
/// to the entry's owner.
public struct ImageOut: Decodable, Equatable, Sendable {
    public let url: String
    public let width: Int
    public let height: Int

    public init(url: String, width: Int, height: Int) {
        self.url = url
        self.width = width
        self.height = height
    }
}

public struct EntryOut: Decodable, Equatable, Sendable {
    public let id: Int
    public let url: String
    public let title: String
    public let notes: String
    public let tags: [String]
    public let fields: [String: String]
    public let image: ImageOut?

    public init(
        id: Int, url: String, title: String, notes: String = "", tags: [String] = [],
        fields: [String: String] = [:], image: ImageOut? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.notes = notes
        self.tags = tags
        self.fields = fields
        self.image = image
    }
}

/// One page of a list the API answers in pages.
public struct Page<Item: Decodable & Sendable>: Decodable, Sendable {
    public let items: [Item]
    public let count: Int
}

public struct LabelOut: Decodable, Equatable, Sendable {
    public let name: String
}

struct ErrorEnvelope: Decodable {
    struct Body: Decodable {
        let code: String
        let message: String
    }
    let error: Body
}
