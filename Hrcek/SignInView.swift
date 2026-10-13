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
            Picker("Sign in with", selection: $session.method) {
                Text("Password").tag(SessionModel.Method.password)
                Text("API token").tag(SessionModel.Method.token)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("method")
            switch session.method {
            case .password:
                TextField("Email or display name", text: $session.email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("email")
                SecureField("Password", text: $session.password)
                    .textContentType(.password)
                    .accessibilityIdentifier("password")
            case .token:
                SecureField("API token", text: $session.token)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("token")
            }
        } footer: {
            switch session.method {
            case .password:
                Text("Your password is used once to make a token for this phone, and never kept.")
            case .token:
                Text("Make one on the website, on your account's clients page, and paste it here.")
            }
        }
    }
}
