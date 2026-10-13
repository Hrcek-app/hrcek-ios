import Foundation
import Synchronization

/// HrcekKit's own translations, and the language the person chose for the
/// app and the share sheet alike. Strings here go through `L10n.string`.
public enum L10n {
    public static let bundle = Bundle.module

    /// The languages there are translations for, English first.
    public static let languages = ["en", "sl"]

    private static let chosen = Mutex<String?>(nil)

    /// The language the person chose; nil follows the phone.
    public static var choice: String? {
        get { chosen.withLock { $0 } }
        set { chosen.withLock { $0 = newValue } }
    }

    /// The language in use: for HrcekKit's strings, the views and the
    /// server's messages alike.
    public static var language: String { resolve(choice, preferred: Locale.preferredLanguages) }

    public static var locale: Locale { Locale(identifier: language) }

    /// The choice when there is a translation for it, else the phone's
    /// first language there is one for, else English.
    public static func resolve(_ choice: String?, preferred: [String]) -> String {
        if let choice, languages.contains(choice) { return choice }
        for tag in preferred {
            let code = Locale.Language(identifier: tag).languageCode?.identifier
            if let code, languages.contains(code) { return code }
        }
        return languages[0]
    }

    /// A string of HrcekKit's, in `language` or the language in use.
    public static func string(_ resource: LocalizedStringResource, language: String? = nil)
        -> String
    {
        // The bundle a literal names is the app's; these strings are HrcekKit's.
        let localized = LocalizedStringResource(
            resource.defaultValue, table: resource.table,
            locale: Locale(identifier: language ?? self.language),
            bundle: .atURL(bundle.bundleURL))
        return String(localized: localized)
    }

    /// One language's translations, for tests that check a specific language.
    public static func bundle(for language: String) -> Bundle? {
        if let path = bundle.path(forResource: language, ofType: "lproj") {
            return Bundle(path: path)
        }
        // English is the source text itself, so it has no .lproj of its own.
        return language == bundle.developmentLocalization ? bundle : nil
    }
}

extension Locale {
    /// The calling bundle's string in this locale. For text UIKit draws
    /// itself, such as navigation titles, which ignores SwiftUI's locale.
    public func string(_ resource: LocalizedStringResource) -> String {
        var resource = resource
        resource.locale = self
        return String(localized: resource)
    }
}
