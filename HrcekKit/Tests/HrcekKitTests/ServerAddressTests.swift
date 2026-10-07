import Foundation
import Testing

@testable import HrcekKit

@Suite struct ServerAddressTests {
    @Test(arguments: [
        ("hrcek.example.com", "https://hrcek.example.com"),
        ("  Hrcek.Example.COM/  ", "https://hrcek.example.com"),
        ("https://hrcek.example.com/", "https://hrcek.example.com"),
        ("https://example.com/hrcek/", "https://example.com/hrcek"),
        ("http://localhost:8000", "http://localhost:8000"),
        ("http://127.0.0.1:8000/", "http://127.0.0.1:8000"),
    ])
    func normalises(typed: String, expected: String) throws {
        #expect(try ServerAddress(typed).url.absoluteString == expected)
    }

    @Test(arguments: ["", "   "])
    func refusesEmpty(typed: String) {
        #expect(throws: ServerAddress.Problem.empty) { try ServerAddress(typed) }
    }

    @Test(arguments: [
        "ftp://example.com", "https://", "https://example.com/?a=1", "https://exa mple.com",
    ])
    func refusesWhatIsNotAWebAddress(typed: String) {
        #expect(throws: ServerAddress.Problem.invalid) { try ServerAddress(typed) }
    }

    @Test(arguments: ["http://hrcek.example.com", "http://192.168.1.10:8000"])
    func refusesPlainHTTPExceptLocally(typed: String) {
        #expect(throws: ServerAddress.Problem.insecure) { try ServerAddress(typed) }
    }

    @Test func buildsEndpoints() throws {
        let server = try ServerAddress("https://example.com/hrcek")
        #expect(
            server.endpoint("/api/entries/").absoluteString
                == "https://example.com/hrcek/api/entries/")
        #expect(server.host == "example.com")
    }
}
