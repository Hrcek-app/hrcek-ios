import Foundation

/// The address of a Hrček server, normalised from what the person typed.
public struct ServerAddress: Hashable, Sendable, Codable {
    public enum Problem: Error, Equatable, Sendable {
        case empty, invalid, insecure
    }

    // Plain http would send the password in the clear; only this machine is exempt.
    private static let localHosts: Set<String> = ["localhost", "127.0.0.1", "::1", "[::1]"]

    public let url: URL

    public init(_ text: String) throws(Problem) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .empty }
        let withScheme = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard var parts = URLComponents(string: withScheme),
            let scheme = parts.scheme?.lowercased(), ["http", "https"].contains(scheme),
            let host = parts.host?.lowercased(), !host.isEmpty,
            parts.query == nil, parts.fragment == nil, parts.user == nil
        else { throw .invalid }
        if scheme == "http", !Self.localHosts.contains(host) { throw .insecure }
        parts.scheme = scheme
        parts.host = host
        while parts.path.hasSuffix("/") { parts.path.removeLast() }
        guard let url = parts.url else { throw .invalid }
        self.url = url
    }

    public var host: String { url.host() ?? "" }

    public func endpoint(_ path: String) -> URL {
        url.appending(path: path)
    }
}
