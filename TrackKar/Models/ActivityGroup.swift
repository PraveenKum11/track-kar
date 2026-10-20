import Foundation
import SwiftData

/// An optional, one-level bucket of activities whose time is summed (e.g. "Interview prep").
@Model
final class ActivityGroup {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#8E8E93"
    /// Optional goal, e.g. 40 hours of interview prep.
    var targetHours: Double?
    var isArchived: Bool = false
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \Activity.group)
    var activities: [Activity]? = []

    init(name: String, colorHex: String = "#8E8E93", createdAt: Date = .now) {
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
    }
}
