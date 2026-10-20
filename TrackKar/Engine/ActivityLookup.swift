import Foundation
import SwiftData

enum ActivityLookup {
    /// The non-archived activity whose name matches, ignoring case.
    static func activity(named name: String, in context: ModelContext) -> Activity? {
        let descriptor = FetchDescriptor<Activity>(predicate: #Predicate { !$0.isArchived })
        let activities = (try? context.fetch(descriptor)) ?? []
        return activities.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
    }

    /// Activities matching `query`, names starting with it first.
    static func suggestions(for query: String, from activities: [Activity], limit: Int = 5) -> [Activity] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let matches = activities.filter { $0.name.localizedCaseInsensitiveContains(query) }
        let prefixed = matches.filter { $0.name.lowercased().hasPrefix(query.lowercased()) }
        let rest = matches.filter { !$0.name.lowercased().hasPrefix(query.lowercased()) }
        return Array((prefixed + rest).prefix(limit))
    }

    /// Distinct activities from the most recent entries, newest first.
    static func recentActivities(from entries: [TimeEntry], excluding excluded: Activity?, limit: Int) -> [Activity] {
        var seen = Set<PersistentIdentifier>()
        var result: [Activity] = []
        for entry in entries {
            guard let activity = entry.activity, !activity.isArchived, activity != excluded else { continue }
            guard seen.insert(activity.persistentModelID).inserted else { continue }
            result.append(activity)
            if result.count == limit { break }
        }
        return result
    }

    /// Creates an activity named `title` and attaches every unsaved entry with that name to it.
    @discardableResult
    static func promote(title: String, in context: ModelContext, at date: Date) -> Activity {
        let count = (try? context.fetchCount(FetchDescriptor<Activity>())) ?? 0
        let activity = Activity(name: title, colorHex: ActivityPalette.color(forIndex: count), createdAt: date)
        context.insert(activity)

        let unsaved = FetchDescriptor<TimeEntry>(predicate: #Predicate { $0.activity == nil })
        for entry in (try? context.fetch(unsaved)) ?? []
        where entry.title.localizedCaseInsensitiveCompare(title) == .orderedSame {
            entry.activity = activity
        }
        return activity
    }
}
