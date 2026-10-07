import HrcekKit
import SwiftUI

struct SignInView: View {
    @Environment(SessionModel.self) private var session

    var body: some View {
        NavigationStack {
            Form {
                serverSection
                accountSection
                if let message = session.errorMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("error")
                    }
                }
                Section {
                    Button {
                        Task { await session.signIn() }
                    } label: {
                        if session.isWorking { ProgressView() } else { Text("Sign in") }
                    }
                    .disabled(!session.canSignIn)
                    .accessibilityIdentifier("signIn")
                }
            }
            .navigationTitle("Sign in to Hrček")
        }
    }

    private var serverSection: some View {
        @Bindable var session = session
        return Section {
            TextField(
                "Server address", text: $session.serverText,
                prompt: Text(verbatim: "hrcek.example.com")
            )
            .textContentType(.URL)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .accessibilityIdentifier("server")
        } header: {
            Text("Server address")
        } footer: {
            Text("The address you open Hrček at in your browser.")
        }
    }

    private var accountSection: some View {
        @Bindable var session = session
        return Section {
            TextField("Email", text: $session.email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("email")
            SecureField("Password", text: $session.password)
                .textContentType(.password)
                .accessibilityIdentifier("password")
        }
    }
}
