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
    /// The account's labels that fit what is being typed.
    public private(set) var suggestions: [String] = []
    /// How long typing must pause before labels are asked for, so a word
    /// typed costs one request rather than one per letter.
    public var suggestionDelay = Duration.milliseconds(200)
    /// Whether the address is already saved, so saving updates it.
    public private(set) var isExisting = false
    /// Whether a picture is saved with the entry, and which.
    public var pictures = PictureState.none
    /// Why the picture was not saved with an entry that was.
    public private(set) var pictureTrouble: String?
    /// The account's fields could not be read; the form shows the entry's
    /// own instead, so saving changes none of the others.
    public private(set) var fieldsUnavailable = false
    /// Why the last attempt failed, shown under the form.
    public private(set) var message: String?

    private let store: any CredentialStore
    private let pages: PageAccess
    private let makeService: @Sendable (Credentials) -> EntryService
    private var service: EntryService?
    private var definitions: [FieldOut]?
    private var offered: [URL] = []
    /// The opening lookup failed for a reason other than "not saved", so
    /// the form may be about to replace an entry it never showed.
    private var mustLookAgain = false

    public init(
        store: any CredentialStore, pages: PageAccess = .live,
        makeService: @escaping @Sendable (Credentials) -> EntryService = {
            EntryService(credentials: $0)
        }
    ) {
        self.store = store
        self.pages = pages
        self.makeService = makeService
    }

    public func start(_ page: SharedPage?) async {
        guard let page else {
            phase = .unavailable(
                L10n.string("There's no web address to save here."))
            return
        }
        guard let credentials = try? store.load() else {
            phase = .signedOut
            return
        }
        let service = makeService(credentials)
        self.service = service
        async let definitions = Self.definitions(from: service)
        let found: Result<EntryOut?, any Error>
        do {
            found = .success(try await service.lookup(page.url.absoluteString))
        } catch {
            found = .failure(error)
        }
        self.definitions = await definitions
        offered = page.pictures ?? []
        fieldsUnavailable = self.definitions == nil
        draft = EntryDraft(page: page, definitions: self.definitions)
        pictures = PictureState(candidates: offered, held: nil, existing: false)
        do {
            if let entry = try found.get() { await show(entry) }
        } catch {
            guard !signOutIfRevoked(error) else { return }
            mustLookAgain = true
            report(error)
        }
        phase = .editing
        // Reading the page can be slow; the form need not wait for it.
        if page.pictures == nil { await readPictures(of: page.url) }
    }

    /// Adds what was typed as tags, one per comma.
    public func commitTagText() {
        for tag in tagText.split(separator: ",") { draft.addTag(String(tag)) }
        tagText = ""
        suggestions = []
    }

    public func choose(_ suggestion: String) {
        draft.addTag(suggestion)
        tagText = ""
        suggestions = []
    }

    /// Call whenever `tagText` changes; cancelling the call drops it.
    public func updateSuggestions() async {
        let prefix = tagText.trimmingCharacters(in: .whitespaces)
        guard let service, !prefix.isEmpty else {
            suggestions = []
            return
        }
        do {
            try await Task.sleep(for: suggestionDelay)
            let labels = try await service.labels(startingWith: prefix)
            // The person may have typed on, or added the tag, while it was asked.
            guard !Task.isCancelled, tagText.trimmingCharacters(in: .whitespaces) == prefix
            else { return }
            // Offering a tag already there would only invite a duplicate.
            let fresh = labels.filter { label in
                !draft.tags.contains { EntryDraft.same($0, label) }
            }
            suggestions = Array(fresh.prefix(8))
        } catch is CancellationError {
            return
        } catch {
            // Typing on cancels the request, which then fails as a transport error.
            if Task.isCancelled { return }
            // A convenience whose absence explains itself; not worth an error.
            Log.share.notice("No suggestions: \(String(describing: error), privacy: .public)")
            suggestions = []
        }
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
                await show(entry)
                message = L10n.string(
                    "This page is already saved. Check what it holds, then save again.")
                return false
            }
            mustLookAgain = false
            let saver = PictureSaver(service: service, pages: pages)
            let (created, trouble) = try await saver.save(draft.request(), choice: pictures.choice)
            pictureTrouble = trouble
            phase = .saved(created: created)
            return true
        } catch {
            if !signOutIfRevoked(error) { report(error) }
            return false
        }
    }

    private func readPictures(of page: URL) async {
        let found = await pages.pictures(page)
        offered = found
        pictures.offer(found)
    }

    private static func definitions(from service: EntryService) async -> [FieldOut]? {
        do {
            return try await service.fields()
        } catch {
            Log.share.notice("No fields: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    private func show(_ entry: EntryOut) async {
        let held = await heldPicture(entry)
        draft = EntryDraft(entry: entry, definitions: definitions)
        pictures = PictureState(candidates: offered, held: held, existing: true)
        isExisting = true
    }

    private func heldPicture(_ entry: EntryOut) async -> HeldPicture? {
        guard let image = entry.image else { return nil }
        guard let data = try? await service?.picture(image) else { return .unshowable }
        return .shown(data)
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
