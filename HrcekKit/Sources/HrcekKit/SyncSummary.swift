import Foundation

extension SyncResult {
    /// One line on what a sync did, in the language in use. Nil when
    /// there is nothing to say.
    public var summary: String? { summary(language: nil) }

    func summary(language: String?) -> String? {
        let parts = counts(language: language) + [stopLine(language: language)].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private func counts(language: String?) -> [String] {
        var parts: [String] = []
        if saved > 0 { parts.append(L10n.string("\(saved) entries saved.", language: language)) }
        if held > 0 {
            parts.append(
                L10n.string(
                    "\(held) already on Hrček; choose which to keep.", language: language))
        }
        if refused > 0 {
            parts.append(L10n.string("Hrček refused \(refused) entries.", language: language))
        }
        for title in withoutPicture {
            parts.append(L10n.string("Saved without its picture: \(title)", language: language))
        }
        return parts
    }

    private func stopLine(language: String?) -> String? {
        switch stopped {
        case .unavailable: L10n.string("Hrček can't be reached.", language: language)
        case .unauthorized:
            L10n.string("Hrček no longer accepts this phone's sign-in.", language: language)
        case .failed: L10n.string("Hrček couldn't be asked. Try again later.", language: language)
        case .interrupted:
            L10n.string("Not finished. The rest will be sent later.", language: language)
        case .busy, nil: nil
        }
    }
}
