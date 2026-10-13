import Foundation
import Observation
import Synchronization

/// Where the chosen language is kept, for app and share sheet alike.
public protocol LanguageStore: Sendable {
    func load() throws -> String?
    /// Nil forgets the choice: the language then follows the phone.
    func save(_ language: String?) throws
}

/// The choice in the Keychain group the share extension reads too. Not a
/// secret, but the only storage the two share.
public struct KeychainLanguageStore: LanguageStore {
    public static let shared = KeychainLanguageStore(accessGroup: KeychainItem.sharedGroup)

    private let item: KeychainItem

    public init(service: String = "app.hrcek.language", accessGroup: String?) {
        item = KeychainItem(service: service, accessGroup: accessGroup)
    }

    public func load() throws -> String? {
        try item.read().flatMap { String(bytes: $0, encoding: .utf8) }
    }

    public func save(_ language: String?) throws {
        if let language { try item.write(Data(language.utf8)) } else { try item.delete() }
    }
}

/// For tests and previews.
public final class InMemoryLanguageStore: LanguageStore {
    private let stored: Mutex<String?>

    public init(_ language: String? = nil) {
        stored = Mutex(language)
    }

    public func load() throws -> String? { stored.withLock { $0 } }
    public func save(_ language: String?) throws { stored.withLock { $0 = language } }
}

/// The language picker: Automatic, or one of the languages there are
/// translations for.
@MainActor
@Observable
public final class LanguageModel {
    public struct Option: Hashable, Sendable {
        /// Nil is Automatic.
        public let tag: String?
        public let name: String
    }

    /// The person's choice; nil follows the phone.
    public private(set) var choice: String?

    private let store: any LanguageStore
    private let preferred: [String]
    private let apply: @Sendable (String?) -> Void

    public init(
        store: any LanguageStore, preferred: [String] = Locale.preferredLanguages,
        apply: @escaping @Sendable (String?) -> Void = { L10n.choice = $0 }
    ) {
        self.store = store
        self.preferred = preferred
        self.apply = apply
        choice = try? store.load()
        apply(choice)
    }

    /// Remembers the choice for app and share sheet, and speaks it from now on.
    public func choose(_ tag: String?) {
        choice = tag
        do {
            try store.save(tag)
        } catch {
            Log.ui.error("Language not saved: \(String(describing: error), privacy: .public)")
        }
        apply(tag)
    }

    public var language: String { L10n.resolve(choice, preferred: preferred) }

    public var locale: Locale { Locale(identifier: language) }

    public var options: [Option] {
        // Automatic names the language it means, in the language in use.
        let automatic = L10n.resolve(nil, preferred: preferred)
        let meaning = locale.localizedString(forLanguageCode: automatic) ?? automatic
        let automaticName = L10n.string("Automatic (\(meaning))", language: language)
        // Each language in itself: the one name that works for somebody
        // who has landed in a language they cannot read.
        return [Option(tag: nil, name: automaticName)]
            + L10n.languages.map { tag in
                let own = Locale(identifier: tag)
                let name = own.localizedString(forLanguageCode: tag) ?? tag
                return Option(tag: tag, name: name.capitalized(with: own))
            }
    }
}
