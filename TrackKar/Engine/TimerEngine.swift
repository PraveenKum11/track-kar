import Foundation
import Observation
import OSLog
import SwiftData

enum TrackingState: Equatable {
    case idle, running, paused
}

/// Something to start tracking: a saved activity or a typed name.
enum StartTarget: Equatable {
    case activity(Activity)
    case title(String)

    var displayName: String {
        switch self {
        case .activity(let activity): activity.name
        case .title(let title): title.nilIfBlank ?? String(localized: "Untitled")
        }
    }
}

/// What to do with the running entry when starting something else.
enum SwitchChoice {
    /// Keep the current entry in History and start a new one.
    case saveAndSwitch
    /// Keep the timer running, but count its time toward the new target.
    case moveTime
    /// Delete the current entry and start a new one.
    case discard
}

/// Remaining time for a countdown or the current Pomodoro phase.
struct CountdownStatus: Equatable {
    var total: TimeInterval
    /// Negative once a countdown runs into overtime.
    var remaining: TimeInterval
    var phase: PomodoroPhase?
    /// The phase hasn't been started yet (auto-start is off, or the Mac slept through a phase end).
    var isWaiting = false
    var completedFocus = 0
    var cyclesBeforeLongBreak = 4

    var isOvertime: Bool { remaining < 0 }
    var progress: Double { total > 0 ? min(1, max(0, 1 - remaining / total)) : 0 }
}

/// The single source of truth for the active time entry. Only this type mutates active entries.
///
/// Time is stored as segment timestamps and recomputed on demand, so a running timer survives sleep,
/// quit and crashes. `now` only drives re-rendering; it never accumulates time.
@Observable
final class TimerEngine {
    private(set) var activeEntry: TimeEntry?
    /// Refreshed every second while an entry is active so views re-render (and a paused time can blink).
    private(set) var now: Date
    /// The entry whose "Save as activity?" question is waiting for an answer.
    private(set) var savePromptEntry: TimeEntry?

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private let settings: () -> TimerSettings
    @ObservationIgnored private let notifier: TimerNotifying
    @ObservationIgnored private let ticks: Bool
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private let logger = Logger(subsystem: "com.praveenkumar.TrackKar", category: "TimerEngine")

    init(
        context: ModelContext,
        clock: @escaping () -> Date = { .now },
        settings: @escaping () -> TimerSettings = { .current },
        notifier: TimerNotifying = SilentNotifier(),
        ticks: Bool = true
    ) {
        self.context = context
        self.clock = clock
        self.settings = settings
        self.notifier = notifier
        self.ticks = ticks
        self.now = clock()
        restoreActiveEntry()
        advanceTimers()
        commit()
    }

    var state: TrackingState {
        guard let activeEntry else { return .idle }
        return activeEntry.isRunning ? .running : .paused
    }

    var elapsed: TimeInterval { activeEntry?.duration(at: now) ?? 0 }

    var countdown: CountdownStatus? {
        guard let entry = activeEntry else { return nil }
        let settings = settings()
        switch entry.mode {
        case .stopwatch:
            return nil
        case .timer:
            guard let target = entry.targetDuration else { return nil }
            return CountdownStatus(total: target, remaining: target - entry.duration(at: now))
        case .pomodoro:
            guard let phase = entry.pomodoroPhase else { return nil }
            let total = settings.length(of: phase)
            var status = CountdownStatus(
                total: total,
                remaining: total,
                phase: phase,
                completedFocus: entry.completedFocusCount,
                cyclesBeforeLongBreak: settings.cyclesBeforeLongBreak
            )
            guard let phaseStart = entry.phaseStartedAt else {
                status.isWaiting = true
                return status
            }
            let spent = phase.isBreak
                ? now.timeIntervalSince(phaseStart)
                : entry.closedSegmentTime(since: phaseStart) + (entry.openSegment.map { now.timeIntervalSince($0.start) } ?? 0)
            status.remaining = max(0, total - spent)
            return status
        }
    }

