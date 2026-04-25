import Foundation

enum PomodoroPhase: String, CaseIterable, Identifiable {
    case focus
    case shortBreak
    case longBreak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus:
            String(localized: "phase.focus.title")
        case .shortBreak:
            String(localized: "phase.shortBreak.title")
        case .longBreak:
            String(localized: "phase.longBreak.title")
        }
    }

    var shortTitle: String {
        switch self {
        case .focus:
            String(localized: "phase.focus.shortTitle")
        case .shortBreak:
            String(localized: "phase.shortBreak.shortTitle")
        case .longBreak:
            String(localized: "phase.longBreak.shortTitle")
        }
    }

    var statusIcon: String {
        switch self {
        case .focus:
            "timer"
        case .shortBreak:
            "cup.and.saucer.fill"
        case .longBreak:
            "moon.zzz.fill"
        }
    }

    var menuBarSymbol: String {
        switch self {
        case .focus:
            "timer"
        case .shortBreak:
            "cup.and.saucer"
        case .longBreak:
            "moon.zzz"
        }
    }

    var defaultDuration: Int {
        switch self {
        case .focus:
            25 * 60
        case .shortBreak:
            5 * 60
        case .longBreak:
            15 * 60
        }
    }
}
