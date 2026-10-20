import Foundation

enum DashboardPeriod: String, CaseIterable, Identifiable {
    case day, week, month, custom

    var id: Self { self }

    var label: String {
        switch self {
        case .day: String(localized: "Day")
        case .week: String(localized: "Week")
        case .month: String(localized: "Month")
        case .custom: String(localized: "Custom")
        }
    }
}

/// The period the Dashboard shows: a day, week or month (stepped back with `offset`), or a custom range.
struct DashboardRange: Equatable {
    var period: DashboardPeriod = .week
    /// 0 is the current period, -1 the one before, and so on.
    var offset = 0
    /// Inclusive days for `.custom`.
    var customStart = Calendar.current.date(byAdding: .day, value: -13, to: .now) ?? .now
    var customEnd = Date.now

    func interval(calendar: Calendar, now: Date) -> DateInterval {
        interval(offset: offset, calendar: calendar, now: now)
    }

    /// The period of the same kind just before, for comparisons.
    func previousInterval(calendar: Calendar, now: Date) -> DateInterval {
        guard period == .custom else { return interval(offset: offset - 1, calendar: calendar, now: now) }
        let current = interval(calendar: calendar, now: now)
        return DateInterval(start: current.start.addingTimeInterval(-current.duration), end: current.start)
    }

    private func interval(offset: Int, calendar: Calendar, now: Date) -> DateInterval {
        let component: Calendar.Component
        switch period {
        case .day: component = .day
        case .week: component = .weekOfYear
        case .month: component = .month
        case .custom:
            let first = calendar.startOfDay(for: min(customStart, customEnd))
            let last = calendar.startOfDay(for: max(customStart, customEnd))
            let end = calendar.date(byAdding: .day, value: 1, to: last) ?? last
            return DateInterval(start: first, end: end)
        }
        let reference = calendar.date(byAdding: component, value: offset, to: now) ?? now
        return calendar.dateInterval(of: component, for: reference) ?? DateInterval(start: reference, duration: 0)
    }

    /// "Today", "Last week", "September 2026"…
    func title(calendar: Calendar, now: Date) -> String {
        let interval = interval(calendar: calendar, now: now)
        switch (period, offset) {
        case (.day, 0): return String(localized: "Today")
        case (.day, -1): return String(localized: "Yesterday")
        case (.day, _): return interval.start.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        case (.week, 0): return String(localized: "This week")
        case (.week, -1): return String(localized: "Last week")
        case (.month, 0): return String(localized: "This month")
        case (.month, -1): return String(localized: "Last month")
        case (.month, _): return interval.start.formatted(.dateTime.month(.wide).year())
        case (.week, _), (.custom, _): return dateRange(calendar: calendar, now: now)
        }
    }

    /// "13 – 19 Oct 2026"
    func dateRange(calendar: Calendar, now: Date) -> String {
        let interval = interval(calendar: calendar, now: now)
        let lastDay = interval.end.addingTimeInterval(-1)
        guard !calendar.isDate(interval.start, inSameDayAs: lastDay) else {
            return interval.start.formatted(.dateTime.day().month(.abbreviated).year())
        }
        return (interval.start..<lastDay).formatted(.interval.day().month(.abbreviated).year())
    }

    /// "previous week" etc., for comparisons.
    var previousLabel: String {
        switch period {
        case .day: String(localized: "the day before")
        case .week: String(localized: "the week before")
        case .month: String(localized: "the month before")
        case .custom: String(localized: "the period before")
        }
    }
}
