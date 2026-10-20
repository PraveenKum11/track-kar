import SwiftUI

/// Big time, the entry's name, and the controls for its mode.
struct ActiveTimerView: View {
    let entry: TimeEntry
    /// Space toggles pause only while the name field isn't being typed in.
    let allowsSpaceShortcut: Bool

    @Environment(TimerEngine.self) private var engine
    @Environment(\.appTheme) private var theme

    var body: some View {
        let countdown = engine.countdown
        VStack(spacing: 10) {
            if let countdown {
                Text(caption(for: countdown))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(countdown.isOvertime ? Color.orange : theme.secondaryText)
                    .textCase(.uppercase)
            }

            Text(timeText(countdown))
                .font(.system(size: 40, weight: .light, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(isDimmed(countdown) ? theme.secondaryText : theme.primaryText)

            if let countdown {
                ProgressView(value: countdown.isOvertime ? 1 : countdown.progress)
                    .tint(countdown.isOvertime ? .orange : countdown.phase?.isBreak == true ? .green : theme.accent)
                    .frame(maxWidth: 220)
            }

            nameLine(countdown)
                .font(.callout)

            controls(countdown)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Text

    private func timeText(_ countdown: CountdownStatus?) -> String {
        guard let countdown else { return DurationFormat.clock(engine.elapsed) }
        if countdown.isOvertime { return "+" + DurationFormat.clock(-countdown.remaining) }
        return DurationFormat.clock(countdown.remaining.rounded(.up))
    }

    private func caption(for countdown: CountdownStatus) -> String {
        if countdown.isOvertime { return String(localized: "Overtime") }
        guard let phase = countdown.phase else {
            return String(localized: "Timer · \(DurationFormat.short(countdown.total))")
        }
        switch phase {
        case .focus:
            let number = countdown.completedFocus % max(1, countdown.cyclesBeforeLongBreak) + 1
            return String(localized: "Focus \(number) of \(countdown.cyclesBeforeLongBreak)")
        case .shortBreak, .longBreak:
            return phase.label
        }
    }

    private func isDimmed(_ countdown: CountdownStatus?) -> Bool {
        if countdown?.isWaiting == true { return true }
        return engine.state == .paused && countdown?.phase?.isBreak != true
    }

    private func nameLine(_ countdown: CountdownStatus?) -> some View {
        HStack(spacing: 6) {
            if let hex = entry.colorHex {
                Circle()
                    .fill(Color.activity(hex))
                    .frame(width: 8, height: 8)
            }
            Text(entry.displayName)
                .lineLimit(1)
            if countdown?.isWaiting == true {
                Text("· Ready")
                    .foregroundStyle(theme.secondaryText)
            } else if engine.state == .paused, countdown?.phase?.isBreak != true {
                Text("· Paused")
                    .foregroundStyle(theme.secondaryText)
            }
            if entry.mode == .pomodoro, entry.completedFocusCount > 0 {
                Text("· ^[\(entry.completedFocusCount) pomodoro](inflect: true)")
                    .foregroundStyle(theme.secondaryText)
            } else if entry.breakCount > 0 {
                Text("· ^[\(entry.breakCount) break](inflect: true)")
                    .foregroundStyle(theme.secondaryText)
            }
        }
    }

    // MARK: Controls

    @ViewBuilder
    private func controls(_ countdown: CountdownStatus?) -> some View {
        HStack(spacing: 8) {
            if let phase = countdown?.phase, countdown?.isWaiting == true {
                wideButton(
                    phase.isBreak ? "Start Break" : "Start Focus",
                    systemImage: phase.isBreak ? "cup.and.saucer.fill" : "play.fill",
                    prominent: true
                ) { engine.startPhase() }
                    .keyboardShortcut(allowsSpaceShortcut ? KeyboardShortcut(.space, modifiers: []) : nil)
                if phase.isBreak {
                    skipButton("Skip Break")
                }
            } else if countdown?.phase?.isBreak == true {
                skipButton("Skip Break")
            } else {
                wideButton(
                    engine.state == .paused ? "Resume" : "Pause",
                    systemImage: engine.state == .paused ? "play.fill" : "pause.fill"
                ) { engine.togglePause() }
                    .keyboardShortcut(allowsSpaceShortcut ? KeyboardShortcut(.space, modifiers: []) : nil)
                if countdown?.phase == .focus {
                    skipButton("Skip")
                }
            }

            wideButton("Stop", systemImage: "stop.fill", prominent: countdown?.isWaiting != true) {
                engine.stop()
            }
            .keyboardShortcut(".", modifiers: .command)
        }
    }

    private func skipButton(_ title: LocalizedStringKey) -> some View {
        wideButton(title, systemImage: "forward.end.fill") { engine.skipPhase() }
            .help("End this phase now and start the next one")
    }

    private func wideButton(
        _ title: LocalizedStringKey,
        systemImage: String,
        prominent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .themedButton(prominent: prominent)
    }
}
