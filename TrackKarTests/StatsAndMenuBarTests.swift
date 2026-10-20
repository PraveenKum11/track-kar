import Foundation
import SwiftData
import Testing
@testable import TrackKar

@MainActor
struct StatsTests {
    let container = Persistence.makeContainer(inMemory: true)
    let clock = TestClock()
    let engine: TimerEngine
    let calendar = Calendar(identifier: .gregorian)

    var context: ModelContext { container.mainContext }

    init() {
        engine = TimerEngine(context: container.mainContext, clock: { [clock] in clock.date }, ticks: false)
    }

    @Test func daysEndWithToday() {
        let days = Stats.days(endingAt: clock.date, count: 3, calendar: calendar)
        #expect(days.count == 3)
        #expect(days.last?.contains(clock.date) == true)
        #expect(days[0].start < days[1].start)
    }

    @Test func dailyAmountsSplitAcrossMidnight() throws {
        let activity = try EntryEditing.createActivity(name: "Night owl", colorHex: nil, group: nil, in: context)
        let midnight = calendar.startOfDay(for: clock.date) + 86_400
        clock.date = midnight - 600
        engine.start(activity: activity)
        clock.advance(1_800)
        engine.stop()

        let days = Stats.days(endingAt: clock.date, count: 2, calendar: calendar)
        let amounts = Stats.dailyAmounts(for: [activity], days: days, at: clock.date)
        #expect(amounts.map(\.seconds) == [600, 1_200])
    }

    @Test func extraActivitiesFoldIntoOther() throws {
        var activities: [Activity] = []
        for index in 0..<10 {
            let activity = try EntryEditing.createActivity(name: "A\(index)", colorHex: nil, group: nil, in: context)
            engine.start(activity: activity)
            clock.advance(TimeInterval(100 * (10 - index)))
            activities.append(activity)
        }
        engine.stop()

        let days = Stats.days(endingAt: clock.date, count: 1, calendar: calendar)
        let amounts = Stats.dailyAmounts(for: activities, days: days, at: clock.date)
        let series = amounts.map(\.series)

        #expect(series.count == 8)
        #expect(series.prefix(7) == ["A0", "A1", "A2", "A3", "A4", "A5", "A6"])
        let other = try #require(amounts.last)
        #expect(other.series == "Other")
        #expect(Int(other.seconds.rounded()) == 300 + 200 + 100)
    }
}

@MainActor
struct MenuBarOptionsTests {
    @Test func roundTripsThroughRawValue() {
        var options = MenuBarOptions()
        options.showName = true
        options.timeFormat = .units
        options.idleDisplay = .hidden
        #expect(MenuBarOptions(rawValue: options.rawValue) == options)
    }

    @Test func missingKeysFallBackToDefaults() {
        let options = MenuBarOptions(rawValue: #"{"showName": true}"#)
        var expected = MenuBarOptions()
        expected.showName = true
        #expect(options == expected)
    }

    @Test func runningShowsIconAndTimeByDefault() {
        let content = make(.running)
        #expect(content == MenuBarContent(symbolName: "timer", text: "1:24:05"))
    }

    @Test func pausedGlyphReplacesTheIcon() {
        #expect(make(.paused).symbolName == "pause.circle")
    }

    @Test func blinkingHidesTheTimeOnAlternateSeconds() {
        var options = MenuBarOptions()
        options.pausedStyle = .blink
        #expect(make(.paused, options: options, blinkOn: true).text == "1:24:05")
        #expect(make(.paused, options: options, blinkOn: false).text == nil)
        #expect(make(.paused, options: options, blinkOn: false).symbolName == "timer")
    }

    @Test func nameIsTruncatedAndPrecedesTheTime() {
        var options = MenuBarOptions()
        options.showName = true
        options.nameLength = 8
        options.timeFormat = .clockNoSeconds
        #expect(make(.running, options: options).text == "Intervi… 1:24")
    }

    @Test func idleCanShowTodaysTotal() {
        var options = MenuBarOptions()
        options.idleDisplay = .iconAndToday
        #expect(make(.idle, options: options) == MenuBarContent(symbolName: "timer", text: "3h 42m"))
    }

    @Test func neverRendersAnEmptyItem() {
        var options = MenuBarOptions()
        options.showIcon = false
        options.showTime = false
        #expect(make(.running, options: options).symbolName == "timer")
    }

    private func make(_ state: TrackingState, options: MenuBarOptions = MenuBarOptions(), blinkOn: Bool = true) -> MenuBarContent {
        MenuBarContent.make(
            options: options,
            state: state,
            elapsed: 5_045,
            activityName: "Interview prep",
            colorHex: "#2A78D6",
            todayTotal: 13_379,
            blinkOn: blinkOn
        )
    }
}

@MainActor
struct MenuBarImageSlotTests {
    private func make(_ state: TrackingState, _ configure: (inout MenuBarOptions) -> Void) -> MenuBarContent {
        var options = MenuBarOptions()
        configure(&options)
        return MenuBarContent.make(
            options: options, state: state, elapsed: 60, activityName: "A",
            colorHex: "#2A78D6", todayTotal: 0, blinkOn: true
        )
    }

    @Test func colorDotTakesTheIconSlot() {
        let content = make(.running) { $0.showColorDot = true }
        #expect(content.colorHex == "#2A78D6")
        #expect(content.symbolName == nil)
    }

    @Test func pauseGlyphBeatsTheColorDot() {
        let content = make(.paused) { $0.showColorDot = true }
        #expect(content.symbolName == "pause.circle")
        #expect(content.colorHex == nil)
    }
}
