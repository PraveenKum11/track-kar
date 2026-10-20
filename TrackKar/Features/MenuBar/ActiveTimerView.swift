import SwiftUI

/// The running entry as a card tinted with its activity's color: name and status, big time,
/// progress for countdowns, and the controls for its mode.
struct ActiveTimerView: View {
    let entry: TimeEntry
    /// Space toggles pause only while the name field isn't being typed in.
    let allowsSpaceShortcut: Bool

    @Environment(TimerEngine.self) private var engine
    @Environment(\.appTheme) private var theme

    private var activityColor: Color? {
        entry.colorHex.map(Color.activity)
    }

    var body: some View {
        let countdown = engine.countdown
        VStack(spacing: 12) {
            header(countdown)

            Text(timeText(countdown))
                .font(.system(size: 44, weight: .light, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(isDimmed(countdown) ? theme.secondaryText : theme.primaryText)
                .frame(maxWidth: .infinity)

            if let countdown {
                ProgressBar(value: countdown.isOvertime ? 1 : countdown.progress, color: progressColor(countdown))
            }

            Text(detail(countdown))
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
                .lineLimit(1)

            controls(countdown)
                .controlSize(.large)
        }
        .padding(14)
        .themedSurface(cornerRadius: 14, tint: activityColor)
    }

    // MARK: Header

    private func header(_ countdown: CountdownStatus?) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(activityColor ?? theme.secondaryText.opacity(0.5))
                .frame(width: 9, height: 9)
            Text(entry.displayName)
                .font(.headline)
                .lineLimit(1)
            Spacer(minLength: 8)
            if let status = status(countdown) {
                Text(status.text)
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(status.color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(status.color.opacity(0.15), in: .capsule)
                    .lineLimit(1)
            }
        }
    }

    private func status(_ countdown: CountdownStatus?) -> (text: String, color: Color)? {
        if let countdown {
            if countdown.isOvertime { return (String(localized: "Overtime"), .orange) }
            if countdown.isWaiting { return (String(localized: "Ready"), theme.secondaryText) }
            if let phase = countdown.phase {
                switch phase {
                case .focus:
                    if engine.state == .paused { return (String(localized: "Paused"), theme.secondaryText) }
                    let number = countdown.completedFocus % max(1, countdown.cyclesBeforeLongBreak) + 1
                    return (String(localized: "Focus \(number)/\(countdown.cyclesBeforeLongBreak)"), theme.accent)
                case .shortBreak, .longBreak:
                    return (phase.label, .green)
                }
            }
        }
        if engine.state == .paused { return (String(localized: "Paused"), theme.secondaryText) }
        return nil
    }

    // MARK: Text

    private func timeText(_ countdown: CountdownStatus?) -> String {
        guard let countdown else { return DurationFormat.clock(engine.elapsed) }
        if countdown.isOvertime { return "+" + DurationFormat.clock(-countdown.remaining) }
        return DurationFormat.clock(countdown.remaining.rounded(.up))
    }

    /// One quiet line of context under the time.
    private func detail(_ countdown: CountdownStatus?) -> String {
        var parts: [String] = []
        switch entry.mode {
        case .stopwatch:
            parts.append(String(localized: "Since \(entry.createdAt.formatted(date: .omitted, time: .shortened))"))
        case .timer:
            parts.append(String(localized: "\(DurationFormat.short(countdown?.total ?? 0)) timer"))
            if countdown?.isOvertime == true {
                parts.append(String(localized: "\(DurationFormat.clock(engine.elapsed)) tracked"))
            }
        case .pomodoro:
            if let countdown, countdown.phase?.isBreak == true || countdown.isWaiting {
                parts.append(String(localized: "\(DurationFormat.short(countdown.total)) \(countdown.phase?.label.lowercased() ?? "")"))
            } else {
                parts.append(String(localized: "\(DurationFormat.short(countdown?.total ?? 0)) focus"))
            }
            if entry.completedFocusCount > 0 {
                parts.append(String(localized: "^[\(entry.completedFocusCount) pomodoro](inflect: true) done"))
            }
        }
        if entry.mode != .pomodoro, entry.breakCount > 0 {
            parts.append(String(localized: "^[\(entry.breakCount) break](inflect: true)"))
        }
        return parts.joined(separator: " · ")
    }

    private func isDimmed(_ countdown: CountdownStatus?) -> Bool {
        if countdown?.isWaiting == true { return true }
        return engine.state == .paused && countdown?.phase?.isBreak != true
    }

    private func progressColor(_ countdown: CountdownStatus) -> Color {
        if countdown.isOvertime { return .orange }
        if countdown.phase?.isBreak == true { return .green }
        return activityColor ?? theme.accent
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
                // Prominent glass buttons draw symbols in a vibrant tint that doesn't match
                // their white text; keep the whole label white.
                .foregroundStyle(prominent ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        }
        .themedButton(prominent: prominent)
    }
}

/// A slim rounded progress bar.
private struct ProgressBar: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(color)
                    .frame(width: max(4, proxy.size.width * value))
            }
        }
        .frame(height: 4)
        .animation(.linear(duration: 0.3), value: value)
        .accessibilityElement()
        .accessibilityValue(Text(value.formatted(.percent.precision(.fractionLength(0)))))
    }
}
