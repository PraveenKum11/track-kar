# Track Kar

*"Track kar" is Hindi for "track it".*

Track Kar is a minimal, native macOS menu bar app for personal time tracking. You can start a timer with or without a name, pause it for breaks, and stop it when you're done. Your time adds up on saved activities across days, and you can see where it went on a dashboard. A Pomodoro timer with built-in white noise is also included.

> **Status:** early development. See [PLAN.md](PLAN.md) for the roadmap.

## Features (planned)
- A menu bar timer with stopwatch, countdown and Pomodoro modes.
- Saved activities, with optional groups for combined totals.
- Breaks that are counted but never added to your tracked time.
- White, pink and brown noise, generated on-device.
- A dashboard, history editing, and CSV/JSON export.
- Light, Dark or System appearance, in either the Liquid Glass or the Solid style.
- Fully local, with no accounts and no network.

## Requirements
- macOS 26 Tahoe or later.
- Xcode 26 or later, to build.

## Build from source
```sh
git clone https://github.com/<you>/track-kar.git
cd track-kar
open TrackKar.xcodeproj
```
In Xcode, choose the **TrackKar** scheme and press **⌘R**. The app appears in the menu bar and has no Dock icon.

To build and test from the command line instead:
```sh
xcodebuild -project TrackKar.xcodeproj -scheme TrackKar build
xcodebuild -project TrackKar.xcodeproj -scheme TrackKar test
```

### Sample data
Debug builds accept a launch argument that loads realistic sample data into an in-memory store. Your real data is never touched:
```sh
open TrackKar.app --args -TrackKarSampleData YES
```
In Xcode, add `-TrackKarSampleData YES` under **Product → Scheme → Edit Scheme → Run → Arguments**.

## Running a downloaded build
Release builds are ad-hoc signed and not notarized, because the app is free and has no paid Apple Developer account. The first time you open the app, macOS will block it:
1. Right-click **Track Kar.app** and choose **Open**, or
2. Open **System Settings → Privacy & Security** and click **Open Anyway**.

## Project layout
```
TrackKar/          App source (App, Features, Models, Engine, Theme, ...)
TrackKarTests/     Unit tests (Swift Testing)
TrackKar.xcodeproj Xcode project. Folders are synced, so new files are picked up automatically
PLAN.md            Product plan and roadmap
```

## License
[MIT](LICENSE)
