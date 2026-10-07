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

/// A new entry. The API replaces an existing one wholesale, so this is
/// only ever sent for an address the lookup said is not saved yet.
public struct EntryIn: Encodable, Sendable {
    public let url: String
    public let title: String
}

public struct EntryOut: Decodable, Equatable, Sendable {
    public let id: Int
    public let url: String
    public let title: String
}

struct ErrorEnvelope: Decodable {
    struct Body: Decodable {
        let code: String
        let message: String
    }
    let error: Body
}
