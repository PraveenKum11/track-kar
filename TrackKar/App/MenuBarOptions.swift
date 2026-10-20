import Foundation

enum MenuBarTimeFormat: String, Codable, CaseIterable, Identifiable {
    case clock, clockNoSeconds, units

    var id: Self { self }

    var label: String {
        switch self {
        case .clock: "1:24:05"
        case .clockNoSeconds: "1:24"
        case .units: "1h 24m"
        }
    }

    func format(_ seconds: TimeInterval) -> String {
        switch self {
        case .clock: DurationFormat.clock(seconds)
        case .clockNoSeconds: DurationFormat.clockNoSeconds(seconds)
        case .units: DurationFormat.short(seconds)
        }
    }
}

enum MenuBarIdleDisplay: String, Codable, CaseIterable, Identifiable {
    case iconOnly, iconAndToday, hidden

    var id: Self { self }

    var label: String {
        switch self {
        case .iconOnly: String(localized: "Icon only")
        case .iconAndToday: String(localized: "Icon and today's total")
        case .hidden: String(localized: "Hidden")
        }
    }
}

enum MenuBarPausedStyle: String, Codable, CaseIterable, Identifiable {
    case pauseGlyph, dim, blink

    var id: Self { self }

    var label: String {
        switch self {
        case .pauseGlyph: String(localized: "Show a pause icon")
        case .dim: String(localized: "Dim the time")
        case .blink: String(localized: "Blink the time")
        }
    }
}

enum MenuBarIcon: String, Codable, CaseIterable, Identifiable {
    case timer, stopwatch, clock, hourglass

    var id: Self { self }

    var symbolName: String { rawValue }
}

/// Everything the Settings → Menu Bar page controls, stored as one JSON string.
struct MenuBarOptions: Equatable {
    var showIcon = true
    var showTime = true
    var showName = false
    var nameLength = 16
    var showColorDot = false
    var timeFormat: MenuBarTimeFormat = .clock
    var idleDisplay: MenuBarIdleDisplay = .iconOnly
    var pausedStyle: MenuBarPausedStyle = .pauseGlyph
    var icon: MenuBarIcon = .timer
    /// Keeps neighbouring menu bar items from shifting as digits change.
    var fixedWidth = true
    /// For countdowns and Pomodoro: show time left rather than time tracked.
    var countdownShowsRemaining = true
    /// Show a focus or break icon during Pomodoro.
    var showPhaseIcon = true
}

// Explicit coding so options added later decode with their defaults, and so
// `RawRepresentable` doesn't route Codable through `rawValue` (which would recurse).
extension MenuBarOptions: Codable {
    private enum CodingKeys: String, CodingKey {
        case showIcon, showTime, showName, nameLength, showColorDot
        case timeFormat, idleDisplay, pausedStyle, icon, fixedWidth
        case countdownShowsRemaining, showPhaseIcon
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = MenuBarOptions()
        showIcon = try container.decodeIfPresent(Bool.self, forKey: .showIcon) ?? defaults.showIcon
        showTime = try container.decodeIfPresent(Bool.self, forKey: .showTime) ?? defaults.showTime
        showName = try container.decodeIfPresent(Bool.self, forKey: .showName) ?? defaults.showName
        nameLength = try container.decodeIfPresent(Int.self, forKey: .nameLength) ?? defaults.nameLength
        showColorDot = try container.decodeIfPresent(Bool.self, forKey: .showColorDot) ?? defaults.showColorDot
        timeFormat = (try? container.decodeIfPresent(MenuBarTimeFormat.self, forKey: .timeFormat)) ?? defaults.timeFormat
        idleDisplay = (try? container.decodeIfPresent(MenuBarIdleDisplay.self, forKey: .idleDisplay)) ?? defaults.idleDisplay
        pausedStyle = (try? container.decodeIfPresent(MenuBarPausedStyle.self, forKey: .pausedStyle)) ?? defaults.pausedStyle
        icon = (try? container.decodeIfPresent(MenuBarIcon.self, forKey: .icon)) ?? defaults.icon
        fixedWidth = try container.decodeIfPresent(Bool.self, forKey: .fixedWidth) ?? defaults.fixedWidth
        countdownShowsRemaining = try container.decodeIfPresent(Bool.self, forKey: .countdownShowsRemaining) ?? defaults.countdownShowsRemaining
        showPhaseIcon = try container.decodeIfPresent(Bool.self, forKey: .showPhaseIcon) ?? defaults.showPhaseIcon
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(showIcon, forKey: .showIcon)
        try container.encode(showTime, forKey: .showTime)
        try container.encode(showName, forKey: .showName)
        try container.encode(nameLength, forKey: .nameLength)
        try container.encode(showColorDot, forKey: .showColorDot)
        try container.encode(timeFormat, forKey: .timeFormat)
        try container.encode(idleDisplay, forKey: .idleDisplay)
        try container.encode(pausedStyle, forKey: .pausedStyle)
        try container.encode(icon, forKey: .icon)
        try container.encode(fixedWidth, forKey: .fixedWidth)
        try container.encode(countdownShowsRemaining, forKey: .countdownShowsRemaining)
        try container.encode(showPhaseIcon, forKey: .showPhaseIcon)
    }
}

