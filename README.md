# PomodoroBar

PomodoroBar 是一个轻量的 macOS 菜单栏番茄钟，用 SwiftUI 构建。它不会出现在 Dock 里，可以直接在菜单栏显示倒计时，并在专注或休息结束时发送系统通知。

PomodoroBar is a lightweight macOS menu bar Pomodoro timer built with SwiftUI. It stays out of the Dock, shows the current countdown in the menu bar, and sends a notification when a focus or break session ends.

<p align="center">
  <img src="Assets/app-icon.png" alt="PomodoroBar app icon" width="112">
</p>

![PomodoroBar screenshot](Assets/screenshot.jpg)

## 功能 / Features

- 菜单栏倒计时，显示当前阶段图标和进度百分比<br>
  Menu bar countdown with the current phase icon and progress percentage.
- 全新沙漏图标，支持浅色、深色、透明和着色外观<br>
  New hourglass app icon with light, dark, clear, and tinted appearances.
- 专注阶段的菜单栏沙漏会根据剩余时间自动变化<br>
  Focus hourglass in the menu bar changes automatically as time runs down.
- 支持专注、短休息、长休息三个阶段<br>
  Focus, short break, and long break phases.
- 每轮结束后自动切换到下一个阶段，每完成 4 轮专注后进入长休息<br>
  Automatic phase switching after each session, with a long break after every 4 focus rounds.
- 支持开始、暂停、重置、跳过和退出<br>
  Start, pause, reset, skip, and quit controls.
- 自动保存当天完成的专注次数，并支持悬停后快速清除当天计数<br>
  Saves the daily completed-focus count locally, with hover-to-clear support for today's count.
- 首次冷启动时提示应用已在菜单栏运行<br>
  Shows a first-launch hint so users can find the app in the menu bar.
- 系统通知和提示音<br>
  System notifications and sounds.
- 支持简体中文和英文界面<br>
  Simplified Chinese and English localization.
- 提供本地 APP 和 DMG 打包脚本<br>
  Local APP and DMG packaging scripts.

## 下载 / Download

请从 [GitHub Releases](https://github.com/Dream-of-July/PomodoroBar/releases) 下载最新版本。

Download the latest build from [GitHub Releases](https://github.com/Dream-of-July/PomodoroBar/releases).

- `PomodoroBar_1.0 Beta 3.dmg`：主版本，适用于 macOS 26.0 或更新版本。<br>
  Main build for macOS 26.0 or later.
- `PomodoroBarLegacy_1.0 Beta 3.dmg`：旧系统版本，适用于 macOS 13.0 或更新版本。<br>
  Legacy build for macOS 13.0 or later.

## 系统要求 / Requirements

- Xcode，需支持 Swift 6<br>
  Xcode with Swift 6 support.
- 主版本：macOS 26.0 或更新版本<br>
  Main target: macOS 26.0 or later.
- 旧系统版本：macOS 13.0 或更新版本<br>
  Legacy target: macOS 13.0 or later.

## 构建 / Build

使用 Xcode 打开 `PomodoroBar.xcodeproj`，然后运行 `PomodoroBar` scheme。

Open `PomodoroBar.xcodeproj` in Xcode and run the `PomodoroBar` scheme.

也可以使用命令行构建：

You can also build from the command line:

```bash
xcodebuild -project PomodoroBar.xcodeproj -scheme PomodoroBar -configuration Release build
```

Legacy 版本：

Legacy build:

```bash
xcodebuild -project PomodoroBar.xcodeproj -scheme PomodoroBarLegacy -configuration Release build
```

## 本地运行 / Local Run

```bash
./script/build_and_run.sh
```

## 打包 / Package

生成本地 APP 并安装到 `/Applications`：

Build a local APP and install it to `/Applications`:

```bash
./script/package_app.sh
```

生成主版本 DMG：

Build the main DMG file:

```bash
./script/package_dmg.sh
```

生成旧系统版本 DMG：

Build the legacy DMG file:

```bash
./script/package_legacy_dmg.sh
```

## 注意 / Notes

PomodoroBar 目前使用本地/开发者签名。如果公开分发未公证版本，用户可能需要在 macOS 的“隐私与安全性”里手动允许打开。

PomodoroBar is currently local/developer signed. If you distribute an unnotarized build publicly, users may need to allow it manually in macOS Privacy & Security.

## 许可证 / License

MIT
