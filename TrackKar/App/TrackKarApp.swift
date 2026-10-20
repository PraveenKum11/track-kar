import SwiftData
import SwiftUI

@main
struct TrackKarApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    private let container: ModelContainer
    @State private var engine: TimerEngine
    @AppStorage(PreferenceKey.menuBarOptions) private var menuBarOptions = MenuBarOptions()

    init() {
        #if DEBUG
        let container = SampleData.isRequested ? Persistence.makeContainer(inMemory: true) : Persistence.makeContainer()
        if SampleData.isRequested { SampleData.seed(container.mainContext) }
        #else
        let container = Persistence.makeContainer()
        #endif
        self.container = container
        _engine = State(initialValue: TimerEngine(context: container.mainContext))
    }

    var body: some Scene {
        MenuBarExtra(isInserted: isMenuBarItemShown) {
            PopoverView()
                .environment(engine)
        } label: {
            MenuBarLabel(engine: engine, options: menuBarOptions)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(container)

        Window("Track Kar", id: WindowID.main) {
            MainWindowView()
                .environment(engine)
                .themedRoot()
        }
        .defaultSize(width: 980, height: 640)
        .defaultLaunchBehavior(.suppressed)
        .modelContainer(container)

        Settings {
            SettingsView()
        }
    }

    /// Hidden only when the user chose "Hidden" for idle and nothing is being tracked.
    private var isMenuBarItemShown: Binding<Bool> {
        Binding(
            get: { !(menuBarOptions.idleDisplay == .hidden && engine.state == .idle) },
            set: { _ in }
        )
    }
}

enum WindowID {
    static let main = "main"
}
