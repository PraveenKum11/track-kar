import Foundation
import SwiftData

enum EditingError: LocalizedError, Equatable {
    case emptyName
    case duplicateName(String)
    case endNotAfterStart
    case startAfterFirstRun
    case endBeforeLastRun
    case entryIsActive

    var errorDescription: String? {
        switch self {
        case .emptyName:
            String(localized: "Enter a name.")
        case .duplicateName(let name):
            String(localized: "An activity named “\(name)” already exists.")
        case .endNotAfterStart:
            String(localized: "The end time must be after the start time.")
        case .startAfterFirstRun:
            String(localized: "The start time can't be after this entry's first break began.")
        case .endBeforeLastRun:
            String(localized: "The end time can't be before this entry's last break ended.")
        case .entryIsActive:
            String(localized: "Stop the timer before changing this entry's times.")
        }
    }
}

/// Changes made from History and Activities. Active-entry state changes stay in `TimerEngine`.
enum EntryEditing {
    // MARK: Entries

    @discardableResult
    static func createManualEntry(
        title: String,
        activity: Activity?,
        start: Date,
        end: Date,
        notes: String?,
        in context: ModelContext
    ) throws -> TimeEntry {
        guard end > start else { throw EditingError.endNotAfterStart }
        let title = activity?.name ?? title.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = TimeEntry(title: title, activity: activity, createdAt: start)
        entry.endedAt = end
        entry.notes = notes?.nilIfBlank
        context.insert(entry)
        let segment = Segment(start: start)
        context.insert(segment)
        segment.end = end
        segment.entry = entry
        return entry
    }

    /// Moves the entry's start and end. Breaks in between are kept, so the new range must still
    /// contain them: the start can't pass the end of the first segment, nor the end the start of the last.
    static func setTimes(of entry: TimeEntry, start: Date, end: Date) throws {
        guard !entry.isActive else { throw EditingError.entryIsActive }
        guard end > start else { throw EditingError.endNotAfterStart }
        let segments = (entry.segments ?? []).sorted { $0.start < $1.start }
        guard let first = segments.first, let last = segments.last else {
            throw EditingError.endNotAfterStart
        }
        if let firstEnd = first.end, start >= firstEnd { throw EditingError.startAfterFirstRun }
        guard end > last.start else { throw EditingError.endBeforeLastRun }

        first.start = start
        last.end = end
        entry.createdAt = start
        entry.endedAt = end
    }

    /// Links the entry to `activity`, or makes it unsaved with `title` when `activity` is nil.
    static func assign(_ entry: TimeEntry, to activity: Activity?, title: String) {
        entry.activity = activity
        entry.title = activity?.name ?? title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Activities

    static func validateActivityName(
        _ name: String,
        excluding activity: Activity? = nil,
        in context: ModelContext
    ) throws -> String {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw EditingError.emptyName }
        let all = (try? context.fetch(FetchDescriptor<Activity>())) ?? []
        if all.contains(where: { $0 != activity && $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            throw EditingError.duplicateName(name)
        }
        return name
    }

    @discardableResult
    static func createActivity(
        name: String,
        colorHex: String?,
        group: ActivityGroup?,
        in context: ModelContext,
        at date: Date = .now
    ) throws -> Activity {
        let name = try validateActivityName(name, in: context)
        let count = (try? context.fetchCount(FetchDescriptor<Activity>())) ?? 0
        let activity = Activity(name: name, colorHex: colorHex ?? ActivityPalette.color(forIndex: count), createdAt: date)
        context.insert(activity)
        activity.group = group
        return activity
    }

    /// Renames and keeps each entry's name snapshot in step.
    static func rename(_ activity: Activity, to name: String, in context: ModelContext) throws {
        let name = try validateActivityName(name, excluding: activity, in: context)
        activity.name = name
        for entry in activity.entries ?? [] {
            entry.title = name
        }
    }

    /// Moves every entry from `source` to `target`, then deletes `source`.
    static func merge(_ source: Activity, into target: Activity, in context: ModelContext) {
        guard source != target else { return }
        for entry in source.entries ?? [] {
            entry.activity = target
            entry.title = target.name
        }
        context.delete(source)
    }

    /// Deletes the activity. Its entries stay in History as unsaved entries under the same name.
    static func delete(_ activity: Activity, in context: ModelContext) {
        for entry in activity.entries ?? [] {
            entry.activity = nil
        }
        context.delete(activity)
    }

    // MARK: Groups

    /// Deletes the group. Its activities become ungrouped; no time is lost.
    static func delete(_ group: ActivityGroup, in context: ModelContext) {
        for activity in group.activities ?? [] {
            activity.group = nil
        }
        context.delete(group)
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension String {
    /// Localizes and applies grammar agreement, so `^[2 break](inflect: true)` becomes "2 breaks".
    /// Plain `String(localized:)` leaves that markup as-is; only `Text` and `AttributedString` apply it.
    static func inflected(_ resource: LocalizedStringResource) -> String {
        String(AttributedString(localized: resource).characters)
    }
}
