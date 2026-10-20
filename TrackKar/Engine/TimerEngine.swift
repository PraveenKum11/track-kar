import Foundation
import Observation
import OSLog
import SwiftData

enum TrackingState: Equatable {
    case idle, running, paused
}

/// The single source of truth for the active time entry. Only this type mutates active entries.
///
/// Time is stored as segment timestamps and recomputed on demand, so a running timer survives sleep,
/// quit and crashes. `now` only drives re-rendering; it never accumulates time.
@Observable
final class TimerEngine {
    private(set) var activeEntry: TimeEntry?
    /// Refreshed every second while running so views re-render.
    private(set) var now: Date
    /// The entry whose "Save as activity?" question is waiting for an answer.
    private(set) var savePromptEntry: TimeEntry?

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private let ticks: Bool
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private let logger = Logger(subsystem: "com.praveenkumar.TrackKar", category: "TimerEngine")

    init(context: ModelContext, clock: @escaping () -> Date = { .now }, ticks: Bool = true) {
        self.context = context
        self.clock = clock
        self.ticks = ticks
        self.now = clock()
        restoreActiveEntry()
        updateTicker()
    }

    var state: TrackingState {
        guard let activeEntry else { return .idle }
        return activeEntry.isRunning ? .running : .paused
    }

    var elapsed: TimeInterval { activeEntry?.duration(at: now) ?? 0 }

    // MARK: - Actions

    /// Starts tracking `title`, reusing a saved activity with the same name if there is one.
    func start(title: String, newActivityBehavior: NewActivityBehavior) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty, let activity = ActivityLookup.activity(named: title, in: context) {
            start(activity: activity)
            return
        }

        stop()
        let entry = beginEntry(title: title, activity: nil)
        savePromptEntry = nil
        if !title.isEmpty {
            switch newActivityBehavior {
            case .ask: savePromptEntry = entry
            case .alwaysSave: ActivityLookup.promote(title: title, in: context, at: clock())
            case .neverSave: break
            }
        }
        commit()
    }

    func start(activity: Activity) {
        stop()
        beginEntry(title: activity.name, activity: activity)
        savePromptEntry = nil
        commit()
    }

    func pause() {
        guard let entry = activeEntry, let segment = entry.openSegment else { return }
        let time = clock()
        segment.end = time
        let pause = Break(kind: .pause, start: time)
        context.insert(pause)
        pause.entry = entry
        commit()
    }

    func resume() {
        guard let entry = activeEntry, entry.openSegment == nil else { return }
        let time = clock()
        entry.openBreak?.end = time
        let segment = Segment(start: time)
        context.insert(segment)
        segment.entry = entry
        commit()
    }

    func togglePause() {
        switch state {
        case .running: pause()
        case .paused: resume()
        case .idle: break
        }
    }

    func stop() {
        guard let entry = activeEntry else { return }
        close(entry, at: clock())
        activeEntry = nil
        commit()
    }

    func saveActivityFromPrompt() {
        guard let entry = savePromptEntry else { return }
        ActivityLookup.promote(title: entry.title, in: context, at: clock())
        savePromptEntry = nil
        commit()
    }

    func dismissSavePrompt() {
        savePromptEntry = nil
    }

    // MARK: - Internals

    @discardableResult
    private func beginEntry(title: String, activity: Activity?) -> TimeEntry {
        let time = clock()
        let entry = TimeEntry(title: title, activity: activity, createdAt: time)
        context.insert(entry)
        let segment = Segment(start: time)
        context.insert(segment)
        segment.entry = entry
        activeEntry = entry
        return entry
    }

    private func close(_ entry: TimeEntry, at time: Date) {
        if let segment = entry.openSegment {
            segment.end = time
            entry.endedAt = time
        } else {
            // Stopped while paused: the session really ended when the pause began,
            // so the trailing pause is not a break.
            if let pause = entry.openBreak {
                entry.breaks?.removeAll { $0 == pause }
                context.delete(pause)
            }
            entry.endedAt = entry.segments?.compactMap(\.end).max() ?? time
        }
    }

    /// Picks up an entry left running or paused by a previous launch.
    private func restoreActiveEntry() {
        let descriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let open = (try? context.fetch(descriptor)) ?? []
        activeEntry = open.first
        // Only one entry may be active; close any strays where they last ran.
        for stray in open.dropFirst() {
            let lastEnd = stray.segments?.compactMap(\.end).max() ?? stray.createdAt
            close(stray, at: lastEnd)
        }
        if open.count > 1 { save() }
    }

    private func commit() {
        save()
        updateTicker()
    }

    private func save() {
        do {
            try context.save()
        } catch {
            logger.error("Saving failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func updateTicker() {
        now = clock()
        guard ticks else { return }
        if state == .running {
            guard tickTask == nil else { return }
            tickTask = Task { [weak self] in
                while !Task.isCancelled {
                    // Wake on whole seconds so the display flips in step with the wall clock.
                    let fraction = Date.now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1)
                    try? await Task.sleep(for: .seconds(1 - fraction))
                    guard let self else { return }
                    self.now = self.clock()
                }
            }
        } else {
            tickTask?.cancel()
            tickTask = nil
        }
    }
}
