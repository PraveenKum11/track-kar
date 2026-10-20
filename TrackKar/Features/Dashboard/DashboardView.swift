import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// "Where did my time go?" for a day, week, month or custom range.
struct DashboardView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(\.modelContext) private var context
    @AppStorage(PreferenceKey.firstWeekday) private var firstWeekday: FirstWeekday = .system
    @AppStorage(PreferenceKey.dashboardGrouping) private var grouping: BreakdownGrouping = .activity

    @State private var range = DashboardRange()
    @State private var pendingExport: PreparedExport?
    @State private var exportError: String?

    var body: some View {
        let calendar = firstWeekday.calendar
        // Running timers tick `engine.now`; otherwise read the clock so "today" stays current.
        let now = engine.state == .running ? engine.now : .now
        let interval = range.interval(calendar: calendar, now: now)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                rangeControls(calendar: calendar, now: now)
                DashboardContent(
                    interval: interval,
                    previous: range.previousInterval(calendar: calendar, now: now),
                    previousLabel: range.previousLabel,
                    now: now,
                    calendar: calendar,
                    grouping: $grouping
                )
            }
            .padding(24)
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Section("\(range.title(calendar: calendar, now: now))") {
                        Button("Export as CSV…") { export(.csv, in: interval, calendar: calendar) }
                        Button("Export as JSON…") { export(.json, in: interval, calendar: calendar) }
                    }
                    Section("Everything") {
                        Button("Export All as CSV…") { export(.csv, in: nil, calendar: calendar) }
                        Button("Export All as JSON…") { export(.json, in: nil, calendar: calendar) }
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .help("Export tracked time as CSV or JSON")
            }
        }
        .fileExporter(
            isPresented: Binding(get: { pendingExport != nil }, set: { if !$0 { pendingExport = nil } }),
            document: pendingExport?.document,
            contentType: pendingExport?.format.contentType ?? .commaSeparatedText,
            defaultFilename: pendingExport?.filename
        ) { result in
            if case .failure(let error) = result {
                exportError = error.localizedDescription
            }
        }
        .alert("Export Failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .onChange(of: range.period) {
            range.offset = 0
        }
    }

    // MARK: Range

    private func rangeControls(calendar: Calendar, now: Date) -> some View {
        HStack(spacing: 16) {
            Picker("Period", selection: $range.period) {
                ForEach(DashboardPeriod.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            Spacer()

            if range.period == .custom {
                DatePicker("From", selection: $range.customStart, displayedComponents: .date)
                    .labelsHidden()
                Text("–")
                DatePicker("To", selection: $range.customEnd, displayedComponents: .date)
                    .labelsHidden()
            } else {
                Button {
                    range.offset -= 1
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                }
                .help("Previous \(range.period.label.lowercased())")

                VStack(spacing: 1) {
                    Text(range.title(calendar: calendar, now: now))
                        .font(.headline)
                    Text(range.dateRange(calendar: calendar, now: now))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 170)

                Button {
                    range.offset += 1
                } label: {
                    Label("Next", systemImage: "chevron.right")
                }
                .disabled(range.offset >= 0)
                .help("Next \(range.period.label.lowercased())")
            }
        }
        .labelStyle(.iconOnly)
    }

    // MARK: Export

    /// Exports entries overlapping `interval`, or everything when it's nil.
    private func export(_ format: ExportFormat, in interval: DateInterval?, calendar: Calendar) {
        do {
            pendingExport = try PreparedExport.make(format, in: interval, context: context)
        } catch {
            exportError = error.localizedDescription
        }
    }
}

/// The numbers, chart and breakdown for one range. Separate so its query can follow the range.
private struct DashboardContent: View {
    let interval: DateInterval
    let previous: DateInterval
    let previousLabel: String
    let now: Date
    let calendar: Calendar
    @Binding var grouping: BreakdownGrouping

    @Environment(\.appTheme) private var theme
    @Query private var entries: [TimeEntry]

    init(
        interval: DateInterval,
        previous: DateInterval,
        previousLabel: String,
        now: Date,
        calendar: Calendar,
        grouping: Binding<BreakdownGrouping>
    ) {
        self.interval = interval
        self.previous = previous
        self.previousLabel = previousLabel
        self.now = now
        self.calendar = calendar
        _grouping = grouping
        // Entries overlapping the current or previous period.
        let start = min(interval.start, previous.start)
        let end = interval.end
        let openEnded = Date.distantFuture
        _entries = Query(filter: #Predicate<TimeEntry> { $0.createdAt < end && ($0.endedAt ?? openEnded) > start })
    }

    var body: some View {
        let total = Stats.total(of: entries, in: interval, at: now)
        let previousTotal = Stats.total(of: entries, in: previous, at: now)
        let breakdown = Stats.breakdown(of: entries, in: interval, at: now, by: grouping)
        let breaks = Stats.breakStats(of: entries, in: interval, at: now)
        let elapsedDays = Stats.elapsedDays(of: interval, at: now, calendar: calendar)
        let sessions = entries.filter { $0.duration(in: interval, at: now) > 0 }.count
        let (buckets, unit) = Stats.buckets(for: interval, calendar: calendar)

        VStack(alignment: .leading, spacing: 20) {
            headline(total: total, previousTotal: previousTotal)

            HStack(alignment: .top, spacing: 12) {
                tile("Daily average", value: elapsedDays > 0 ? DurationFormat.short(total / Double(elapsedDays)) : "–")
                tile("Sessions", value: sessions.formatted())
                tile("Breaks", value: breaks.count.formatted(), detail: breaks.count > 0 ? "\(DurationFormat.short(breaks.total)) total" : nil)
                tile("Average break", value: breaks.count > 0 ? DurationFormat.short(breaks.average) : "–")
            }
            .fixedSize(horizontal: false, vertical: true)

            if total == 0 {
                ContentUnavailableView(
                    "Nothing Tracked",
                    systemImage: "chart.bar",
                    description: Text("No time was tracked in this period.")
                )
                .frame(maxWidth: .infinity)
            } else {
                if buckets.count > 1 {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(unit == .day ? "Each day" : "Each week")
                                .font(.headline)
                            Spacer()
                            groupingPicker
                        }
                        DailyStackedChart(
                            amounts: Stats.dailyAmounts(of: entries, buckets: buckets, at: now, by: grouping),
                            buckets: buckets,
                            unit: unit
                        )
                        .frame(height: 240)
                    }
                    .padding()
                    .themedSurface(cornerRadius: 12)
                }

                breakdownList(breakdown, total: total, showsPicker: buckets.count <= 1)
            }
        }
    }

    private var groupingPicker: some View {
        Picker("Group by", selection: $grouping) {
            Text("Activity").tag(BreakdownGrouping.activity)
            Text("Group").tag(BreakdownGrouping.group)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }

    private func headline(total: TimeInterval, previousTotal: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(DurationFormat.short(total))
                .font(.system(size: 48, weight: .light, design: .rounded))
                .monospacedDigit()
            comparison(total: total, previousTotal: previousTotal)
                .font(.callout)
        }
    }

    @ViewBuilder
    private func comparison(total: TimeInterval, previousTotal: TimeInterval) -> some View {
        let difference = total - previousTotal
        if previousTotal == 0, total == 0 {
            Text("Nothing tracked yet")
                .foregroundStyle(theme.secondaryText)
        } else if previousTotal == 0 {
            Text("tracked · nothing in \(previousLabel)")
                .foregroundStyle(theme.secondaryText)
        } else if abs(difference) < 60 {
            Text("tracked · about the same as \(previousLabel)")
                .foregroundStyle(theme.secondaryText)
        } else {
            let percent = (abs(difference) / previousTotal).formatted(.percent.precision(.fractionLength(0)))
            HStack(spacing: 4) {
                Text("tracked ·")
                    .foregroundStyle(theme.secondaryText)
                Image(systemName: difference > 0 ? "arrow.up" : "arrow.down")
                Text("\(DurationFormat.short(abs(difference))) (\(percent))")
                    .monospacedDigit()
                Text(difference > 0 ? "more than \(previousLabel)" : "less than \(previousLabel)")
                    .foregroundStyle(theme.secondaryText)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func tile(_ title: LocalizedStringKey, value: String, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
            Text(value)
                .font(.title3)
                .monospacedDigit()
                .lineLimit(1)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .themedSurface(cornerRadius: 10)
    }

    private func breakdownList(_ items: [BreakdownItem], total: TimeInterval, showsPicker: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(grouping == .activity ? "By activity" : "By group")
                    .font(.headline)
                Spacer()
                if showsPicker { groupingPicker }
            }
            ForEach(items) { item in
                let share = total > 0 ? item.seconds / total : 0
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.activity(item.colorHex))
                            .frame(width: 8, height: 8)
                        Text(item.name)
                            .lineLimit(1)
                        Text("^[\(item.sessions) session](inflect: true)")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                        Spacer()
                        Text(DurationFormat.short(item.seconds))
                            .monospacedDigit()
                        Text(share.formatted(.percent.precision(.fractionLength(0))))
                            .monospacedDigit()
                            .foregroundStyle(theme.secondaryText)
                            .frame(width: 44, alignment: .trailing)
                    }
                    GeometryReader { proxy in
                        Capsule()
                            .fill(Color.activity(item.colorHex))
                            .frame(width: max(3, proxy.size.width * share))
                    }
                    .frame(height: 4)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding()
        .themedSurface(cornerRadius: 12)
    }
}
