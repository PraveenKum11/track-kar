import Foundation

enum CountdownEndBehavior: String, Codable, CaseIterable, Identifiable {
    case stop, overtime

    var id: Self { self }

    var label: String {
        switch self {
        case .stop: String(localized: "Stop the timer")
        case .overtime: String(localized: "Keep counting as overtime")
        }
    }
}

/// Countdown and Pomodoro settings (Settings → Timers), stored as one JSON string.
struct TimerSettings: Equatable {
    var countdownEnd: CountdownEndBehavior = .stop
    var focusMinutes = 25
    var shortBreakMinutes = 5
    var longBreakMinutes = 15
    /// Focus sessions before a long break.
    var cyclesBeforeLongBreak = 4
    var autoStartBreaks = true
    var autoStartFocus = false

    func length(of phase: PomodoroPhase) -> TimeInterval {
        let minutes = switch phase {
        case .focus: focusMinutes
        case .shortBreak: shortBreakMinutes
        case .longBreak: longBreakMinutes
        }
        return TimeInterval(minutes * 60)
    }

    /// The break that follows the `completedFocus`-th focus session.
    func breakPhase(afterCompletedFocus completedFocus: Int) -> PomodoroPhase {
        completedFocus > 0 && completedFocus % max(1, cyclesBeforeLongBreak) == 0 ? .longBreak : .shortBreak
    }

    /// Reads the saved settings, falling back to defaults.
    static var current: TimerSettings {
        UserDefaults.standard.string(forKey: PreferenceKey.timerSettings).flatMap(TimerSettings.init(rawValue:)) ?? TimerSettings()
    }
}

// Explicit coding so settings added later decode with their defaults (see `MenuBarOptions`).
extension TimerSettings: Codable {
    private enum CodingKeys: String, CodingKey {
        case countdownEnd, focusMinutes, shortBreakMinutes, longBreakMinutes
        case cyclesBeforeLongBreak, autoStartBreaks, autoStartFocus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = TimerSettings()
        countdownEnd = (try? container.decodeIfPresent(CountdownEndBehavior.self, forKey: .countdownEnd)) ?? defaults.countdownEnd
        focusMinutes = try container.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? defaults.focusMinutes
        shortBreakMinutes = try container.decodeIfPresent(Int.self, forKey: .shortBreakMinutes) ?? defaults.shortBreakMinutes
        longBreakMinutes = try container.decodeIfPresent(Int.self, forKey: .longBreakMinutes) ?? defaults.longBreakMinutes
        cyclesBeforeLongBreak = try container.decodeIfPresent(Int.self, forKey: .cyclesBeforeLongBreak) ?? defaults.cyclesBeforeLongBreak
        autoStartBreaks = try container.decodeIfPresent(Bool.self, forKey: .autoStartBreaks) ?? defaults.autoStartBreaks
        autoStartFocus = try container.decodeIfPresent(Bool.self, forKey: .autoStartFocus) ?? defaults.autoStartFocus
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(countdownEnd, forKey: .countdownEnd)
        try container.encode(focusMinutes, forKey: .focusMinutes)
        try container.encode(shortBreakMinutes, forKey: .shortBreakMinutes)
        try container.encode(longBreakMinutes, forKey: .longBreakMinutes)
        try container.encode(cyclesBeforeLongBreak, forKey: .cyclesBeforeLongBreak)
        try container.encode(autoStartBreaks, forKey: .autoStartBreaks)
        try container.encode(autoStartFocus, forKey: .autoStartFocus)
    }
}

extension TimerSettings: RawRepresentable {
    init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let settings = try? JSONDecoder().decode(TimerSettings.self, from: data)
        else { return nil }
        self = settings
    }

    /// Sorted keys keep the string stable: `RawRepresentable` types compare equal by `rawValue`.
    var rawValue: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(self) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
}

/// How the next timer from the popover runs.
enum TimerKind: Equatable {
    case stopwatch
    case countdown(TimeInterval)
    case pomodoro
}
