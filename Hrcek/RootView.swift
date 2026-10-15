import HrcekKit
import SwiftUI

struct RootView: View {
    @Environment(SessionModel.self) private var session
    @Environment(PendingModel.self) private var pending
    @Environment(\.scenePhase) private var scenePhase

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
            guard phase == .active else { return }
            // The screen is chosen before the sync, so a list it empties stays
            // up with what it did.
            pending.activate()
            BackgroundWork.start("Sync") { [session, pending] in
                // The token may have been removed on the website while we were away.
                await session.refresh()
                let result = await pending.sync(session.credentials)
                // A refused token: refresh says so and signs out.
                if result?.stopped == .unauthorized { await session.refresh() }
            }
        }
        // The share extension keeps pages while the app is open, too.
        .task {
            for await _ in PendingQueue.changes() { pending.reload() }
        }
    }
}
