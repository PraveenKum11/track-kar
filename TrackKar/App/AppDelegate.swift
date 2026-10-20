import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// SwiftUI quits a single-`Window` app when that window closes. Track Kar lives in the
    /// menu bar, so closing the main window must leave it running.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
