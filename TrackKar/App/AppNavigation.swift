import Observation
import SwiftData
import SwiftUI

enum SidebarItem: Hashable {
    case dashboard
    case history
    case activities
    case group(PersistentIdentifier)
    case settings
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case general, timers, menuBar, appearance

    var id: Self { self }

    var label: String {
        switch self {
        case .general: String(localized: "General")
        case .timers: String(localized: "Timers")
        case .menuBar: String(localized: "Menu Bar")
        case .appearance: String(localized: "Appearance")
        }
    }
}

/// What the main window shows. Shared so the popover and menu commands can open a specific page.
@Observable
final class AppNavigation {
    var selection: SidebarItem? = .dashboard
    var settingsTab: SettingsTab = .general

    /// Opens the main window on a Settings section.
    func showSettings(_ tab: SettingsTab = .general, using openWindow: OpenWindowAction) {
        settingsTab = tab
        selection = .settings
        AppActivation.showMainWindow(openWindow)
    }
}

/// Replaces the app menu's "Settings…" item, which would otherwise look for a Settings scene.
struct SettingsCommand: View {
    let navigation: AppNavigation
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Settings…") {
            navigation.showSettings(using: openWindow)
        }
        .keyboardShortcut(",")
    }
}
