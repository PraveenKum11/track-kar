import Foundation
import SwiftData

enum TimerMode: String, Codable {
    case stopwatch, timer, pomodoro
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
