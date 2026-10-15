import HrcekKit
import SwiftUI

/// Saves kept for later: the app's first screen while any wait.
struct PendingListView: View {
    @Environment(PendingModel.self) private var pending
    @Environment(SessionModel.self) private var session
    @Environment(\.locale) private var locale
    @State private var showingSettings = false
    @State private var deleting: PendingEntry?

    var body: some View {
        NavigationStack {
            Group {
                if pending.entries.isEmpty {
                    ContentUnavailableView {
                        Label {
                            Text("Nothing is waiting.").accessibilityIdentifier("nothingWaiting")
                        } icon: {
                            Image(systemName: "checkmark.circle").accessibilityHidden(true)
                        }
                    } description: {
                        // Often the sync that emptied the list, and what it could not do.
                        if let summary = pending.summary {
                            Text(verbatim: summary).accessibilityIdentifier("syncSummary")
                        }
                    }
                } else {
                    list
                }
            }
            .navigationTitle(locale.string("Waiting to sync"))
            .toolbar { toolbar }
            .sheet(isPresented: $showingSettings) { settings }
            .confirmationDialog(
                "Delete this page?", isPresented: deletingBinding, titleVisibility: .visible,
                presenting: deleting
            ) { entry in
                Button("Delete", role: .destructive) { pending.delete(entry) }
                    .accessibilityIdentifier("confirmDelete")
            } message: { _ in
                Text("It has not been saved to Hrček, and will be gone from this phone.")
            }
        }
        // Signing in from the settings is how waiting pages find their way.
        .onChange(of: session.credentials) { _, credentials in
            if credentials != nil { sync() }
        }
    }

    private var list: some View {
        List {
            syncSection
            Section {
                ForEach(pending.entries) { entry in
                    PendingRow(
                        entry: entry, picture: PendingQueue.shared.pictureData(of: entry),
                        elsewhere: pending.isForAnotherServer(entry, session.credentials)
                    )
                    .swipeActions {
                        Button("Delete", role: .destructive) { deleting = entry }
                            .accessibilityIdentifier("delete")
                    }
                }
            }
        }
    }

    private var syncSection: some View {
        Section {
            if session.credentials == nil {
                Button("Sign in to sync these.") { showingSettings = true }
                    .accessibilityIdentifier("signInToSync")
            } else {
                Button {
                    sync()
                } label: {
                    if pending.isSyncing { ProgressView() } else { Text("Sync now") }
                }
                .disabled(!pending.canSync(session.credentials))
                .accessibilityIdentifier("syncNow")
            }
            if let summary = pending.summary {
                Text(verbatim: summary).accessibilityIdentifier("syncSummary")
            }
        } footer: {
            Text("\(pending.count) pages waiting to sync")
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        if pending.entries.isEmpty {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { pending.dismiss() }.accessibilityIdentifier("done")
            }
        }
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showingSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .accessibilityIdentifier("settings")
        }
    }

    @ViewBuilder private var settings: some View {
        if let credentials = session.credentials {
            SignedInView(credentials: credentials) { showingSettings = false }
        } else {
            SignInView { showingSettings = false }
        }
    }

    private func sync() {
        BackgroundWork.start("Sync") { [pending, session] in
            let result = await pending.sync(session.credentials)
            // A refused token: refresh says so and signs out.
            if result?.stopped == .unauthorized { await session.refresh() }
        }
    }

    private var deletingBinding: Binding<Bool> {
        Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    }
}
