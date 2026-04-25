import Foundation

enum TimerStatus: String {
    case idle
    case running
    case paused

    var title: String {
        switch self {
        case .idle:
            String(localized: "status.ready")
        case .running:
            String(localized: "status.running")
        case .paused:
            String(localized: "status.paused")
        }
    }
}
