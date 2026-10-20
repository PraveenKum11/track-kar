import Foundation
import SwiftUI

enum PreferenceKey {
    static let newActivityBehavior = "newActivityBehavior"
    static let appearanceMode = "appearanceMode"
    static let themeStyle = "themeStyle"
    static let accentColor = "accentColor"
    static let firstWeekday = "firstWeekday"
    static let menuBarOptions = "menuBarOptions"
    static let activitiesLayout = "activitiesLayout"
    static let showArchivedActivities = "showArchivedActivities"
    static let timerSettings = "timerSettings"
    static let selectedTimerMode = "selectedTimerMode"
    static let countdownMinutes = "countdownMinutes"
    static let dashboardGrouping = "dashboardGrouping"
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

enum AccentChoice: String, CaseIterable, Identifiable {
    case system, blue, purple, pink, red, orange, yellow, green, graphite

    var id: Self { self }

    var label: String {
        switch self {
        case .system: String(localized: "System")
        case .blue: String(localized: "Blue")
        case .purple: String(localized: "Purple")
        case .pink: String(localized: "Pink")
        case .red: String(localized: "Red")
        case .orange: String(localized: "Orange")
        case .yellow: String(localized: "Yellow")
        case .green: String(localized: "Green")
        case .graphite: String(localized: "Graphite")
        }
    }

    /// `nil` follows the system accent color.
    var color: Color? {
        switch self {
        case .system: nil
        case .blue: Color(nsColor: .systemBlue)
        case .purple: Color(nsColor: .systemPurple)
        case .pink: Color(nsColor: .systemPink)
        case .red: Color(nsColor: .systemRed)
        case .orange: Color(nsColor: .systemOrange)
        case .yellow: Color(nsColor: .systemYellow)
        case .green: Color(nsColor: .systemGreen)
        case .graphite: Color(nsColor: .systemGray)
        }
    }
}

/// Stored as a `Calendar` weekday number; 0 follows the system.
enum FirstWeekday: Int, CaseIterable, Identifiable {
    case system = 0, sunday = 1, monday = 2, saturday = 7

    var id: Self { self }

    var label: String {
        switch self {
        case .system: String(localized: "System")
        case .sunday: String(localized: "Sunday")
        case .monday: String(localized: "Monday")
        case .saturday: String(localized: "Saturday")
        }
    }

    /// The calendar used for weeks in History and, later, the Dashboard.
    var calendar: Calendar {
        var calendar = Calendar.current
        if self != .system { calendar.firstWeekday = rawValue }
        return calendar
    }
}

enum ActivitiesLayout: String, CaseIterable, Identifiable {
    case flat, grouped

    var id: Self { self }

    var label: String {
        switch self {
        case .flat: String(localized: "Flat")
        case .grouped: String(localized: "By Group")
        }
    }
}
