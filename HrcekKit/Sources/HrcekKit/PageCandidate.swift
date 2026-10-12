import Foundation

/// A picture a page offers, before ranking.
public struct PageCandidate: Equatable, Sendable {
    public let url: String
    /// Zero when unknown: a page's head names a picture without its size.
    public let width: Double
    public let height: Double
    /// Named in the page's head (og:image and the like) rather than shown in it.
    public let fromHead: Bool

    public init(url: String, width: Double, height: Double, fromHead: Bool) {
        self.url = url
        self.width = width
        self.height = height
        self.fromHead = fromHead
    }

    /// Below this either way it is furniture, not a picture.
    static let minimumSide = 100.0
    /// Enough to choose from.
    static let maximumCount = 60

    /// The head's pictures first, in the page's order, then its images
    /// largest first. A page that names its own picture has answered the
    /// question; size only orders the rest.
    public static func rank(_ candidates: [PageCandidate]) -> [URL] {
        var seen = Set<String>()
        var head: [URL] = []
        var body: [(url: URL, area: Double)] = []
        for candidate in candidates {
            guard let url = usable(candidate), seen.insert(url.absoluteString).inserted else {
                continue
            }
            if candidate.fromHead {
                head.append(url)
            } else {
                body.append((url, candidate.width * candidate.height))
            }
        }
        let largestFirst = body.enumerated()
            .sorted { ($0.element.area, -$0.offset) > ($1.element.area, -$1.offset) }
            .map(\.element.url)
        return Array((head + largestFirst).prefix(maximumCount))
    }

    private static func usable(_ candidate: PageCandidate) -> URL? {
        guard let url = URL(string: candidate.url),
            ["http", "https"].contains(url.scheme?.lowercased() ?? "")
        else { return nil }
        // The server refuses SVG outright: it is a document that can carry script.
        let path = url.path().lowercased()
        if path.hasSuffix(".svg") || path.hasSuffix(".svgz") { return nil }
        if !candidate.fromHead,
            candidate.width < minimumSide || candidate.height < minimumSide
        {
            return nil
        }
        return url
    }
}
