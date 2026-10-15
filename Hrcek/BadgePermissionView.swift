import HrcekKit
import SwiftUI

/// Why the app is about to ask, before iOS asks.
struct BadgePermissionView: View {
    @Environment(PendingModel.self) private var pending

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "app.badge").font(.system(size: 48)).accessibilityHidden(true)
            Text(
                """
                Hrček can show how many pages are waiting on its icon. \
                iOS asks whether to allow it.
                """
            )
            .multilineTextAlignment(.center)
            .accessibilityIdentifier("badgeExplanation")
            Button("Continue") { Task { await pending.askForBadge() } }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("badgeContinue")
            Button("Not now") { pending.declineBadgeForNow() }
                .accessibilityIdentifier("badgeNotNow")
        }
        .padding(32)
        .presentationDetents([.medium])
    }
}
