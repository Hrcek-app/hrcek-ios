import HrcekKit
import SwiftUI

/// How many pages wait, at the top of the settings.
struct PendingCountSection: View {
    @Environment(PendingModel.self) private var pending

    var body: some View {
        if !pending.entries.isEmpty {
            Section {
                Label {
                    Text("\(pending.count) pages waiting to sync")
                } icon: {
                    Image(systemName: "clock").accessibilityHidden(true)
                }
                // One element, read as its text alone.
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("pendingCount")
            }
        }
    }
}
