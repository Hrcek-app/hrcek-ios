import Foundation

public enum APIError: Error, Equatable, Sendable {
    /// The server refused with a code from its catalogue; `message` is
    /// already in the person's language.
    case server(status: Int, code: String, message: String)
    case transport(URLError.Code)
    /// An answer that is neither the expected success nor the error envelope.
    case unexpectedResponse(status: Int)

    public var code: String? {
        if case .server(_, let code, _) = self { code } else { nil }
    }
}