extension MenuBarOptions: RawRepresentable {
    init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let options = try? JSONDecoder().decode(MenuBarOptions.self, from: data)
        else { return nil }
        self = options
    }

    /// Sorted keys keep the string stable: `RawRepresentable` types compare equal by `rawValue`.
    var rawValue: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(self) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
}

/// What the status item shows for a given state. Pure, so the Settings preview and tests can use it.
struct MenuBarContent: Equatable {
    var symbolName: String?
    var text: String?
    var colorHex: String?
    var isDimmed = false

    static func make(
        options: MenuBarOptions,
        state: TrackingState,
        elapsed: TimeInterval,
        activityName: String?,
        colorHex: String?,
        todayTotal: TimeInterval,
        blinkOn: Bool,
        countdown: CountdownStatus? = nil
    ) -> MenuBarContent {
        var symbol = options.icon.symbolName
        if options.showPhaseIcon, let phase = countdown?.phase {
            symbol = phase.symbolName
        }
        // A Pomodoro break, or a phase waiting to start, isn't a manual pause.
        let isWaiting = countdown?.isWaiting == true
        let isPaused = state == .paused && countdown?.phase?.isBreak != true && !isWaiting

        guard state != .idle else {
            switch options.idleDisplay {
            case .iconOnly, .hidden:
                return MenuBarContent(symbolName: symbol)
            case .iconAndToday:
                return MenuBarContent(symbolName: symbol, text: DurationFormat.short(todayTotal))
            }
        }

        var parts: [String] = []
        if options.showName, let activityName, !activityName.isEmpty {
            parts.append(truncate(activityName, to: options.nameLength))
        }
        var showTime = options.showTime
        if isPaused, options.pausedStyle == .blink, !blinkOn {
            showTime = false
        }
        if showTime {
            parts.append(timeText(options: options, elapsed: elapsed, countdown: countdown))
        }

        var content = MenuBarContent()
        content.text = parts.isEmpty ? nil : parts.joined(separator: " ")
        // A status item label renders a single image, so the pause glyph, color dot and icon
        // take that slot in that order of precedence.
        if isPaused, options.pausedStyle == .pauseGlyph {
            content.symbolName = "pause.circle"
        } else if options.showColorDot, let colorHex {
            content.colorHex = colorHex
        } else if options.showIcon {
            content.symbolName = symbol
        }
        content.isDimmed = (isPaused && options.pausedStyle == .dim) || isWaiting
        // Never leave an empty status item; keep the blinking time's space by falling back to the icon.
        if content.symbolName == nil, content.colorHex == nil, content.text == nil {
            content.symbolName = symbol
        }
        return content
    }

    private static func timeText(options: MenuBarOptions, elapsed: TimeInterval, countdown: CountdownStatus?) -> String {
        guard let countdown, options.countdownShowsRemaining else {
            return options.timeFormat.format(elapsed)
        }
        if countdown.isOvertime {
            return "+" + options.timeFormat.format(-countdown.remaining)
        }
        // Round up so a countdown reads 0:00:00 only when it's actually done.
        return options.timeFormat.format(countdown.remaining.rounded(.up))
    }

    private static func truncate(_ name: String, to length: Int) -> String {
        guard name.count > length, length > 1 else { return name }
        return String(name.prefix(length - 1)) + "…"
    }
}
