import AppKit
import Foundation
import UserNotifications

@MainActor
final class PomodoroNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PomodoroNotifier()

    private let notificationCenter = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        notificationCenter.delegate = self
    }

    func requestAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notifyFocusCompleted(nextPhase: PomodoroPhase) {
        playSound(named: "Glass")
        postNotification(
            title: String(localized: "notification.focusComplete.title"),
            body: nextPhase == .longBreak
                ? String(localized: "notification.focusComplete.longBreak.body")
                : String(localized: "notification.focusComplete.shortBreak.body"),
            identifier: "focus-complete-\(Date().timeIntervalSince1970)"
        )
    }

    func notifyBreakCompleted() {
        playSound(named: "Ping")
        postNotification(
            title: String(localized: "notification.breakComplete.title"),
            body: String(localized: "notification.breakComplete.body"),
            identifier: "break-complete-\(Date().timeIntervalSince1970)"
        )
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    private func postNotification(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )

        notificationCenter.add(request)
    }

    private func playSound(named name: String) {
        if let sound = NSSound(named: NSSound.Name(name)) {
            sound.play()
        } else {
            NSSound.beep()
        }
    }
}
