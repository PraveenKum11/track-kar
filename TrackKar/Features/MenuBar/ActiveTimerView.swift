import SwiftUI

/// Big elapsed time, the entry's name, and pause/stop controls.
struct ActiveTimerView: View {
    let entry: TimeEntry
    /// Space toggles pause only while the name field isn't being typed in.
    let allowsSpaceShortcut: Bool

    @Environment(TimerEngine.self) private var engine
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 10) {
            Text(DurationFormat.clock(engine.elapsed))
                .font(.system(size: 40, weight: .light, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(engine.state == .paused ? theme.secondaryText : theme.primaryText)

            HStack(spacing: 6) {
                if let hex = entry.colorHex {
                    Circle()
                        .fill(Color.activity(hex))
                        .frame(width: 8, height: 8)
                }
                Text(entry.displayName)
                    .lineLimit(1)
                if engine.state == .paused {
                    Text("· Paused")
                        .foregroundStyle(theme.secondaryText)
                }
                if entry.breakCount > 0 {
                    Text("· ^[\(entry.breakCount) break](inflect: true)")
                        .foregroundStyle(theme.secondaryText)
                }
            }
            .font(.callout)

            HStack(spacing: 10) {
                Button {
                    engine.togglePause()
                } label: {
                    Label(
                        engine.state == .paused ? "Resume" : "Pause",
                        systemImage: engine.state == .paused ? "play.fill" : "pause.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .keyboardShortcut(allowsSpaceShortcut ? KeyboardShortcut(.space, modifiers: []) : nil)
                .themedButton()

                Button {
                    engine.stop()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut(".", modifiers: .command)
                .themedButton(prominent: true)
            }
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
    }
}
