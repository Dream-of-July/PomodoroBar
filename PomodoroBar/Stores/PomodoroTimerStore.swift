import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class PomodoroTimerStore {
    var phase: PomodoroPhase = .focus
    var status: TimerStatus = .idle
    var remainingSeconds: Int = PomodoroPhase.focus.defaultDuration
    var completedFocusRounds: Int = 0
    var todayCompletedCount: Int = 0

    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar

    private let completedKey = "todayCompletedCount"
    private let roundsKey = "completedFocusRounds"
    private let dateKey = "lastCompletionDate"
    private let notifier = PomodoroNotifier.shared

    private enum PhaseAdvanceMode {
        case automatic
        case manual
    }

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        loadPersistedState()
        start()
    }

    deinit {
        ticker?.cancel()
    }

    var totalSeconds: Int {
        phase.defaultDuration
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1 - (Double(remainingSeconds) / Double(totalSeconds))
    }

    var formattedRemainingTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var primaryActionTitle: String {
        status == .running ? String(localized: "action.pause") : String(localized: "action.start")
    }

    var primaryActionSystemImage: String {
        status == .running ? "pause.fill" : "play.fill"
    }

    var nextPhaseSummary: String {
        let nextPhase: PomodoroPhase

        switch phase {
        case .focus:
            nextPhase = willUseLongBreakAfterCurrentFocus ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            nextPhase = .focus
        }

        return String(
            format: String(localized: "timer.nextPhaseFormat"),
            nextPhase.title
        )
    }

    func startPause() {
        switch status {
        case .idle, .paused:
            start()
        case .running:
            status = .paused
            stopTicker()
        }
    }

    func reset() {
        stopTicker()
        status = .idle
        remainingSeconds = phase.defaultDuration
    }

    func skip() {
        advancePhaseAfterCompletion(mode: .manual)
    }

    func clearTodayCompletedCount() {
        todayCompletedCount = 0
        completedFocusRounds = 0
        persistDailyState()
    }

    func selectPhase(_ newPhase: PomodoroPhase) {
        let shouldContinueRunning = status == .running

        stopTicker()
        phase = newPhase
        remainingSeconds = newPhase.defaultDuration

        if shouldContinueRunning {
            start()
        } else {
            status = .idle
        }
    }

    func quit() {
        NSApp.terminate(nil)
    }

    private var willUseLongBreakAfterCurrentFocus: Bool {
        (completedFocusRounds + 1).isMultiple(of: 4)
    }

    private func startTicker() {
        guard ticker == nil else { return }

        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))

                guard !Task.isCancelled else { break }
                self?.tick()
            }
        }
    }

    private func start() {
        status = .running
        startTicker()
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }

    private func tick() {
        guard status == .running else { return }

        if remainingSeconds > 1 {
            remainingSeconds -= 1
        } else {
            advancePhaseAfterCompletion(mode: .automatic)
        }
    }

    private func advancePhaseAfterCompletion(mode: PhaseAdvanceMode) {
        stopTicker()

        switch phase {
        case .focus:
            completedFocusRounds += 1
            todayCompletedCount += 1
            persistDailyState()
            phase = completedFocusRounds.isMultiple(of: 4) ? .longBreak : .shortBreak
            notifier.notifyFocusCompleted(nextPhase: phase)
        case .shortBreak, .longBreak:
            phase = .focus
            notifier.notifyBreakCompleted()
        }

        remainingSeconds = phase.defaultDuration
        switch mode {
        case .automatic:
            start()
        case .manual:
            status = .idle
        }
    }

    private func loadPersistedState() {
        if let lastDate = defaults.object(forKey: dateKey) as? Date,
           calendar.isDateInToday(lastDate) {
            todayCompletedCount = defaults.integer(forKey: completedKey)
            completedFocusRounds = defaults.integer(forKey: roundsKey)
        } else {
            todayCompletedCount = 0
            completedFocusRounds = 0
            persistDailyState()
        }
    }

    private func persistDailyState() {
        defaults.set(todayCompletedCount, forKey: completedKey)
        defaults.set(completedFocusRounds, forKey: roundsKey)
        defaults.set(Date(), forKey: dateKey)
    }
}
