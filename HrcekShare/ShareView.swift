import HrcekKit
import SwiftUI

struct ShareView: View {
    let model: ShareModel
    let done: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                content
            }
            // The sheet often opens at half height; centred content would sit off-screen.
            .padding(.top, 48)
            .padding(.horizontal)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("Hrček")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: done).accessibilityIdentifier("done")
                }
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .working:
            ProgressView("Saving…").accessibilityIdentifier("saving")
        case .saved:
            Label("Saved", systemImage: "checkmark.circle.fill")
                .font(.title2).accessibilityIdentifier("saved")
        case .alreadySaved:
            Label("Already saved", systemImage: "checkmark.circle")
                .font(.title2).accessibilityIdentifier("alreadySaved")
        case .signedOut:
            Text("Open the Hrček app and sign in first.")
                .multilineTextAlignment(.center).accessibilityIdentifier("signedOut")
        case .failed(let message):
            Text(message).multilineTextAlignment(.center).accessibilityIdentifier("error")
            Button("Try again") { Task { await model.retry() } }
                .buttonStyle(.borderedProminent).accessibilityIdentifier("retry")
        }
    }
}
