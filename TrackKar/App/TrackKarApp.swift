import SwiftUI

@main
struct TrackKarApp: App {
    var body: some Scene {
        MenuBarExtra("Track Kar", systemImage: "timer") {
            PopoverView()
        }
        .menuBarExtraStyle(.window)

        Window("Track Kar", id: WindowID.main) {
            MainWindowView()
        }
        .defaultSize(width: 900, height: 600)
        .defaultLaunchBehavior(.suppressed)
    }
}

enum WindowID {
    static let main = "main"
}
