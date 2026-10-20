import Foundation
import SwiftData
import Testing
@testable import TrackKar

@MainActor
struct SwitchingTests {
    let container = Persistence.makeContainer(inMemory: true)
    let clock = TestClock()
    let engine: TimerEngine

    var context: ModelContext { container.mainContext }

    init() {
        engine = TimerEngine(context: container.mainContext, clock: { [clock] in clock.date }, ticks: false)
    }

    private func entries() throws -> [TimeEntry] {
        try context.fetch(FetchDescriptor<TimeEntry>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    @Test func idleNeverNeedsConfirmation() {
        #expect(!engine.needsSwitchConfirmation(for: .title("Anything")))
    }

    @Test func reselectingTheCurrentTargetIsNotASwitch() throws {
        let gym = try EntryEditing.createActivity(name: "Gym", colorHex: nil, group: nil, in: context)
        engine.start(activity: gym)
        #expect(!engine.needsSwitchConfirmation(for: .activity(gym)))
        #expect(!engine.needsSwitchConfirmation(for: .title("gym")))
        #expect(engine.needsSwitchConfirmation(for: .title("Reading")))
    }

    @Test func untitledTimersAskBeforeSwitching() {
        engine.start(title: "", newActivityBehavior: .ask)
        #expect(engine.needsSwitchConfirmation(for: .title("Reading")))
    }

    @Test func saveAndSwitchKeepsTheOldEntry() throws {
        engine.start(title: "First", newActivityBehavior: .neverSave)
        clock.advance(600)
        engine.switchActiveEntry(to: .title("Second"), choice: .saveAndSwitch, newActivityBehavior: .neverSave)

        let all = try entries()
        #expect(all.map(\.title) == ["First", "Second"])
        #expect(all[0].duration(at: clock.date) == 600)
        #expect(engine.activeEntry == all[1])
    }

    @Test func moveTimeKeepsTheTimerRunningUnderTheNewActivity() throws {
        let dsa = try EntryEditing.createActivity(name: "DSA", colorHex: nil, group: nil, in: context)
        engine.start(title: "", newActivityBehavior: .ask)
        clock.advance(600)
        engine.pause()
        clock.advance(60)
        engine.resume()
        let original = try #require(engine.activeEntry)

        engine.switchActiveEntry(to: .activity(dsa), choice: .moveTime, newActivityBehavior: .ask)

        #expect(try entries().count == 1)
        #expect(engine.activeEntry == original)
        #expect(engine.state == .running)
        #expect(original.activity == dsa)
        #expect(original.title == "DSA")
        #expect(original.breakCount == 1)
        #expect(original.duration(at: clock.date) == 600)
    }

    @Test func moveTimeToANewNameFollowsTheSaveSetting() throws {
        engine.start(title: "", newActivityBehavior: .ask)
        engine.switchActiveEntry(to: .title("Errands"), choice: .moveTime, newActivityBehavior: .ask)
        #expect(engine.activeEntry?.title == "Errands")
        #expect(engine.savePromptEntry == engine.activeEntry)

        engine.switchActiveEntry(to: .title("Chores"), choice: .moveTime, newActivityBehavior: .alwaysSave)
        #expect(engine.activeEntry?.activity?.name == "Chores")
        #expect(engine.savePromptEntry == nil)
    }

    @Test func discardDeletesTheOldEntryAndStartsTheNewOne() throws {
        engine.start(title: "Oops", newActivityBehavior: .ask)
        clock.advance(300)
        engine.pause()
        engine.switchActiveEntry(to: .title("Real work"), choice: .discard, newActivityBehavior: .neverSave)

        let all = try entries()
        #expect(all.map(\.title) == ["Real work"])
        #expect(engine.state == .running)
        #expect(engine.savePromptEntry == nil)
        #expect(try context.fetchCount(FetchDescriptor<Segment>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Break>()) == 0)
    }
}

@MainActor
struct RestartTests {
    let container = Persistence.makeContainer(inMemory: true)
    let clock = TestClock()
    let engine: TimerEngine

    init() {
        engine = TimerEngine(context: container.mainContext, clock: { [clock] in clock.date }, ticks: false)
    }

    @Test func restartsTheMostRecentActivityInTheSameMode() throws {
        let gym = try EntryEditing.createActivity(name: "Gym", colorHex: nil, group: nil, in: container.mainContext)
        engine.start(title: "Reading", newActivityBehavior: .neverSave)
        clock.advance(60)
        engine.start(activity: gym, kind: .countdown(900))
        clock.advance(60)
        engine.stop()

        engine.restartMostRecent(newActivityBehavior: .ask)

        #expect(engine.activeEntry?.activity == gym)
        #expect(engine.activeEntry?.mode == .timer)
        #expect(engine.activeEntry?.targetDuration == 900)
    }

    @Test func restartsUnsavedNamesAndStartsUntitledWhenEmpty() {
        engine.restartMostRecent(newActivityBehavior: .neverSave)
        #expect(engine.activeEntry?.title == "")
        engine.stop()

        clock.advance(10)
        engine.start(title: "Errands", newActivityBehavior: .neverSave)
        engine.stop()
        engine.restartMostRecent(newActivityBehavior: .neverSave)
        #expect(engine.activeEntry?.title == "Errands")
    }
}
