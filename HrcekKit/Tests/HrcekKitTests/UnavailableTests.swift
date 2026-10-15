import Foundation
import Testing

@testable import HrcekKit

@Suite struct UnavailableTests {
    @Test(arguments: [
        APIError.transport(.notConnectedToInternet), .transport(.timedOut),
        .transport(.cannotConnectToHost), .transport(.networkConnectionLost),
        .unexpectedResponse(status: 502), .unexpectedResponse(status: 503),
        .unexpectedResponse(status: 504),
        .server(status: 503, code: "HRC-CORE-0001", message: "Down."),
    ])
    func waitingCouldFix(_ error: APIError) {
        #expect(error.isUnavailable)
    }

    @Test(arguments: [
        APIError.transport(.serverCertificateUntrusted),
        .transport(.secureConnectionFailed),
        .unexpectedResponse(status: 500), .unexpectedResponse(status: 429),
        .unexpectedResponse(status: 200),
        .server(status: 401, code: "HRC-AUTH-0004", message: "No."),
        .server(status: 422, code: "HRC-CORE-0002", message: "No."),
        .server(status: 500, code: "HRC-CORE-0001", message: "No."),
    ])
    func waitingWouldNotFix(_ error: APIError) {
        #expect(!error.isUnavailable)
    }
}
