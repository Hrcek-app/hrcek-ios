import Foundation

/// Runs `work` while iOS lets the extension live on, and cancels it when
/// iOS says time is up: a share sheet may be closed and killed while it
/// is still sending.
func whileAllowed(_ work: @escaping @Sendable () async -> Void) async {
    let task = Task { await work() }
    let finished = DispatchSemaphore(value: 0)
    let reason = "Sending waiting pages"
    ProcessInfo.processInfo.performExpiringActivity(withReason: reason) { expired in
        if expired {
            task.cancel()
        } else {
            finished.wait()
        }
    }
    await task.value
    finished.signal()
}
