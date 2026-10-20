import SwiftData
import SwiftUI

/// All activities, flat or by group, plus unsaved names that can be turned into activities.
struct ActivitiesView: View {
    @Environment(\.modelContext) private var context
    @Environment(TimerEngine.self) private var engine
    @Query(sort: \Activity.name) private var activities: [Activity]
    @Query(filter: #Predicate<ActivityGroup> { !$0.isArchived }, sort: \ActivityGroup.name)
    private var groups: [ActivityGroup]
    @Query(filter: #Predicate<TimeEntry> { $0.activity == nil }) private var unsavedEntries: [TimeEntry]

    @AppStorage(PreferenceKey.activitiesLayout) private var layout: ActivitiesLayout = .flat
    @AppStorage(PreferenceKey.showArchivedActivities) private var showArchived = false

    @State private var editor: ActivityEditorSheet.Target?
    @State private var confirmation: Confirmation?

    private enum Confirmation: Identifiable {
        case delete(Activity)
        case merge(Activity, into: Activity)

        var id: String {
            switch self {
            case .delete(let activity): "delete-\(activity.id)"
            case .merge(let source, let target): "merge-\(source.id)-\(target.id)"
            }
        }
    }

    private var visible: [Activity] {
        activities.filter { showArchived || !$0.isArchived }
    }

    private struct UnsavedName: Identifiable {
        let title: String
        let entries: [TimeEntry]
        var id: String { title.lowercased() }
    }

    /// Unsaved entries grouped by name, ignoring case.
    private var unsavedNames: [UnsavedName] {
        let named = unsavedEntries.filter { !$0.title.isEmpty }
        return Dictionary(grouping: named) { $0.title.lowercased() }
            .compactMap { _, entries in
                entries.max { $0.createdAt < $1.createdAt }.map { UnsavedName(title: $0.title, entries: entries) }
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        List {
            switch layout {
            case .flat:
                ForEach(visible) { row(for: $0, showsGroup: true) }
            case .grouped:
                ForEach(groups) { group in
                    let members = visible.filter { $0.group == group }
                    if !members.isEmpty {
                        Section {
                            ForEach(members) { row(for: $0, showsGroup: false) }
                        } header: {
                            sectionHeader(group.name, total: group.totalDuration(at: engine.now))
                        }
                    }
                }
                let ungrouped = visible.filter { $0.group == nil || $0.group?.isArchived == true }
                if !ungrouped.isEmpty {
                    Section("Ungrouped") {
                        ForEach(ungrouped) { row(for: $0, showsGroup: false) }
                    }
                }
            }

            if !unsavedNames.isEmpty {
                Section {
                    ForEach(unsavedNames) { name in
                        HStack {
                            Text(name.title)
                            Text("^[\(name.entries.count) entry](inflect: true)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(DurationFormat.short(Stats.total(of: name.entries, at: engine.now)))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            Button("Save as Activity") {
                                ActivityLookup.promote(title: name.title, in: context, at: .now)
                                engine.saveChanges()
                            }
                            .controlSize(.small)
                        }
                    }
                } header: {
                    Text("Unsaved")
                } footer: {
                    Text("Names you tracked without saving. Saving one links all of its entries.")
                }
            }
        }
        .overlay {
            if activities.isEmpty, unsavedNames.isEmpty {
                ContentUnavailableView(
                    "No Activities",
                    systemImage: "square.stack",
                    description: Text("Activities are the things you track time against. Their time adds up across days.")
                )
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Picker("Layout", selection: $layout) {
                        ForEach(ActivitiesLayout.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.inline)
                    Divider()
                    Toggle("Show Archived", isOn: $showArchived)
                } label: {
                    Label("View Options", systemImage: "line.3.horizontal.decrease")
                }
                .help("Layout and archived activities")

                Button {
                    editor = .new
                } label: {
                    Label("New Activity", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editor) { ActivityEditorSheet(target: $0) }
        .confirmationDialog(
            confirmationTitle,
            isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } }),
            presenting: confirmation
        ) { confirmation in
            switch confirmation {
            case .delete(let activity):
                Button("Delete Activity", role: .destructive) {
                    EntryEditing.delete(activity, in: context)
                    engine.saveChanges()
                }
            case .merge(let source, let target):
                Button("Merge") {
                    EntryEditing.merge(source, into: target, in: context)
                    engine.saveChanges()
                }
            }
        } message: { confirmation in
            switch confirmation {
            case .delete:
                Text("Its entries stay in History as unsaved entries.")
            case .merge(let source, let target):
                Text("All of “\(source.name)”'s entries move to “\(target.name)”, and “\(source.name)” is deleted.")
            }
        }
        .navigationTitle("Activities")
    }

    private var confirmationTitle: String {
        switch confirmation {
        case .delete(let activity): String(localized: "Delete “\(activity.name)”?")
        case .merge(let source, let target): String(localized: "Merge “\(source.name)” into “\(target.name)”?")
        case nil: ""
        }
    }

    private func sectionHeader(_ title: String, total: TimeInterval) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(DurationFormat.short(total))
                .monospacedDigit()
        }
    }

    private func row(for activity: Activity, showsGroup: Bool) -> some View {
        ActivityRow(activity: activity, showsGroup: showsGroup, now: engine.now)
            .draggable(activity.id.uuidString)
            .contextMenu { contextMenu(for: activity) }
            .onTapGesture(count: 2) { editor = .edit(activity) }
    }

    @ViewBuilder
    private func contextMenu(for activity: Activity) -> some View {
        Button("Start Timer") { engine.start(activity: activity) }
            .disabled(activity.isArchived)
        Button("Edit…") { editor = .edit(activity) }

        Menu("Move to Group") {
            Button("None") { setGroup(nil, for: activity) }
                .disabled(activity.group == nil)
            Divider()
            ForEach(groups) { group in
                Button(group.name) { setGroup(group, for: activity) }
                    .disabled(activity.group == group)
            }
        }

        Menu("Merge Into") {
            ForEach(activities.filter { $0 != activity && !$0.isArchived }) { target in
                Button(target.name) { confirmation = .merge(activity, into: target) }
            }
        }

        Divider()

        Button(activity.isArchived ? "Unarchive" : "Archive") {
            activity.isArchived.toggle()
            engine.saveChanges()
        }
        Button("Delete…", role: .destructive) { confirmation = .delete(activity) }
    }

    private func setGroup(_ group: ActivityGroup?, for activity: Activity) {
        activity.group = group
        engine.saveChanges()
    }
}

private struct ActivityRow: View {
    let activity: Activity
    let showsGroup: Bool
    let now: Date

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.activity(activity.colorHex))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(activity.name)
                    if activity.isArchived {
                        Text("Archived")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.quaternary, in: .capsule)
                    }
                }
                HStack(spacing: 4) {
                    if showsGroup, let group = activity.group {
                        Label(group.name, systemImage: "folder")
                        Text("·")
                    }
                    if let lastUsed = activity.lastUsed {
                        Text("Last used \(lastUsed.formatted(.relative(presentation: .named)))")
                    } else {
                        Text("Not used yet")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text(DurationFormat.short(activity.totalDuration(at: now)))
                .monospacedDigit()
        }
        .padding(.vertical, 2)
        .contentShape(.rect)
        .opacity(activity.isArchived ? 0.6 : 1)
    }
}
