import AppKit
import SwiftUI

final class LegacyAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        PomodoroNotifier.shared.requestAuthorization()
    }
}

@main
struct PomodoroBarLegacyApp: App {
    @NSApplicationDelegateAdaptor(LegacyAppDelegate.self) private var appDelegate
    @StateObject private var timerStore = LegacyPomodoroTimerStore()

    var body: some Scene {
        MenuBarExtra {
            LegacyPomodoroPanelView(store: timerStore)
        } label: {
            LegacyStatusLabelView(store: timerStore)
        }
        .menuBarExtraStyle(.window)
    }
}
