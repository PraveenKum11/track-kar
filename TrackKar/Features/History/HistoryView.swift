import SwiftData
import SwiftUI

/// Every entry, newest first, grouped by the day it started.
struct HistoryView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(\.modelContext) private var context
    @Query(sort: \TimeEntry.createdAt, order: .reverse) private var entries: [TimeEntry]

    @State private var selection = Set<TimeEntry.ID>()
    @State private var editor: EntryEditorSheet.Target?
    @State private var pendingDeletion: [TimeEntry] = []

    private struct Day: Identifiable {
        let start: Date
        let entries: [TimeEntry]
        var id: Date { start }
    }

    private var days: [Day] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.createdAt) }
        return grouped
            .map { Day(start: $0.key, entries: $0.value) }
            .sorted { $0.start > $1.start }
    }

    var body: some View {
        List(selection: $selection) {
            ForEach(days) { day in
                Section {
                    ForEach(day.entries) { entry in
                        EntryRow(entry: entry, now: engine.now)
                            .tag(entry.id)
                    }
                } header: {
                    dayHeader(day)
                }
            }
        }
        .overlay {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No Time Tracked Yet",
                    systemImage: "clock",
                    description: Text("Start a timer from the menu bar, or add an entry for time you forgot to track.")
                )
            }
        }
        .contextMenu(forSelectionType: TimeEntry.ID.self) { ids in
            contextMenu(for: selectedEntries(ids))
        } primaryAction: { ids in
            if let entry = selectedEntries(ids).first { editor = .edit(entry) }
        }
        .onDeleteCommand {
            pendingDeletion = selectedEntries(selection).filter { !$0.isActive }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editor = .new
                } label: {
                    Label("Add Entry", systemImage: "plus")
                }
                .help("Add time you forgot to track")
            }
        }
        .sheet(item: $editor) { target in
            EntryEditorSheet(target: target)
        }
        .confirmationDialog(
            pendingDeletion.count == 1
                ? "Delete this entry?"
                : "Delete \(pendingDeletion.count) entries?",
            isPresented: Binding(get: { !pendingDeletion.isEmpty }, set: { if !$0 { pendingDeletion = [] } })
        ) {
            Button("Delete", role: .destructive) {
                engine.delete(pendingDeletion)
                selection.subtract(pendingDeletion.map(\.id))
                pendingDeletion = []
            }
        } message: {
            Text("This can't be undone.")
        }
        .navigationTitle("History")
    }

    private func dayHeader(_ day: Day) -> some View {
        let interval = Calendar.current.dateInterval(of: .day, for: day.start) ?? DateInterval(start: day.start, duration: 86_400)
        let total = Stats.total(of: day.entries, in: interval, at: engine.now)
        return HStack {
            Text(dayTitle(day.start))
            Spacer()
            Text(DurationFormat.short(total))
                .monospacedDigit()
        }
    }

    private func dayTitle(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return String(localized: "Today") }
        if calendar.isDateInYesterday(date) { return String(localized: "Yesterday") }
        let sameYear = calendar.isDate(date, equalTo: .now, toGranularity: .year)
        return sameYear
            ? date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
            : date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
    }

    private func selectedEntries(_ ids: Set<TimeEntry.ID>) -> [TimeEntry] {
        entries.filter { ids.contains($0.id) }
    }

    @ViewBuilder
    private func contextMenu(for selected: [TimeEntry]) -> some View {
        if selected.count == 1, let entry = selected.first {
            Button("Edit…") { editor = .edit(entry) }
            if entry.activity == nil, !entry.title.isEmpty {
                Button("Save “\(entry.title)” as Activity") {
                    ActivityLookup.promote(title: entry.title, in: context, at: .now)
                    engine.saveChanges()
                }
            }
            Divider()
        }
        let deletable = selected.filter { !$0.isActive }
        Button(deletable.count > 1 ? "Delete \(deletable.count) Entries…" : "Delete…", role: .destructive) {
            pendingDeletion = deletable
        }
        .disabled(deletable.isEmpty)
    }
}

/// One entry: name, time range, breaks and duration.
struct EntryRow: View {
    let entry: TimeEntry
    let now: Date

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(entry.colorHex.map(Color.activity) ?? Color.secondary.opacity(0.4))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.displayName)
                        .lineLimit(1)
                    if entry.activity == nil, !entry.title.isEmpty {
                        Text("Unsaved")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.quaternary, in: .capsule)
                    }
                }
                HStack(spacing: 4) {
                    Text(timeRange)
                    if entry.breakCount > 0 {
                        Text("· ^[\(entry.breakCount) break](inflect: true)")
                    }
                    if let notes = entry.notes, !notes.isEmpty {
                        Text("· \(notes)")
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if entry.isActive {
                Text(entry.isRunning ? "Running" : "Paused")
                    .font(.caption)
                    .foregroundStyle(.tint)
            }
            Text(DurationFormat.clock(entry.duration(at: now)))
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }

    private var timeRange: String {
        let start = entry.createdAt.formatted(date: .omitted, time: .shortened)
        guard let end = entry.endedAt else { return "\(start) – " + String(localized: "now") }
        let sameDay = Calendar.current.isDate(entry.createdAt, inSameDayAs: end)
        let endText = sameDay
            ? end.formatted(date: .omitted, time: .shortened)
            : end.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        return "\(start) – \(endText)"
    }
}
