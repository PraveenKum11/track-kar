import Foundation
import SwiftData

enum TimerMode: String, Codable, CaseIterable, Identifiable {
    case stopwatch, timer, pomodoro

    var id: Self { self }

    var label: String {
        switch self {
        case .stopwatch: String(localized: "Stopwatch")
        case .timer: String(localized: "Timer")
        case .pomodoro: String(localized: "Pomodoro")
        }
    }
}

nonisolated enum PomodoroPhase: String, Codable {
    case focus, shortBreak, longBreak

    var isBreak: Bool { self != .focus }

    var breakKind: BreakKind? {
        switch self {
        case .focus: nil
        case .shortBreak: .shortBreak
        case .longBreak: .longBreak
        }
    }

    var label: String {
        switch self {
        case .focus: String(localized: "Focus")
        case .shortBreak: String(localized: "Short break")
        case .longBreak: String(localized: "Long break")
        }
    }

    var symbolName: String {
        switch self {
        case .focus: "brain"
        case .shortBreak, .longBreak: "cup.and.saucer.fill"
        }
    }
}

/// One tracked session, from start to stop. Its duration is the sum of its segments; breaks never count.
@Model
final class TimeEntry {
    var id: UUID = UUID()
    /// Free-text name. For entries with an activity this is a snapshot of the activity's name.
    var title: String = ""
    /// `nil` means an unsaved, ad-hoc entry.
    var activity: Activity?
    var modeRaw: String = TimerMode.stopwatch.rawValue
    var targetDuration: TimeInterval?
    var notes: String?
    var createdAt: Date = Date.now
    /// `nil` while the entry is active (running or paused).
    var endedAt: Date?

    // Countdown timer: when the target was reached (it may keep counting as overtime).
    var targetReachedAt: Date?

    // Pomodoro state, stored so a session survives quit and relaunch.
    var pomodoroPhaseRaw: String?
    /// When the current phase began; `nil` while waiting for the user to start it.
    var phaseStartedAt: Date?
    var completedFocusCount: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \Segment.entry)
    var segments: [Segment]? = []

    @Relationship(deleteRule: .cascade, inverse: \Break.entry)
    var breaks: [Break]? = []

    init(title: String, activity: Activity?, mode: TimerMode = .stopwatch, createdAt: Date) {
        self.title = title
        self.activity = activity
        self.modeRaw = mode.rawValue
        self.createdAt = createdAt
    }

    var mode: TimerMode {
        get { TimerMode(rawValue: modeRaw) ?? .stopwatch }
        set { modeRaw = newValue.rawValue }
    }

    var displayName: String {
        if let activity { return activity.name }
        return title.isEmpty ? String(localized: "Untitled") : title
    }

    var colorHex: String? { activity?.colorHex }

    var pomodoroPhase: PomodoroPhase? {
        get { pomodoroPhaseRaw.flatMap(PomodoroPhase.init(rawValue:)) }
        set { pomodoroPhaseRaw = newValue?.rawValue }
    }

    /// Closed segment time that started at or after `date`, e.g. focus done earlier in this phase.
    func closedSegmentTime(since date: Date) -> TimeInterval {
        (segments ?? []).reduce(0) { total, segment in
            guard segment.start >= date, let end = segment.end else { return total }
            return total + end.timeIntervalSince(segment.start)
        }
    }

    var isActive: Bool { endedAt == nil }
    var openSegment: Segment? { segments?.first { $0.end == nil } }
    var openBreak: Break? { breaks?.first { $0.end == nil } }
    var isRunning: Bool { openSegment != nil }
    var breakCount: Int { breaks?.count ?? 0 }

    func duration(at now: Date) -> TimeInterval {
        (segments ?? []).reduce(0) { $0 + $1.duration(at: now) }
    }

    /// Tracked time that falls inside `interval`, e.g. the part of an entry that ran today.
    func duration(in interval: DateInterval, at now: Date) -> TimeInterval {
        (segments ?? []).reduce(0) { total, segment in
            total + TimeMath.overlap(start: segment.start, end: segment.end ?? now, with: interval)
        }
    }
}
