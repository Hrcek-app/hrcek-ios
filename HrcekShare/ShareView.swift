import HrcekKit
import SwiftUI

struct ShareView: View {
    let model: ShareModel
    let done: () -> Void

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Hrček")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
        }
    }

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("loading")
        case .editing, .saving:
            EntryForm(model: model)
        case .saved(let created):
            notice {
                Label(created ? "Saved" : "Updated", systemImage: "checkmark.circle.fill")
                    .font(.title2).accessibilityIdentifier(created ? "saved" : "updated")
            }
        case .signedOut:
            notice {
                Text("Open the Hrček app and sign in first.").accessibilityIdentifier("signedOut")
            }
        case .revoked:
            notice {
                Text(
                    """
                    Hrček no longer accepts this phone's sign-in. \
                    Open the Hrček app and sign in again.
                    """
                )
                .accessibilityIdentifier("revoked")
            }
        case .unavailable(let message):
            notice { Text(message).accessibilityIdentifier("error") }
        }
    }

    // The sheet often opens at half height; centred content would sit off-screen.
    private func notice(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .multilineTextAlignment(.center)
            .padding(.top, 48)
            .padding(.horizontal)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        switch model.phase {
        case .editing, .saving:
            ToolbarItem(placement: .cancellationAction) {
                // Closing mid-save could cut off the work that follows the entry.
                Button("Cancel", action: done)
                    .disabled(model.phase == .saving)
                    .accessibilityIdentifier("cancel")
            }
            ToolbarItem(placement: .confirmationAction) { saveButton }
        default:
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", action: done).accessibilityIdentifier("done")
            }
        }
    }

    @ViewBuilder private var saveButton: some View {
        if model.phase == .saving {
            ProgressView().accessibilityIdentifier("saving")
        } else {
            Button(model.isExisting ? "Update" : "Save") {
                Task {
                    guard await model.save() else { return }
                    // Long enough to read the confirmation; Done closes sooner.
                    try? await Task.sleep(for: .seconds(2))
                    done()
                }
            }
            .accessibilityIdentifier("save")
        }
    }
}
