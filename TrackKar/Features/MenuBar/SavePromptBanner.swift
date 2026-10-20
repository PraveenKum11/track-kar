import SwiftUI

/// "Save 'X' as an activity?" shown after starting a timer with a new name.
struct SavePromptBanner: View {
    let title: String

    @Environment(TimerEngine.self) private var engine
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Save “\(title)” as an activity?")
                .font(.callout.weight(.medium))
            Text("Saved activities add up across sessions and days.")
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
            HStack {
                Spacer()
                Button("Just this once") {
                    engine.dismissSavePrompt()
                }
                .themedButton()
                Button("Save") {
                    engine.saveActivityFromPrompt()
                }
                .themedButton(prominent: true)
            }
            .controlSize(.small)
        }
        .padding(10)
        .themedSurface()
    }
}
