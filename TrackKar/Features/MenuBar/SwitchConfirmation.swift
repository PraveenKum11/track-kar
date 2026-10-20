import SwiftUI

/// Asked before starting something else while a timer is running or paused, so tracked time is
/// never ended or lost without the user choosing what happens to it.
struct SwitchConfirmation: View {
    let current: TimeEntry
    let target: StartTarget
    let onChoose: (SwitchChoice?) -> Void

    @Environment(TimerEngine.self) private var engine
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Switch to “\(target.displayName)”?")
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
                Text("“\(current.displayName)” has \(DurationFormat.clock(engine.elapsed)) tracked.")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(2)
            }

            VStack(spacing: 6) {
                choiceButton(
                    "Save and switch",
                    detail: "Keep it in History and start a new timer.",
                    systemImage: "checkmark.circle",
                    prominent: true,
                    choice: .saveAndSwitch
                )
                .keyboardShortcut(.defaultAction)
                choiceButton(
                    "Move this time to “\(target.displayName)”",
                    detail: "Keep the timer running under the new name.",
                    systemImage: "arrow.right.circle",
                    choice: .moveTime
                )
                choiceButton(
                    "Discard and switch",
                    detail: "Delete this time and start a new timer.",
                    systemImage: "trash",
                    role: .destructive,
                    choice: .discard
                )
            }

            HStack {
                Spacer()
                Button("Cancel") { onChoose(nil) }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.borderless)
            }
        }
        .padding(10)
        .themedSurface()
    }

    private func choiceButton(
        _ title: String,
        detail: LocalizedStringKey,
        systemImage: String,
        prominent: Bool = false,
        role: ButtonRole? = nil,
        choice: SwitchChoice
    ) -> some View {
        Button(role: role) {
            onChoose(choice)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .frame(width: 18)
                    .foregroundStyle(role == .destructive ? AnyShapeStyle(.red) : AnyShapeStyle(.foreground))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .lineLimit(1)
                    Text(detail)
                        .font(.caption2)
                        .opacity(0.8)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .themedButton(prominent: prominent)
    }
}
