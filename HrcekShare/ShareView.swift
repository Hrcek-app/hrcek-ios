import SwiftUI

struct ShareView: View {
    let done: () -> Void

    var body: some View {
        NavigationStack {
            Text("Hrček")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", action: done).accessibilityIdentifier("done")
                    }
                }
        }
    }
}
