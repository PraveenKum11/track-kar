import SwiftData
import SwiftUI

@main
struct TrackKarApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    private let container: ModelContainer
    @State private var engine: TimerEngine
    @State private var widthLock = StatusItemWidthLock()
    @State private var navigation = AppNavigation()
    private let awayMonitor: AwayMonitor
    private let hotkeys: Hotkeys
    @AppStorage(PreferenceKey.menuBarOptions) private var menuBarOptions = MenuBarOptions()
    @AppStorage(PreferenceKey.hasSeenWelcome) private var hasSeenWelcome = false

    init() {
        #if DEBUG
        let container: ModelContainer
        if let url = SampleData.storeURL {
            container = Persistence.makeContainer(url: url)
        } else if SampleData.isRequested {
            container = Persistence.makeContainer(inMemory: true)
            SampleData.seed(container.mainContext)
        } else {
            container = Persistence.makeContainer()
        }
        // Sample runs never ask for notification permission on the user's behalf.
        let notifier: TimerNotifying = SampleData.isRequested ? SilentNotifier() : SystemNotifier()
        #else
        let container = Persistence.makeContainer()
        let notifier: TimerNotifying = SystemNotifier()
        #endif
        self.container = container
        let engine = TimerEngine(context: container.mainContext, notifier: notifier)
        _engine = State(initialValue: engine)
        awayMonitor = AwayMonitor(engine: engine)
        hotkeys = Hotkeys(engine: engine)
    }

    var body: some Scene {
        MenuBarExtra(isInserted: isMenuBarItemShown) {
            PopoverView(widthLock: widthLock)
                .environment(engine)
                .environment(navigation)
        } label: {
            MenuBarLabel(engine: engine, options: menuBarOptions, widthLock: widthLock)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(container)

        Window("Track Kar", id: WindowID.main) {
            MainWindowView()
                .environment(engine)
                .environment(navigation)
                .themedRoot()
        }
        .defaultSize(width: 980, height: 640)
        .defaultLaunchBehavior(.suppressed)
        .modelContainer(container)
        .commands {
            CommandGroup(replacing: .appSettings) {
                SettingsCommand(navigation: navigation)
            }
        }

        Window("Welcome to Track Kar", id: WindowID.welcome) {
            WelcomeView()
                .environment(navigation)
                .themedRoot()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultLaunchBehavior(showsWelcome ? .presented : .suppressed)


    }

    /// First launch only, and never under tests or sample data.
    private var showsWelcome: Bool {
        #if DEBUG
        if SampleData.isRequested { return false }
        #endif
        return !hasSeenWelcome && !Persistence.isRunningTests
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
    static let welcome = "welcome"
}
