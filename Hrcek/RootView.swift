import HrcekKit
import SwiftUI

struct RootView: View {
    @Environment(SessionModel.self) private var session
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let credentials = session.credentials {
                SignedInView(credentials: credentials)
            } else {
                SignInView()
            }
        }
        // The token may have been removed on the website while we were away.
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { Task { await session.refresh() } }
        }
    }
}
