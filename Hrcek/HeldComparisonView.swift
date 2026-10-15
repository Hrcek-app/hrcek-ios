import HrcekKit
import SwiftUI

/// Hrček's entry beside the person's kept copy, to choose between them.
struct HeldComparisonView: View {
    let entry: PendingEntry
    let credentials: Credentials
    @Environment(PendingModel.self) private var pending
    @Environment(\.dismiss) private var dismiss
    /// A second tap while Hrček is being written to would send it twice.
    @State private var replacing = false

    var body: some View {
        List {
            Section("Yours") {
                details(
                    title: entry.request.title, notes: entry.request.notes,
                    tags: entry.request.tags, fields: entry.request.fields ?? [:])
                if let data = PendingQueue.shared.pictureData(of: entry) {
                    KeptPicture(data: data, side: 120)
                }
            }
            Section("On Hrček") { theirs }
            Section { choices }
        }
        .navigationTitle(
            Text(verbatim: entry.request.title.isEmpty ? entry.url : entry.request.title)
        )
        .navigationBarTitleDisplayMode(.inline)
        .task { await pending.compare(entry, credentials: credentials) }
        .onDisappear { pending.endComparison() }
    }

    @ViewBuilder private var choices: some View {
        Button("Keep what's on Hrček") {
            pending.keep(entry)
            dismiss()
        }
        .disabled(!pending.canKeep || replacing)
        .accessibilityIdentifier("keepTheirs")
        Button {
            replace()
        } label: {
            if replacing {
                ProgressView()
            } else if pending.comparison == .gone {
                Text("Save mine")
            } else {
                Text("Replace with mine")
            }
        }
        .disabled(!pending.canReplace || replacing)
        .accessibilityIdentifier("replaceWithMine")
    }

    @ViewBuilder private var theirs: some View {
        switch pending.comparison {
        case .loading, nil:
            ProgressView()
        case .shown(let held, let picture):
            details(title: held.title, notes: held.notes, tags: held.tags, fields: held.fields)
            switch picture {
            case .shown(let data): KeptPicture(data: data, side: 120)
            case .unshowable: Text("It has a picture that cannot be shown here")
            case nil: EmptyView()
            }
        case .gone:
            Text("Hrček no longer has this page.").accessibilityIdentifier("gone")
        case .unavailable(let message):
            Text(verbatim: message).foregroundStyle(.red).accessibilityIdentifier("compareError")
        }
    }

    private func details(
        title: String, notes: String, tags: [String], fields: [String: String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: title).font(.headline)
            if !notes.isEmpty { Text(verbatim: notes) }
            if !tags.isEmpty { Text(verbatim: tags.joined(separator: ", ")).font(.caption) }
            ForEach(fields.sorted { $0.key < $1.key }, id: \.key) { name, value in
                LabeledContent {
                    Text(verbatim: value)
                } label: {
                    Text(verbatim: name)
                }
                .font(.caption)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// A write the person asked for: leaving the app must not cut it off.
    private func replace() {
        replacing = true
        BackgroundWork.start("Replace") { [pending, entry, credentials, dismiss] in
            // Saved, or refused and back on the list with Hrček's reason.
            let settled = await pending.replace(entry, credentials: credentials)
            replacing = false
            if settled { dismiss() }
        }
    }
}
