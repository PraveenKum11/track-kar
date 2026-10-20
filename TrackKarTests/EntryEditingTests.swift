import Foundation
import SwiftData
import Testing
@testable import TrackKar

@MainActor
struct EntryEditingTests {
    let container = Persistence.makeContainer(inMemory: true)
    let clock = TestClock()
    let engine: TimerEngine

    var context: ModelContext { container.mainContext }

    init() {
        engine = TimerEngine(context: container.mainContext, clock: { [clock] in clock.date }, ticks: false)
    }

    /// 10 min work, 5 min break, 20 min work.
    private func entryWithBreak() throws -> TimeEntry {
        engine.start(title: "Work", newActivityBehavior: .neverSave)
        clock.advance(600)
        engine.pause()
        clock.advance(300)
        engine.resume()
        clock.advance(1_200)
        engine.stop()
        return try #require(try context.fetch(FetchDescriptor<TimeEntry>()).first)
    }

    // MARK: Entries

    @Test func manualEntryHasOneSegment() throws {
        let start = clock.date
        let entry = try EntryEditing.createManualEntry(
            title: " Reading ", activity: nil, start: start, end: start + 1_800, notes: "  ", in: context
        )
        #expect(entry.title == "Reading")
        #expect(entry.notes == nil)
        #expect(entry.duration(at: clock.date + 99_999) == 1_800)
        #expect(entry.segments?.count == 1)
        #expect(!entry.isActive)
    }

