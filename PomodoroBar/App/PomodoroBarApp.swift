import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        PomodoroNotifier.shared.requestAuthorization()
    }
}

@main
struct PomodoroBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var timerStore = PomodoroTimerStore()

    var body: some Scene {
        MenuBarExtra {
            PomodoroPanelView(store: timerStore)
        } label: {
            StatusLabelView(store: timerStore)
        }
        .menuBarExtraStyle(.window)
    }
}
