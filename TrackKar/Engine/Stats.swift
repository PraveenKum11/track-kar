import Foundation

/// One bar segment in a per-day chart.
nonisolated struct DailyAmount: Identifiable, Equatable {
    var day: Date
    var series: String
    var colorHex: String
    var seconds: TimeInterval

    var id: String { "\(day.timeIntervalSinceReferenceDate)-\(series)" }
    var hours: Double { seconds / 3_600 }
}

/// Pure aggregation, usable from SwiftData models, which aren't main-actor isolated.
nonisolated enum Stats {
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

    /// Per-day time for each activity. The `maxSeries - 1` largest activities keep their own
    /// series; the rest fold into "Other" so colors are never reused within one chart.
    static func dailyAmounts(
        for activities: [Activity],
        days: [DateInterval],
        at now: Date,
        maxSeries: Int = 8
    ) -> [DailyAmount] {
        let ranked = activities
            .map { ($0, total(of: $0.entries ?? [], at: now)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
        let needsOther = ranked.count > maxSeries
        let named = needsOther ? Array(ranked.prefix(maxSeries - 1)) : ranked
        let folded = needsOther ? Array(ranked.dropFirst(maxSeries - 1)) : []
        let other = String(localized: "Other")

        var amounts: [DailyAmount] = []
        for day in days {
            for activity in named {
                let seconds = total(of: activity.entries ?? [], in: day, at: now)
                if seconds > 0 {
                    amounts.append(DailyAmount(day: day.start, series: activity.name, colorHex: activity.colorHex, seconds: seconds))
                }
            }
            let otherSeconds = folded.reduce(0) { $0 + total(of: $1.entries ?? [], in: day, at: now) }
            if otherSeconds > 0 {
                amounts.append(DailyAmount(day: day.start, series: other, colorHex: ActivityPalette.neutral, seconds: otherSeconds))
            }
        }
        return amounts
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
