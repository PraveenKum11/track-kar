import SwiftData
import SwiftUI

/// The full app window: sidebar navigation plus a timer control in the toolbar.
struct MainWindowView: View {
    @Environment(\.modelContext) private var context
    @Environment(TimerEngine.self) private var engine
    @Environment(AppNavigation.self) private var navigation
    @Query(filter: #Predicate<ActivityGroup> { !$0.isArchived }, sort: \ActivityGroup.name)
    private var groups: [ActivityGroup]

    @State private var groupEditor: GroupEditorSheet.Target?
    @State private var groupToDelete: ActivityGroup?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                TrackingToolbarControl()
            }
        }
        .sheet(item: $groupEditor) { target in
            GroupEditorSheet(target: target) { group in
                navigation.selection = .group(group.persistentModelID)
            }
        }
        .confirmationDialog(
            "Delete “\(groupToDelete?.name ?? "")”?",
            isPresented: Binding(get: { groupToDelete != nil }, set: { if !$0 { groupToDelete = nil } }),
            presenting: groupToDelete
        ) { group in
            Button("Delete Group", role: .destructive) {
                if navigation.selection == .group(group.persistentModelID) { navigation.selection = .activities }
                EntryEditing.delete(group, in: context)
                engine.saveChanges()
            }
        } message: { _ in
            Text("Its activities become ungrouped. No tracked time is lost.")
        }
        .frame(minWidth: 760, minHeight: 480)
        // Behave like a regular app (Dock icon, ⌘-Tab, app menu) while the window is open.
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            AppActivation.bringToFront()
        }
        .onDisappear {
            AppActivation.mainWindowClosed()
        }
    }

    private var sidebar: some View {
        @Bindable var navigation = navigation
        return List(selection: $navigation.selection) {
            Section {
                Label("History", systemImage: "clock.arrow.circlepath")
                    .tag(SidebarItem.history)
                Label("Activities", systemImage: "square.stack")
                    .tag(SidebarItem.activities)
            }

            Section("Groups") {
                ForEach(groups) { group in
                    Label {
                        Text(group.name)
                    } icon: {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(Color.activity(group.colorHex))
                    }
                    .tag(SidebarItem.group(group.persistentModelID))
                    .dropDestination(for: String.self) { ids, _ in
                        assignActivities(withIDs: ids, to: group)
                    }
                    .contextMenu {
                        Button("Edit Group…") { groupEditor = .edit(group) }
                        Button("Delete Group…", role: .destructive) { groupToDelete = group }
                    }
                }
            }

            Section {
                Label("Settings", systemImage: "gearshape")
                    .tag(SidebarItem.settings)
            }
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        .safeAreaInset(edge: .bottom) {
            Button {
                groupEditor = .new
            } label: {
                Label("New Group", systemImage: "plus")
            }
            .buttonStyle(.borderless)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch navigation.selection {
        case .history, nil:
            HistoryView()
        case .activities:
            ActivitiesView()
        case .group(let id):
            if let group = groups.first(where: { $0.persistentModelID == id }) {
                GroupDetailView(group: group) { groupEditor = .edit(group) }
            } else {
                ContentUnavailableView("No Group Selected", systemImage: "folder")
            }
        case .settings:
            SettingsView()
        }
    }

    /// Handles activities dragged from the Activities list onto a sidebar group.
    private func assignActivities(withIDs ids: [String], to group: ActivityGroup) {
        let uuids = Set(ids.compactMap(UUID.init(uuidString:)))
        let activities = (try? context.fetch(FetchDescriptor<Activity>())) ?? []
        for activity in activities where uuids.contains(activity.id) {
            activity.group = group
        }
        engine.saveChanges()
    }
}

/// Toolbar timer: live status with pause/stop, or a button that opens the popover's controls.
private struct TrackingToolbarControl: View {
    @Environment(TimerEngine.self) private var engine
    @State private var isShowingPopover = false

    var body: some View {
        HStack(spacing: 8) {
            if let entry = engine.activeEntry {
                if let hex = entry.colorHex {
                    Circle()
                        .fill(Color.activity(hex))
                        .frame(width: 8, height: 8)
                }
                Text(entry.displayName)
                    .lineLimit(1)
                    .frame(maxWidth: 200)
                Text(toolbarTime)
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundStyle(engine.state == .paused ? .secondary : .primary)
                Button {
                    engine.togglePause()
                } label: {
                    Label(
                        engine.state == .paused ? "Resume" : "Pause",
                        systemImage: engine.state == .paused ? "play.fill" : "pause.fill"
                    )
                }
                Button {
                    engine.stop()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
            } else {
                Button {
                    isShowingPopover = true
                } label: {
                    Label("Start Timer", systemImage: "play.fill")
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        .padding(.horizontal, 10)
        // Toolbars squeeze items to their minimum; size to content so the time stays on one line.
        .fixedSize()
        .popover(isPresented: $isShowingPopover, arrowEdge: .bottom) {
            PopoverView()
        }
    }

    /// Time left for countdowns and Pomodoro phases, time tracked otherwise.
    private var toolbarTime: String {
        guard let countdown = engine.countdown else { return DurationFormat.clock(engine.elapsed) }
        if countdown.isOvertime { return "+" + DurationFormat.clock(-countdown.remaining) }
        let remaining = DurationFormat.clock(countdown.remaining.rounded(.up))
        return countdown.phase.map { "\($0.label) \(remaining)" } ?? remaining
    }
}
