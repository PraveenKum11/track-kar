import AppKit
import UserNotifications

struct TimerAlert: Equatable {
    var date: Date
    var title: String
    var body: String
}

/// Delivers countdown and Pomodoro alerts, plus "still tracking?" reminders. The engine keeps at
/// most one pending alert of each kind.
protocol TimerNotifying: AnyObject {
    /// Replaces any pending countdown or phase alert; `nil` cancels it.
    func schedule(_ alert: TimerAlert?)
    /// Replaces any pending "still tracking?" reminder; `nil` cancels it.
    func scheduleReminder(_ reminder: TimerAlert?)
    /// A countdown or phase ended while the app was watching.
    func didReachAlert()
}

/// For tests and previews.
final class SilentNotifier: TimerNotifying {
    func schedule(_ alert: TimerAlert?) {}
    func scheduleReminder(_ reminder: TimerAlert?) {}
    func didReachAlert() {}
}

/// Schedules a system notification for the exact end time, so it fires (with sound) even if the
/// app is suspended or the Mac was asleep. Without notification permission it plays a sound itself.
final class SystemNotifier: NSObject, TimerNotifying, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    /// Bumped per identifier so a slow authorization check can't add a superseded request.
    private var generations: [String: Int] = [:]
    private var isAuthorized = false

    override init() {
        super.init()
        center.delegate = self
    }

    func schedule(_ alert: TimerAlert?) {
        replace("timer-alert", with: alert)
    }

    func scheduleReminder(_ reminder: TimerAlert?) {
        replace("still-tracking", with: reminder)
    }

    private func replace(_ identifier: String, with alert: TimerAlert?) {
        let current = (generations[identifier] ?? 0) + 1
        generations[identifier] = current
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard let alert, alert.date > .now else { return }

        Task {
            guard await requestAuthorizationIfNeeded(), current == generations[identifier] else { return }
            let content = UNMutableNotificationContent()
            content.title = alert.title
            content.body = alert.body
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, alert.date.timeIntervalSinceNow), repeats: false)
            try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        }
    }

    func didReachAlert() {
        if !isAuthorized {
            NSSound(named: "Glass")?.play()
        }
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            isAuthorized = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .authorized, .provisional:
            isAuthorized = true
        default:
            isAuthorized = false
        }
        return isAuthorized
    }

    /// Show alerts even while Track Kar is the active app.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
