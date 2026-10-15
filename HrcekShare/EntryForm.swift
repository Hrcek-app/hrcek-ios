import HrcekKit
import SwiftUI

/// The entry as it will be saved: what the page offers, or what is
/// already saved for it.
struct EntryForm: View {
    @Bindable var model: ShareModel

    var body: some View {
        ScrollViewReader { proxy in
            form
                // Suggestions sit under the field, where the keyboard would hide them.
                .onChange(of: model.suggestions) { _, suggestions in
                    guard !suggestions.isEmpty else { return }
                    withAnimation { proxy.scrollTo(TagEditor.fieldID, anchor: .top) }
                }
        }
    }

    private var form: some View {
        Form {
            Section { heading }
            Section("Title") {
                TextField("Title", text: $model.draft.title, axis: .vertical)
                    .accessibilityIdentifier("title")
            }
            Section("Notes") {
                TextField("Notes", text: $model.draft.notes, axis: .vertical)
                    .lineLimit(3...10)
                    .accessibilityIdentifier("notes")
            }
            PictureSection(model: model)
            Section("Tags") {
                TagEditor(model: model)
            }
            FieldsSection(model: model)
            if let message = model.message {
                Section {
                    Text(message).foregroundStyle(.red).accessibilityIdentifier("message")
                }
            }
        }
        .disabled(model.phase == .saving)
    }

    /// The address, and where the entry stands.
    @ViewBuilder private var heading: some View {
        Text(model.draft.url)
            .font(.footnote).foregroundStyle(.secondary)
            .lineLimit(1).truncationMode(.middle)
            .accessibilityIdentifier("address")
        if model.isExisting {
            Label("Already saved", systemImage: "checkmark.circle")
                .accessibilityIdentifier("alreadySaved")
        }
        if model.isOffline {
            Label(
                "Hrček can't be reached. Saving keeps this entry on this phone until it can.",
                systemImage: "icloud.slash"
            )
            .accessibilityIdentifier("offlineNote")
        }
        if model.keptCopy != nil {
            Label("Waiting to be saved to Hrček.", systemImage: "clock")
                .accessibilityIdentifier("waitingNote")
        }
        if model.heldCopy != nil {
            Label(
                "You also have an unsynced copy of this page. Saving here replaces it.",
                systemImage: "doc.on.doc"
            )
            .accessibilityIdentifier("heldNote")
        }
    }
}
