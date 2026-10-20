import Foundation
import SwiftData
import Testing
@testable import TrackKar

@MainActor
struct AwayDetectorTests {
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func reportsAwayOnlyOnceTheUserIsBack() {
        var detector = AwayDetector(threshold: 600)
        #expect(detector.update(now: start, idleSeconds: 30, isTracking: true) == nil)
        // 15 minutes idle: away since 15 minutes ago, but not back yet.
        #expect(detector.update(now: start + 900, idleSeconds: 900, isTracking: true) == nil)
        #expect(detector.awaySince == start)
        // Back: the last input was 2 seconds ago.
        let away = detector.update(now: start + 1_202, idleSeconds: 2, isTracking: true)
        #expect(away == AwayInterval(start: start, end: start + 1_200))
        #expect(detector.awaySince == nil)
    }

    @Test func shortIdlesAndIdleTimersAreIgnored() {
        var detector = AwayDetector(threshold: 600)
        #expect(detector.update(now: start + 300, idleSeconds: 300, isTracking: true) == nil)
        #expect(detector.update(now: start + 301, idleSeconds: 1, isTracking: true) == nil)
        #expect(detector.update(now: start + 900, idleSeconds: 900, isTracking: false) == nil)
        #expect(detector.awaySince == nil)
    }

    @Test func offWhenThresholdIsZero() {
        var detector = AwayDetector(threshold: 0)
        #expect(detector.update(now: start, idleSeconds: 99_999, isTracking: true) == nil)
        #expect(detector.sleepEnded(from: start, to: start + 99_999, wasTracking: true) == nil)
    }

    @Test func longSleepsCountAsAway() {
        var detector = AwayDetector(threshold: 600)
        #expect(detector.sleepEnded(from: start, to: start + 300, wasTracking: true) == nil)
        #expect(detector.sleepEnded(from: start, to: start + 3_600, wasTracking: true) == AwayInterval(start: start, end: start + 3_600))
        #expect(detector.sleepEnded(from: start, to: start + 3_600, wasTracking: false) == nil)
    }
}

@MainActor
struct AwayResolutionTests {
    let container = Persistence.makeContainer(inMemory: true)
    let clock = TestClock()
    let settings = SettingsBox()
    let notifier = RecordingNotifier()
    let engine: TimerEngine

    var context: ModelContext { container.mainContext }

    init() {
        engine = TimerEngine(
            context: container.mainContext,
            clock: { [clock] in clock.date },
            settings: { [settings] in settings.value },
            notifier: notifier,
            ticks: false
        )
    }

    private func entry() throws -> TimeEntry {
        try #require(engine.activeEntry)
    }

    /// 10 min of work, then away for 45 min, then back for 1 min before answering.
    private func workThenAway() -> Date {
        engine.start(title: "Deep work", newActivityBehavior: .neverSave)
        let leftAt = clock.date + 600
        clock.advance(600 + 2_700 + 60)
        engine.reportAway(AwayInterval(start: leftAt, end: leftAt + 2_700))
        return leftAt
    }

    @Test func keepingCountsTheTimeAway() throws {
        _ = workThenAway()
        engine.resolveAway(.keep)
        #expect(engine.pendingAway == nil)
        #expect(try entry().duration(at: clock.date) == 3_360)
    }

    @Test func discardingRemovesTheTimeAwayAndKeepsRunning() throws {
        let leftAt = workThenAway()
        engine.resolveAway(.discard)

        let entry = try entry()
        #expect(engine.state == .running)
        #expect(entry.duration(at: clock.date) == 660)
        let gap = try #require(entry.breaks?.first)
        #expect(gap.kind == .away)
        #expect(gap.start == leftAt)
        #expect(gap.end == leftAt + 2_700)
    }

    @Test func discardAndPauseStopsTheClockWhereTheUserLeft() throws {
        let leftAt = workThenAway()
        engine.resolveAway(.discardAndPause)

        let entry = try entry()
        #expect(engine.state == .paused)
        #expect(entry.duration(at: clock.date) == 600)
        #expect(entry.openBreak?.start == leftAt)

        clock.advance(30)
        engine.resume()
        #expect(entry.openBreak == nil)
        #expect(entry.breakCount == 1)
    }

    @Test func awayIsOnlyRecordedWhileRunning() {
        engine.start(title: "Deep work", newActivityBehavior: .neverSave)
        engine.pause()
        engine.reportAway(AwayInterval(start: clock.date, end: clock.date + 1_000))
        #expect(engine.pendingAway == nil)
    }

    @Test func overlappingReportsMerge() {
        engine.start(title: "Deep work", newActivityBehavior: .neverSave)
        let t = clock.date
        clock.advance(5_000)
        engine.reportAway(AwayInterval(start: t + 100, end: t + 1_000))
        engine.reportAway(AwayInterval(start: t + 800, end: t + 3_000))
        #expect(engine.pendingAway == AwayInterval(start: t + 100, end: t + 3_000))
    }

    @Test func stoppingClearsThePendingQuestion() {
        _ = workThenAway()
        engine.stop()
        #expect(engine.pendingAway == nil)
    }

    // MARK: Reminders

    @Test func stopwatchesGetAReminderEveryFewHours() throws {
        settings.value.stillTrackingHours = 2
        let start = clock.date
        engine.start(title: "Deep work", newActivityBehavior: .neverSave)
        #expect(notifier.pendingReminder?.date == start + 7_200)
        #expect(notifier.pendingReminder?.body.contains("2h") == true)

        clock.advance(600)
        engine.pause()
        #expect(notifier.pendingReminder == nil)
        clock.advance(600)
        engine.resume()
        // Paused time doesn't count toward the two hours.
        #expect(notifier.pendingReminder?.date == start + 7_800)
    }

    @Test func remindersCanBeTurnedOffAndSkipCountdowns() {
        settings.value.stillTrackingHours = 0
        engine.start(title: "Deep work", newActivityBehavior: .neverSave)
        #expect(notifier.pendingReminder == nil)

        settings.value.stillTrackingHours = 1
        engine.start(title: "Tea", kind: .countdown(300), newActivityBehavior: .neverSave)
        #expect(notifier.pendingReminder == nil)
    }
}
