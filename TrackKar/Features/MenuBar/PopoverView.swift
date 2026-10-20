import SwiftUI

/// The menu bar popover: the minimal surface for starting, pausing and stopping.
struct PopoverView: View {
    /// Set for the menu bar popover, so the status item keeps its width while it's open.
    var widthLock: StatusItemWidthLock?

    @Environment(TimerEngine.self) private var engine
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @AppStorage(PreferenceKey.newActivityBehavior) private var newActivityBehavior: NewActivityBehavior = .ask
    @AppStorage(PreferenceKey.selectedTimerMode) private var selectedMode: TimerMode = .stopwatch
    @AppStorage(PreferenceKey.countdownMinutes) private var countdownMinutes = 25
    @AppStorage(PreferenceKey.menuBarOptions) private var menuBarOptions = MenuBarOptions()

    @State private var name = ""
    @State private var pendingSwitch: StartTarget?
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let entry = engine.activeEntry {
                // While tracking, the timer leads and switching is secondary.
                ActiveTimerView(entry: entry, allowsSpaceShortcut: !isNameFocused && pendingSwitch == nil)

                if let target = pendingSwitch {
                    SwitchConfirmation(current: entry, target: target) { choice in
                        if let choice {
                            engine.switchActiveEntry(
                                to: target, choice: choice, kind: selectedKind, newActivityBehavior: newActivityBehavior
                            )
                        }
                        pendingSwitch = nil
                    }
                } else if let prompt = engine.savePromptEntry {
                    SavePromptBanner(title: prompt.title)
                }

                nameField
            } else {
                nameField
                TimerModePicker(mode: $selectedMode, countdownMinutes: $countdownMinutes) {
                    AppActivation.showSettings(openSettings)
                }
                if let prompt = engine.savePromptEntry {
                    SavePromptBanner(title: prompt.title)
                }
            }

            RecentChips { start(.activity($0)) }

            Divider()

            footer
        }
        .padding(16)
        .frame(width: 320)
        .themedRoot()
        .background {
            if let widthLock {
                PopoverPositionPin { isVisible in
                    if isVisible {
                        widthLock.popoverOpened(
                            reserving: MenuBarLabel.currentWidth(engine: engine, options: menuBarOptions)
                        )
                    } else {
                        widthLock.popoverClosed()
                    }
                }
            }
        }
        .onAppear {
            isNameFocused = engine.state == .idle
        }
    }

    private var nameField: some View {
        let isIdle = engine.state == .idle
        return NameField(
            text: $name,
            isFocused: $isNameFocused,
            placeholder: isIdle
                ? String(localized: "What are you working on?")
                : String(localized: "Switch to something else…"),
            systemImage: isIdle ? "square.and.pencil" : "arrow.left.arrow.right",
            onStart: isIdle ? { start(StartTarget.title(name)) } : nil,
            onSubmit: submit
        )
    }

    private var footer: some View {
        let reference = engine.state == .running ? engine.now : .now
        let today = Calendar.current.dateInterval(of: .day, for: reference) ?? DateInterval(start: reference, duration: 0)

        return TodaySummary(day: today, now: reference) {
            HStack(spacing: 12) {
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
    }

    private var selectedKind: TimerKind {
        switch selectedMode {
        case .stopwatch: .stopwatch
        case .timer: .countdown(TimeInterval(countdownMinutes * 60))
        case .pomodoro: .pomodoro
        }
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
            engine.start(target, kind: selectedKind, newActivityBehavior: newActivityBehavior)
        } else if case .title(let title) = target, title.nilIfBlank == nil {
            // Return in an empty field while tracking does nothing.
        } else if engine.needsSwitchConfirmation(for: target) {
            pendingSwitch = target
        }
        name = ""
        isNameFocused = false
    }
}