    // MARK: - Actions

    /// Starts tracking `title`, reusing a saved activity with the same name if there is one.
    func start(title: String, kind: TimerKind = .stopwatch, newActivityBehavior: NewActivityBehavior) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty, let activity = ActivityLookup.activity(named: title, in: context) {
            start(activity: activity, kind: kind)
            return
        }

        stop()
        let entry = beginEntry(title: title, activity: nil, kind: kind)
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

    func start(activity: Activity, kind: TimerKind = .stopwatch) {
        stop()
        beginEntry(title: activity.name, activity: activity, kind: kind)
        savePromptEntry = nil
        commit()
    }

    func start(_ target: StartTarget, kind: TimerKind = .stopwatch, newActivityBehavior: NewActivityBehavior) {
        switch target {
        case .activity(let activity): start(activity: activity, kind: kind)
        case .title(let title): start(title: title, kind: kind, newActivityBehavior: newActivityBehavior)
        }
    }

    /// Starting `target` would end a running or paused entry, so the user should choose what
    /// happens to it. Re-selecting what's already being tracked isn't a switch.
    func needsSwitchConfirmation(for target: StartTarget) -> Bool {
        guard let entry = activeEntry else { return false }
        switch target {
        case .activity(let activity):
            return entry.activity != activity
        case .title(let title):
            let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            return title.localizedCaseInsensitiveCompare(entry.displayName) != .orderedSame
        }
    }

    func switchActiveEntry(
        to target: StartTarget,
        choice: SwitchChoice,
        kind: TimerKind = .stopwatch,
        newActivityBehavior: NewActivityBehavior
    ) {
        switch choice {
        case .saveAndSwitch:
            start(target, kind: kind, newActivityBehavior: newActivityBehavior)
        case .discard:
            discardActiveEntry()
            start(target, kind: kind, newActivityBehavior: newActivityBehavior)
        case .moveTime:
            moveActiveEntry(to: target, newActivityBehavior: newActivityBehavior)
        }
    }

    /// Deletes the running or paused entry without saving it.
    func discardActiveEntry() {
        guard let entry = activeEntry else { return }
        activeEntry = nil
        if entry == savePromptEntry { savePromptEntry = nil }
        context.delete(entry)
        commit()
    }

    /// Re-labels the running entry; its time so far now counts toward `target`.
    func moveActiveEntry(to target: StartTarget, newActivityBehavior: NewActivityBehavior) {
        guard let entry = activeEntry else { return }
        savePromptEntry = nil
        switch target {
        case .activity(let activity):
            EntryEditing.assign(entry, to: activity, title: activity.name)
        case .title(let title):
            let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty, let activity = ActivityLookup.activity(named: title, in: context) {
                EntryEditing.assign(entry, to: activity, title: activity.name)
            } else {
                EntryEditing.assign(entry, to: nil, title: title)
                if !title.isEmpty {
                    switch newActivityBehavior {
                    case .ask: savePromptEntry = entry
                    case .alwaysSave: ActivityLookup.promote(title: title, in: context, at: clock())
                    case .neverSave: break
                    }
                }
            }
        }
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
        // A Pomodoro break or a phase waiting to start isn't a pause; use start/skip instead.
        if entry.mode == .pomodoro, entry.pomodoroPhase != .focus || entry.phaseStartedAt == nil { return }
        let time = clock()
        entry.openBreak?.end = time
        let segment = Segment(start: time)
        context.insert(segment)
        segment.entry = entry
        commit()
    }

    /// Starts a Pomodoro phase that is waiting for the user.
    func startPhase() {
        guard let entry = activeEntry, let phase = entry.pomodoroPhase, entry.phaseStartedAt == nil else { return }
        let time = clock()
        if phase.isBreak {
            beginBreak(phase, for: entry, at: time)
        } else {
            beginFocus(for: entry, at: time)
        }
        commit()
    }

