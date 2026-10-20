import SwiftUI
import UserNotifications

/// Settings → Timers: what happens when a countdown ends, and the Pomodoro rhythm.
struct TimerSettingsView: View {
    @AppStorage(PreferenceKey.timerSettings) private var settings = TimerSettings()
    @Environment(TimerEngine.self) private var engine

    var body: some View {
        Form {
            Section("Timer") {
                Picker("When time is up", selection: $settings.countdownEnd) {
                    ForEach(CountdownEndBehavior.allCases) { Text($0.label).tag($0) }
                }
            }

            Section {
                Stepper("Focus: \(settings.focusMinutes) min", value: $settings.focusMinutes, in: 5...120, step: 5)
                Stepper("Short break: \(settings.shortBreakMinutes) min", value: $settings.shortBreakMinutes, in: 1...30)
                Stepper("Long break: \(settings.longBreakMinutes) min", value: $settings.longBreakMinutes, in: 5...60, step: 5)
                Stepper(
                    "Long break after ^[\(settings.cyclesBeforeLongBreak) focus session](inflect: true)",
                    value: $settings.cyclesBeforeLongBreak,
                    in: 2...8
                )
                Toggle("Start breaks automatically", isOn: $settings.autoStartBreaks)
                Toggle("Start focus automatically after a break", isOn: $settings.autoStartFocus)
            } header: {
                Text("Pomodoro")
            } footer: {
                Text("Only focus time is tracked. Breaks are counted but never added to your time.")
            }

            Section("Notifications") {
                NotificationStatusRow()
            }

            Section {
                Button("Restore Defaults") { settings = TimerSettings() }
                    .disabled(settings == TimerSettings())
            }
        }
        .formStyle(.grouped)
        .frame(height: 560)
        .onChange(of: settings) {
            engine.timerSettingsChanged()
        }
    }
}

/// Shows whether Track Kar may post notifications, with a way to fix it.
private struct NotificationStatusRow: View {
    @State private var status: UNAuthorizationStatus?

    var body: some View {
        LabeledContent {
            switch status {
            case .notDetermined:
                Button("Allow Notifications") { request() }
            case .denied:
                Button("Open Notification Settings") { openSystemSettings() }
            default:
                EmptyView()
            }
        } label: {
            Text("Alerts when a timer or phase ends")
            Text(description)
        }
        .task { await refresh() }
    }

    private var description: String {
        switch status {
        case .authorized, .provisional, .ephemeral: String(localized: "On")
        case .denied: String(localized: "Off. Track Kar plays a sound instead while it's open.")
        case .notDetermined: String(localized: "Not set up yet")
        default: ""
        }
    }

    private func refresh() async {
        status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    private func request() {
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            await refresh()
        }
    }

    private func openSystemSettings() {
        let id = Bundle.main.bundleIdentifier ?? ""
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)") {
            NSWorkspace.shared.open(url)
        }
    }
}
