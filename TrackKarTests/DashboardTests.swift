import Foundation
import SwiftData
import Testing
@testable import TrackKar

@MainActor
struct DashboardRangeTests {
    /// Monday-first calendar in UTC, so expectations don't depend on the machine.
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2
        return calendar
    }

    /// Wednesday 21 October 2026, 15:00 UTC.
    let now = ISO8601DateFormatter().date(from: "2026-10-21T15:00:00Z")!

    private func day(_ string: String) -> Date {
        ISO8601DateFormatter().date(from: "\(string)T00:00:00Z")!
    }

    @Test func weekFollowsTheFirstWeekday() {
        let range = DashboardRange(period: .week)
        let interval = range.interval(calendar: calendar, now: now)
        #expect(interval.start == day("2026-10-19"))
        #expect(interval.end == day("2026-10-26"))
        #expect(range.previousInterval(calendar: calendar, now: now).start == day("2026-10-12"))
    }

    @Test func offsetStepsBackWholePeriods() {
        var range = DashboardRange(period: .month)
        range.offset = -1
        let interval = range.interval(calendar: calendar, now: now)
        #expect(interval.start == day("2026-09-01"))
        #expect(interval.end == day("2026-10-01"))
        #expect(range.previousInterval(calendar: calendar, now: now).start == day("2026-08-01"))
    }

    @Test func customRangeIncludesBothDaysAndComparesWithTheSameLengthBefore() {
        var range = DashboardRange(period: .custom)
        range.customStart = day("2026-10-10").addingTimeInterval(3_600)
        range.customEnd = day("2026-10-14").addingTimeInterval(7_200)
        let interval = range.interval(calendar: calendar, now: now)
        #expect(interval.start == day("2026-10-10"))
        #expect(interval.end == day("2026-10-15"))
        let previous = range.previousInterval(calendar: calendar, now: now)
        #expect(previous.start == day("2026-10-05"))
        #expect(previous.end == day("2026-10-10"))
    }

    @Test func titlesNameRecentPeriods() {
        #expect(DashboardRange(period: .day).title(calendar: calendar, now: now) == "Today")
        #expect(DashboardRange(period: .week, offset: -1).title(calendar: calendar, now: now) == "Last week")
        #expect(DashboardRange(period: .month).title(calendar: calendar, now: now) == "This month")
    }

    @Test func longRangesUseWeeklyBuckets() {
        let quarter = DateInterval(start: day("2026-07-01"), end: day("2026-10-01"))
        let (weekly, unit) = Stats.buckets(for: quarter, calendar: calendar)
        #expect(unit == .weekOfYear)
        #expect(weekly.count == 14)

        let week = DateInterval(start: day("2026-10-19"), end: day("2026-10-26"))
        let (daily, dayUnit) = Stats.buckets(for: week, calendar: calendar)
        #expect(dayUnit == .day)
        #expect(daily.count == 7)
    }

    @Test func elapsedDaysStopAtToday() {
        let week = DateInterval(start: day("2026-10-19"), end: day("2026-10-26"))
        #expect(Stats.elapsedDays(of: week, at: now, calendar: calendar) == 3)
        let lastWeek = DateInterval(start: day("2026-10-12"), end: day("2026-10-19"))
        #expect(Stats.elapsedDays(of: lastWeek, at: now, calendar: calendar) == 7)
    }
}

@MainActor
struct BreakdownAndExportTests {
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

    /// DSA 30m (in "Prep"), Gym 20m with a 5m pause, and an unsaved 10m "Errands".
    private func seed() throws -> DateInterval {
        let start = clock.date
        let prep = ActivityGroup(name: "Prep", colorHex: "#6250D6")
        context.insert(prep)
        let dsa = try EntryEditing.createActivity(name: "DSA", colorHex: nil, group: prep, in: context)
        let gym = try EntryEditing.createActivity(name: "Gym", colorHex: nil, group: nil, in: context)
        engine.start(activity: dsa)
        clock.advance(1_800)
        engine.start(activity: gym)
        clock.advance(600)
        engine.pause()
        clock.advance(300)
        engine.resume()
        clock.advance(600)
        engine.start(title: "Errands", newActivityBehavior: .neverSave)
        clock.advance(600)
        engine.stop()
        return DateInterval(start: start, end: clock.date)
    }

    @Test func breakdownByActivityIsLargestFirstWithUnsavedTogether() throws {
        let range = try seed()
        let items = Stats.breakdown(of: try entries(), in: range, at: clock.date, by: .activity)
        #expect(items.map(\.name) == ["DSA", "Gym", "Unsaved"])
        #expect(items.map(\.seconds) == [1_800, 1_200, 600])
        #expect(items.map(\.sessions) == [1, 1, 1])
    }

    @Test func breakdownByGroupPutsEverythingElseInUngrouped() throws {
        let range = try seed()
        let items = Stats.breakdown(of: try entries(), in: range, at: clock.date, by: .group)
        // Equal totals sort by name.
        #expect(items.map(\.name) == ["Prep", "Ungrouped"])
        #expect(items.map(\.seconds) == [1_800, 1_800])
    }

    @Test func breakStatsCountPausesInTheRange() throws {
        let range = try seed()
        let stats = Stats.breakStats(of: try entries(), in: range, at: clock.date)
        #expect(stats == BreakStats(count: 1, total: 300))
        #expect(stats.average == 300)
    }

    @Test func csvHasAHeaderRowPerEntryAndEscapes() throws {
        _ = try seed()
        let all = try entries()
        all[2].notes = "Bank, \"post\" office\nthen groceries"
        let csv = Exporter.csv(all, at: clock.date)
        let lines = csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }

        #expect(lines.first == Exporter.csvHeader.joined(separator: ","))
        #expect(csv.contains("\"Bank, \"\"post\"\" office\nthen groceries\""))
        #expect(lines[1].contains(",0:30:00,0.50,DSA,Prep,DSA,stopwatch,0,0,,"))
        #expect(lines[2].contains(",0:20:00,0.33,Gym,,Gym,stopwatch,1,5,,"))
    }

    @Test func csvNeutralizesFormulaLikeCells() {
        #expect(Exporter.escape("=SUM(A1)") == "'=SUM(A1)")
        #expect(Exporter.escape("plain") == "plain")
    }

    @Test func jsonRoundTripsTheWholeRecord() throws {
        _ = try seed()
        let data = try Exporter.json(
            try entries(),
            activities: try context.fetch(FetchDescriptor<Activity>()),
            groups: try context.fetch(FetchDescriptor<ActivityGroup>()),
            at: clock.date
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file = try decoder.decode(ExportFile.self, from: data)

        #expect(file.version == 1)
        #expect(file.groups.map(\.name) == ["Prep"])
        #expect(file.activities.count == 2)
        #expect(file.entries.map(\.durationSeconds) == [1_800, 1_200, 600])
        #expect(file.entries[1].segments.count == 2)
        #expect(file.entries[1].breaks.map(\.kind) == ["pause"])
        #expect(file.entries[2].activityID == nil)
        #expect(file.activities.first { $0.name == "DSA" }?.groupID == file.groups.first?.id)
    }
}
