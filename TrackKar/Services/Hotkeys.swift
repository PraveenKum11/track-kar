import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let togglePopover = Self("togglePopover", initial: .init(.t, modifiers: [.control, .option]))
    static let startStopTimer = Self("startStopTimer")
    static let pauseResumeTimer = Self("pauseResumeTimer")
}

/// Global shortcuts, set in Settings → General. They work while other apps are in front.
final class Hotkeys {
    init(engine: TimerEngine) {
        KeyboardShortcuts.onKeyUp(for: .togglePopover) {
            StatusItemButton.toggle()
        }
        KeyboardShortcuts.onKeyUp(for: .startStopTimer) {
            if engine.state == .idle {
                engine.restartMostRecent(newActivityBehavior: Self.newActivityBehavior)
            } else {
                engine.stop()
            }
        }
        KeyboardShortcuts.onKeyUp(for: .pauseResumeTimer) {
            engine.togglePause()
        }
    }

    private static var newActivityBehavior: NewActivityBehavior {
        UserDefaults.standard.string(forKey: PreferenceKey.newActivityBehavior).flatMap(NewActivityBehavior.init(rawValue:)) ?? .ask
    }
}

/// Opens the menu bar popover from code. `MenuBarExtra` has no API for this, so it clicks the
/// status item's button, which lives in one of the app's status bar windows.
enum StatusItemButton {
    static func toggle() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where String(describing: type(of: window)).contains("StatusBar") {
            if let button = find(in: window.contentView) {
                button.performClick(nil)
                return
            }
        }
    }

    private static func find(in view: NSView?) -> NSStatusBarButton? {
        guard let view else { return nil }
        if let button = view as? NSStatusBarButton { return button }
        for subview in view.subviews {
            if let button = find(in: subview) { return button }
        }
        return nil
    }
}
