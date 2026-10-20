import SwiftUI

/// "How much time have I put into interview prep so far?"
struct GroupDetailView: View {
    let group: ActivityGroup
    let onEdit: () -> Void

    @Environment(TimerEngine.self) private var engine
    @Environment(\.appTheme) private var theme
    @AppStorage(PreferenceKey.firstWeekday) private var firstWeekday: FirstWeekday = .system

    private var activities: [Activity] {
        (group.activities ?? []).sorted { $0.totalDuration(at: engine.now) > $1.totalDuration(at: engine.now) }
    }

    var body: some View {
        let now = engine.now
        let entries = group.entries
        let total = Stats.total(of: entries, at: now)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(total: total)

                if activities.isEmpty {
                    ContentUnavailableView(
                        "No Activities in This Group",
                        systemImage: "folder",
                        description: Text("Edit the group to add activities, or drag activities onto it in the sidebar.")
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    summaryTiles(entries: entries, total: total)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last 30 days")
                            .font(.headline)
                        let days = Stats.days(endingAt: now, count: 30, calendar: firstWeekday.calendar)
                        DailyStackedChart(
                            amounts: Stats.dailyAmounts(for: activities, days: days, at: now),
                            buckets: days,
                            emptyMessage: "No time tracked in the last 30 days."
                        )
                        .frame(height: 220)
                    }
                    .padding()
                    .themedSurface(cornerRadius: 12)

                    breakdown(total: total, now: now)
                }
            }
            .padding(24)
        }
        .navigationTitle(group.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onEdit) {
                    Label("Edit Group", systemImage: "pencil")
                }
            }
        }
    }

    private func header(total: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(Color.activity(group.colorHex))
                Text(group.name)
                    .font(.title2.weight(.semibold))
            }
            Text(DurationFormat.short(total))
                .font(.system(size: 44, weight: .light, design: .rounded))
                .monospacedDigit()
            Text("tracked in total")
                .foregroundStyle(theme.secondaryText)

            if let targetHours = group.targetHours, targetHours > 0 {
                let target = targetHours * 3_600
                ProgressView(value: min(total, target), total: target) {
                    Text("\(DurationFormat.short(total)) of \(DurationFormat.short(target))")
                        .font(.callout)
                } currentValueLabel: {
                    Text((total / target).formatted(.percent.precision(.fractionLength(0))))
                }
                .frame(maxWidth: 420)
                .padding(.top, 6)
            }
        }
    }

    private func summaryTiles(entries: [TimeEntry], total: TimeInterval) -> some View {
        let first = entries.map(\.createdAt).min()
        let last = entries.map(\.createdAt).max()
        let trackedDays = Set(entries.map { Calendar.current.startOfDay(for: $0.createdAt) }).count

        return HStack(alignment: .top, spacing: 12) {
            tile("Sessions", value: entries.count.formatted())
            tile("Days tracked", value: trackedDays.formatted())
            tile("Average per day", value: trackedDays > 0 ? DurationFormat.short(total / Double(trackedDays)) : "–")
            tile("First session", value: first?.formatted(date: .abbreviated, time: .omitted) ?? "–")
            tile("Last session", value: last?.formatted(.relative(presentation: .named)) ?? "–")
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func tile(_ title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
            Text(value)
                .font(.title3)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .themedSurface(cornerRadius: 10)
    }

    private func breakdown(total: TimeInterval, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("By activity")
                .font(.headline)
            ForEach(activities) { activity in
                let seconds = activity.totalDuration(at: now)
                let share = total > 0 ? seconds / total : 0
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Circle()
                            .fill(Color.activity(activity.colorHex))
                            .frame(width: 8, height: 8)
                        Text(activity.name)
                        Spacer()
                        Text(DurationFormat.short(seconds))
                            .monospacedDigit()
                        Text(share.formatted(.percent.precision(.fractionLength(0))))
                            .monospacedDigit()
                            .foregroundStyle(theme.secondaryText)
                            .frame(width: 44, alignment: .trailing)
                    }
                    GeometryReader { proxy in
                        Capsule()
                            .fill(Color.activity(activity.colorHex))
                            .frame(width: max(2, proxy.size.width * share))
                    }
                    .frame(height: 4)
                }
            }
        }
        .padding()
        .themedSurface(cornerRadius: 12)
    }
}
