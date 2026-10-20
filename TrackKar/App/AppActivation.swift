import AppKit
import SwiftUI

/// Track Kar is a menu bar (accessory) app. While the main window is open it becomes a regular
/// app so it has a Dock icon, ⌘-Tab entry and app menu.
enum AppActivation {
    static func showMainWindow(_ openWindow: OpenWindowAction) {
        NSApp.setActivationPolicy(.regular)
        openWindow(id: WindowID.main)
        bringToFront()
    }

    /// Activation right after a policy change is ignored, so wait one runloop pass. Cooperative
    /// `activate()` leaves the window behind the previously active app when invoked from the
    /// menu bar panel, so this asks to take focus explicitly.
    static func bringToFront() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows
                .first { $0.identifier?.rawValue == WindowID.main && $0.isVisible }?
                .makeKeyAndOrderFront(nil)
        }
    }

    static func mainWindowClosed() {
        NSApp.setActivationPolicy(.accessory)
    }
}
