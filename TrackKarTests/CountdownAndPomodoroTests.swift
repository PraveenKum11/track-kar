import Foundation
import SwiftData
import Testing
@testable import TrackKar

@MainActor
final class RecordingNotifier: TimerNotifying {
    var scheduled: [TimerAlert?] = []
    var reminders: [TimerAlert?] = []
    var reached = 0

    var pending: TimerAlert? { scheduled.last ?? nil }
    var pendingReminder: TimerAlert? { reminders.last ?? nil }

    func schedule(_ alert: TimerAlert?) { scheduled.append(alert) }
    func scheduleReminder(_ reminder: TimerAlert?) { reminders.append(reminder) }
    func didReachAlert() { reached += 1 }
}

@MainActor
final class SettingsBox {
    var value = TimerSettings()
}

@MainActor
struct CountdownAndPomodoroTests {
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

    /// Simulates the once-a-second tick catching up to the clock.
    private func tick(after seconds: TimeInterval) {
        clock.advance(seconds)
        engine.timerSettingsChanged()
    }

    private func onlyEntry() throws -> TimeEntry {
        try #require(try context.fetch(FetchDescriptor<TimeEntry>()).first)
    }

    // MARK: Countdown

    @Test func countdownStopsExactlyAtTheTargetEvenWhenNoticedLate() throws {
        let start = clock.date
        engine.start(title: "Tea", kind: .countdown(300), newActivityBehavior: .neverSave)
        #expect(notifier.pending?.date == start + 300)

        tick(after: 330)

        let entry = try onlyEntry()
        #expect(engine.state == .idle)
        #expect(entry.endedAt == start + 300)
        #expect(entry.duration(at: clock.date) == 300)
        #expect(entry.targetReachedAt == start + 300)
        #expect(notifier.reached == 1)
        #expect(notifier.pending == nil)
    }

    @Test func countdownPausesDoNotCountAndMoveTheDeadline() throws {
        let start = clock.date
        engine.start(title: "Tea", kind: .countdown(300), newActivityBehavior: .neverSave)
        clock.advance(100)
        engine.pause()
        #expect(notifier.pending == nil)
        clock.advance(1_000)
        engine.resume()
        #expect(notifier.pending?.date == start + 1_300)
        #expect(engine.countdown?.remaining == 200)

        tick(after: 199)
        #expect(engine.state == .running)
        tick(after: 1)
        #expect(engine.state == .idle)
    }

    @Test func overtimeKeepsCountingAfterTheTarget() throws {
        settings.value.countdownEnd = .overtime
        engine.start(title: "Essay", kind: .countdown(60), newActivityBehavior: .neverSave)
        tick(after: 90)

        #expect(engine.state == .running)
        #expect(engine.countdown?.remaining == -30)
        #expect(engine.countdown?.isOvertime == true)
        #expect(notifier.reached == 1)

        tick(after: 60)
        #expect(notifier.reached == 1)
    }

    // MARK: Pomodoro

    @Test func focusEndsIntoAnAutoStartedShortBreak() throws {
        let start = clock.date
        engine.start(title: "DSA", kind: .pomodoro, newActivityBehavior: .neverSave)
        #expect(engine.countdown?.phase == .focus)
        #expect(notifier.pending?.date == start + 1_500)

        tick(after: 1_502)

        let entry = try onlyEntry()
        #expect(entry.pomodoroPhase == .shortBreak)
        #expect(entry.completedFocusCount == 1)
        #expect(entry.duration(at: clock.date) == 1_500)
        #expect(entry.openBreak?.kind == .shortBreak)
        #expect(entry.phaseStartedAt == start + 1_500)
        #expect(engine.countdown?.remaining == 298)
        #expect(notifier.pending?.date == start + 1_800)
    }

    @Test func breakEndsIntoWaitingFocusByDefault() throws {
        engine.start(title: "DSA", kind: .pomodoro, newActivityBehavior: .neverSave)
        tick(after: 1_500)
        tick(after: 300)

        let entry = try onlyEntry()
        #expect(entry.pomodoroPhase == .focus)
        #expect(entry.phaseStartedAt == nil)
        #expect(engine.countdown?.isWaiting == true)
        #expect(entry.openBreak == nil)
        #expect(entry.breaks?.first?.duration(at: clock.date) == 300)
        // Waiting time isn't tracked.
        tick(after: 600)
        #expect(entry.duration(at: clock.date) == 1_500)

        engine.startPhase()
        #expect(engine.state == .running)
        tick(after: 60)
        #expect(entry.duration(at: clock.date) == 1_560)
    }

