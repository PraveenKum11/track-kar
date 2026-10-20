import AppKit
import UserNotifications

struct TimerAlert: Equatable {
    var date: Date
    var title: String
    var body: String
}

/// Delivers countdown and Pomodoro alerts. The engine keeps at most one pending alert.
protocol TimerNotifying: AnyObject {
    /// Replaces any pending alert; `nil` cancels it.
    func schedule(_ alert: TimerAlert?)
    /// A countdown or phase ended while the app was watching.
    func didReachAlert()
}

/// For tests and previews.
final class SilentNotifier: TimerNotifying {
    func schedule(_ alert: TimerAlert?) {}
    func didReachAlert() {}
}

/// Schedules a system notification for the exact end time, so it fires (with sound) even if the
/// app is suspended or the Mac was asleep. Without notification permission it plays a sound itself.
final class SystemNotifier: NSObject, TimerNotifying, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private let identifier = "timer-alert"
    private var generation = 0
    private var isAuthorized = false

    override init() {
        super.init()
        center.delegate = self
    }

    func schedule(_ alert: TimerAlert?) {
        generation += 1
        let current = generation
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard let alert, alert.date > .now else { return }

        Task {
            guard await requestAuthorizationIfNeeded(), current == generation else { return }
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
