import Foundation
import Observation

/// The share sheet: looks the page up, lets the person edit it, saves it.
@MainActor
@Observable
public final class ShareModel {
    public enum Phase: Equatable, Sendable {
        case loading, editing, saving
        case saved(created: Bool)
        /// Kept on the phone, to be sent once Hrček can be reached.
        case kept
        case signedOut, revoked
        case unavailable(String)
    }

    public private(set) var phase = Phase.loading
    public var draft = EntryDraft(url: "")
    /// A tag being typed, not yet added.
    public var tagText = ""
    /// The account's labels that fit what is being typed.
    public internal(set) var suggestions: [String] = []
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
    /// The opening lookup found Hrček unreachable: saving keeps the entry.
    public private(set) var isOffline = false
    /// The kept copy the form shows, waiting or refused.
    public private(set) var keptCopy: PendingEntry?
    /// A copy held for review at this address; saving here replaces it.
    public private(set) var heldCopy: PendingEntry?
    /// How many kept entries are being sent after a save; nil when none are.
    public private(set) var syncingCount: Int?
    /// What sending them did, in one line.
    public private(set) var syncSummary: String?

    private let store: any CredentialStore
    private let queue: PendingQueue
    private let pages: PageAccess
    private let makeService: @Sendable (Credentials) -> EntryService
    private(set) var service: EntryService?
    private var credentials: Credentials?
    private var definitions: [FieldOut]?
    private var offered: [URL] = []
    /// The opening lookup failed for a reason other than "not saved", so
    /// the form may be about to replace an entry it never showed.
    private var mustLookAgain = false

    public init(
        store: any CredentialStore, queue: PendingQueue, pages: PageAccess = .live,
        makeService: @escaping @Sendable (Credentials) -> EntryService = {
            EntryService(credentials: $0)
        }
    ) {
        self.store = store
        self.queue = queue
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
        self.credentials = credentials
        let copy = queue.get(page.url.absoluteString)
            .flatMap { $0.server == credentials.server ? $0 : nil }
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
        guard await showFound(found) else { return }
        if let copy { open(copy) }
        phase = .editing
        // Reading the page can be slow; the form need not wait for it.
        if page.pictures == nil { await readPictures(of: page.url) }
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
            if try await foundOnSecondLook(service) { return false }
            mustLookAgain = false
            let request = draft.request().with(imageUrl: nil)
            let (picture, data) = await PendingEntry.Picture.chosen(
                pictures.choice, kept: keptCopy, queue: queue, pages: pages)
            guard let credentials else { return false }
            let entry = PendingEntry(request: request, picture: picture, server: credentials.server)
            if isOffline { return keep(entry, picture: data) }
            return try await send(entry, picture: data, service: service)
        } catch {
            if !signOutIfRevoked(error) { report(error) }
            return false
        }
    }

    /// When the opening lookup failed, looks again, so the form never
    /// replaces an entry it did not show. True when it found one.
    private func foundOnSecondLook(_ service: EntryService) async throws -> Bool {
        guard !isOffline, mustLookAgain else { return false }
        let entry: EntryOut?
        do {
            entry = try await service.lookup(draft.url)
        } catch let error as APIError where error.isUnavailable {
            // Kept like any save that finds Hrček down; its sync looks first.
            isOffline = true
            return false
        }
        guard let entry else { return false }
        mustLookAgain = false
        await show(entry)
        message = L10n.string("This page is already saved. Check what it holds, then save again.")
        return true
    }

    /// Sends the entry, or keeps it when Hrček turns out to be down.
    private func send(
        _ entry: PendingEntry, picture data: Data?, service: EntryService
    ) async throws -> Bool {
        do {
            let (created, trouble) = try await PendingSync.send(
                entry, picture: data, service: service)
            // Only the copy shown: a newer one may have been kept meanwhile.
            if let shown = keptCopy ?? heldCopy { try? queue.remove(shown.url, id: shown.id) }
            pictureTrouble = trouble
            phase = .saved(created: created)
            return true
        } catch let error as APIError where error.isUnavailable {
            return keep(entry, picture: data)
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

    /// Shows what the opening lookup found. False when it signed out.
    private func showFound(_ found: Result<EntryOut?, any Error>) async -> Bool {
        do {
            if let entry = try found.get() { await show(entry) }
        } catch let error as APIError where error.isUnavailable {
            // Kept for later instead; the form says so.
            isOffline = true
        } catch {
            guard !signOutIfRevoked(error) else { return false }
            mustLookAgain = true
            report(error)
        }
        return true
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

// Copies kept on the phone.
extension ShareModel {
    /// Sends what else is waiting, so a save is also when kept ones go.
    /// Gives up after `limit`, leaving the rest for next time.
    public func syncWaiting(within limit: Duration = .seconds(10)) async {
        guard let service, let credentials else { return }
        let waiting = queue.list().filter {
            $0.server == credentials.server && $0.state == .waiting
        }
        guard !waiting.isEmpty else { return }
        syncingCount = waiting.count
        defer { syncingCount = nil }
        let result = await PendingSync.run(
            queue: queue, service: service, server: credentials.server, within: limit)
        syncSummary = result.summary
    }

    private func keep(_ entry: PendingEntry, picture: Data?) -> Bool {
        do {
            try queue.put(entry, picture: picture)
            phase = .kept
            Log.share.info("Kept for later")
            return true
        } catch PendingQueue.Failure.full {
            message = L10n.string(
                "100 entries are already waiting to be saved. Sync or delete some first.")
        } catch {
            report(error)
        }
        return false
    }

    /// A held copy is only mentioned: the form shows Hrček's entry. So is
    /// any copy when Hrček holds an entry at its address: its sync would
    /// hold it, and the sheet must not guess either. Otherwise the copy is
    /// what the form shows, a held one too when Hrček's entry cannot be
    /// had: the form would otherwise drop the person's edits. Kept again it
    /// waits, and its sync looks first.
    private func open(_ copy: PendingEntry) {
        guard !isExisting, copy.state != .held || isOffline else {
            heldCopy = copy
            return
        }
        keptCopy = copy
        draft = EntryDraft(request: copy.request, definitions: definitions)
        pictures = PictureState(
            kept: copy.picture, data: queue.pictureData(of: copy), offered: offered)
        if case .refused(let message) = copy.state { self.message = message }
    }
}
