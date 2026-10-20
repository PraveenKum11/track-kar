#if DEBUG
import Foundation
import SwiftData

/// Realistic data for screenshots and manual testing. Launch with `-TrackKarSampleData YES`;
/// the app then uses an in-memory store, so real data is never touched.
enum SampleData {
    static var isRequested: Bool {
        UserDefaults.standard.bool(forKey: "TrackKarSampleData")
    }

    static func seed(_ context: ModelContext, now: Date = .now) {
        let calendar = Calendar.current
        let prep = ActivityGroup(name: "Interview prep", colorHex: ActivityPalette.slots[6].light)
        prep.targetHours = 40
        context.insert(prep)

        let specs: [(name: String, group: ActivityGroup?, minutes: [Int])] = [
            ("DSA practice", prep, [60, 45, 0, 90, 30, 75, 0, 60, 50, 0, 40, 80, 0, 55]),
            ("System design", prep, [0, 60, 45, 0, 90, 0, 30, 0, 60, 45, 0, 0, 70, 0]),
            ("Mock interviews", prep, [0, 0, 60, 0, 0, 0, 60, 0, 0, 0, 60, 0, 0, 45]),
            ("Client X website", nil, [180, 150, 200, 0, 0, 210, 160, 190, 0, 0, 170, 200, 140, 120]),
            ("Gym", nil, [45, 0, 50, 0, 45, 0, 0, 45, 0, 50, 0, 45, 0, 40]),
            ("Reading", nil, [20, 30, 0, 25, 0, 40, 20, 0, 30, 0, 25, 0, 35, 0]),
        ]

        for (index, spec) in specs.enumerated() {
            let activity = Activity(name: spec.name, colorHex: ActivityPalette.color(forIndex: index))
            context.insert(activity)
            activity.group = spec.group
            for (daysAgo, minutes) in spec.minutes.enumerated() where minutes > 0 {
                guard let day = calendar.date(byAdding: .day, value: -(daysAgo + 1), to: calendar.startOfDay(for: now)) else { continue }
                let start = day.addingTimeInterval(TimeInterval(8 + index * 2) * 3_600)
                addEntry(for: activity, start: start, minutes: minutes, withBreak: minutes >= 60, in: context)
            }
        }

        // An unsaved name, and today's work with a timer still running.
        let errands = TimeEntry(title: "Errands", activity: nil, createdAt: now.addingTimeInterval(-5 * 3_600))
        context.insert(errands)
        addSegment(to: errands, start: errands.createdAt, end: errands.createdAt + 1_500, in: context)
        errands.endedAt = errands.createdAt + 1_500

        let activities = (try? context.fetch(FetchDescriptor<Activity>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        if let client = activities.first(where: { $0.name == "Client X website" }) {
            addEntry(for: client, start: now.addingTimeInterval(-4 * 3_600), minutes: 95, withBreak: true, in: context)
        }
        if let dsa = activities.first(where: { $0.name == "DSA practice" }) {
            let running = TimeEntry(title: dsa.name, activity: dsa, createdAt: now.addingTimeInterval(-42 * 60))
            context.insert(running)
            addSegment(to: running, start: running.createdAt, end: nil, in: context)
        }
        try? context.save()
    }

    private static func addEntry(for activity: Activity, start: Date, minutes: Int, withBreak: Bool, in context: ModelContext) {
        let entry = TimeEntry(title: activity.name, activity: activity, createdAt: start)
        context.insert(entry)
        let work = TimeInterval(minutes * 60)
        if withBreak {
            let firstHalf = work / 2
            addSegment(to: entry, start: start, end: start + firstHalf, in: context)
            let pause = Break(kind: .pause, start: start + firstHalf)
            context.insert(pause)
            pause.end = start + firstHalf + 600
            pause.entry = entry
            addSegment(to: entry, start: start + firstHalf + 600, end: start + work + 600, in: context)
            entry.endedAt = start + work + 600
        } else {
            addSegment(to: entry, start: start, end: start + work, in: context)
            entry.endedAt = start + work
        }
    }

    private static func addSegment(to entry: TimeEntry, start: Date, end: Date?, in context: ModelContext) {
        let segment = Segment(start: start)
        context.insert(segment)
        segment.end = end
        segment.entry = entry
    }
}
#endif