    @Test func manualEntryRejectsEndBeforeStart() {
        #expect(throws: EditingError.endNotAfterStart) {
            try EntryEditing.createManualEntry(
                title: "x", activity: nil, start: clock.date, end: clock.date, notes: nil, in: context
            )
        }
    }

    @Test func movingTimesKeepsBreaks() throws {
        let entry = try entryWithBreak()
        let originalStart = entry.createdAt
        try EntryEditing.setTimes(of: entry, start: originalStart - 300, end: try #require(entry.endedAt) + 60)

        #expect(entry.duration(at: clock.date) == 1_800 + 300 + 60)
        #expect(entry.breakCount == 1)
        #expect(entry.createdAt == originalStart - 300)
    }

    @Test func startCannotPassTheFirstBreak() throws {
        let entry = try entryWithBreak()
        #expect(throws: EditingError.startAfterFirstRun) {
            try EntryEditing.setTimes(of: entry, start: entry.createdAt + 700, end: try #require(entry.endedAt))
        }
    }

    @Test func endCannotPassTheLastBreak() throws {
        let entry = try entryWithBreak()
        #expect(throws: EditingError.endBeforeLastRun) {
            try EntryEditing.setTimes(of: entry, start: entry.createdAt, end: entry.createdAt + 800)
        }
    }

    @Test func activeEntryTimesAreLocked() throws {
        engine.start(title: "Live", newActivityBehavior: .neverSave)
        let entry = try #require(engine.activeEntry)
        #expect(throws: EditingError.entryIsActive) {
            try EntryEditing.setTimes(of: entry, start: clock.date - 60, end: clock.date + 60)
        }
    }

    @Test func deletingSkipsTheActiveEntry() throws {
        let finished = try entryWithBreak()
        engine.start(title: "Live", newActivityBehavior: .neverSave)
        let active = try #require(engine.activeEntry)

        engine.delete([finished, active])

        let remaining = try context.fetch(FetchDescriptor<TimeEntry>())
        #expect(remaining == [active])
        #expect(try context.fetchCount(FetchDescriptor<Break>()) == 0)
    }

    // MARK: Activities

    @Test func duplicateNamesAreRejectedIgnoringCase() throws {
        try EntryEditing.createActivity(name: "Gym", colorHex: nil, group: nil, in: context)
        #expect(throws: EditingError.duplicateName("gym")) {
            try EntryEditing.createActivity(name: "gym", colorHex: nil, group: nil, in: context)
        }
    }

    @Test func newActivitiesTakePaletteSlotsInOrder() throws {
        let first = try EntryEditing.createActivity(name: "A", colorHex: nil, group: nil, in: context)
        let second = try EntryEditing.createActivity(name: "B", colorHex: nil, group: nil, in: context)
        #expect(first.colorHex == ActivityPalette.slots[0].light)
        #expect(second.colorHex == ActivityPalette.slots[1].light)
    }

    @Test func renameUpdatesEntrySnapshots() throws {
        let activity = try EntryEditing.createActivity(name: "DSA", colorHex: nil, group: nil, in: context)
        engine.start(activity: activity)
        engine.stop()

        try EntryEditing.rename(activity, to: "DSA practice", in: context)

        #expect(activity.entries?.first?.title == "DSA practice")
    }

    @Test func mergeMovesEntriesAndDeletesSource() throws {
        let source = try EntryEditing.createActivity(name: "Leetcode", colorHex: nil, group: nil, in: context)
        let target = try EntryEditing.createActivity(name: "DSA", colorHex: nil, group: nil, in: context)
        engine.start(activity: source)
        clock.advance(100)
        engine.start(activity: target)
        clock.advance(50)
        engine.stop()

        EntryEditing.merge(source, into: target, in: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Activity>()) == [target])
        #expect(target.entries?.count == 2)
        #expect(target.totalDuration(at: clock.date) == 150)
    }

    @Test func deletingAnActivityKeepsItsEntriesUnsaved() throws {
        let activity = try EntryEditing.createActivity(name: "Gym", colorHex: nil, group: nil, in: context)
        engine.start(activity: activity)
        engine.stop()

        EntryEditing.delete(activity, in: context)
        try context.save()

        let entry = try #require(try context.fetch(FetchDescriptor<TimeEntry>()).first)
        #expect(entry.activity == nil)
        #expect(entry.title == "Gym")
    }

    // MARK: Groups

    @Test func groupTotalFollowsMembership() throws {
        let prep = ActivityGroup(name: "Interview prep")
        let other = ActivityGroup(name: "Other")
        context.insert(prep)
        context.insert(other)
        let dsa = try EntryEditing.createActivity(name: "DSA", colorHex: nil, group: prep, in: context)
        let design = try EntryEditing.createActivity(name: "System design", colorHex: nil, group: prep, in: context)
        engine.start(activity: dsa)
        clock.advance(600)
        engine.start(activity: design)
        clock.advance(900)
        engine.stop()

        #expect(prep.totalDuration(at: clock.date) == 1_500)

        design.group = other
        #expect(prep.totalDuration(at: clock.date) == 600)
        #expect(other.totalDuration(at: clock.date) == 900)
    }

    @Test func deletingAGroupUngroupsItsActivities() throws {
        let group = ActivityGroup(name: "Prep")
        context.insert(group)
        let dsa = try EntryEditing.createActivity(name: "DSA", colorHex: nil, group: group, in: context)

        EntryEditing.delete(group, in: context)
        try context.save()

        #expect(dsa.group == nil)
        #expect(try context.fetch(FetchDescriptor<Activity>()) == [dsa])
    }
}

@MainActor
struct EraseTests {
    let container = Persistence.makeContainer(inMemory: true)
    let clock = TestClock()
    let engine: TimerEngine

    var context: ModelContext { container.mainContext }

    init() {
        engine = TimerEngine(context: container.mainContext, clock: { [clock] in clock.date }, ticks: false)
    }

    @Test func erasingRemovesEverythingIncludingTheRunningTimer() throws {
        let group = ActivityGroup(name: "Prep")
        context.insert(group)
        let dsa = try EntryEditing.createActivity(name: "DSA", colorHex: nil, group: group, in: context)
        engine.start(activity: dsa)
        clock.advance(600)
        engine.pause()
        clock.advance(60)
        engine.resume()
        engine.start(title: "Errands", newActivityBehavior: .ask)

        engine.eraseAllData()

        #expect(engine.state == .idle)
        #expect(engine.activeEntry == nil)
        #expect(engine.savePromptEntry == nil)
        #expect(try context.fetchCount(FetchDescriptor<TimeEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Segment>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Break>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Activity>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<ActivityGroup>()) == 0)

        // Tracking works normally afterwards.
        engine.start(title: "Fresh start", newActivityBehavior: .neverSave)
        #expect(engine.state == .running)
    }
}
