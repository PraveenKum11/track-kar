import Foundation
import SwiftData

/// A saved, reusable thing to track time against. Time adds up across sessions and days.
@Model
final class Activity {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#2A78D6"
    /// Emoji or SF Symbol name.
    var icon: String?
    var isArchived: Bool = false
    var createdAt: Date = Date.now
    /// `nil` means ungrouped.
    var group: ActivityGroup?

    @Relationship(deleteRule: .nullify, inverse: \TimeEntry.activity)
    var entries: [TimeEntry]? = []

    init(name: String, colorHex: String, createdAt: Date = .now) {
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
    }
}

/// Eight colors validated for color-vision deficiency and contrast in both modes.
/// Stored hexes are the light steps; `Color.activity(_:)` swaps in the dark step.
nonisolated enum ActivityPalette {
    struct Slot {
        let name: String
        let light: String
        let dark: String
    }

    static let slots = [
        Slot(name: "Blue", light: "#2A78D6", dark: "#3987E5"),
        Slot(name: "Orange", light: "#EB6834", dark: "#D95926"),
        Slot(name: "Aqua", light: "#1BAF7A", dark: "#199E70"),
        Slot(name: "Yellow", light: "#EDA100", dark: "#C98500"),
        Slot(name: "Magenta", light: "#E87BA4", dark: "#D55181"),
        Slot(name: "Green", light: "#008300", dark: "#008300"),
        Slot(name: "Violet", light: "#6250D6", dark: "#9085E9"),
        Slot(name: "Red", light: "#E34948", dark: "#E66767"),
    ]

    /// Neutral used for "Other" in charts and for groups by default.
    static let neutral = "#8E8E93"

    /// New activities take palette slots in a fixed order.
    static func color(forIndex index: Int) -> String {
        slots[index % slots.count].light
    }

    static func slot(forHex hex: String) -> Slot? {
        slots.first { $0.light.caseInsensitiveCompare(hex) == .orderedSame }
    }
}
