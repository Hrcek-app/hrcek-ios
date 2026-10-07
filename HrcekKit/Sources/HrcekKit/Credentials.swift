import Foundation

/// Everything app and extension need to talk to the server as the person.
public struct Credentials: Codable, Equatable, Sendable, CustomStringConvertible {
    public let server: ServerAddress
    public let token: String
    public let displayName: String

    public init(server: ServerAddress, token: String, displayName: String) {
        self.server = server
        self.token = token
        self.displayName = displayName
    }

    public var description: String {
        "Credentials(server: \(server.url.absoluteString), token: ‹redacted›)"
    }
}
