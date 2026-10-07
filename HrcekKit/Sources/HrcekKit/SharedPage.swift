import Foundation
import UniformTypeIdentifiers

/// The web page a person shared, as browsers hand it over.
public struct SharedPage: Equatable, Sendable {
    public let url: URL
    public let title: String?

    public init(url: URL, title: String?) {
        self.url = url
        self.title = title
    }

    @MainActor
    public static func from(_ items: [NSExtensionItem]) async -> SharedPage? {
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
