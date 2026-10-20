import SwiftData
import SwiftUI

/// Creates or edits an activity: name, color and group.
struct ActivityEditorSheet: View {
    enum Target: Identifiable {
        case new
        case edit(Activity)

        var id: String {
            switch self {
            case .new: "new"
            case .edit(let activity): activity.id.uuidString
            }
        }
    }

    let target: Target

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(TimerEngine.self) private var engine
    @Query(filter: #Predicate<ActivityGroup> { !$0.isArchived }, sort: \ActivityGroup.name)
    private var groups: [ActivityGroup]

    @State private var name = ""
    @State private var colorHex = ActivityPalette.color(forIndex: 0)
    @State private var groupID: PersistentIdentifier?
    @State private var errorMessage: String?

    private var activity: Activity? {
        if case .edit(let activity) = target { return activity }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                TextField("Name", text: $name)
                LabeledContent("Color") {
                    ColorSwatchPicker(hex: $colorHex)
                }
                Picker("Group", selection: $groupID) {
                    Text("None").tag(PersistentIdentifier?.none)
                    ForEach(groups) { group in
                        Text(group.name).tag(Optional(group.persistentModelID))
                    }
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
                Button(activity == nil ? "Create" : "Save") { save() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 460)
        .onAppear(perform: load)
    }

    private func load() {
        if let activity {
            name = activity.name
            colorHex = activity.colorHex
            groupID = activity.group?.persistentModelID
        } else {
            let count = (try? context.fetchCount(FetchDescriptor<Activity>())) ?? 0
            colorHex = ActivityPalette.color(forIndex: count)
        }
    }

    private func save() {
        let group = groups.first { $0.persistentModelID == groupID }
        do {
            if let activity {
                if name != activity.name {
                    try EntryEditing.rename(activity, to: name, in: context)
                }
                activity.colorHex = colorHex
                activity.group = group
            } else {
                try EntryEditing.createActivity(name: name, colorHex: colorHex, group: group, in: context)
            }
            engine.saveChanges()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
