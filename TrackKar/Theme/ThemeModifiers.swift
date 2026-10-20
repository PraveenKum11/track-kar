import SwiftUI

extension View {
    /// Applies the user's appearance mode and style. Put it once at the root of each window.
    func themedRoot() -> some View {
        modifier(ThemedRoot())
    }

    /// A raised area: glass in the Glass style, an opaque card in the Solid style.
    func themedSurface(cornerRadius: CGFloat = 10) -> some View {
        modifier(ThemedSurface(cornerRadius: cornerRadius))
    }

    func themedButton(prominent: Bool = false) -> some View {
        modifier(ThemedButton(prominent: prominent))
    }
}

private struct ThemedRoot: ViewModifier {
    @AppStorage(PreferenceKey.themeStyle) private var style: ThemeStyle = .glass
    @AppStorage(PreferenceKey.appearanceMode) private var mode: AppearanceMode = .system
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        // Reduce Transparency always wins over the chosen style.
        let theme = AppTheme.forStyle(reduceTransparency ? .solid : style)
        content
            .environment(\.appTheme, theme)
            .background(theme.surface)
            .preferredColorScheme(mode.colorScheme)
    }
}

private struct ThemedSurface: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.appTheme) private var theme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        switch theme.style {
        case .glass:
            content.glassEffect(.regular, in: shape)
        case .solid:
            content
                .background(theme.elevatedSurface, in: shape)
                .overlay(shape.strokeBorder(theme.separator))
        }
    }
}

private struct ThemedButton: ViewModifier {
    let prominent: Bool
    @Environment(\.appTheme) private var theme

    func body(content: Content) -> some View {
        switch (theme.style, prominent) {
        case (.glass, true): content.buttonStyle(.glassProminent)
        case (.glass, false): content.buttonStyle(.glass)
        case (.solid, true): content.buttonStyle(.borderedProminent)
        case (.solid, false): content.buttonStyle(.bordered)
        }
    }
}
