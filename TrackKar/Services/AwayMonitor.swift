import AppKit
import CoreGraphics
import SwiftUI

/// Watches for time away from the Mac (idle input or sleep) while a timer runs, and asks the
/// user what to do with it once they're back.
final class AwayMonitor: NSObject, NSWindowDelegate {
    private let engine: TimerEngine
    private var detector = AwayDetector(threshold: 0)
    private var sleepStartedAt: Date?
    private var wasTrackingAtSleep = false
    private var pollTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var promptWindow: NSWindow?

    /// Any keyboard, mouse or trackpad input (`kCGAnyInputEventType`).
    private static let anyInput = unsafeBitCast(UInt32.max, to: CGEventType.self)

    init(engine: TimerEngine) {
        self.engine = engine
        super.init()
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.willSleep() }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.didWake() }
        })
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                self?.poll()
            }
        }
        #if DEBUG
        // `-TrackKarSimulateAwayMinutes N` reports N minutes away shortly after launch.
        let simulated = UserDefaults.standard.integer(forKey: "TrackKarSimulateAwayMinutes")
        if simulated > 0 {
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(2))
                let now = Date.now
                self?.report(AwayInterval(start: now.addingTimeInterval(-TimeInterval(simulated * 60)), end: now.addingTimeInterval(-30)))
            }
        }
        #endif
    }

    private var threshold: TimeInterval {
        TimeInterval(TimerSettings.current.awayThresholdMinutes * 60)
    }

    private func poll() {
        detector.threshold = threshold
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: Self.anyInput)
        if let away = detector.update(now: .now, idleSeconds: idle, isTracking: engine.state == .running) {
            report(away)
        }
    }

    private func willSleep() {
        sleepStartedAt = .now
        wasTrackingAtSleep = engine.state == .running
    }

    private func didWake() {
        detector.threshold = threshold
        guard let start = sleepStartedAt else { return }
        sleepStartedAt = nil
        if let away = detector.sleepEnded(from: start, to: .now, wasTracking: wasTrackingAtSleep) {
            report(away)
        }
    }

    private func report(_ away: AwayInterval) {
        engine.reportAway(away)
        if engine.pendingAway != nil { showPrompt() }
    }

    // MARK: Prompt

    private func showPrompt() {
        if let promptWindow {
            promptWindow.makeKeyAndOrderFront(nil)
        } else {
            let view = AwayPromptView { [weak self] choice in self?.choose(choice) }
                .environment(engine)
                .themedRoot()
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = String(localized: "Welcome Back")
            window.styleMask = [.titled, .closable]
            window.level = .floating
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            promptWindow = window
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func choose(_ choice: AwayChoice) {
        engine.resolveAway(choice)
        promptWindow?.close()
    }

    /// Closing the window without choosing keeps the time, the choice that loses nothing.
    func windowWillClose(_ notification: Notification) {
        if engine.pendingAway != nil { engine.resolveAway(.keep) }
        promptWindow = nil
    }
}

/// "You were away for 45m. Remove it, remove it and pause, or keep it?"
struct AwayPromptView: View {
    let onChoose: (AwayChoice) -> Void

    @Environment(TimerEngine.self) private var engine
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 34))
                .foregroundStyle(theme.accent)
                .accessibilityHidden(true)

            if let away = engine.pendingAway {
                let length = DurationFormat.short(away.duration)
                VStack(spacing: 6) {
                    Text("You were away for \(length)")
                        .font(.title3.weight(.semibold))
                    Text(detail(away))
                        .foregroundStyle(theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 8) {
                    choice("Remove \(length) and keep going", prominent: true, .discard)
                        .keyboardShortcut(.defaultAction)
                    choice("Remove \(length) and pause", .discardAndPause)
                    choice("Keep the time", .keep)
                        .keyboardShortcut(.cancelAction)
                }
                .controlSize(.large)
            }
        }
        .padding(24)
        .frame(width: 340)
    }

    private func detail(_ away: AwayInterval) -> String {
        let name = engine.activeEntry?.displayName ?? String(localized: "Your timer")
        let from = away.start.formatted(date: .omitted, time: .shortened)
        let to = away.end.formatted(date: .omitted, time: .shortened)
        return String(localized: "“\(name)” kept running from \(from) to \(to).")
    }

    private func choice(_ title: String, prominent: Bool = false, _ choice: AwayChoice) -> some View {
        Button {
            onChoose(choice)
        } label: {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .themedButton(prominent: prominent)
    }
}
