import Foundation
import UniformTypeIdentifiers

/// The web page a person shared, as browsers hand it over.
public struct SharedPage: Equatable, Sendable {
    public let url: URL
    public let title: String?
    /// The pictures the page offers, best first; nil when the browser
    /// handed over only the address and the page has not been read.
    public let pictures: [URL]?

    public init(url: URL, title: String?, pictures: [URL]? = nil) {
        self.url = url
        self.title = title
        self.pictures = pictures
    }

    @MainActor
    public static func from(_ items: [NSExtensionItem]) async -> SharedPage? {
        // Safari runs Preprocess.js and hands over only what it found.
        for provider in items.flatMap({ $0.attachments ?? [] })
        where provider.hasItemConformingToTypeIdentifier(UTType.propertyList.identifier) {
            if let page = await preprocessed(from: provider) { return page }
        }
        for item in items {
            let title = item.attributedTitle?.string ?? item.attributedContentText?.string
            for provider in item.attachments ?? [] {
                guard let url = await webURL(from: provider) else { continue }
                let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines)
                let useful = trimmed.flatMap { $0.isEmpty || $0 == url.absoluteString ? nil : $0 }
                return SharedPage(url: url, title: useful)
            }
        }
        return nil
    }

    @MainActor
    private static func preprocessed(from provider: NSItemProvider) async -> SharedPage? {
        let list = await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.propertyList.identifier) { item, _ in
                let results = (item as? NSDictionary)?[NSExtensionJavaScriptPreprocessingResultsKey]
                continuation.resume(returning: Preprocessed(results as? NSDictionary))
            }
        }
        return list.page
    }

    /// Preprocess.js's answer: the page's address, title and pictures.
    private struct Preprocessed: @unchecked Sendable {
        let results: NSDictionary?

        init(_ results: NSDictionary?) { self.results = results }

        var page: SharedPage? {
            guard let address = results?["url"] as? String, let url = URL(string: address),
                isWeb(url)
            else { return nil }
            let title = (results?["title"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let raw = (results?["pictures"] as? [[String: Any]] ?? []).compactMap(candidate)
            return SharedPage(
                url: url, title: title?.isEmpty == false ? title : nil,
                pictures: PageCandidate.rank(raw))
        }

        private func candidate(_ raw: [String: Any]) -> PageCandidate? {
            guard let url = raw["url"] as? String else { return nil }
            return PageCandidate(
                url: url, width: (raw["width"] as? NSNumber)?.doubleValue ?? 0,
                height: (raw["height"] as? NSNumber)?.doubleValue ?? 0,
                fromHead: raw["fromHead"] as? Bool ?? false)
        }
    }

    // Some browsers share the address as text rather than as a URL item.
    @MainActor
    private static func webURL(from provider: NSItemProvider) async -> URL? {
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
            let url = await loadURL(from: provider), isWeb(url)
        {
            return url
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
            let text = await loadText(from: provider)
        {
            return firstWebURL(in: text)
        }
        return nil
    }

    @MainActor
    private static func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                continuation.resume(returning: url)
            }
        }
    }

    @MainActor
    private static func loadText(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: String.self) { text, _ in
                continuation.resume(returning: text)
            }
        }
    }

    private static func firstWebURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        return detector?.matches(in: text, range: range).compactMap(\.url).first(where: isWeb)
    }

    private static func isWeb(_ url: URL) -> Bool {
        ["http", "https"].contains(url.scheme?.lowercased() ?? "")
    }
}
