import SwiftUI

/// The eight palette colors as swatches, plus a custom color well.
struct ColorSwatchPicker: View {
    @Binding var hex: String

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ActivityPalette.slots, id: \.light) { slot in
                Button {
                    hex = slot.light
                } label: {
                    Circle()
                        .fill(Color.activity(slot.light))
                        .frame(width: 20, height: 20)
                        .overlay {
                            if slot.light.caseInsensitiveCompare(hex) == .orderedSame {
                                Image(systemName: "checkmark")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .buttonStyle(.plain)
                .help(slot.name)
                .accessibilityLabel(slot.name)
            }

            ColorPicker(
                "Custom",
                selection: Binding(
                    get: { Color(hex: hex) },
                    set: { hex = $0.hexString ?? hex }
                ),
                supportsOpacity: false
            )
            .labelsHidden()
            .help("Custom color")
        }
    }
}
