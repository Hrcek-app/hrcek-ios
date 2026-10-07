import SwiftUI

struct RootView: View {
    var body: some View {
        NavigationStack {
            Text("Save pages to Hrček with your browser's Share button.")
                .multilineTextAlignment(.center)
                .padding()
                .accessibilityIdentifier("introduction")
                .navigationTitle("Hrček")
        }
    }
}
