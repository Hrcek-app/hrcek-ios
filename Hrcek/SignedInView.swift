import HrcekKit
import SwiftUI

struct SignedInView: View {
    let credentials: Credentials
    @Environment(SessionModel.self) private var session
    @State private var confirmingSignOut = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Signed in as \(credentials.displayName) on \(credentials.server.host)")
                        .accessibilityIdentifier("signedInAs")
                }
                Section("How to save a page") {
                    Label("Open the page in Safari or another browser.", systemImage: "safari")
                    Label("Tap the Share button.", systemImage: "square.and.arrow.up")
                    Label(
                        "Choose Hrček. If it isn't in the row, tap More and add it.",
                        systemImage: "plus.circle")
                }
                signOutSection
            }
            .navigationTitle("Hrček")
        }
    }

    private var signOutSection: some View {
        Section {
            Button("Sign out", role: .destructive) { confirmingSignOut = true }
                .accessibilityIdentifier("signOut")
                .confirmationDialog(
                    "Sign out?", isPresented: $confirmingSignOut, titleVisibility: .visible
                ) {
                    Button("Sign out", role: .destructive) { session.signOut() }
                        .accessibilityIdentifier("confirmSignOut")
                } message: {
                    Text(
                        """
                        This phone forgets your sign-in. Its access token keeps working \
                        until you remove it on the website's clients page.
                        """)
                }
        } footer: {
            Link(
                "Manage this phone's access on the website",
                destination: credentials.server.endpoint("/accounts/me/clients/"))
        }
    }
}
