import UIKit

/// Work that may outlast the app's time in the foreground.
@MainActor
final class BackgroundWork {
    private var identifier = UIBackgroundTaskIdentifier.invalid
    private var task: Task<Void, Never>?

    private init() {}

    /// Runs `work` with background time, cancelled when the time runs out.
    static func start(_ name: String, _ work: @escaping @MainActor () async -> Void) {
        // A sync holds a lock in the shared container, and iOS kills a
        // process suspended with one held (0xdead10cc): a cancelled sync
        // ends and lets go of it.
        let holder = BackgroundWork()
        holder.identifier = UIApplication.shared.beginBackgroundTask(withName: name) {
            holder.task?.cancel()
            holder.end()
        }
        holder.task = Task {
            await work()
            holder.end()
        }
    }

    /// Ends the background time once, whichever comes first: the work or
    /// the time running out.
    private func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
