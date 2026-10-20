import SwiftUI

/// The menu bar popover: the minimal surface for starting, pausing and stopping.
struct PopoverView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @AppStorage(PreferenceKey.newActivityBehavior) private var newActivityBehavior: NewActivityBehavior = .ask

    @State private var name = ""
    @State private var pendingSwitch: StartTarget?
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 8) {
                NameField(
                    text: $name,
                    isFocused: $isNameFocused,
                    placeholder: engine.state == .idle
                        ? String(localized: "What are you working on?")
                        : String(localized: "Switch to something else…"),
                    onSubmit: submit
                )
                if engine.state == .idle {
                    Button {
                        start(StartTarget.title(name))
                    } label: {
                        Label("Start", systemImage: "play.fill")
                            .labelStyle(.iconOnly)
                    }
                    .themedButton(prominent: true)
                    .controlSize(.large)
                    .help("Start (Return)")
                }
            }

            if let entry = engine.activeEntry {
                ActiveTimerView(entry: entry, allowsSpaceShortcut: !isNameFocused && pendingSwitch == nil)
            }

            if let target = pendingSwitch, let entry = engine.activeEntry {
                SwitchConfirmation(current: entry, target: target) { choice in
                    if let choice {
                        engine.switchActiveEntry(to: target, choice: choice, newActivityBehavior: newActivityBehavior)
                    }
                    pendingSwitch = nil
                }
            } else if let entry = engine.savePromptEntry {
                SavePromptBanner(title: entry.title)
            }

            RecentChips { start(.activity($0)) }

            Divider()

            footer
        }
        .padding(16)
        .frame(width: 320)
        .themedRoot()
        .onAppear {
            isNameFocused = engine.state == .idle
        }
    }

    private var footer: some View {
        let reference = engine.state == .running ? engine.now : .now
        let today = Calendar.current.dateInterval(of: .day, for: reference) ?? DateInterval(start: reference, duration: 0)

        return HStack(spacing: 12) {
            TodayTotalView(day: today, now: reference)
            Spacer()
            Button {
                AppActivation.showMainWindow(openWindow)
            } label: {
                Label("Open Track Kar", systemImage: "macwindow")
            }
            .keyboardShortcut("o")
            .help("Open Track Kar (⌘O)")

            Button {
                AppActivation.showSettings(openSettings)
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .keyboardShortcut(",")
            .help("Settings (⌘,)")

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit Track Kar", systemImage: "power")
            }
            .keyboardShortcut("q")
            .help("Quit Track Kar (⌘Q)")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
    }

    private func submit(_ submission: NameField.Submission) {
        let target: StartTarget = switch submission {
        case .activity(let activity): .activity(activity)
        case .title(let title): .title(title)
        }
        start(target)
    }

    /// Starts right away when idle; otherwise asks what to do with the running entry.
    private func start(_ target: StartTarget) {
        if engine.state == .idle {
            engine.start(target, newActivityBehavior: newActivityBehavior)
        } else if case .title(let title) = target, title.nilIfBlank == nil {
            // Return in an empty field while tracking does nothing.
        } else if engine.needsSwitchConfirmation(for: target) {
            pendingSwitch = target
        }
        name = ""
        isNameFocused = false
    }
}
