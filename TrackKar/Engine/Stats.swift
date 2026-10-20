import Foundation

/// One bar segment in a stacked chart. `day` is the start of its bucket (a day or a week).
nonisolated struct DailyAmount: Identifiable, Equatable {
    var day: Date
    var series: String
    var colorHex: String
    var seconds: TimeInterval

    var id: String { "\(day.timeIntervalSinceReferenceDate)-\(series)" }
    var hours: Double { seconds / 3_600 }
}

/// How time is split in breakdowns and charts.
nonisolated enum BreakdownGrouping: String, CaseIterable, Identifiable {
    case activity, group

    var id: Self { self }
}

/// Time for one activity or group within a range.
nonisolated struct BreakdownItem: Identifiable, Equatable {
    var key: String
    var name: String
    var colorHex: String
    var seconds: TimeInterval
    var sessions: Int

    var id: String { key }
}

/// Pauses and Pomodoro breaks that started within a range.
nonisolated struct BreakStats: Equatable {
    var count = 0
    var total: TimeInterval = 0

    var average: TimeInterval { count > 0 ? total / Double(count) : 0 }
}

/// Pure aggregation, usable from SwiftData models, which aren't main-actor isolated.
nonisolated enum Stats {
    /// Neutral for unsaved or ungrouped time, distinct from the default group gray.
    static let unassignedColorHex = "#B4B4BA"

    static func total(of entries: [TimeEntry], at now: Date) -> TimeInterval {
        entries.reduce(0) { $0 + $1.duration(at: now) }
    }

    static func total(of entries: [TimeEntry], in interval: DateInterval, at now: Date) -> TimeInterval {
        entries.reduce(0) { $0 + $1.duration(in: interval, at: now) }
    }

    /// The `count` whole days ending with the day containing `now`, oldest first.
    static func days(endingAt now: Date, count: Int, calendar: Calendar) -> [DateInterval] {
        let today = calendar.startOfDay(for: now)
        return (0..<count).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return calendar.dateInterval(of: .day, for: day)
        }
    }

    /// Chart buckets covering `interval`: days, or weeks once there would be too many bars.
    static func buckets(for interval: DateInterval, calendar: Calendar) -> (buckets: [DateInterval], unit: Calendar.Component) {
        let dayCount = calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 0
        let unit: Calendar.Component = dayCount > 62 ? .weekOfYear : .day
        var buckets: [DateInterval] = []
        var cursor = calendar.dateInterval(of: unit, for: interval.start)?.start ?? interval.start
        while cursor < interval.end, let bucket = calendar.dateInterval(of: unit, for: cursor) {
            buckets.append(bucket)
            cursor = bucket.end
        }
        return (buckets, unit)
    }

    /// Which activity or group an entry's time counts toward.
    private static func slot(for entry: TimeEntry, grouping: BreakdownGrouping) -> (key: String, name: String, colorHex: String) {
        switch grouping {
        case .activity:
            if let activity = entry.activity {
                return (activity.id.uuidString, activity.name, activity.colorHex)
            }
            return ("unsaved", String(localized: "Unsaved"), unassignedColorHex)
        case .group:
            if let group = entry.activity?.group {
                return (group.id.uuidString, group.name, group.colorHex)
            }
            return ("ungrouped", String(localized: "Ungrouped"), unassignedColorHex)
        }
    }

    /// Time per activity or group inside `interval`, largest first.
    static func breakdown(
        of entries: [TimeEntry],
        in interval: DateInterval,
        at now: Date,
        by grouping: BreakdownGrouping
    ) -> [BreakdownItem] {
        var items: [String: BreakdownItem] = [:]
        for entry in entries {
            let seconds = entry.duration(in: interval, at: now)
            guard seconds > 0 else { continue }
            let slot = slot(for: entry, grouping: grouping)
            var item = items[slot.key] ?? BreakdownItem(key: slot.key, name: slot.name, colorHex: slot.colorHex, seconds: 0, sessions: 0)
            item.seconds += seconds
            item.sessions += 1
            items[slot.key] = item
        }
        return items.values.sorted { $0.seconds == $1.seconds ? $0.name < $1.name : $0.seconds > $1.seconds }
    }

    /// Per-bucket time for each activity or group. The `maxSeries - 1` largest keep their own
    /// series; the rest fold into "Other" so colors are never reused within one chart.
    static func dailyAmounts(
        of entries: [TimeEntry],
        buckets: [DateInterval],
        at now: Date,
        by grouping: BreakdownGrouping = .activity,
        maxSeries: Int = 8
    ) -> [DailyAmount] {
        guard let first = buckets.first, let last = buckets.last else { return [] }
        let ranked = breakdown(of: entries, in: DateInterval(start: first.start, end: last.end), at: now, by: grouping)
        let needsOther = ranked.count > maxSeries
        let named = needsOther ? Array(ranked.prefix(maxSeries - 1)) : ranked
        let namedKeys = Set(named.map(\.key))
        let other = String(localized: "Other")

        var amounts: [DailyAmount] = []
        for bucket in buckets {
            let items = breakdown(of: entries, in: bucket, at: now, by: grouping)
            for item in named {
                if let match = items.first(where: { $0.key == item.key }) {
                    amounts.append(DailyAmount(day: bucket.start, series: item.name, colorHex: item.colorHex, seconds: match.seconds))
                }
            }
            let otherSeconds = items.filter { !namedKeys.contains($0.key) }.reduce(0) { $0 + $1.seconds }
            if otherSeconds > 0 {
                amounts.append(DailyAmount(day: bucket.start, series: other, colorHex: ActivityPalette.neutral, seconds: otherSeconds))
            }
        }
        return amounts
    }

    /// Per-day time for each of `activities` (the group page's chart).
    static func dailyAmounts(
        for activities: [Activity],
        days: [DateInterval],
        at now: Date,
        maxSeries: Int = 8
    ) -> [DailyAmount] {
        dailyAmounts(of: activities.flatMap { $0.entries ?? [] }, buckets: days, at: now, maxSeries: maxSeries)
    }

    static func breakStats(of entries: [TimeEntry], in interval: DateInterval, at now: Date) -> BreakStats {
        var stats = BreakStats()
        for entry in entries {
            for pause in entry.breaks ?? [] where interval.contains(pause.start) {
                stats.count += 1
                stats.total += pause.duration(at: now)
            }
        }
        return stats
    }

    /// Days of `interval` that have started by `now`, for per-day averages of the current period.
    static func elapsedDays(of interval: DateInterval, at now: Date, calendar: Calendar) -> Int {
        let end = min(interval.end, now)
        guard end > interval.start else { return 0 }
        let lastDay = calendar.startOfDay(for: end == interval.end ? end.addingTimeInterval(-1) : end)
        return (calendar.dateComponents([.day], from: calendar.startOfDay(for: interval.start), to: lastDay).day ?? 0) + 1
    }
}

extension Activity {
    func totalDuration(at now: Date) -> TimeInterval {
        Stats.total(of: entries ?? [], at: now)
    }

    var lastUsed: Date? {
        entries?.map(\.createdAt).max()
    }
}

extension ActivityGroup {
    var entries: [TimeEntry] {
        (activities ?? []).flatMap { $0.entries ?? [] }
    }

    func totalDuration(at now: Date) -> TimeInterval {
        Stats.total(of: entries, at: now)
    }
}
