import Foundation

/// The pictures a page names in its head, read from the page itself. For
/// browsers that hand over only an address; Safari runs Preprocess.js.
public enum PagePictures {
    /// (attribute, value) pairs that name a picture, in order of preference.
    private static let names: [(String, String)] = [
        ("property", "og:image"), ("property", "og:image:secure_url"),
        ("name", "twitter:image"), ("name", "twitter:image:src"),
        ("rel", "image_src"), ("itemprop", "image"),
    ]

    /// Fetches the page and ranks what its head names. Answers nothing
    /// rather than failing: a page without pictures is not an error.
    public static func fetch(_ page: URL, session: URLSession = .shared) async -> [URL] {
        var request = URLRequest(url: page, timeoutInterval: 10)
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        do {
            // The head is near the top; the rest of a long page is not needed.
            let (head, _) = try await session.data(for: request, upTo: 1_000_000)
            // Not every page is UTF-8; Latin-1 reads any byte, enough for addresses.
            let html =
                String(bytes: head, encoding: .utf8) ?? String(bytes: head, encoding: .isoLatin1)
                ?? ""
            return PageCandidate.rank(candidates(inHTML: html, base: page))
        } catch {
            Log.share.notice("Page not read: \(Log.summary(of: error), privacy: .public)")
            return []
        }
    }

    static func candidates(inHTML html: String, base: URL) -> [PageCandidate] {
        let head = html.firstRange(of: "</head>").map { html[..<$0.lowerBound] } ?? html[...]
        // Regex is not Sendable, so it is made where it is used.
        let tag = /<(?:meta|link)\b[^>]*>/.ignoresCase()
        let tags = head.matches(of: tag).map { attributes(of: String($0.output)) }
        return names.flatMap { name, value in
            tags.compactMap { attributes -> PageCandidate? in
                // An empty address would resolve to the page itself.
                guard attributes[name]?.lowercased() == value,
                    let raw = attributes["content"] ?? attributes["href"], !raw.isEmpty,
                    let url = URL(string: raw, relativeTo: base)?.absoluteURL
                else { return nil }
                return PageCandidate(url: url.absoluteString, width: 0, height: 0, fromHead: true)
            }
        }
    }

    private static func attributes(of tag: String) -> [String: String] {
        var found: [String: String] = [:]
        let attribute = /([A-Za-z_:][-A-Za-z0-9_:.]*)\s*=\s*(?:"([^"]*)"|'([^']*)')/
        for match in tag.matches(of: attribute) {
            let value = match.output.2 ?? match.output.3 ?? ""
            found[match.output.1.lowercased()] = unescaped(String(value))
        }
        return found
    }

    private static func unescaped(_ text: String) -> String {
        [("&quot;", "\""), ("&#39;", "'"), ("&lt;", "<"), ("&gt;", ">"), ("&amp;", "&")]
            .reduce(text) { $0.replacingOccurrences(of: $1.0, with: $1.1) }
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
