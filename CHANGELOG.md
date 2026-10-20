# Changelog

All notable changes to Track Kar are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-10-20

The first public release.

### Added
- **Menu bar timer.** Start tracking by typing what you're working on and pressing Return. Saved activities autocomplete, and recent activities restart in one click.
- **Stopwatch, Timer and Pomodoro modes.**
  - The timer has presets and a custom length, and either stops at the target or keeps counting as overtime.
  - Pomodoro has focus, short and long breaks, auto-start options and skip.
- **Breaks.** Pausing and Pomodoro breaks are counted but never added to tracked time.
- **Safe switching.** Starting something else while a timer runs asks whether to save and switch, move the time to the new task, or discard it.
- **Activities and groups.** Save names as activities so time adds up across days. Group related activities, with an optional target in hours. Rename, recolor, archive, merge and delete.
- **Dashboard:**
  - day, week, month or custom ranges, with totals compared with the previous period.
  - daily average, sessions and break stats.
  - a stacked chart by activity or group, and a breakdown list.
- **History.** Every session by day. Edit times, names and notes, add sessions you forgot to track, and delete sessions.
- **Export.** CSV for spreadsheets, or JSON for a complete backup, for any range or everything.
- **Time away.** If the Mac sleeps or sits idle while a timer runs, a Welcome Back prompt asks whether to keep that time.
- **"Still tracking?"** reminders after long stopwatch sessions.
- **Notifications** when a timer or Pomodoro phase ends, with a sound fallback.
- **Global keyboard shortcuts:** show the popover (⌃⌥T by default), start or stop, and pause or resume.
- **Customizable menu bar item:** icon, time, activity name, color dot, time format, and paused and idle styles, with a live preview.
- **Appearance:** Light, Dark or System, in Liquid Glass or an opaque Solid style, with an accent color.
- **Settings** in the main window: launch at login, first day of week, timers, reminders, menu bar, appearance, backup, and erase all data.
- **Welcome screen** on first launch, and an app icon.
- **Local-only storage.** No account, no network access, and data that survives quits and crashes.

[Unreleased]: https://github.com/PraveenKum11/track-kar/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/PraveenKum11/track-kar/releases/tag/v0.1.0
