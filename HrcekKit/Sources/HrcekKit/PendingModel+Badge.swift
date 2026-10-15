import Foundation

extension PendingModel {
    /// Brings the badge, and whether to ask for it, up to date. Once up,
    /// the explanation stays until the person answers it or iOS has an
    /// answer: the sync on opening often empties the list under it.
    public func refreshBadge() async {
        let status = await badge.status()
        badgeDenied = status == .denied
        if status != .undetermined {
            needsBadgePermission = false
        } else if !entries.isEmpty, !askedThisLaunch {
            needsBadgePermission = true
        }
        await badge.set(count)
    }

    /// Shows iOS's question, at most once a launch.
    public func askForBadge() async {
        guard !askedThisLaunch else { return }
        askedThisLaunch = true
        needsBadgePermission = false
        badgeDenied = !(await badge.request())
        await badge.set(count)
    }

    public func declineBadgeForNow() {
        askedThisLaunch = true
        needsBadgePermission = false
    }

    /// Refreshes after the ones already started, so an older count
    /// never lands on the icon after a newer one.
    func scheduleBadgeRefresh() {
        badgeRefresh = Task { [previous = badgeRefresh] in
            await previous?.value
            await refreshBadge()
        }
    }

    /// Waits for the refreshes reloads have started: work with background
    /// time awaits it, so the icon is right before the app is suspended.
    public func badgeRefreshed() async {
        await badgeRefresh?.value
    }
}
