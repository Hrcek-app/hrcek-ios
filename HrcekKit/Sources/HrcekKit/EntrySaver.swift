import Foundation

public enum SaveOutcome: Equatable, Sendable {
    case saved, alreadySaved
}

/// Saves a shared page without ever overwriting one already saved: the
/// API replaces an entry wholesale, which would wipe its notes and tags.
public struct EntrySaver: Sendable {
    private let client: APIClient

    public init(
        credentials: Credentials, language: String = APIClient.preferredLanguage,
        session: URLSession = .shared
    ) {
        client = APIClient(
            server: credentials.server, token: credentials.token, language: language,
            session: session)
    }

    public func save(url: URL, title: String?) async throws -> SaveOutcome {
        let address = url.absoluteString
        do {
            _ = try await client.post(
                "/api/entries/lookup", body: LookupIn(url: address), as: EntryOut.self)
            Log.share.info("Already saved")
            return .alreadySaved
        } catch let error as APIError where error.code == "HRC-CORE-0003" {
            // Not saved yet: carry on.
        }
        _ = try await client.post(
            "/api/entries/", body: EntryIn(url: address, title: title ?? ""), as: EntryOut.self)
        Log.share.info("Saved")
        return .saved
    }
}
