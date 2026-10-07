import Foundation
import Testing

@testable import HrcekKit

@Suite struct UserFacingErrorTests {
    @Test func showsTheServersOwnMessage() {
        let error = APIError.server(status: 401, code: "HRC-AUTH-0001", message: "Napačno geslo.")
        #expect(UserFacingError.message(for: error) == "Napačno geslo.")
    }

    @Test(arguments: [
        (
            APIError.transport(.notConnectedToInternet),
            "You're offline. Connect to the internet and try again.",
            "Niste povezani z internetom. Povežite se in poskusite znova."
        ),
        (
            APIError.transport(.timedOut), "The server took too long to answer. Try again.",
            "Strežnik se ni odzval dovolj hitro. Poskusite znova."
        ),
        (
            APIError.transport(.cannotFindHost), "Can't reach the server. Check the address.",
            "Strežnika ni mogoče doseči. Preverite naslov."
        ),
        (
            APIError.transport(.serverCertificateUntrusted),
            "Can't make a secure connection to the server.",
            "S strežnikom ni mogoče vzpostaviti varne povezave."
        ),
        (
            APIError.transport(.networkConnectionLost), "Can't reach the server. Try again.",
            "Strežnika ni mogoče doseči. Poskusite znova."
        ),
        (
            APIError.unexpectedResponse(status: 429),
            "Too many attempts. Wait a while and try again.",
            "Preveč poskusov. Počakajte nekaj časa in poskusite znova."
        ),
        (
            APIError.unexpectedResponse(status: 503),
            "The server is having trouble. Try again later.",
            "Strežnik ima težave. Poskusite znova pozneje."
        ),
        (
            APIError.unexpectedResponse(status: 404),
            "The server's answer wasn't understood. Is this a Hrček address?",
            "Odgovora strežnika ni mogoče razumeti. Je to naslov strežnika Hrček?"
        ),
    ])
    func explainsTransportProblems(error: APIError, english: String, slovenian: String) throws {
        let en = try #require(L10n.bundle(for: "en"))
        let sl = try #require(L10n.bundle(for: "sl"))
        #expect(UserFacingError.message(for: error, bundle: en) == english)
        #expect(UserFacingError.message(for: error, bundle: sl) == slovenian)
    }

    @Test(arguments: [
        (
            ServerAddress.Problem.empty, "Enter the address of your Hrček server.",
            "Vnesite naslov svojega strežnika Hrček."
        ),
        (
            ServerAddress.Problem.invalid, "That doesn't look like a web address.",
            "To ni videti kot spletni naslov."
        ),
        (
            ServerAddress.Problem.insecure, "The address must start with https://.",
            "Naslov se mora začeti s https://."
        ),
    ])
    func explainsAddressProblems(
        problem: ServerAddress.Problem, english: String, slovenian: String
    ) throws {
        let en = try #require(L10n.bundle(for: "en"))
        let sl = try #require(L10n.bundle(for: "sl"))
        #expect(UserFacingError.message(for: problem, bundle: en) == english)
        #expect(UserFacingError.message(for: problem, bundle: sl) == slovenian)
    }

    @Test func hasAFallback() throws {
        struct Odd: Error {}
        let sl = try #require(L10n.bundle(for: "sl"))
        #expect(
            UserFacingError.message(for: Odd(), bundle: sl)
                == "Nekaj je šlo narobe. Poskusite znova.")
    }
}
