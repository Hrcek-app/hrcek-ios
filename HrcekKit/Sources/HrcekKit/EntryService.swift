import Foundation

/// Reads and writes the person's entries, and reads what their account
/// defines for them.
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

    /// The fields this account's entries may carry.
    public func fields() async throws -> [FieldOut] {
        try await client.get("/api/fields/", as: Page<FieldOut>.self).value.items
    }

    /// The account's labels starting with `prefix`, alphabetically.
    public func labels(startingWith prefix: String) async throws -> [String] {
        let query = [URLQueryItem(name: "starts_with", value: prefix)]
        return try await client.get("/api/labels/", query: query, as: Page<LabelOut>.self)
            .value.items.map(\.name)
    }

    /// The bytes of the picture an entry holds, or nil when they are not
    /// a picture: the server answers a sign-in page to a token it will not
    /// take for this address.
    public func picture(_ image: ImageOut) async throws -> Data? {
        let (data, type) = try await client.data(image.url, accept: "image/*, application/json")
        return type?.hasPrefix("image/") == true ? data : nil
    }

    /// Replaces the entry's picture with these bytes.
    public func upload(_ picture: PictureBytes, to entry: Int) async throws {
        _ = try await client.upload(
            "/api/entries/\(entry)/image", file: picture.data, filename: picture.filename,
            type: picture.type, as: EntryOut.self)
    }

    /// Posting an entry cannot remove its picture; this can.
    public func removePicture(from entry: Int) async throws {
        try await client.delete("/api/entries/\(entry)/image")
    }

    public func save(_ entry: EntryIn) async throws -> (entry: EntryOut, created: Bool) {
        let response = try await client.post("/api/entries/", body: entry, as: EntryOut.self)
        Log.share.info("Saved, status \(response.status)")
        return (response.value, response.status == 201)
    }
}
