import Foundation

/// A stretch when nobody was at the Mac while a timer ran.
struct AwayInterval: Equatable {
    var start: Date
    var end: Date

    var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// What to do with time away.
enum AwayChoice {
    /// Count it as tracked time.
    case keep
    /// Remove it and keep the timer running.
    case discard
    /// Remove it and leave the timer paused from when the user left.
    case discardAndPause
}

/// Turns idle-time readings and sleep/wake events into away intervals. Pure, so it can be tested
/// without a real idle Mac; `AwayMonitor` feeds it.
struct AwayDetector {
    /// How long without input (or asleep) counts as away. 0 turns detection off.
    var threshold: TimeInterval
    /// Input within this many seconds means the user is back.
    var returnTolerance: TimeInterval = 5
    private(set) var awaySince: Date?

    init(threshold: TimeInterval) {
        self.threshold = threshold
    }

    /// Call periodically while a timer runs. Returns the away interval once the user comes back.
    mutating func update(now: Date, idleSeconds: TimeInterval, isTracking: Bool) -> AwayInterval? {
        guard isTracking, threshold > 0 else {
            awaySince = nil
            return nil
        }
        if idleSeconds >= threshold {
            if awaySince == nil { awaySince = now.addingTimeInterval(-idleSeconds) }
            return nil
        }
        guard let since = awaySince, idleSeconds < returnTolerance else { return nil }
        awaySince = nil
        // The user came back at their latest input, not when this reading happened.
        return AwayInterval(start: since, end: now.addingTimeInterval(-idleSeconds))
    }

    /// Call on wake. A sleep counts as away when it was long enough.
    mutating func sleepEnded(from start: Date, to end: Date, wasTracking: Bool) -> AwayInterval? {
        awaySince = nil
        guard wasTracking, threshold > 0, end.timeIntervalSince(start) >= threshold else { return nil }
        return AwayInterval(start: start, end: end)
    }
}