    /// Ends the current Pomodoro phase now and starts the next one. Skipping focus counts it as done.
    func skipPhase() {
        guard let entry = activeEntry, let phase = entry.pomodoroPhase else { return }
        let time = clock()
        if entry.phaseStartedAt == nil {
            guard phase.isBreak else { return }
            entry.pomodoroPhase = .focus
            beginFocus(for: entry, at: time)
        } else {
            finishPhase(of: entry, at: time, startNext: true)
        }
        commit()
    }

    /// Call after the Timers settings change so deadlines and notifications follow.
    func timerSettingsChanged() {
        advanceTimers()
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

    /// Deletes finished entries. The active entry is skipped; stop it first.
    func delete(_ entries: [TimeEntry]) {
        for entry in entries where entry != activeEntry {
            if entry == savePromptEntry { savePromptEntry = nil }
            context.delete(entry)
        }
        commit()
    }

    /// Persists edits made elsewhere (History, Activities) and refreshes dependent views.
    func saveChanges() {
        commit()
    }

    /// Tracked time today, including the part of entries that crossed midnight.
    func todayTotal(calendar: Calendar = .current) -> TimeInterval {
        let reference = state == .running ? now : clock()
        guard let today = calendar.dateInterval(of: .day, for: reference) else { return 0 }
        let dayStart = today.start
        let openEnded = Date.distantFuture
        let descriptor = FetchDescriptor<TimeEntry>(predicate: #Predicate { ($0.endedAt ?? openEnded) > dayStart })
        let entries = (try? context.fetch(descriptor)) ?? []
        return Stats.total(of: entries, in: today, at: reference)
    }

    // MARK: - Internals

    @discardableResult
    private func beginEntry(title: String, activity: Activity?, kind: TimerKind) -> TimeEntry {
        let time = clock()
        let entry = TimeEntry(title: title, activity: activity, createdAt: time)
        context.insert(entry)
        switch kind {
        case .stopwatch:
            break
        case .countdown(let duration):
            entry.mode = .timer
            entry.targetDuration = duration
        case .pomodoro:
            entry.mode = .pomodoro
            entry.pomodoroPhase = .focus
            entry.phaseStartedAt = time
        }
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
            // Stopped while paused or on a break: the session really ended when work last
            // stopped, so the trailing pause or break is not counted.
            if let trailing = entry.openBreak {
                entry.breaks?.removeAll { $0 == trailing }
                context.delete(trailing)
            }
            entry.endedAt = entry.segments?.compactMap(\.end).max() ?? time
        }
    }

    // MARK: - Countdown and Pomodoro

    /// When the running countdown or current Pomodoro phase ends, if it's counting down.
    private func deadline(of entry: TimeEntry) -> Date? {
        switch entry.mode {
        case .stopwatch:
            return nil
        case .timer:
            guard entry.targetReachedAt == nil, let target = entry.targetDuration, let open = entry.openSegment else { return nil }
            // Time before the open segment, plus whatever is left of the target.
            return open.start + (target - entry.duration(at: open.start))
        case .pomodoro:
            guard let phase = entry.pomodoroPhase, let phaseStart = entry.phaseStartedAt else { return nil }
            let length = settings().length(of: phase)
            if phase.isBreak { return phaseStart + length }
            guard let open = entry.openSegment else { return nil }
            return open.start + (length - entry.closedSegmentTime(since: phaseStart))
        }
    }

    /// Applies countdown ends and Pomodoro phase changes that are due, at their exact times.
    private func advanceTimers() {
        guard let entry = activeEntry else { return }
        let time = clock()
        var changed = false
        switch entry.mode {
        case .stopwatch:
            break
        case .timer:
            if let deadline = deadline(of: entry), deadline <= time {
                entry.targetReachedAt = deadline
                if settings().countdownEnd == .stop {
                    close(entry, at: deadline)
                    activeEntry = nil
                }
                changed = true
            }
        case .pomodoro:
            var steps = 0
            while steps < 20, let deadline = deadline(of: entry), deadline <= time {
                // If the Mac slept through a phase end, don't auto-start the next phase:
                // that would log focus time nobody did.
                let caughtUpLate = time.timeIntervalSince(deadline) > 60
                finishPhase(of: entry, at: deadline, startNext: false, allowAutoStart: !caughtUpLate)
                steps += 1
            }
            changed = steps > 0
        }
        if changed {
            notifier.didReachAlert()
            commit()
        }
    }

    private func finishPhase(of entry: TimeEntry, at time: Date, startNext: Bool, allowAutoStart: Bool = true) {
        let settings = settings()
        switch entry.pomodoroPhase {
        case .focus:
            entry.openSegment?.end = time
            // Skipping while paused ends that pause here.
            if let pause = entry.openBreak, pause.kind == .pause { pause.end = time }
            entry.completedFocusCount += 1
            let next = settings.breakPhase(afterCompletedFocus: entry.completedFocusCount)
            entry.pomodoroPhase = next
            if startNext || (settings.autoStartBreaks && allowAutoStart) {
                beginBreak(next, for: entry, at: time)
            } else {
                entry.phaseStartedAt = nil
            }
        case .shortBreak, .longBreak:
            entry.openBreak?.end = time
            entry.pomodoroPhase = .focus
            if startNext || (settings.autoStartFocus && allowAutoStart) {
                beginFocus(for: entry, at: time)
            } else {
                entry.phaseStartedAt = nil
            }
        case nil:
            break
        }
    }

    private func beginFocus(for entry: TimeEntry, at time: Date) {
        entry.phaseStartedAt = time
        let segment = Segment(start: time)
        context.insert(segment)
        segment.entry = entry
    }

    private func beginBreak(_ phase: PomodoroPhase, for entry: TimeEntry, at time: Date) {
        entry.phaseStartedAt = time
        let pause = Break(kind: phase.breakKind ?? .shortBreak, start: time)
        context.insert(pause)
        pause.entry = entry
    }

    /// The notification for the next countdown or phase end, if one is coming.
    private func nextAlert() -> TimerAlert? {
        guard let entry = activeEntry, let date = deadline(of: entry) else { return nil }
        let settings = settings()
        let name = entry.displayName
        switch (entry.mode, entry.pomodoroPhase) {
        case (.timer, _):
            let target = DurationFormat.short(entry.targetDuration ?? 0)
            return TimerAlert(date: date, title: String(localized: "Time's up"), body: String(localized: "\(name): \(target) done."))
        case (.pomodoro, .focus):
            let next = settings.breakPhase(afterCompletedFocus: entry.completedFocusCount + 1)
            let minutes = DurationFormat.short(settings.length(of: next))
            let body = settings.autoStartBreaks
                ? String(localized: "Your \(minutes) break has started.")
                : String(localized: "Take a \(minutes) break when you're ready.")
            return TimerAlert(date: date, title: String(localized: "Focus session done"), body: body)
        case (.pomodoro, _):
            let body = settings.autoStartFocus
                ? String(localized: "Back to \(name).")
                : String(localized: "Ready to focus on \(name)?")
            return TimerAlert(date: date, title: String(localized: "Break's over"), body: body)
        default:
            return nil
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
        notifier.schedule(nextAlert())
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
        if state != .idle {
            guard tickTask == nil else { return }
            tickTask = Task { [weak self] in
                while !Task.isCancelled {
                    // Wake on whole seconds so the display flips in step with the wall clock.
                    let fraction = Date.now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1)
                    try? await Task.sleep(for: .seconds(1 - fraction))
                    guard let self else { return }
                    self.now = self.clock()
                    self.advanceTimers()
                }
            }
        } else {
            tickTask?.cancel()
            tickTask = nil
        }
    }
}
