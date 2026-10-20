import Foundation
import SwiftData
import Testing
@testable import TrackKar

@MainActor
final class TestClock {
    var date = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func advance(_ seconds: TimeInterval) {
        date += seconds
    }
}

@MainActor
struct TimerEngineTests {
    let container = Persistence.makeContainer(inMemory: true)
    let clock = TestClock()
    let engine: TimerEngine

    init() {
        engine = TimerEngine(context: container.mainContext, clock: { [clock] in clock.date }, ticks: false)
    }

    private func entries() throws -> [TimeEntry] {
        try container.mainContext.fetch(FetchDescriptor<TimeEntry>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    private func activities() throws -> [Activity] {
        try container.mainContext.fetch(FetchDescriptor<Activity>())
    }

    // MARK: - Duration and breaks

    @Test func pausesAreCountedAsBreaksButNotTracked() throws {
        engine.start(title: "Deep work", newActivityBehavior: .neverSave)
        clock.advance(600)
        engine.pause()
        #expect(engine.state == .paused)
        clock.advance(300)
        engine.resume()
        clock.advance(120)
        engine.stop()

        let entry = try #require(try entries().first)
        #expect(entry.duration(at: clock.date) == 720)
        #expect(entry.breakCount == 1)
        #expect(entry.breaks?.first?.duration(at: clock.date) == 300)
        #expect(entry.endedAt == clock.date)
        #expect(engine.state == .idle)
    }

    @Test func stoppingWhilePausedEndsTheEntryAtThePause() throws {
        engine.start(title: "Reading", newActivityBehavior: .neverSave)
        clock.advance(100)
        engine.pause()
        let pausedAt = clock.date
        clock.advance(10_000)
        engine.stop()

        let entry = try #require(try entries().first)
        #expect(entry.endedAt == pausedAt)
        #expect(entry.breakCount == 0)
        #expect(entry.duration(at: clock.date) == 100)
    }

    @Test func startingAnotherTimerStopsTheCurrentOne() throws {
        engine.start(title: "First", newActivityBehavior: .neverSave)
        clock.advance(60)
        engine.start(title: "Second", newActivityBehavior: .neverSave)

        let all = try entries()
        #expect(all.count == 2)
        #expect(all[0].endedAt == clock.date)
        #expect(all[0].duration(at: clock.date) == 60)
        #expect(engine.activeEntry == all[1])
    }

    @Test func runningEntryIsRestoredByANewEngine() throws {
        engine.start(title: "Survives relaunch", newActivityBehavior: .neverSave)
        clock.advance(42)

        let relaunched = TimerEngine(context: container.mainContext, clock: { [clock] in clock.date }, ticks: false)
        #expect(relaunched.state == .running)
        #expect(relaunched.activeEntry?.title == "Survives relaunch")
        #expect(relaunched.elapsed == 42)
    }

    @Test func durationIsClippedToADay() throws {
        let calendar = Calendar(identifier: .gregorian)
        let midnight = calendar.startOfDay(for: clock.date).addingTimeInterval(86_400)
        clock.date = midnight.addingTimeInterval(-1_800)
        engine.start(title: "Late night", newActivityBehavior: .neverSave)
        clock.advance(3_600)

        let entry = try #require(engine.activeEntry)
        let nextDay = DateInterval(start: midnight, duration: 86_400)
        #expect(entry.duration(in: nextDay, at: clock.date) == 1_800)
        #expect(entry.duration(at: clock.date) == 3_600)
    }

    // MARK: - Activities and the save prompt

    @Test func existingActivityIsReusedIgnoringCase() throws {
        let activity = Activity(name: "Interview Prep", colorHex: "#4F7CFF")
        container.mainContext.insert(activity)

        engine.start(title: "interview prep", newActivityBehavior: .ask)

        #expect(engine.activeEntry?.activity == activity)
        #expect(engine.savePromptEntry == nil)
        #expect(try activities().count == 1)
    }

    @Test func askBehaviorLeavesEntryUnsavedAndPrompts() throws {
        engine.start(title: "Gym", newActivityBehavior: .ask)

        #expect(engine.activeEntry?.activity == nil)
        #expect(engine.savePromptEntry == engine.activeEntry)
        #expect(try activities().isEmpty)
    }

    @Test func savingFromThePromptAlsoClaimsEarlierUnsavedEntries() throws {
        engine.start(title: "Gym", newActivityBehavior: .neverSave)
        clock.advance(60)
        engine.start(title: "gym", newActivityBehavior: .ask)
        engine.saveActivityFromPrompt()

        let activity = try #require(try activities().first)
        #expect(activity.name == "gym")
        #expect(try entries().allSatisfy { $0.activity == activity })
        #expect(engine.savePromptEntry == nil)
    }

    @Test func justThisOnceKeepsTheEntryUnsaved() throws {
        engine.start(title: "Errands", newActivityBehavior: .ask)
        engine.dismissSavePrompt()

        #expect(engine.savePromptEntry == nil)
        #expect(engine.activeEntry?.activity == nil)
        #expect(try activities().isEmpty)
    }

    @Test func alwaysSaveCreatesTheActivityImmediately() throws {
        engine.start(title: "Side project", newActivityBehavior: .alwaysSave)

        #expect(engine.activeEntry?.activity?.name == "Side project")
        #expect(engine.savePromptEntry == nil)
    }

    @Test func untitledEntriesNeverPrompt() throws {
        engine.start(title: "   ", newActivityBehavior: .ask)

        #expect(engine.activeEntry?.title == "")
        #expect(engine.activeEntry?.displayName == "Untitled")
        #expect(engine.savePromptEntry == nil)
    }

    // MARK: - Formatting

    @Test func durationsRoundDown() {
        #expect(DurationFormat.clock(5_045.9) == "1:24:05")
        #expect(DurationFormat.short(119) == "1m")
        #expect(DurationFormat.short(13_379) == "3h 42m")
    }

    // MARK: - Lookup helpers

    @Test func suggestionsPutPrefixMatchesFirst() {
        let design = Activity(name: "System design", colorHex: "#000000")
        let dsa = Activity(name: "DSA practice", colorHex: "#000000")
        let names = ActivityLookup.suggestions(for: "s", from: [design, dsa]).map(\.name)
        #expect(names == ["System design", "DSA practice"])
    }

    @Test func recentActivitiesAreDistinctAndExcludeTheActiveOne() throws {
        let a = Activity(name: "A", colorHex: "#000000")
        let b = Activity(name: "B", colorHex: "#000000")
        container.mainContext.insert(a)
        container.mainContext.insert(b)
        engine.start(activity: a)
        clock.advance(1)
        engine.start(activity: b)
        clock.advance(1)
        engine.start(activity: a)

        let newestFirst = try entries().reversed()
        let recent = ActivityLookup.recentActivities(from: Array(newestFirst), excluding: a, limit: 4)
        #expect(recent == [b])
    }
}
