import HrcekKit
import SwiftUI

struct RootView: View {
    @Environment(SessionModel.self) private var session
    @Environment(PendingModel.self) private var pending
    @Environment(\.scenePhase) private var scenePhase
    /// Opening the app, or coming back from the background, is a return;
    /// a moment under an iOS alert, Notification Centre or Control Centre
    /// (inactive, then active again) is not.
    @State private var returning = true

    var body: some View {
        Group {
            if pending.isPresented {
                PendingListView()
            } else if let credentials = session.credentials {
                SignedInView(credentials: credentials)
            } else {
                SignInView()
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .background { returning = true }
            guard phase == .active, returning else { return }
            returning = false
            // The screen is chosen before the sync, so a list it empties stays
            // up with what it did.
            pending.activate()
            BackgroundWork.start("Sync") { [session, pending] in
                // The token may have been removed on the website while we were away.
                await session.refresh()
                let result = await pending.sync(session.credentials)
                // A refused token: refresh says so and signs out.
                if result?.stopped == .unauthorized { await session.refresh() }
                // With nothing to sync, activation's own refresh may still be
                // running; the icon must be right before the app is suspended.
                await pending.badgeRefreshed()
            }
        }
        // Why the app wants the badge, before iOS asks.
        .sheet(
            isPresented: Binding(
                get: { pending.needsBadgePermission },
                set: { if !$0 { pending.declineBadgeForNow() } })
        ) {
            BadgePermissionView()
        }
        // The share extension keeps pages while the app is open, too.
        .task {
            for await _ in PendingQueue.changes() { pending.reload() }
        }
    }
}
