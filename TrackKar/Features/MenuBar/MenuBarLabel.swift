import SwiftUI

/// The status item itself. Phase 2's Menu Bar settings will make each part configurable.
struct MenuBarLabel: View {
    let engine: TimerEngine

    var body: some View {
        switch engine.state {
        case .idle:
            Image(systemName: "timer")
        case .running:
            HStack(spacing: 4) {
                Image(systemName: "timer")
                Text(DurationFormat.clock(engine.elapsed))
                    .monospacedDigit()
            }
        case .paused:
            HStack(spacing: 4) {
                Image(systemName: "pause.circle")
                Text(DurationFormat.clock(engine.elapsed))
                    .monospacedDigit()
            }
        }
    }
}
