import HrcekKit
import SwiftUI
import UIKit

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
                if pending.badgeDenied {
                    Text(
                        """
                        The app icon can't show this count. \
                        Allow notifications for Hrček in Settings.
                        """
                    )
                    .font(.footnote)
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        Link("Open Settings", destination: url)
                            .accessibilityIdentifier("openSettings")
                    }
                }
            }
        }
    }
}
