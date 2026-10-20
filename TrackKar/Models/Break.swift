import Foundation
import SwiftData

enum BreakKind: String, Codable {
    case pause, shortBreak, longBreak
}

/// A pause or Pomodoro break. Counted for stats, never added to tracked time.
@Model
final class Break {
    var id: UUID = UUID()
    var kindRaw: String = BreakKind.pause.rawValue
    var start: Date = Date.now
    /// `nil` while the break is in progress.
    var end: Date?
    var entry: TimeEntry?

    init(kind: BreakKind, start: Date) {
        self.kindRaw = kind.rawValue
        self.start = start
    }

    var kind: BreakKind {
        get { BreakKind(rawValue: kindRaw) ?? .pause }
        set { kindRaw = newValue.rawValue }
    }

    func duration(at now: Date) -> TimeInterval {
        max(0, (end ?? now).timeIntervalSince(start))
    }
}
