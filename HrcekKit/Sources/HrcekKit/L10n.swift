import Foundation

/// HrcekKit's own translations. Strings here use `bundle: L10n.bundle`.
public enum L10n {
    public static let bundle = Bundle.module

    /// One language's translations, for tests that check a specific language.
    public static func bundle(for language: String) -> Bundle? {
        if let path = bundle.path(forResource: language, ofType: "lproj") {
            return Bundle(path: path)
        }
        // English is the source text itself, so it has no .lproj of its own.
        return language == bundle.developmentLocalization ? bundle : nil
    }
}
