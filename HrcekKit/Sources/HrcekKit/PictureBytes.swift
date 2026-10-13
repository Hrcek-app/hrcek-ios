import Foundation

/// A picture's bytes, read from where the page has it.
public struct PictureBytes: Equatable, Sendable {
    public let data: Data
    public let type: String
    public let filename: String

    public init(data: Data, type: String, filename: String) {
        self.data = data
        self.type = type
        self.filename = filename
    }

    /// The server's limit.
    static let maximumSize = 10 * 1024 * 1024

    /// Reading the bytes here is preferred to giving the server the
    /// address: it will not fetch from private hosts, and a signed or
    /// referer-checked address will not answer it. Nil means "give the
    /// address instead", never a failure.
    public static func fetch(_ url: URL, session: URLSession = cookieless) async -> PictureBytes? {
        do {
            let read = try await session.data(for: URLRequest(url: url), upTo: maximumSize)
            guard read.complete, !read.data.isEmpty,
                let type = read.response.mimeType, type.hasPrefix("image/"),
                // Refused outright by the server; not worth an upload.
                !type.contains("svg")
            else { return nil }
            return PictureBytes(
                data: read.data, type: type, filename: filename(for: url.lastPathComponent))
        } catch {
            Log.share.notice("Picture not read: \(Log.summary(of: error), privacy: .public)")
            return nil
        }
    }

    /// A name safe in a multipart header: the address's last part is the
    /// page's to choose, and can carry line breaks and quotes.
    static func filename(for name: String) -> String {
        let unsafe = CharacterSet.controlCharacters.union(CharacterSet(charactersIn: "\"\\;/"))
        let safe = String(
            String.UnicodeScalarView(name.unicodeScalars.filter { !unsafe.contains($0) }))
        return safe.isEmpty ? "picture" : String(safe.prefix(100))
    }

    /// Reading a picture is not worth handing another site a cookie.
    public static let cookieless = URLSession(configuration: .ephemeral)
}

/// What the share sheet reads from the web rather than from Hrček.
public struct PageAccess: Sendable {
    public var pictures: @Sendable (URL) async -> [URL]
    public var bytes: @Sendable (URL) async -> PictureBytes?

    public init(
        pictures: @escaping @Sendable (URL) async -> [URL],
        bytes: @escaping @Sendable (URL) async -> PictureBytes?
    ) {
        self.pictures = pictures
        self.bytes = bytes
    }

    public static let live = PageAccess(
        pictures: { await PagePictures.fetch($0) }, bytes: { await PictureBytes.fetch($0) })
}
