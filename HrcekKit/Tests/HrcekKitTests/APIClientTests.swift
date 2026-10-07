import Foundation
import Testing

@testable import HrcekKit

@Suite struct APIClientTests {
    let server: ServerAddress

    init() throws {
        server = try ServerAddress("https://hrcek.example.com")
    }

    @Test func sendsTokenLanguageAndJSON() async throws {
        let session = StubURLProtocol.session { request in
            #expect(request.url?.absoluteString == "https://hrcek.example.com/api/entries/lookup")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer hrcek_test1")
            #expect(request.value(forHTTPHeaderField: "Accept-Language") == "sl")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            let body = try request.jsonBody()
            #expect(body == ["url": "https://example.com/a"])
            return (200, Data(#"{"id":7,"url":"https://example.com/a","title":"A"}"#.utf8))
        }
        let client = APIClient(
            server: server, token: "hrcek_test1", language: "sl", session: session)
        let response = try await client.post(
            "/api/entries/lookup", body: LookupIn(url: "https://example.com/a"), as: EntryOut.self)
        #expect(response.status == 200)
        #expect(response.value == EntryOut(id: 7, url: "https://example.com/a", title: "A"))
    }

    @Test func decodesSnakeCase() async throws {
        let session = StubURLProtocol.session(
            status: 200, json: #"{"email":"n@example.com","display_name":"Nina"}"#)
        let client = APIClient(server: server, session: session)
        let user = try await client.get("/api/auth/me", as: UserOut.self)
        #expect(user.value == UserOut(email: "n@example.com", displayName: "Nina"))
    }

    @Test func turnsTheErrorEnvelopeIntoAServerError() async {
        let session = StubURLProtocol.session(
            status: 401,
            json: #"{"error":{"code":"HRC-AUTH-0001","message":"Wrong.","details":{}}}"#)
        let client = APIClient(server: server, session: session)
        await #expect(
            throws: APIError.server(status: 401, code: "HRC-AUTH-0001", message: "Wrong.")
        ) {
            try await client.get("/api/auth/me", as: UserOut.self)
        }
    }

    @Test func reportsAnAnswerItCannotRead() async {
        let session = StubURLProtocol.session(status: 502, json: "<html>Bad gateway</html>")
        let client = APIClient(server: server, session: session)
        await #expect(throws: APIError.unexpectedResponse(status: 502)) {
            try await client.get("/api/auth/me", as: UserOut.self)
        }
    }

    @Test func reportsASuccessWithTheWrongShape() async {
        let session = StubURLProtocol.session(status: 200, json: #"{"unexpected":true}"#)
        let client = APIClient(server: server, session: session)
        await #expect(throws: APIError.unexpectedResponse(status: 200)) {
            try await client.get("/api/auth/me", as: UserOut.self)
        }
    }

    @Test func reportsTransportFailures() async {
        let session = StubURLProtocol.session { _ in throw URLError(.notConnectedToInternet) }
        let client = APIClient(server: server, session: session)
        await #expect(throws: APIError.transport(.notConnectedToInternet)) {
            try await client.get("/api/auth/me", as: UserOut.self)
        }
    }

    @Test func omitsAuthorizationWithoutAToken() async throws {
        let session = StubURLProtocol.session { request in
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            return (200, Data(#"{"email":"n@example.com","display_name":null}"#.utf8))
        }
        _ = try await APIClient(server: server, session: session)
            .get("/api/auth/me", as: UserOut.self)
    }
}
