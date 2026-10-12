import Foundation
import Observation

/// The share sheet: looks the page up, lets the person edit it, saves it.
@MainActor
@Observable
public final class ShareModel {
    public enum Phase: Equatable, Sendable {
        case loading, editing, saving
        case saved(created: Bool)
        case signedOut, revoked
        case unavailable(String)
    }

    public private(set) var phase = Phase.loading
    public var draft = EntryDraft(url: "")
    /// A tag being typed, not yet added.
    public var tagText = ""
    /// Whether the address is already saved, so saving updates it.
    public private(set) var isExisting = false
    /// Why the last attempt failed, shown under the form.
    public private(set) var message: String?

    private let store: any CredentialStore
    private let makeService: @Sendable (Credentials) -> EntryService
    private var service: EntryService?
    /// The opening lookup failed for a reason other than "not saved", so
    /// the form may be about to replace an entry it never showed.
    private var mustLookAgain = false

    public init(
        store: any CredentialStore,
        makeService: @escaping @Sendable (Credentials) -> EntryService = {
            EntryService(credentials: $0)
        }
    ) {
        self.store = store
        self.makeService = makeService
    }

    public func start(_ page: SharedPage?) async {
        guard let page else {
            phase = .unavailable(
                String(localized: "There's no web address to save here.", bundle: L10n.bundle))
            return
        }
        guard let credentials = try? store.load() else {
            phase = .signedOut
            return
        }
        let service = makeService(credentials)
        self.service = service
        draft = EntryDraft(page: page)
        do {
            if let entry = try await service.lookup(draft.url) { show(entry) }
        } catch {
            guard !signOutIfRevoked(error) else { return }
            mustLookAgain = true
            report(error)
        }
        phase = .editing
    }

    /// Adds what was typed as tags, one per comma.
    public func commitTagText() {
        for tag in tagText.split(separator: ",") { draft.addTag(String(tag)) }
        tagText = ""
    }

    /// Answers whether the entry was saved.
    public func save() async -> Bool {
        guard let service, phase == .editing else { return false }
        // Somebody who typed a tag and tapped Save meant to keep it.
        commitTagText()
        phase = .saving
        message = nil
        defer { if phase == .saving { phase = .editing } }
        do {
            if mustLookAgain, let entry = try await service.lookup(draft.url) {
                mustLookAgain = false
                show(entry)
                message = String(
                    localized: "This page is already saved. Check what it holds, then save again.",
                    bundle: L10n.bundle)
                return false
            }
            mustLookAgain = false
            let (_, created) = try await service.save(draft.request())
            phase = .saved(created: created)
            return true
        } catch {
            if !signOutIfRevoked(error) { report(error) }
            return false
        }
    }

    private func show(_ entry: EntryOut) {
        draft = EntryDraft(entry: entry)
        isExisting = true
    }

    private func report(_ error: any Error) {
        Log.share.notice("Share failed: \(String(describing: error), privacy: .public)")
        message = UserFacingError.message(for: error)
    }

    private func signOutIfRevoked(_ error: any Error) -> Bool {
        guard (error as? APIError)?.code == "HRC-AUTH-0004" else { return false }
        try? store.delete()
        phase = .revoked
        return true
    }
}
