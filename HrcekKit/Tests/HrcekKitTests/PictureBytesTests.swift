import Foundation
import Testing

@testable import HrcekKit

@Suite struct PictureBytesTests {
    let address = URL(string: "https://cdn.example.com/pics/watch.jpg?w=800")

    func fetch(_ status: Int, _ data: Data, _ type: String) async throws -> PictureBytes? {
        let session = StubURLProtocol.typedSession { request in
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            return .init(status: status, body: data, type: type)
        }
        return await PictureBytes.fetch(try #require(address), session: session)
    }

    @Test func readsAPicture() async throws {
        let bytes = try await fetch(200, Data([1, 2]), "image/jpeg")
        let expected = PictureBytes(data: Data([1, 2]), type: "image/jpeg", filename: "watch.jpg")
        #expect(bytes == expected)
    }

    @Test func leavesToTheServerWhatItCannotRead() async throws {
        #expect(try await fetch(404, Data([1]), "image/jpeg") == nil)
        #expect(try await fetch(200, Data(), "image/jpeg") == nil)
        #expect(try await fetch(200, Data("<svg/>".utf8), "image/svg+xml") == nil)
        #expect(try await fetch(200, Data("<html>".utf8), "text/html") == nil)
        let tooBig = Data(count: 10 * 1024 * 1024 + 1)
        #expect(try await fetch(200, tooBig, "image/jpeg") == nil)
    }

    @Test func aFilenameCannotBreakTheUploadsHeaders() {
        #expect(PictureBytes.filename(for: "a\r\nX: y\";b\\c.jpg") == "aX: ybc.jpg")
        #expect(PictureBytes.filename(for: "") == "picture")
        #expect(PictureBytes.filename(for: String(repeating: "x", count: 300)).count == 100)
    }
}
