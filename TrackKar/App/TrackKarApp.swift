import SwiftData
import SwiftUI

@main
struct TrackKarApp: App {
    private let container: ModelContainer
    @State private var engine: TimerEngine

    init() {
        let container = Persistence.makeContainer()
        self.container = container
        _engine = State(initialValue: TimerEngine(context: container.mainContext))
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environment(engine)
        } label: {
            MenuBarLabel(engine: engine)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(container)

        Window("Track Kar", id: WindowID.main) {
            MainWindowView()
                .environment(engine)
                .themedRoot()
        }
        .defaultSize(width: 900, height: 600)
        .defaultLaunchBehavior(.suppressed)
        .modelContainer(container)

        Settings {
            SettingsView()
        }
    }
}

enum WindowID {
    static let main = "main"
}
