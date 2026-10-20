import SwiftUI

/// Placeholder for the menu bar popover. Replaced by the timer UI in Phase 1.
struct PopoverView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 12) {
            Text("Track Kar")
                .font(.headline)
            Text("Nothing to track yet.")
                .foregroundStyle(.secondary)

            Divider()

            HStack {
                Button("Open Track Kar") {
                    openWindow(id: WindowID.main)
                    NSApp.activate()
                }
                .keyboardShortcut("o")

                Spacer()

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding()
        .frame(width: 320)
    }
}

#Preview {
    PopoverView()
}
