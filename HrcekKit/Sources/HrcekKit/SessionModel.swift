import Foundation
import Observation

/// The app's sign-in state and the sign-in form.
@MainActor
@Observable
public final class SessionModel {
    /// How the person proves who they are.
    public enum Method: Hashable, Sendable {
        /// Traded once for a token, then forgotten.
        case password
        /// Made on the website and pasted here.
        case token
    }

    public private(set) var credentials: Credentials?
    public var method = Method.password
    public var serverText = ""
    public var email = ""
    public var password = ""
    public var token = ""
    public private(set) var isWorking = false
    public private(set) var errorMessage: String?

    private let auth: AuthService

    public init(auth: AuthService) {
        self.auth = auth
        credentials = auth.current()
    }

    public var canSignIn: Bool {
        let needed = method == .password ? [serverText, email, password] : [serverText, token]
        return !isWorking
            && !needed.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    public func signIn() async {
        guard canSignIn else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let server = try ServerAddress(serverText)
            switch method {
            case .password:
                credentials = try await auth.signIn(
                    server: server, email: email, password: password)
            case .token:
                credentials = try await auth.signIn(server: server, token: token)
            }
            password = ""
            token = ""
        } catch {
            Log.ui.notice("Sign-in failed: \(String(describing: error), privacy: .public)")
            errorMessage = UserFacingError.message(for: error)
        }
    }

    public func signOut() {
        do {
            try auth.signOut()
        } catch {
            Log.ui.error("Sign-out failed: \(String(describing: error), privacy: .public)")
        }
        credentials = nil
    }

    /// Checks the stored token still works; a revoked one signs the person out.
    public func refresh() async {
        guard credentials != nil else { return }
        do {
            credentials = try await auth.refresh()
        } catch let error as APIError where error.code == "HRC-AUTH-0004" {
            signOut()
            errorMessage = L10n.string("Your sign-in has expired or was revoked. Sign in again.")
        } catch {
            // Offline or a server hiccup: the token may still be good.
            Log.ui.notice("Refresh failed: \(String(describing: error), privacy: .public)")
        }
    }
}
