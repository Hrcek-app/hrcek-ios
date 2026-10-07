import Foundation
import Observation

/// The share sheet: saves the shared page at once and reports how it went.
@MainActor
@Observable
public final class ShareModel {
    public enum State: Equatable, Sendable {
        case working, saved, alreadySaved, signedOut
        case failed(String)
    }

    public private(set) var state = State.working

    private let store: any CredentialStore
    private let makeSaver: @Sendable (Credentials) -> EntrySaver
    private var page: SharedPage?

    public init(
        store: any CredentialStore,
        makeSaver: @escaping @Sendable (Credentials) -> EntrySaver = {
            EntrySaver(credentials: $0)
        }
    ) {
        self.store = store
        self.makeSaver = makeSaver
    }

    public func save(_ page: SharedPage?) async {
        self.page = page
        await retry()
    }

    public func retry() async {
        guard let page else {
            state = .failed(
                String(localized: "There's no web address to save here.", bundle: L10n.bundle))
            return
        }
        guard let credentials = try? store.load() else {
            state = .signedOut
            return
        }
        state = .working
        do {
            let outcome = try await makeSaver(credentials).save(url: page.url, title: page.title)
            state = outcome == .saved ? .saved : .alreadySaved
        } catch let error as APIError where error.code == "HRC-AUTH-0004" {
            try? store.delete()
            state = .signedOut
        } catch {
            Log.share.notice("Save failed: \(String(describing: error), privacy: .public)")
            state = .failed(UserFacingError.message(for: error))
        }
    }
}