    @Test func everyFourthFocusIsFollowedByALongBreak() throws {
        settings.value.autoStartFocus = true
        engine.start(title: "DSA", kind: .pomodoro, newActivityBehavior: .neverSave)
        var phases: [PomodoroPhase] = []
        for _ in 0..<4 {
            tick(after: 1_500)
            phases.append(try #require(engine.countdown?.phase))
            tick(after: TimeInterval(settings.value.length(of: phases.last!)))
        }
        #expect(phases == [.shortBreak, .shortBreak, .shortBreak, .longBreak])
        #expect(try onlyEntry().completedFocusCount == 4)
    }

    @Test func manualPausesExtendTheFocusPhase() throws {
        let start = clock.date
        engine.start(title: "DSA", kind: .pomodoro, newActivityBehavior: .neverSave)
        clock.advance(600)
        engine.pause()
        clock.advance(120)
        engine.resume()

        #expect(notifier.pending?.date == start + 1_620)
        tick(after: 899)
        #expect(engine.countdown?.phase == .focus)
        tick(after: 1)
        #expect(engine.countdown?.phase == .shortBreak)
    }

    @Test func breaksCannotBePausedOrResumedLikeFocus() throws {
        engine.start(title: "DSA", kind: .pomodoro, newActivityBehavior: .neverSave)
        tick(after: 1_500)
        engine.resume()
        #expect(engine.state == .paused)
        #expect(try onlyEntry().openSegment == nil)
    }

    @Test func sleepingThroughAPhaseEndDoesNotInventFocusTime() throws {
        settings.value.autoStartFocus = true
        engine.start(title: "DSA", kind: .pomodoro, newActivityBehavior: .neverSave)

        tick(after: 3 * 3_600)

        let entry = try onlyEntry()
        #expect(entry.duration(at: clock.date) == 1_500)
        #expect(entry.completedFocusCount == 1)
        #expect(entry.pomodoroPhase == .shortBreak)
        #expect(engine.countdown?.isWaiting == true)
    }

    @Test func skippingFocusCountsItAndStartsTheBreakNow() throws {
        settings.value.autoStartBreaks = false
        engine.start(title: "DSA", kind: .pomodoro, newActivityBehavior: .neverSave)
        clock.advance(600)
        engine.skipPhase()

        let entry = try onlyEntry()
        #expect(entry.completedFocusCount == 1)
        #expect(entry.pomodoroPhase == .shortBreak)
        #expect(entry.phaseStartedAt == clock.date)
        #expect(entry.duration(at: clock.date) == 600)

        engine.skipPhase()
        #expect(entry.pomodoroPhase == .focus)
        #expect(engine.state == .running)
    }

    @Test func stoppingDuringABreakEndsTheEntryWhenFocusEnded() throws {
        let start = clock.date
        engine.start(title: "DSA", kind: .pomodoro, newActivityBehavior: .neverSave)
        tick(after: 1_500)
        clock.advance(100)
        engine.stop()

        let entry = try onlyEntry()
        #expect(entry.endedAt == start + 1_500)
        #expect(entry.breakCount == 0)
        #expect(notifier.pending == nil)
    }

    @Test func pomodoroSurvivesARelaunch() throws {
        engine.start(title: "DSA", kind: .pomodoro, newActivityBehavior: .neverSave)
        tick(after: 1_500)

        let relaunched = TimerEngine(
            context: context,
            clock: { [clock] in clock.date },
            settings: { [settings] in settings.value },
            notifier: notifier,
            ticks: false
        )
        #expect(relaunched.countdown?.phase == .shortBreak)
        #expect(relaunched.countdown?.remaining == 300)
    }

    @Test func settingsRoundTripAndDefault() {
        var custom = TimerSettings()
        custom.focusMinutes = 50
        custom.countdownEnd = .overtime
        #expect(TimerSettings(rawValue: custom.rawValue) == custom)
        #expect(TimerSettings(rawValue: "{}") == TimerSettings())
    }
}
