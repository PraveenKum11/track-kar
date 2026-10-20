import Foundation
import SwiftData

/// A saved, reusable thing to track time against. Time adds up across sessions and days.
@Model
final class Activity {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#4F7CFF"
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

enum ActivityPalette {
    static let colors = [
        "#4F7CFF", "#FF6B6B", "#2EC4B6", "#FFB020", "#A66CFF",
        "#3DBE6B", "#FF7AB6", "#00A3D9", "#8D6E63", "#7A869A",
    ]

    /// Cycles through the palette so consecutive activities get distinct colors.
    static func color(forIndex index: Int) -> String {
        colors[index % colors.count]
    }
}
