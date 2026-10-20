import Foundation
import SwiftData

/// A continuous running interval inside a time entry. Pausing closes it; resuming opens a new one.
@Model
final class Segment {
    var id: UUID = UUID()
    var start: Date = Date.now
    /// `nil` while running.
    var end: Date?
    var entry: TimeEntry?

    init(start: Date) {
        self.start = start
    }

    func duration(at now: Date) -> TimeInterval {
        max(0, (end ?? now).timeIntervalSince(start))
    }
}
