import SwiftUI

/// Stopwatch · Timer · Pomodoro, plus the chosen mode's options. Shown while idle.
struct TimerModePicker: View {
    @Binding var mode: TimerMode
    @Binding var countdownMinutes: Int
    let onOpenSettings: () -> Void

    @AppStorage(PreferenceKey.timerSettings) private var settings = TimerSettings()
    @Environment(\.appTheme) private var theme

    private static let presets = [5, 15, 25, 50]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            modeSegments

            switch mode {
            case .stopwatch:
                EmptyView()
            case .timer:
                countdownOptions
            case .pomodoro:
                pomodoroSummary
            }
        }
    }

    /// A full-width segmented control. The system segmented picker only sizes to its content.
    private var modeSegments: some View {
        HStack(spacing: 2) {
            ForEach(TimerMode.allCases) { option in
                let isSelected = option == mode
                Button {
                    mode = option
                } label: {
                    Text(option.label)
                        .font(.callout.weight(isSelected ? .semibold : .regular))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .contentShape(.rect)
                        .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(theme.primaryText))
                        .background(isSelected ? theme.accent : .clear, in: .rect(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(2)
        .themedSurface(cornerRadius: 9)
        .animation(.snappy(duration: 0.2), value: mode)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Timer mode")
    }

    private var countdownOptions: some View {
        HStack(spacing: 6) {
            ForEach(Self.presets, id: \.self) { minutes in
                Button("\(minutes)m") { countdownMinutes = minutes }
                    .themedButton(prominent: minutes == countdownMinutes)
                    .controlSize(.small)
            }
            Spacer(minLength: 4)
            Stepper(value: $countdownMinutes, in: 1...480) {
                Text("\(countdownMinutes) min")
                    .monospacedDigit()
                    .font(.callout)
            }
            .help("Custom length")
        }
    }

    private var pomodoroSummary: some View {
        HStack {
            Text("\(settings.focusMinutes)m focus · \(settings.shortBreakMinutes)m break · long break every \(settings.cyclesBeforeLongBreak)")
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
                .lineLimit(2)
            Spacer(minLength: 4)
            Button("Change…", action: onOpenSettings)
                .buttonStyle(.borderless)
                .font(.caption)
        }
    }
}
