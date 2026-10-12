import HrcekKit
import SwiftUI

/// The entry as it will be saved: what the page offers, or what is
/// already saved for it.
struct EntryForm: View {
    @Bindable var model: ShareModel

    var body: some View {
        Form {
            Section {
                Text(model.draft.url)
                    .font(.footnote).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
                    .accessibilityIdentifier("address")
                if model.isExisting {
                    Label("Already saved", systemImage: "checkmark.circle")
                        .accessibilityIdentifier("alreadySaved")
                }
            }
            Section("Title") {
                TextField("Title", text: $model.draft.title, axis: .vertical)
                    .accessibilityIdentifier("title")
            }
            Section("Notes") {
                TextField("Notes", text: $model.draft.notes, axis: .vertical)
                    .lineLimit(3...10)
                    .accessibilityIdentifier("notes")
            }
            Section("Tags") {
                TagEditor(model: model)
            }
            if let message = model.message {
                Section {
                    Text(message).foregroundStyle(.red).accessibilityIdentifier("message")
                }
            }
        }
        .disabled(model.phase == .saving)
    }
}
