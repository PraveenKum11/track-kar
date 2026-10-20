import SwiftData
import SwiftUI

/// Creates or edits a group: name, color, optional target, and which activities belong to it.
struct GroupEditorSheet: View {
    enum Target: Identifiable {
        case new
        case edit(ActivityGroup)

        var id: String {
            switch self {
            case .new: "new"
            case .edit(let group): group.id.uuidString
            }
        }
    }

    let target: Target
    var onSave: (ActivityGroup) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(TimerEngine.self) private var engine
    @Query(filter: #Predicate<Activity> { !$0.isArchived }, sort: \Activity.name)
    private var activities: [Activity]

    @State private var name = ""
    @State private var colorHex = ActivityPalette.color(forIndex: 0)
    @State private var hasTarget = false
    @State private var targetHours = 10.0
    @State private var memberIDs = Set<PersistentIdentifier>()
    @State private var errorMessage: String?

    private var group: ActivityGroup? {
        if case .edit(let group) = target { return group }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Name", text: $name, prompt: Text("Interview prep"))
                    LabeledContent("Color") {
                        ColorSwatchPicker(hex: $colorHex)
                    }
                    Toggle("Set a target", isOn: $hasTarget)
                    if hasTarget {
                        TextField("Target hours", value: $targetHours, format: .number.precision(.fractionLength(0...1)))
                    }
                }

                Section {
                    if activities.isEmpty {
                        Text("No activities yet.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(activities) { activity in
                        Toggle(isOn: membership(for: activity)) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.activity(activity.colorHex))
                                    .frame(width: 8, height: 8)
                                Text(activity.name)
                                if let other = activity.group, other != group {
                                    Text("in \(other.name)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Activities")
                } footer: {
                    Text("An activity belongs to one group at most. Adding it here moves it out of any other group.")
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
                Button(group == nil ? "Create" : "Save") { save() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 460, height: 520)
        .onAppear(perform: load)
    }

    private func membership(for activity: Activity) -> Binding<Bool> {
        Binding(
            get: { memberIDs.contains(activity.persistentModelID) },
            set: { isMember in
                if isMember {
                    memberIDs.insert(activity.persistentModelID)
                } else {
                    memberIDs.remove(activity.persistentModelID)
                }
            }
        )
    }

    private func load() {
        guard let group else { return }
        name = group.name
        colorHex = group.colorHex
        hasTarget = group.targetHours != nil
        targetHours = group.targetHours ?? 10
        memberIDs = Set((group.activities ?? []).map(\.persistentModelID))
    }

    private func save() {
        guard let trimmed = name.nilIfBlank else {
            errorMessage = EditingError.emptyName.localizedDescription
            return
        }
        guard !hasTarget || targetHours > 0 else {
            errorMessage = String(localized: "The target must be more than 0 hours.")
            return
        }

        let group = self.group ?? {
            let group = ActivityGroup(name: trimmed, colorHex: colorHex)
            context.insert(group)
            return group
        }()
        group.name = trimmed
        group.colorHex = colorHex
        group.targetHours = hasTarget ? targetHours : nil
        for activity in activities {
            if memberIDs.contains(activity.persistentModelID) {
                activity.group = group
            } else if activity.group == group {
                activity.group = nil
            }
        }
        engine.saveChanges()
        onSave(group)
        dismiss()
    }
}
