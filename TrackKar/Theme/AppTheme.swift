import AppKit
import SwiftUI

enum ThemeStyle: String, CaseIterable, Identifiable {
    case glass, solid

    var id: Self { self }

    var label: String {
        switch self {
        case .glass: String(localized: "Liquid Glass")
        case .solid: String(localized: "Solid")
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: Self { self }

    var label: String {
        switch self {
        case .system: String(localized: "System")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Semantic colors for the current style. Views use these and the `themed…` modifiers
/// instead of hard-coding colors or materials, so a style switch restyles everything.
struct AppTheme {
    var style: ThemeStyle
    /// Window or popover background. Clear for glass, so the system material shows through.
    var surface: Color
    /// Cards, fields and other raised areas.
    var elevatedSurface: Color
    var separator: Color
    var primaryText: Color
    var secondaryText: Color
    var accent: Color

    static let glass = AppTheme(
        style: .glass,
        surface: .clear,
        elevatedSurface: .clear,
        separator: Color(nsColor: .separatorColor),
        primaryText: .primary,
        secondaryText: .secondary,
        accent: .accentColor
    )

    static let solid = AppTheme(
        style: .solid,
        surface: Color(nsColor: .windowBackgroundColor),
        elevatedSurface: Color(nsColor: .controlBackgroundColor),
        separator: Color(nsColor: .separatorColor),
        primaryText: .primary,
        secondaryText: .secondary,
        accent: .accentColor
    )

    static func forStyle(_ style: ThemeStyle) -> AppTheme {
        switch style {
        case .glass: .glass
        case .solid: .solid
        }
    }
}

extension EnvironmentValues {
    @Entry var appTheme: AppTheme = .glass
}
