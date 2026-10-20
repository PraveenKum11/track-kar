import SwiftData
import SwiftUI

/// One-click restart for the last few activities.
struct RecentChips: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(\.appTheme) private var theme
    @Query(Self.recentEntries) private var entries: [TimeEntry]

    private static var recentEntries: FetchDescriptor<TimeEntry> {
        var descriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate { $0.activity != nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 50
        return descriptor
    }

    private var activities: [Activity] {
        ActivityLookup.recentActivities(from: entries, excluding: engine.activeEntry?.activity, limit: 4)
    }

    var body: some View {
        if !activities.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Recent")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
                FlowLayout(spacing: 6) {
                    ForEach(activities) { activity in
                        Button {
                            engine.start(activity: activity)
                        } label: {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Color(hex: activity.colorHex))
                                    .frame(width: 7, height: 7)
                                Text(activity.name)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: 130)
                        }
                        .themedButton()
                        .controlSize(.small)
                        .help("Start \(activity.name)")
                    }
                }
            }
        }
    }
}
