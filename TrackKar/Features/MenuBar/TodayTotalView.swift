import SwiftData
import SwiftUI

/// Total tracked time today, including the part of entries that crossed midnight.
struct TodayTotalView: View {
    let day: DateInterval
    let now: Date

    @Environment(\.appTheme) private var theme
    @Query private var entries: [TimeEntry]

    init(day: DateInterval, now: Date) {
        self.day = day
        self.now = now
        let dayStart = day.start
        let openEnded = Date.distantFuture
        _entries = Query(filter: #Predicate<TimeEntry> { ($0.endedAt ?? openEnded) > dayStart })
    }

    var body: some View {
        let total = entries.reduce(0) { $0 + $1.duration(in: day, at: now) }
        Text("Today \(DurationFormat.short(total))")
            .font(.callout)
            .monospacedDigit()
            .foregroundStyle(theme.secondaryText)
    }
}
