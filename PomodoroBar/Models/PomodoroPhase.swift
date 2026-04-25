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
            Self.focusHourglassSymbol(progress: 0)
        case .shortBreak:
            "cup.and.saucer.fill"
        case .longBreak:
            "moon.zzz.fill"
        }
    }

    var menuBarSymbol: String {
        switch self {
        case .focus:
            Self.focusHourglassSymbol(progress: 0)
        case .shortBreak:
            "cup.and.saucer"
        case .longBreak:
            "moon.zzz"
        }
    }

    func statusIcon(progress: Double) -> String {
        switch self {
        case .focus:
            Self.focusHourglassSymbol(progress: progress)
        case .shortBreak, .longBreak:
            statusIcon
        }
    }

    func menuBarSymbol(progress: Double) -> String {
        switch self {
        case .focus:
            Self.focusHourglassSymbol(progress: progress)
        case .shortBreak, .longBreak:
            menuBarSymbol
        }
    }

    static func focusHourglassSymbol(progress: Double) -> String {
        let clampedProgress = min(1, max(0, progress))

        switch clampedProgress {
        case ..<0.34:
            return "hourglass.bottomhalf.filled"
        case ..<0.67:
            return "hourglass"
        default:
            return "hourglass.tophalf.filled"
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
