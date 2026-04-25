# PomodoroBar

PomodoroBar is a lightweight macOS menu bar Pomodoro timer built with SwiftUI. It stays out of the Dock, shows the current countdown in the menu bar, and sends a notification when a focus or break session ends.

## Features

- Menu bar countdown with phase icon and progress percentage
- Focus, short break, and long break phases
- Automatic phase switching after each session
- Long break after every 4 focus rounds
- Pause, reset, skip, and quit controls
- Daily completed-focus count saved locally
- System notifications and sounds
- English and Simplified Chinese localization
- DMG packaging scripts for local releases

## Requirements

- Xcode with Swift 6 support
- Main target: macOS 26.0 or later
- Legacy target: macOS 13.0 or later

## Build

Open `PomodoroBar.xcodeproj` in Xcode and run the `PomodoroBar` scheme.

Or build from the command line:

```bash
xcodebuild -project PomodoroBar.xcodeproj -scheme PomodoroBar -configuration Release build
```

For the legacy build:

```bash
xcodebuild -project PomodoroBar.xcodeproj -scheme PomodoroBarLegacy -configuration Release build
```

## Local Run

```bash
./script/build_and_run.sh
```

## Package

Create a local DMG:

```bash
./script/package_dmg.sh
```

The packaged files are written to `dist/`. Release artifacts are intentionally ignored by Git; upload DMG files through GitHub Releases instead of committing them to the repository.

## Notes

PomodoroBar is distributed as a local/developer-signed macOS app. If you distribute a build publicly, users may need to allow it in macOS Privacy & Security unless you notarize the app with an Apple Developer account.

## License

MIT
