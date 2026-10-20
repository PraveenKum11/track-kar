import Foundation

enum PreferenceKey {
    static let newActivityBehavior = "newActivityBehavior"
    static let appearanceMode = "appearanceMode"
    static let themeStyle = "themeStyle"
}

/// What happens when a timer starts with a name that isn't a saved activity yet.
enum NewActivityBehavior: String, CaseIterable, Identifiable {
    case ask, alwaysSave, neverSave

    var id: Self { self }

    var label: String {
        switch self {
        case .ask: String(localized: "Ask each time")
        case .alwaysSave: String(localized: "Always save as an activity")
        case .neverSave: String(localized: "Never save")
        }
    }
}
