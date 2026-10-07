import Foundation

/// Signs in by trading the password for an API token. The password is
/// never stored; the token is.
public struct AuthService: Sendable {
    private let store: any CredentialStore
    private let deviceName: String
    private let session: URLSession
    private let language: String

    public init(
        store: any CredentialStore, deviceName: String, session: URLSession = .shared,
        language: String = APIClient.preferredLanguage
    ) {
        self.store = store
        self.deviceName = deviceName
        self.session = session
        self.language = language
    }

    public func current() -> Credentials? {
        do {
            return try store.load()
        } catch {
            Log.auth.error(
                "Could not read stored credentials: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    public func signIn(
        server: ServerAddress, email: String, password: String
    ) async throws -> Credentials {
        Log.auth.info("Signing in to \(server.host, privacy: .public)")
        // The token's name is how the person recognises this phone on the website.
        let name = String(localized: "Hrček for iOS (\(deviceName))", bundle: L10n.bundle)
        let exchange = TokenExchangeIn(
            name: name, identifier: email.trimmingCharacters(in: .whitespaces),
            password: password)
        let token = try await APIClient(server: server, language: language, session: session)
            .post("/api/auth/tokens/exchange", body: exchange, as: TokenOut.self).value.token
        let credentials = try await credentials(server: server, token: token)
        try store.save(credentials)
        Log.auth.info("Signed in")
        return credentials
    }

    /// Re-reads who the stored token belongs to. Throws the server's
    /// refusal, so callers can tell a revoked token from being offline.
    public func refresh() async throws -> Credentials? {
        guard let stored = current() else { return nil }
        let fresh = try await credentials(server: stored.server, token: stored.token)
        // The person may have signed out, or in again, while we waited.
        guard current()?.token == stored.token else { return current() }
        try store.save(fresh)
        return fresh
    }

    /// Forgets the token on this device. The API cannot revoke it; the
    /// person does that on the website.
    public func signOut() throws {
        try store.delete()
        Log.auth.info("Signed out")
    }

    private func credentials(server: ServerAddress, token: String) async throws -> Credentials {
        let user = try await APIClient(
            server: server, token: token, language: language, session: session
        )
        .get("/api/auth/me", as: UserOut.self).value
        return Credentials(
            server: server, token: token, displayName: user.displayName ?? user.email)
    }
}
