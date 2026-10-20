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
        VStack(alignment: .leading, spacing: 10) {
            modeSegments

            // Options sit in an inset card so they stay clear of the popover's edges.
            switch mode {
            case .stopwatch:
                EmptyView()
            case .timer:
                optionsCard { countdownOptions }
            case .pomodoro:
                optionsCard { pomodoroSummary }
            }
        }
    }

    private func optionsCard(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedSurface(cornerRadius: 10)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(Self.presets, id: \.self) { minutes in
                    Button {
                        countdownMinutes = minutes
                    } label: {
                        Text("\(minutes)m")
                            .frame(maxWidth: .infinity)
                    }
                    .themedButton(prominent: minutes == countdownMinutes)
                    .controlSize(.small)
                }
            }
            HStack {
                Text("Length")
                    .foregroundStyle(theme.secondaryText)
                Spacer()
                Stepper(value: $countdownMinutes, in: 1...480) {
                    Text("\(countdownMinutes) min")
                        .monospacedDigit()
                }
                .help("Custom length")
            }
            .font(.callout)
        }
    }

    private var pomodoroSummary: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Label("\(settings.focusMinutes) min focus, \(settings.shortBreakMinutes) min breaks", systemImage: "brain")
                Label("\(settings.longBreakMinutes) min long break every \(settings.cyclesBeforeLongBreak)", systemImage: "cup.and.saucer")
            }
            .font(.caption)
            .foregroundStyle(theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Button("Edit", action: onOpenSettings)
                .themedButton()
                .controlSize(.small)
                .help("Change Pomodoro lengths in Settings")
        }
    }
}
