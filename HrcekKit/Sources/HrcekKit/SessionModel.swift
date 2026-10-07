import Foundation
import Observation

/// The app's sign-in state and the sign-in form.
@MainActor
@Observable
public final class SessionModel {
    public private(set) var credentials: Credentials?
    public var serverText = ""
    public var email = ""
    public var password = ""
    public private(set) var isWorking = false
    public private(set) var errorMessage: String?

    private let auth: AuthService

    public init(auth: AuthService) {
        self.auth = auth
        credentials = auth.current()
    }

    public var canSignIn: Bool {
        !isWorking
            && ![serverText, email, password].contains {
                $0.trimmingCharacters(in: .whitespaces).isEmpty
            }
    }

    public func signIn() async {
        guard canSignIn else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let server = try ServerAddress(serverText)
            credentials = try await auth.signIn(server: server, email: email, password: password)
            password = ""
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
            errorMessage = String(
                localized: "Your sign-in has expired or was revoked. Sign in again.",
                bundle: L10n.bundle)
        } catch {
            // Offline or a server hiccup: the token may still be good.
            Log.ui.notice("Refresh failed: \(String(describing: error), privacy: .public)")
        }
    }
}
