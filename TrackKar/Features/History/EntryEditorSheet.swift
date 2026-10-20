import SwiftData
import SwiftUI

/// Edits an entry, or adds one for time that wasn't tracked live.
struct EntryEditorSheet: View {
    enum Target: Identifiable {
        case new
        case edit(TimeEntry)

        var id: String {
            switch self {
            case .new: "new"
            case .edit(let entry): entry.id.uuidString
            }
        }
    }

    let target: Target

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(TimerEngine.self) private var engine
    @Query(sort: \Activity.name) private var allActivities: [Activity]

    @State private var activityID: PersistentIdentifier?
    @State private var title = ""
    @State private var start = Date.now.addingTimeInterval(-3_600)
    @State private var end = Date.now
    @State private var notes = ""
    @State private var errorMessage: String?

    private var entry: TimeEntry? {
        if case .edit(let entry) = target { return entry }
        return nil
    }

    /// Non-archived activities, plus the entry's own activity even if it's archived.
    private var activities: [Activity] {
        allActivities.filter { !$0.isArchived || $0 == entry?.activity }
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Picker("Activity", selection: $activityID) {
                        Text("None").tag(PersistentIdentifier?.none)
                        ForEach(activities) { activity in
                            Text(activity.name).tag(Optional(activity.persistentModelID))
                        }
                    }
                    if activityID == nil {
                        TextField("Name", text: $title, prompt: Text("Untitled"))
                    }
                }

                Section {
                    DatePicker("Start", selection: $start)
                        .disabled(entry?.isActive == true)
                    if entry?.isActive == true {
                        LabeledContent("End", value: String(localized: "Still running"))
                    } else {
                        DatePicker("End", selection: $end)
                    }
                    if let entry, entry.breakCount > 0 {
                        let breakTime = (entry.breaks ?? []).reduce(0) { $0 + $1.duration(at: engine.now) }
                        LabeledContent("Breaks") {
                            Text("^[\(entry.breakCount) break](inflect: true), \(DurationFormat.short(breakTime))")
                        }
                    }
                    LabeledContent("Tracked") {
                        Text(DurationFormat.clock(trackedPreview))
                            .monospacedDigit()
                    }
                } footer: {
                    if entry?.isActive == true {
                        Text("Times can be edited once the timer is stopped.")
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .labelsHidden()
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(entry == nil ? "Add Entry" : "Save") { save() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 420)
        .onAppear(perform: load)
    }

    /// Tracked time as it will be after saving: breaks stay excluded.
    private var trackedPreview: TimeInterval {
        guard let entry else { return max(0, end.timeIntervalSince(start)) }
        guard !entry.isActive, let original = entry.endedAt else { return entry.duration(at: engine.now) }
        let shift = original.timeIntervalSince(end) + start.timeIntervalSince(entry.createdAt)
        return max(0, entry.duration(at: original) - shift)
    }

    private func load() {
        guard let entry else { return }
        activityID = entry.activity?.persistentModelID
        title = entry.activity == nil ? entry.title : ""
        start = entry.createdAt
        end = entry.endedAt ?? engine.now
        notes = entry.notes ?? ""
    }

    private func save() {
        let activity = activities.first { $0.persistentModelID == activityID }
        do {
            if let entry {
                if !entry.isActive, start != entry.createdAt || end != entry.endedAt {
                    try EntryEditing.setTimes(of: entry, start: start, end: end)
                }
                EntryEditing.assign(entry, to: activity, title: title)
                entry.notes = notes.nilIfBlank
            } else {
                try EntryEditing.createManualEntry(
                    title: title, activity: activity, start: start, end: end, notes: notes, in: context
                )
            }
            engine.saveChanges()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
