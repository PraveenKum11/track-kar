import SwiftData
import SwiftUI

/// Today's total with a thin bar split by activity, so you can see where the day went.
/// `accessory` sits at the end of the total's row (the popover puts its footer buttons there).
struct TodaySummary<Accessory: View>: View {
    let day: DateInterval
    let now: Date
    let accessory: Accessory

    @Environment(\.appTheme) private var theme
    @Query private var entries: [TimeEntry]

    init(day: DateInterval, now: Date, @ViewBuilder accessory: () -> Accessory) {
        self.day = day
        self.now = now
        self.accessory = accessory()
        let dayStart = day.start
        let openEnded = Date.distantFuture
        _entries = Query(filter: #Predicate<TimeEntry> { ($0.endedAt ?? openEnded) > dayStart })
    }

    private struct Slice: Identifiable {
        let id: String
        let name: String
        let color: Color
        let seconds: TimeInterval
    }

    /// Largest first; unsaved and untitled time shares one neutral slice.
    private var slices: [Slice] {
        var byKey: [String: Slice] = [:]
        for entry in entries {
            let seconds = entry.duration(in: day, at: now)
            guard seconds > 0 else { continue }
            let key = entry.activity.map { "\($0.persistentModelID)" } ?? "unsaved"
            let name = entry.activity?.name ?? String(localized: "Unsaved")
            let color = entry.colorHex.map(Color.activity) ?? Color.activity(ActivityPalette.neutral)
            let previous = byKey[key]?.seconds ?? 0
            byKey[key] = Slice(id: key, name: name, color: color, seconds: previous + seconds)
        }
        return byKey.values.sorted { $0.seconds > $1.seconds }
    }

    var body: some View {
        let slices = slices
        let total = slices.reduce(0) { $0 + $1.seconds }

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Today")
                    .foregroundStyle(theme.secondaryText)
                Text(DurationFormat.short(total))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                Spacer(minLength: 12)
                accessory
            }
            .font(.callout)

            if total > 0 {
                GeometryReader { proxy in
                    let gaps = CGFloat(max(0, slices.count - 1)) * 2
                    HStack(spacing: 2) {
                        ForEach(slices) { slice in
                            Capsule()
                                .fill(slice.color)
                                .frame(width: max(3, (proxy.size.width - gaps) * slice.seconds / total))
                                .help("\(slice.name): \(DurationFormat.short(slice.seconds))")
                        }
                    }
                }
                .frame(height: 5)
                .accessibilityElement()
                .accessibilityLabel("Today by activity")
                .accessibilityValue(slices.map { "\($0.name) \(DurationFormat.short($0.seconds))" }.joined(separator: ", "))
            }
        }
    }
}
