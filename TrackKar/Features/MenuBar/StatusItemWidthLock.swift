import AppKit
import Observation
import SwiftUI

/// Keeps the status item from shrinking while its popover is open.
///
/// The menu bar popover is anchored to the item's left edge, and menu bar items grow and shrink
/// leftwards. Stopping a timer removes the time from the item, so without this the item would
/// shrink under the open popover. (`PopoverPositionPin` keeps the popover itself in place.)
@Observable
final class StatusItemWidthLock {
    private(set) var isPopoverOpen = false
    /// The narrowest the item may be while the popover is open.
    private(set) var minimumWidth: CGFloat = 0

    func popoverOpened(reserving width: CGFloat) {
        isPopoverOpen = true
        minimumWidth = width
    }

    func popoverClosed() {
        isPopoverOpen = false
        minimumWidth = 0
    }

    /// Widens the lock if the label grew anyway (for example a longer activity name).
    func accommodate(_ width: CGFloat) {
        guard isPopoverOpen, width > minimumWidth else { return }
        minimumWidth = width
    }
}

/// For the menu bar panel: reports when it is shown or hidden, and while shown keeps it at the
/// horizontal position it opened at. The system re-anchors the panel to the status item whenever
/// the panel resizes, so a status item that changed width would otherwise make it jump sideways.
/// The panel is reused rather than recreated, so `onAppear` and `onDisappear` can't be relied on.
struct PopoverPositionPin: NSViewRepresentable {
    let onVisibilityChange: (Bool) -> Void

    func makeNSView(context: Context) -> PinView {
        let view = PinView()
        view.onVisibilityChange = onVisibilityChange
        return view
    }

    func updateNSView(_ view: PinView, context: Context) {
        view.onVisibilityChange = onVisibilityChange
    }

    final class PinView: NSView {
        var onVisibilityChange: (Bool) -> Void = { _ in }
        private var observations: [NSObjectProtocol] = []
        private var pinnedX: CGFloat?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observations.forEach(NotificationCenter.default.removeObserver)
            observations = []
            guard let window else { return }
            let center = NotificationCenter.default
            observations.append(center.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.visibilityChanged() }
            })
            for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
                observations.append(center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.restorePinnedPosition() }
                })
            }
            visibilityChanged()
        }

        private func visibilityChanged() {
            guard let window else { return }
            let isVisible = window.occlusionState.contains(.visible)
            pinnedX = isVisible ? window.frame.minX : nil
            onVisibilityChange(isVisible)
        }

        private func restorePinnedPosition() {
            guard let window, let pinnedX, window.frame.minX != pinnedX else { return }
            window.setFrameOrigin(NSPoint(x: pinnedX, y: window.frame.minY))
        }
    }
}
