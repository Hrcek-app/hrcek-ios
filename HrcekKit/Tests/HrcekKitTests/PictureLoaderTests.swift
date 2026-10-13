import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import HrcekKit

@Suite struct PictureLoaderTests {
    /// A PNG of the given size, made here so no fixture file is needed.
    static func png(width: Int, height: Int) throws -> Data {
        let context = try #require(
            CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(red: 0.3, green: 0.7, blue: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    @Test func shrinksAPictureToTheSizeAsked() throws {
        let png = try Self.png(width: 800, height: 400)
        let image = try #require(PictureLoader.image(from: png, side: 200))
        #expect(image.width == 200)
        #expect(image.height == 100)
    }

    @Test func neverEnlargesAPicture() throws {
        let png = try Self.png(width: 50, height: 40)
        let image = try #require(PictureLoader.image(from: png, side: 200))
        #expect(image.width == 50)
    }

    @Test func notAPictureIsNothing() {
        #expect(PictureLoader.image(from: Data("<html>".utf8), side: 200) == nil)
    }

    @Test func loadsAndKeepsAPictureFromTheWeb() async throws {
        let png = try Self.png(width: 300, height: 300)
        let asked = Asked()
        let session = StubURLProtocol.typedSession { request in
            asked.queries.withLock { $0.append(request.url?.absoluteString ?? "") }
            return .init(status: 200, body: png, type: "image/png")
        }
        let loader = PictureLoader(session: session)
        let url = try #require(URL(string: "https://cdn.example.com/a.png"))
        #expect(await loader.image(at: url, side: 100)?.width == 100)
        #expect(await loader.image(at: url, side: 100)?.width == 100)
        #expect(asked.all.count == 1, "the second look comes from memory")
    }
}
