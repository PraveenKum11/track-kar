import SwiftData
import SwiftUI

/// "What are you working on?" field with autocomplete from saved activities.
struct NameField: View {
    enum Submission {
        case activity(Activity)
        case title(String)
    }

    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let placeholder: String
    let onSubmit: (Submission) -> Void

    @Query(filter: #Predicate<Activity> { !$0.isArchived }, sort: \Activity.name)
    private var activities: [Activity]
    @State private var highlighted: Int?

    private var suggestions: [Activity] {
        ActivityLookup.suggestions(for: text, from: activities)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .focused(isFocused)
                .onSubmit(submit)
                .onKeyPress(.downArrow) { moveHighlight(by: 1) }
                .onKeyPress(.upArrow) { moveHighlight(by: -1) }
                .onKeyPress(.escape) {
                    guard !text.isEmpty else { return .ignored }
                    text = ""
                    return .handled
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .themedSurface(cornerRadius: 8)

            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, activity in
                        Button {
                            onSubmit(.activity(activity))
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(hex: activity.colorHex))
                                    .frame(width: 8, height: 8)
                                Text(activity.name)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .contentShape(.rect)
                            .background(
                                index == highlighted ? Color.accentColor.opacity(0.2) : .clear,
                                in: .rect(cornerRadius: 6)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .themedSurface(cornerRadius: 8)
            }
        }
        .onChange(of: text) { highlighted = nil }
    }

    private func submit() {
        if let highlighted, suggestions.indices.contains(highlighted) {
            onSubmit(.activity(suggestions[highlighted]))
        } else {
            onSubmit(.title(text))
        }
    }

    private func moveHighlight(by step: Int) -> KeyPress.Result {
        guard !suggestions.isEmpty else { return .ignored }
        let next = (highlighted ?? (step > 0 ? -1 : suggestions.count)) + step
        highlighted = min(max(next, 0), suggestions.count - 1)
        return .handled
    }
}
