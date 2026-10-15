import Foundation

extension APIError {
    /// What a reverse proxy answers for a Hrček that is stopped.
    private static let unavailableStatuses: Set<Int> = [502, 503, 504]

    /// A certificate the phone distrusts today it distrusts tomorrow.
    private static let untrusted: Set<URLError.Code> = [
        .secureConnectionFailed, .serverCertificateUntrusted,
        .serverCertificateHasBadDate, .serverCertificateNotYetValid,
        .serverCertificateHasUnknownRoot, .clientCertificateRejected,
        .clientCertificateRequired, .appTransportSecurityRequiresSecureConnection,
    ]

    /// Whether waiting could fix this failure. Only then is a save kept
    /// for later: a refused token or invalid data will still be refused,
    /// and keeping it would only hide that.
    public var isUnavailable: Bool {
        switch self {
        case .transport(let code):
            !Self.untrusted.contains(code)
        case .server(let status, _, _), .unexpectedResponse(let status):
            Self.unavailableStatuses.contains(status)
        }
    }
}
