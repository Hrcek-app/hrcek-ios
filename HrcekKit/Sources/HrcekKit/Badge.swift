import Foundation
import Synchronization
import UserNotifications

public enum BadgeStatus: Sendable { case undetermined, allowed, denied }

/// The app icon's badge. iOS shows a number only with the person's leave.
public protocol BadgeCenter: Sendable {
    func status() async -> BadgeStatus
    /// Shows iOS's own question; answers whether the badge was allowed.
    func request() async -> Bool
    func set(_ count: Int) async
}

public struct NotificationBadgeCenter: BadgeCenter {
    public init() {}

    public func status() async -> BadgeStatus {
        switch await UNUserNotificationCenter.current().notificationSettings()
            .authorizationStatus
        {
        case .notDetermined: .undetermined
        case .denied: .denied
        default: .allowed
        }
    }

    public func request() async -> Bool {
        // The badge only: nothing here ever alerts or makes a sound.
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.badge]))
            ?? false
    }

    public func set(_ count: Int) async {
        do {
            try await UNUserNotificationCenter.current().setBadgeCount(count)
        } catch {
            Log.app.notice("Badge not set: \(Log.summary(of: error), privacy: .public)")
        }
    }
}

/// A badge whose answer is fixed: for tests, where iOS's real answer
/// would carry over from one run to the next.
public final class FixedBadgeCenter: BadgeCenter {
    private let answer: Mutex<BadgeStatus>
    private let grants: Bool
    public let counts = Mutex<[Int]>([])
    /// How many times iOS's question was asked.
    public let requests = Mutex(0)

    public init(_ status: BadgeStatus, grants: Bool = true) {
        answer = Mutex(status)
        self.grants = grants
    }

    public func status() async -> BadgeStatus { answer.withLock { $0 } }

    public func request() async -> Bool {
        requests.withLock { $0 += 1 }
        answer.withLock { $0 = grants ? .allowed : .denied }
        return grants
    }

    public func set(_ count: Int) async { counts.withLock { $0.append(count) } }
}
