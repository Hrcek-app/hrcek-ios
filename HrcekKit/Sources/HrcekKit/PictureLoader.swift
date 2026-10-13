import CoreGraphics
import Foundation
import ImageIO

/// Loads pictures to show, shrunk as they are decoded: a share extension
/// is given little memory, and a page's pictures can be large.
public final class PictureLoader: Sendable {
    public static let shared = PictureLoader(session: PictureBytes.cookieless)

    private let session: URLSession
    private let cache = Cache()

    public init(session: URLSession) {
        self.session = session
    }

    /// The picture at `url`, no larger than `side` pixels either way.
    public func image(at url: URL, side: Int) async -> CGImage? {
        let key = "\(side) \(url.absoluteString)"
        if let image = cache.image(for: key) { return image }
        // A part of a picture does not decode; a picture larger than this is
        // not worth the memory to show as a thumbnail.
        guard let read = try? await session.data(for: URLRequest(url: url), upTo: 20_000_000),
            read.complete, let image = Self.image(from: read.data, side: side)
        else { return nil }
        cache.keep(image, for: key)
        return image
    }

    public static func image(from data: Data, side: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: side,
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    // NSCache is thread-safe, and evicts when memory runs short.
    private final class Cache: @unchecked Sendable {
        private let store = NSCache<NSString, CGImage>()

        func image(for key: String) -> CGImage? { store.object(forKey: key as NSString) }
        func keep(_ image: CGImage, for key: String) {
            store.setObject(image, forKey: key as NSString)
        }
    }
}
