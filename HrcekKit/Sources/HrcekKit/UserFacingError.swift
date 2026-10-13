import Foundation

/// What to tell a person about a failure, in their language.
public enum UserFacingError {
    public static func message(for error: any Error, language: String? = nil) -> String {
        if let error = error as? APIError { return message(for: error, language: language) }
        if let problem = error as? ServerAddress.Problem {
            return message(for: problem, language: language)
        }
        return L10n.string("Something went wrong. Try again.", language: language)
    }

    private static func message(for error: APIError, language: String?) -> String {
        switch error {
        case .server(_, _, let message):
            message
        case .transport(let code):
            message(for: code, language: language)
        case .unexpectedResponse(let status):
            message(forUnexpected: status, language: language)
        }
    }

    // Rate limits and proxy errors arrive without the error envelope;
    // blaming the address for them would send the person the wrong way.
    private static func message(forUnexpected status: Int, language: String?) -> String {
        switch status {
        case 429:
            L10n.string("Too many attempts. Wait a while and try again.", language: language)
        case 500...599:
            L10n.string("The server is having trouble. Try again later.", language: language)
        default:
            L10n.string(
                "The server's answer wasn't understood. Is this a Hrček address?",
                language: language)
        }
    }

    private static func message(for code: URLError.Code, language: String?) -> String {
        switch code {
        case .notConnectedToInternet, .dataNotAllowed:
            L10n.string(
                "You're offline. Connect to the internet and try again.", language: language)
        case .timedOut:
            L10n.string("The server took too long to answer. Try again.", language: language)
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            L10n.string("Can't reach the server. Check the address.", language: language)
        case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate,
            .serverCertificateNotYetValid, .serverCertificateHasUnknownRoot:
            L10n.string("Can't make a secure connection to the server.", language: language)
        default:
            L10n.string("Can't reach the server. Try again.", language: language)
        }
    }

    private static func message(for problem: ServerAddress.Problem, language: String?) -> String {
        switch problem {
        case .empty: L10n.string("Enter the address of your Hrček server.", language: language)
        case .invalid: L10n.string("That doesn't look like a web address.", language: language)
        case .insecure: L10n.string("The address must start with https://.", language: language)
        }
    }
}
