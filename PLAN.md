# Track Kar: Project Plan

A native macOS menu bar app for personal time tracking, similar in spirit to Toggl Track. It includes a stopwatch, a countdown timer, Pomodoro with white noise, and a dashboard of where your time went.

> Name: **Track Kar** (a Hindi pun: "track kar" means "track it"). Code identifier: `TrackKar`. Repo: `track-kar`.
> Status: planning. Last updated: 2026-10-20.
> Scope: personal use, free and open source (may be published on GitHub). No accounts or sync for now.

---

## 1. Goals and principles

**Goals**
1. Start tracking time in 1–2 clicks from the menu bar, with or without a name.
2. Pause for breaks and stop to end a session. Time stays accurate across sleep, quit and crash.
3. Reuse saved **Activities** (projects or tasks) so time adds up on the same thing across days.
4. Optionally put activities in a **Group** to see the combined total for a bigger goal, such as "Interview prep".
5. Run Pomodoro cycles with optional built-in white noise.
6. Show a dashboard of time spent per activity and per group per day, week and month.

**Design principles**
- **Minimal by default.** The menu bar popover shows only the essentials. Everything else lives in the full app window.
- **Fast.** The popover opens instantly and is fully keyboard-driven (type a name, press Return, and it's running).
- **Native.** Swift and SwiftUI on macOS 26, with system fonts and colors and SF Symbols. No Electron and no web views.
- **Your look, your choice.** Light, dark or system appearance, with or without Liquid Glass (see 3.6).
- **Trustworthy data.** Store timestamps and never "ticking counters", so elapsed time can always be recomputed exactly.
- **Local-only.** All data stays on this Mac, and the app works fully offline. There are no accounts or network calls.
- **Open source.** The repo is clean and buildable by anyone with Xcode, with as few dependencies as possible.

---

## 2. Core concepts and terminology

| Term | Meaning |
|---|---|
| **Activity** | A saved, reusable thing you track time against, such as a project name like "Client X website". It has a name, a color and an optional emoji or icon, and can be archived. Activities form a **flat list**. |
| **Group** (optional) | A named bucket of activities whose time is summed. For example, the "Interview prep" group could hold "DSA practice", "System design" and "Mock interviews", and show one combined total across every session and day. An activity belongs to at most one group or to none. Groups are one level only, with no nesting. |
| **Time Entry** (session) | One tracked session, from Start to Stop. It belongs to an Activity, or it is *unsaved* with just a free-text name. |
| **Segment** | A continuous running interval inside an entry. Pausing closes a segment and resuming opens a new one. Entry duration is the sum of its segments. |
| **Mode** | How the entry was run: `stopwatch` (counts up), `timer` (countdown to a target) or `pomodoro`. All three produce Time Entries, so the dashboard sees everything. |

### The "save permanently?" flow
When you start a timer with a **new** name that doesn't match an existing Activity:
- A small inline prompt appears: **"Save 'Client X' as an activity?"** with the options **Save** and **Just this once**.
  - **Save** creates an Activity, and the entry links to it. Next time it autocompletes.
  - **Just this once** keeps the entry with a free-text name only. It still appears in history and the dashboard, grouped as "Unsaved".
- Unsaved entries can be converted to an Activity later, from History or from the entry's context menu ("Save as activity…" merges all entries with the same name).
- A setting controls the default: *Always ask* (default), *Always save* or *Never ask*.
- Starting a timer with no name creates an "Untitled" entry that you can name later.

---

## 3. Feature scope

### 3.1 Menu bar (popover): the minimal surface
The menu bar item shows the running state. Exactly what it shows is configurable (see 3.5). By default:
- Idle: just the icon.
- Running: the icon plus elapsed time (`1:24:05`).
- Paused: the time is dimmed and shows a pause glyph.
- Pomodoro: the remaining time in the current phase plus a phase indicator (focus or break).

Clicking it opens a compact popover (about 320 pt wide):
```
┌────────────────────────────────┐
│ [ What are you working on? ▾ ] │  ← name field with autocomplete of Activities
│                                │
│        01:24:05                │  ← big timer
│     Client X website           │
│                                │
│   [ ⏸ Pause ]   [ ⏹ Stop ]      │
│                                │
│  Stopwatch · Timer · Pomodoro  │  ← segmented mode switch
│ ────────────────────────────── │
│  Recent:  ● Client X  ● Gym    │  ← 3–5 one-click restart chips
│  Today: 3h 42m                 │
│ ────────────────────────────── │
│  ♪ White noise ▸     Open app ⤢ │
└────────────────────────────────┘
```
- **Timer mode:** quick presets (5, 15, 25 and 50 min) plus a custom value.
- **Pomodoro mode:** shows the phase ("Focus 2/4") and a skip-phase button.
- Keyboard: `Return` starts, `Space` pauses or resumes, `⌘.` stops, and `⌘O` opens the full app.

### 3.2 Full app window: the complete surface
Sidebar navigation:
1. **Dashboard**
   - Range picker: Today, This week, This month or Custom.
   - Total tracked time and a comparison with the previous period.
   - Bar chart of time per day, stacked by activity.
   - Donut or ranked list of time per activity, with a toggle to view it **by group** (ungrouped activities appear on their own).
   - Streaks and averages (later).
2. **Timeline / History**
   - Entries grouped by day, each with its start and end, its duration and the activity's color.
   - Edit an entry (name, activity, start and end, notes), delete it, or split or merge entries.
   - Add a manual entry (for time you forgot to track).
   - Day view as a vertical calendar-style timeline (later).
3. **Activities**
   - List with total time, color and last used date.
   - Create, rename, recolor, archive or merge activities.
   - **Groups:** create a group, give it a color, and add or remove activities by drag-and-drop or from a menu.
   - The list can be shown flat or grouped. Each group header shows its combined total.
   - **Group detail:** the total time, the time per activity inside the group, a per-day chart, and the first and last session. This answers "how much time have I put into interview prep so far?"
   - The group can optionally have a **target** ("Interview prep: 40h"), shown as a progress bar.
4. **Pomodoro**
   - Focus, short-break and long-break lengths, and the number of cycles before a long break.
   - Auto-start next phase (on or off), and sounds.
   - White noise settings (see 3.4).
5. **Settings**
   - General: launch at login, the "save activity?" default, first day of week.
   - Menu Bar: what the menu bar item shows (see 3.5).
   - Appearance: theme, style and accent color (see 3.6).
   - Shortcuts: a global hotkey to start or stop and to open the popover.
   - Notifications: timer done, Pomodoro phase change, and "still tracking?" reminders.
   - Data: export (CSV/JSON), import, backup and restore of the local store, and reset.

### 3.3 Timer behaviours
- **Stopwatch:** counts up until stopped, and pause/resume creates segments.
- **Countdown timer:** a target duration. On reaching zero it sends a notification and plays a sound, then either auto-stops or keeps counting overtime (a setting). The entry records the *actual* tracked time.
- **Pomodoro:** a state machine of `focus → shortBreak → focus → … → longBreak`.
  - One Pomodoro session is one Time Entry against the selected activity. Each focus phase is a segment, so only focus time counts.
  - Breaks are recorded as **Break** records (see below).
- **Breaks never count toward tracked time, but they are counted.** Every manual pause and every Pomodoro break creates a Break record with its start, end and kind (`pause`, `shortBreak` or `longBreak`). This gives:
  - the break count per entry, for example "2h 10m · 3 breaks" in History.
  - breaks per day or week on the Dashboard, plus the total and average break length.
- **Only one active timer at a time.** Starting a new one stops the current one (with an undo toast).
- **Sleep, wake and quit:** because time is stored as timestamps, a running timer stays correct after sleep or a relaunch. On wake after more than N minutes of system sleep (a setting), the app asks "You were away 45m. Keep, discard or pause from when you left?"
- **Idle detection (later):** uses `CGEventSource` idle time to ask the same keep/discard question after N minutes without input.

### 3.4 White noise
- Noise is generated in real time with `AVAudioEngine` and an `AVAudioSourceNode`, so no audio files are needed:
  - White, pink and brown noise.
- Optional bundled ambient loops (rain, café, fireplace) are royalty-free or CC0 and added later.
- Volume slider, and fade in and out (about 2 s) to avoid clicks.
- Options: play only during Pomodoro focus phases, play whenever a timer runs, or manual.
- Accessible from the popover (a small ♪ menu) and from the Pomodoro page.

### 3.5 Menu bar preferences
A dedicated **Settings → Menu Bar** page shows a live preview of the menu bar item at the top, which updates as you change options:
- **While tracking**, choose any combination of:
  - the icon.
  - the elapsed time.
  - the activity name, truncated to N characters.
  - the activity color dot.
- **Time format:** `1:24:05`, `1:24` (no seconds), or `1h 24m`.
- **While idle:** icon only, icon plus today's total, or hidden. If hidden, the item appears only while tracking, and the full app stays reachable from the Dock or Spotlight.
- **While paused:** dim the item, show a pause glyph, or blink the time.
- **During Pomodoro:** show the remaining time or the elapsed time, and the phase indicator (on or off).
- **Icon style:** choose from a few SF Symbol options, or monochrome versus the activity's color.
- **Use a fixed width:** this stops the menu bar items next to it from shifting as digits change, using monospaced digits.

### 3.6 Appearance and themes
A **Settings → Appearance** page has three independent controls and a live preview of the popover:
- **Mode:** System (default), Light or Dark.
- **Style:**
  - **Liquid Glass** (default): translucent glass surfaces, glass buttons and a floating feel.
  - **Solid:** opaque, flat surfaces with standard bordered buttons, no translucency and subtle separators. This is a calm, classic macOS look for people who dislike glass.
  - Room for more styles later, such as "Minimal Mono" or high contrast.
- **Accent color:** System, or a choice of preset colors.

How it works:
- Our own views never hard-code colors or materials. They use a small **theme layer**: an `AppTheme` value in the SwiftUI environment that provides semantic tokens (`surface`, `elevatedSurface`, `separator`, `primaryText`, `secondaryText`, `accent`) and view modifiers (`.themedSurface()`, `.themedButton()`).
  - The **Glass** theme maps these to `.glassEffect(...)` and glass button styles.
  - The **Solid** theme maps them to opaque fills (`Color(nsColor: .windowBackgroundColor)` and similar) and `.bordered` buttons.
- Mode is applied with `.preferredColorScheme`, on the popover's and the window's hosting `NSWindow`, so it can differ from the system setting.
- If the system **Reduce Transparency** accessibility setting is on, the app automatically uses Solid, whatever is selected.
- **Limitation:** standard macOS controls that we don't draw ourselves, such as the window's title bar and toolbar, sidebar chrome and system menus, follow the OS's own macOS 26 look. The Solid style removes glass from everything the app draws and replaces translucent backgrounds where SwiftUI allows it (for example `.toolbarBackground` and `.containerBackground`). It can't fully turn system chrome back into pre-Tahoe styling.

---

## 4. Technical architecture

### 4.1 Stack
| Concern | Choice | Why |
|---|---|---|
| Language | **Swift 6** | Native, modern concurrency |
| UI | **SwiftUI** (+ small AppKit bridges where needed) | `MenuBarExtra` (`.window` style) for the popover and `Window`/`WindowGroup` for the full app |
| Persistence | **SwiftData** | Native, simple, and supports **CloudKit sync** later with minimal changes |
| Charts | **Swift Charts** | Native dashboard charts |
| Audio | **AVFoundation** (`AVAudioEngine`) | Procedural noise generation |
| Notifications | **UserNotifications** | Timer done and phase changes |
| Launch at login | **ServiceManagement** (`SMAppService`) | The modern, sandbox-safe API |
| Global hotkey | [`KeyboardShortcuts`](https://github.com/sindresorhus/KeyboardShortcuts) (SPM) | The only third-party dependency planned |
| Min macOS | **macOS 26 Tahoe** | Uses the latest frameworks with no compatibility branches (see 4.4) |

- **App type:** an agent app (`LSUIElement = YES`), so it has no Dock icon by default. When the full window is open it can temporarily appear in the Dock or ⌘-Tab (a setting).
- **Distribution:** personal use, free and open source.
  - **Primary path:** build it locally from source in Xcode.
  - **Repo:** if published on GitHub, it gets a permissive license (MIT suggested) and a README with build instructions.
  - **Downloads:** the app is ad-hoc signed and not notarized, which avoids paying for the $99/yr Apple Developer account. Anyone downloading a release must right-click and choose Open the first time, and the README explains this.
  - **Sandbox:** the app stays sandboxed, because the sandbox is free and good hygiene.

### 4.2 Data model (SwiftData)
Sync is out of scope, but the model still follows CloudKit's rules: no `@Attribute(.unique)`, all properties optional or defaulted, and all relationships optional. These rules cost nothing now and keep the option open.

```swift
@Model final class ActivityGroup {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#8E8E93"
    var targetHours: Double?     // optional goal, e.g. 40h of interview prep
    var isArchived: Bool = false
    var createdAt: Date = Date()
    @Relationship(deleteRule: .nullify, inverse: \Activity.group)
    var activities: [Activity]? = []
}

@Model final class Activity {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#4F7CFF"
    var icon: String?            // emoji or SF Symbol name
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var group: ActivityGroup?    // nil = ungrouped
    @Relationship(deleteRule: .nullify, inverse: \TimeEntry.activity)
    var entries: [TimeEntry]? = []
}

@Model final class TimeEntry {
    var id: UUID = UUID()
    var title: String = ""       // free-text name (used when unsaved, or as an override)
    var activity: Activity?      // nil = unsaved / ad-hoc
    var mode: String = "stopwatch"   // stopwatch | timer | pomodoro
    var targetDuration: Double?  // for countdown / pomodoro phase
    var notes: String?
    var createdAt: Date = Date()
    var endedAt: Date?           // nil = still active (running or paused)
    @Relationship(deleteRule: .cascade, inverse: \Segment.entry)
    var segments: [Segment]? = []
    @Relationship(deleteRule: .cascade, inverse: \Break.entry)
    var breaks: [Break]? = []
}

@Model final class Segment {
    var id: UUID = UUID()
    var start: Date = Date()
    var end: Date?               // nil = currently running
    var entry: TimeEntry?
}

@Model final class Break {
    var id: UUID = UUID()
    var kind: String = "pause"   // pause | shortBreak | longBreak
    var start: Date = Date()
    var end: Date?               // nil = break in progress
    var entry: TimeEntry?
}
```
- **Duration** = Σ(`(end ?? now) - start`), computed and never stored. That makes it crash-proof.
- **Running** means the entry has a segment with `end == nil`. **Paused** means `endedAt == nil` and every segment is closed.
- **Group total** is the sum of its activities' entry durations, computed by query. Deleting a group only ungroups its activities, and no time is lost.
- Moving an activity to another group moves all of its history with it, because group membership belongs to the activity and not to individual entries.
- **Breaks** are separate from segments, so they can never inflate tracked time. Break count is `breaks.count`.
- Pomodoro config and app settings, including the menu bar preferences, live in `UserDefaults` / `@AppStorage`, not SwiftData.

### 4.3 Code structure
```
personal-timer/
├─ PLAN.md
├─ TrackKar.xcodeproj
├─ TrackKar/
│  ├─ App/            TrackKarApp.swift (MenuBarExtra + Window scenes), AppDelegate bridge
│  ├─ Models/         ActivityGroup, Activity, TimeEntry, Segment, ModelContainer setup
│  ├─ Engine/         TimerEngine (@Observable: start/pause/resume/stop, single source of truth)
│  │                  PomodoroEngine (phase state machine), SleepWakeMonitor, IdleMonitor
│  ├─ Audio/          NoiseGenerator (white/pink/brown), NoisePlayer
│  ├─ Features/
│  │  ├─ MenuBar/     PopoverView, MenuBarLabel, RecentChips
│  │  ├─ Dashboard/   DashboardView, charts, range picker
│  │  ├─ History/     TimelineView, EntryEditor
│  │  ├─ Activities/  ActivityList, ActivityEditor, GroupEditor, GroupDetailView
│  │  ├─ Pomodoro/    PomodoroSettingsView
│  │  └─ Settings/    SettingsView, MenuBarSettingsView, AppearanceSettingsView (with live previews)
│  ├─ Theme/          AppTheme protocol, GlassTheme, SolidTheme, themed view modifiers
│  ├─ Services/       Notifications, LaunchAtLogin, Hotkeys, Export
│  └─ Resources/      Assets, sounds
└─ TrackKarTests/        Engine + duration math + pomodoro state machine tests
```
- `TimerEngine` is the only component that mutates active entries. Views observe it.
- The UI tick runs on a 1 s `TimelineView`/timer that only *re-renders*. It never accumulates time.

### 4.4 Why macOS 26 rather than 14
Choosing macOS 26 as the minimum gives us the following. Most of it would need `if #available` branches or would be unavailable on 14:
| Feature | Min OS | Used for |
|---|---|---|
| **Liquid Glass** design (`.glassEffect`, glass button styles, new toolbars and sidebars) | 26 | The Glass theme. The Solid theme is a deliberate style choice, not an OS fallback. |
| **Controls** for Control Center and the menu bar (WidgetKit) | 26 on Mac | A start/stop control the user can place in Control Center. |
| **App Intents in Spotlight** (actions) | 26 | "Start tracking Interview prep" straight from Spotlight. |
| SwiftData improvements (`#Index`, history tracking, model inheritance) | 15 / 26 | Faster dashboard queries and cleaner models. |
| Window and scene APIs (`.windowStyle(.plain)`, `WindowDragGesture`, launch behaviour) | 15 | A borderless, polished full window and popover behaviour. |
| Rich-text `TextEditor` with `AttributedString` | 26 | Formatted notes on entries. |

The cost is that people on macOS 14 or 15 can't run it if it's published. For a free, personal open-source app that is acceptable. If demand ever appears, we could lower the minimum to 15 by wrapping the 26-only features in availability checks.

---

## 5. Roadmap (phased milestones)

### Phase 0: Project setup
- [x] Install Xcode (27.1, building against the macOS 27 SDK with a deployment target of macOS 26.0).
- [x] Create the Xcode project with these settings:
  - folder-synced groups, so new files need no project edits.
  - Swift 6 with main-actor default isolation.
  - `LSUIElement`, the app sandbox, and the bundle ID `com.praveenkumar.TrackKar`.
  - ad-hoc signing, with the hardened runtime in Release.
  - a shared `TrackKar` scheme and a Swift Testing target.
- [x] Placeholder menu bar popover and main window. The window doesn't open at launch and is opened from the popover.
- [x] `git init` (on `main`), a Swift/Xcode `.gitignore`, a README, and a `LICENSE` (MIT).

### Phase 1: MVP tracker (the core loop)
- [ ] SwiftData models plus `TimerEngine` (start, pause, resume, stop), with unit tests for the duration math.
- [ ] Basic theme layer (`AppTheme` with Glass and Solid), so every view is themeable from day one.
- [ ] Menu bar label with live elapsed time.
- [ ] Popover with a name field and autocomplete, start, pause and stop, and today's total.
- [ ] The "Save as activity?" prompt and the setting for its default.
- [ ] Recent-activity chips for one-click restart.
- [ ] Restore a running timer after quit or relaunch.
- **Exit criteria:** usable daily for basic tracking.

### Phase 2: Full app window
- [ ] Window scene with sidebar navigation, opened from the popover.
- [ ] History / Timeline: list, edit, delete and manual entries.
- [ ] Activities: CRUD, color, archive and merge, plus "save unsaved entries as activity".
- [ ] Groups: CRUD, assign activities, a flat or grouped list toggle, and a group detail view with the total and an optional target progress bar.
- [ ] Settings: launch at login and first day of week.
- [ ] Menu Bar settings page with a live preview (3.5).
- [ ] Theme layer (Glass and Solid, Light, Dark and System, accent color) and the Appearance settings page (3.6). The theme layer itself is built in **Phase 1**, so every view uses it from the start.

### Phase 3: Timer modes and Pomodoro
- [ ] Countdown timer with presets, a notification and sound, and an overtime option.
- [ ] Pomodoro state machine with its settings page, phase notifications, auto-start and skip.
- [ ] Mode switch in the popover, and a Pomodoro indicator in the menu bar.

### Phase 4: White noise
- [ ] `NoiseGenerator` (white, pink and brown) on `AVAudioEngine`, with volume and fades.
- [ ] Popover control and the auto-play with Pomodoro focus option.
- [ ] (Optional) bundled ambient loops.

### Phase 5: Dashboard and insights
- [ ] Range picker, totals and comparison with the previous period.
- [ ] Break stats: count per day, total and average length.
- [ ] Stacked bar chart (per day by activity) and a per-activity breakdown, with a "by group" toggle.
- [ ] CSV/JSON export.

### Phase 6: Polish and robustness
- [ ] Global hotkeys.
- [ ] Sleep/wake handling and idle detection with keep/discard prompts.
- [ ] "Still tracking?" reminders after N hours.
- [ ] Accessibility (VoiceOver labels and Dynamic Type where applicable), empty states and onboarding (one screen).
- [ ] App icon and menu bar icon design.

### Phase 7 (optional): Open-source release on GitHub
- [ ] README with screenshots, features, build-from-source steps and the first-launch Gatekeeper note.
- [ ] GitHub Actions workflow that builds and runs tests on each push.
- [ ] Tagged GitHub Releases with an ad-hoc signed `.zip` of the app.
- [ ] (Optional) Homebrew cask.

### Backlog / ideas (unprioritised)
- Tags (billable, deep work, meeting) alongside activities.
- Daily or weekly goals per activity, with progress rings.
- Calendar integration: show tracked blocks next to calendar events (EventKit).
- Widgets (WidgetKit) and a desktop or Notification Center widget with today's total.
- Shortcuts / App Intents ("Start tracking Client X" from Siri, Shortcuts or Spotlight).
- A start/stop **Control** in Control Center (macOS 26).
- Focus mode integration, which turns on macOS Focus during Pomodoro.
- Sync across devices: iCloud through SwiftData and CloudKit (needs the $99/yr Developer account), or a simple file-based backup to a synced folder. Out of scope for now.
- An iOS companion app, which only makes sense once sync exists.
- Toggl or Clockify import.

---

## 6. Decisions log
| Date | Decision |
|---|---|
| 2026-10-20 | Activities form a **flat list**, with optional one-level **Groups** for combined totals. There is no Client → Project → Task hierarchy. |
| 2026-10-20 | **No accounts or sync** for now. Data stays local, with export and backup. |
| 2026-10-20 | The app is for **personal use** and stays **free and open source**. It may be published on GitHub, built locally, with ad-hoc signed releases and no notarization. |
| 2026-10-20 | The app is named **Track Kar**. |
| 2026-10-20 | **Breaks don't count toward tracked time, but they are recorded and counted** (both pauses and Pomodoro breaks). |
| 2026-10-20 | The minimum OS is **macOS 26 Tahoe**, to use the latest feature set. |
| 2026-10-20 | The menu bar item is fully configurable from a **Settings → Menu Bar** page. |
| 2026-10-20 | Groups are assigned **only in the full app**. The popover stays minimal. |
| 2026-10-20 | **No Apple Intelligence features** for now. |
| 2026-10-20 | The app supports **themes**: Light, Dark or System mode × **Liquid Glass** or **Solid** style, plus an accent color. All UI goes through a theme layer. |

---

## 7. Testing strategy
- **Unit tests:** duration computation across pauses, the Pomodoro state machine transitions, the "unsaved → activity" merge, group totals (including after moving an activity between groups), breaks being counted but excluded from duration, and date-range aggregation for the dashboard (including midnight-spanning entries and DST changes).
- **Manual QA checklist:** sleep or wake mid-timer, quit and relaunch mid-timer, a timer across midnight, timezone change, every theme combination (Light, Dark and System × Glass and Solid, plus Reduce Transparency on), and multiple displays with the menu bar.
- **Dogfooding:** use it daily from the end of Phase 1.

---

## 8. Open questions (to decide before or during the build)
None right now. New questions get added here as they come up during the build.
