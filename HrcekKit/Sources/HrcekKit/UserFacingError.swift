import Foundation

/// What to tell a person about a failure, in their language.
public enum UserFacingError {
    public static func message(for error: any Error, bundle: Bundle = L10n.bundle) -> String {
        if let error = error as? APIError { return message(for: error, bundle: bundle) }
        if let problem = error as? ServerAddress.Problem {
            return message(for: problem, bundle: bundle)
        }
        return String(localized: "Something went wrong. Try again.", bundle: bundle)
    }

    private static func message(for error: APIError, bundle: Bundle) -> String {
        switch error {
        case .server(_, _, let message):
            message
        case .transport(let code):
            message(for: code, bundle: bundle)
        case .unexpectedResponse(let status):
            message(forUnexpected: status, bundle: bundle)
        }
    }

    // Rate limits and proxy errors arrive without the error envelope;
    // blaming the address for them would send the person the wrong way.
    private static func message(forUnexpected status: Int, bundle: Bundle) -> String {
        switch status {
        case 429:
            String(localized: "Too many attempts. Wait a while and try again.", bundle: bundle)
        case 500...599:
            String(localized: "The server is having trouble. Try again later.", bundle: bundle)
        default:
            String(
                localized: "The server's answer wasn't understood. Is this a Hrček address?",
                bundle: bundle)
        }
    }

    private static func message(for code: URLError.Code, bundle: Bundle) -> String {
        switch code {
        case .notConnectedToInternet, .dataNotAllowed:
            String(
                localized: "You're offline. Connect to the internet and try again.",
                bundle: bundle)
        case .timedOut:
            String(localized: "The server took too long to answer. Try again.", bundle: bundle)
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            String(localized: "Can't reach the server. Check the address.", bundle: bundle)
        case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate,
            .serverCertificateNotYetValid, .serverCertificateHasUnknownRoot:
            String(localized: "Can't make a secure connection to the server.", bundle: bundle)
        default:
            String(localized: "Can't reach the server. Try again.", bundle: bundle)
        }
    }

    private static func message(for problem: ServerAddress.Problem, bundle: Bundle) -> String {
        switch problem {
        case .empty: String(localized: "Enter the address of your Hrček server.", bundle: bundle)
        case .invalid: String(localized: "That doesn't look like a web address.", bundle: bundle)
        case .insecure: String(localized: "The address must start with https://.", bundle: bundle)
        }
    }
}
