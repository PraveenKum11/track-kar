import Foundation

/// Pure date math, usable from SwiftData models, which aren't main-actor isolated.
nonisolated enum TimeMath {
    /// Length of the part of `start...end` that falls inside `interval`.
    static func overlap(start: Date, end: Date, with interval: DateInterval) -> TimeInterval {
        let clippedStart = max(start, interval.start)
        let clippedEnd = min(end, interval.end)
        return max(0, clippedEnd.timeIntervalSince(clippedStart))
    }
}

enum DurationFormat {
    /// `1:24:05`
    static func clock(_ seconds: TimeInterval) -> String {
        Duration.seconds(Int(seconds)).formatted(.time(pattern: .hourMinuteSecond))
    }

    /// `1:24`
    static func clockNoSeconds(_ seconds: TimeInterval) -> String {
        Duration.seconds(Int(seconds) / 60 * 60).formatted(.time(pattern: .hourMinute))
    }

    /// `3h 42m`, rounded down like `clock`. Time under a minute reads `<1m`, not `0m`.
    static func short(_ seconds: TimeInterval) -> String {
        if seconds > 0, seconds < 60 { return String(localized: "<1m") }
        return Duration.seconds(Int(seconds)).formatted(
            .units(allowed: [.hours, .minutes], width: .narrow, fractionalPart: .hide(rounded: .down))
        )
    }
}
