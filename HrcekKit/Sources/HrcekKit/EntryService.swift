import Foundation

/// Reads and writes the person's entries.
public struct EntryService: Sendable {
    private let client: APIClient

    public init(
        credentials: Credentials, language: String = APIClient.preferredLanguage,
        session: URLSession = .shared
    ) {
        client = APIClient(
            server: credentials.server, token: credentials.token, language: language,
            session: session)
    }

    /// The entry held at an address, or nil when there is none. Saving
    /// replaces, so the form must show what it would replace.
    public func lookup(_ url: String) async throws -> EntryOut? {
        do {
            return try await client.post(
                "/api/entries/lookup", body: LookupIn(url: url), as: EntryOut.self
            ).value
        } catch let error as APIError where error.code == "HRC-CORE-0003" {
            return nil
        }
    }

    public func save(_ entry: EntryIn) async throws -> (entry: EntryOut, created: Bool) {
        let response = try await client.post("/api/entries/", body: entry, as: EntryOut.self)
        Log.share.info("Saved, status \(response.status)")
        return (response.value, response.status == 201)
    }
}
