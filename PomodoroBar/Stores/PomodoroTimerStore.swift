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
    var focusDurationSeconds: Int = PomodoroPhase.focus.defaultDuration
    var shortBreakDurationSeconds: Int = PomodoroPhase.shortBreak.defaultDuration
    var longBreakDurationSeconds: Int = PomodoroPhase.longBreak.defaultDuration
    var restCycle: [PomodoroPhase] = [.shortBreak, .shortBreak, .shortBreak, .longBreak]

    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar
    private var previewProgress: Double?

    static let rhythmLengthRange = 2...6

    private let completedKey = "todayCompletedCount"
    private let roundsKey = "completedFocusRounds"
    private let dateKey = "lastCompletionDate"
    private let focusDurationKey = "focusDurationSeconds"
    private let shortBreakDurationKey = "shortBreakDurationSeconds"
    private let longBreakDurationKey = "longBreakDurationSeconds"
    private let restCycleKey = "restCycle"
    private let longBreakFrequencyKey = "longBreakFrequency"
    private let sessionPhaseKey = "timerSessionPhase"
    private let sessionStatusKey = "timerSessionStatus"
    private let sessionRemainingSecondsKey = "timerSessionRemainingSeconds"
    private let sessionDateKey = "timerSessionDate"
    private let notifier = PomodoroNotifier.shared

    private enum PhaseAdvanceMode {
        case automatic
        case manual
    }

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        loadDurationPreferences()
        loadPersistedState()

        if loadPersistedTimerSession() {
            if status == .running {
                startTicker()
            }
        } else {
            remainingSeconds = durationSeconds(for: phase)
            start()
        }
    }

    deinit {
        ticker?.cancel()
    }

    var totalSeconds: Int {
        durationSeconds(for: phase)
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1 - (Double(remainingSeconds) / Double(totalSeconds))
    }

    var displayedProgress: Double {
        previewProgress ?? progress
    }

    var displayedRemainingSeconds: Int {
        guard let previewProgress else { return remainingSeconds }
        return remainingSeconds(for: previewProgress)
    }

    var formattedRemainingTime: String {
        let minutes = displayedRemainingSeconds / 60
        let seconds = displayedRemainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var primaryActionTitle: String {
        status == .running ? String(localized: "action.pause") : String(localized: "action.start")
    }

    var primaryActionSystemImage: String {
        status == .running ? "pause.fill" : "play.fill"
    }

    var currentRoundInCycle: Int {
        completedFocusRounds % rhythmLength + 1
    }

    var rhythmLength: Int {
        restCycle.count
    }

    var shortBreaksPerCycle: Int {
        restCycle.filter { $0 == .shortBreak }.count
    }

    var longBreaksPerCycle: Int {
        restCycle.filter { $0 == .longBreak }.count
    }

    var currentTimelinePositionInCycle: Int {
        currentTimelineAbsolutePosition % timelinePositionCount
    }

    var timelinePositionCount: Int {
        rhythmLength * 2
    }

    var nextPhaseSummary: String {
        let nextPhase: PomodoroPhase

        switch phase {
        case .focus:
            nextPhase = nextRestPhaseAfterCurrentFocus
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
            persistTimerSession()
        }
    }

    func reset() {
        stopTicker()
        status = .idle
        remainingSeconds = durationSeconds(for: phase)
        persistTimerSession()
    }

    func skip() {
        advancePhaseAfterCompletion(mode: .manual)
    }

    func clearTodayCompletedCount() {
        todayCompletedCount = 0
        completedFocusRounds = 0
        persistDailyState()
    }

    func setProgress(_ newProgress: Double) {
        guard totalSeconds > 0 else { return }

        let newRemainingSeconds = remainingSeconds(for: newProgress)
        if remainingSeconds != newRemainingSeconds {
            remainingSeconds = newRemainingSeconds
            persistTimerSession()
        }
    }

    func previewProgress(_ newProgress: Double) {
        let clampedProgress = min(1, max(0, newProgress))
        guard previewProgress != clampedProgress else { return }
        previewProgress = clampedProgress
    }

    func commitProgress(_ newProgress: Double) {
        setProgress(newProgress)
        previewProgress = nil
    }

    func durationSeconds(for phase: PomodoroPhase) -> Int {
        switch phase {
        case .focus:
            focusDurationSeconds
        case .shortBreak:
            shortBreakDurationSeconds
        case .longBreak:
            longBreakDurationSeconds
        }
    }

    func durationMinutes(for phase: PomodoroPhase) -> Int {
        durationSeconds(for: phase) / 60
    }

    func setDurationMinutes(_ minutes: Int, for phase: PomodoroPhase) {
        let clampedMinutes = min(180, max(1, minutes))
        let newDurationSeconds = clampedMinutes * 60
        let currentProgress = self.phase == phase ? progress : 0

        switch phase {
        case .focus:
            focusDurationSeconds = newDurationSeconds
        case .shortBreak:
            shortBreakDurationSeconds = newDurationSeconds
        case .longBreak:
            longBreakDurationSeconds = newDurationSeconds
        }

        persistDurationPreferences()

        guard self.phase == phase else { return }

        if status == .idle {
            remainingSeconds = newDurationSeconds
        } else {
            remainingSeconds = Int((Double(newDurationSeconds) * (1 - currentProgress)).rounded())
        }
        persistTimerSession()
    }

    func resetDurationPreferences() {
        let currentProgress = progress

        focusDurationSeconds = PomodoroPhase.focus.defaultDuration
        shortBreakDurationSeconds = PomodoroPhase.shortBreak.defaultDuration
        longBreakDurationSeconds = PomodoroPhase.longBreak.defaultDuration
        persistDurationPreferences()

        if status == .idle {
            remainingSeconds = totalSeconds
        } else {
            remainingSeconds = Int((Double(totalSeconds) * (1 - currentProgress)).rounded())
        }
        persistTimerSession()
    }

    func setRhythmLength(_ length: Int) {
        let clampedLength = min(
            Self.rhythmLengthRange.upperBound,
            max(Self.rhythmLengthRange.lowerBound, length)
        )
        guard restCycle.count != clampedLength else { return }

        if restCycle.count < clampedLength {
            let addedBreaks = Array(repeating: PomodoroPhase.shortBreak, count: clampedLength - restCycle.count)
            restCycle.append(contentsOf: addedBreaks)
        } else {
            restCycle = Array(restCycle.prefix(clampedLength))
        }

        normalizeRestCycle()
        persistRestCycle()
    }

    func toggleRestPhase(at index: Int) {
        guard restCycle.indices.contains(index) else { return }

        restCycle[index] = restCycle[index] == .shortBreak ? .longBreak : .shortBreak
        normalizeRestCycle()
        persistRestCycle()
    }

    func moveRestPhase(from sourceIndex: Int, to destinationIndex: Int) {
        guard restCycle.indices.contains(sourceIndex) else { return }

        let clampedDestination = min(restCycle.count - 1, max(0, destinationIndex))
        guard sourceIndex != clampedDestination else { return }

        let movedPhase = restCycle.remove(at: sourceIndex)
        restCycle.insert(movedPhase, at: clampedDestination)
        normalizeRestCycle()
        persistRestCycle()
    }

    func resetRestCycle() {
        restCycle = Self.defaultRestCycle
        persistRestCycle()
    }

    func phaseForTimelinePosition(_ position: Int) -> PomodoroPhase {
        let wrappedPosition = wrappedTimelinePosition(position)
        guard !wrappedPosition.isMultiple(of: 2) else { return .focus }

        return restCycle[wrappedPosition / 2]
    }

    func moveToPreviousTimelinePosition() {
        moveToTimelineAbsolutePosition(max(0, currentTimelineAbsolutePosition - 1))
    }

    func moveToNextTimelinePosition() {
        moveToTimelineAbsolutePosition(currentTimelineAbsolutePosition + 1)
    }

    func moveToTimelinePositionInCurrentCycle(_ position: Int) {
        let cycleStart = currentTimelineAbsolutePosition - currentTimelinePositionInCycle
        moveToTimelineAbsolutePosition(cycleStart + wrappedTimelinePosition(position))
    }

    func selectPhase(_ newPhase: PomodoroPhase) {
        let shouldContinueRunning = status == .running

        stopTicker()
        phase = newPhase
        remainingSeconds = durationSeconds(for: newPhase)
        persistTimerSession()

        if shouldContinueRunning {
            start()
        } else {
            status = .idle
        }
    }

    func quit() {
        NSApp.terminate(nil)
    }

    private var nextRestPhaseAfterCurrentFocus: PomodoroPhase {
        restCycle[completedFocusRounds % rhythmLength]
    }

    private var completedFocusRestPhase: PomodoroPhase {
        restCycle[(completedFocusRounds - 1) % rhythmLength]
    }

    private var currentTimelineAbsolutePosition: Int {
        switch phase {
        case .focus:
            completedFocusRounds * 2
        case .shortBreak, .longBreak:
            max(0, completedFocusRounds * 2 - 1)
        }
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
        persistTimerSession()
        startTicker()
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }

    private func moveToTimelineAbsolutePosition(_ position: Int) {
        let shouldContinueRunning = status == .running
        let clampedPosition = max(0, position)

        stopTicker()

        if clampedPosition.isMultiple(of: 2) {
            completedFocusRounds = clampedPosition / 2
            phase = .focus
        } else {
            completedFocusRounds = clampedPosition / 2 + 1
            phase = restCycle[(completedFocusRounds - 1) % rhythmLength]
        }

        remainingSeconds = durationSeconds(for: phase)
        persistDailyState()
        persistTimerSession()

        if shouldContinueRunning {
            start()
        } else {
            status = .idle
        }
    }

    private func wrappedTimelinePosition(_ position: Int) -> Int {
        let count = timelinePositionCount
        return (position % count + count) % count
    }

    private func remainingSeconds(for progress: Double) -> Int {
        guard totalSeconds > 0 else { return remainingSeconds }

        let clampedProgress = min(1, max(0, progress))
        return Int((Double(totalSeconds) * (1 - clampedProgress)).rounded())
    }

    private func tick() {
        guard status == .running else { return }

        if remainingSeconds > 1 {
            remainingSeconds -= 1
            persistTimerSession()
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
            phase = completedFocusRestPhase
            notifier.notifyFocusCompleted(nextPhase: phase)
        case .shortBreak, .longBreak:
            phase = .focus
            notifier.notifyBreakCompleted()
        }

        remainingSeconds = durationSeconds(for: phase)
        persistTimerSession()
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

    private func loadPersistedTimerSession() -> Bool {
        guard let sessionDate = defaults.object(forKey: sessionDateKey) as? Date,
              calendar.isDateInToday(sessionDate),
              let rawPhase = defaults.string(forKey: sessionPhaseKey),
              let persistedPhase = PomodoroPhase(rawValue: rawPhase) else {
            return false
        }

        phase = persistedPhase
        let persistedRemainingSeconds = defaults.integer(forKey: sessionRemainingSecondsKey)
        let phaseDuration = durationSeconds(for: phase)
        remainingSeconds = min(phaseDuration, max(1, persistedRemainingSeconds))

        if let rawStatus = defaults.string(forKey: sessionStatusKey),
           let persistedStatus = TimerStatus(rawValue: rawStatus) {
            status = persistedStatus
        } else {
            status = .running
        }

        return true
    }

    private func persistTimerSession() {
        defaults.set(phase.rawValue, forKey: sessionPhaseKey)
        defaults.set(status.rawValue, forKey: sessionStatusKey)
        defaults.set(remainingSeconds, forKey: sessionRemainingSecondsKey)
        defaults.set(Date(), forKey: sessionDateKey)
    }

    private func persistDailyState() {
        defaults.set(todayCompletedCount, forKey: completedKey)
        defaults.set(completedFocusRounds, forKey: roundsKey)
        defaults.set(Date(), forKey: dateKey)
    }

    private func loadDurationPreferences() {
        focusDurationSeconds = persistedDuration(forKey: focusDurationKey, defaultValue: PomodoroPhase.focus.defaultDuration)
        shortBreakDurationSeconds = persistedDuration(forKey: shortBreakDurationKey, defaultValue: PomodoroPhase.shortBreak.defaultDuration)
        longBreakDurationSeconds = persistedDuration(forKey: longBreakDurationKey, defaultValue: PomodoroPhase.longBreak.defaultDuration)
        restCycle = persistedRestCycle()
    }

    private func persistedDuration(forKey key: String, defaultValue: Int) -> Int {
        let duration = defaults.integer(forKey: key)
        return duration > 0 ? duration : defaultValue
    }

    private func persistDurationPreferences() {
        defaults.set(focusDurationSeconds, forKey: focusDurationKey)
        defaults.set(shortBreakDurationSeconds, forKey: shortBreakDurationKey)
        defaults.set(longBreakDurationSeconds, forKey: longBreakDurationKey)
    }

    private func persistedRestCycle() -> [PomodoroPhase] {
        if let rawCycle = defaults.string(forKey: restCycleKey) {
            let cycle = rawCycle
                .split(separator: ",")
                .compactMap { PomodoroPhase(rawValue: String($0)) }
                .filter { $0 == .shortBreak || $0 == .longBreak }

            if Self.rhythmLengthRange.contains(cycle.count) {
                return normalizedRestCycle(cycle)
            }
        }

        let legacyFrequency = defaults.integer(forKey: longBreakFrequencyKey)
        if legacyFrequency > 0 {
            let clampedFrequency = min(
                Self.rhythmLengthRange.upperBound,
                max(Self.rhythmLengthRange.lowerBound, legacyFrequency)
            )
            return Array(repeating: .shortBreak, count: clampedFrequency - 1) + [.longBreak]
        }

        return Self.defaultRestCycle
    }

    private func normalizeRestCycle() {
        restCycle = normalizedRestCycle(restCycle)
    }

    private func normalizedRestCycle(_ cycle: [PomodoroPhase]) -> [PomodoroPhase] {
        var normalizedCycle = cycle
            .filter { $0 == .shortBreak || $0 == .longBreak }

        if normalizedCycle.count < Self.rhythmLengthRange.lowerBound {
            normalizedCycle.append(contentsOf: Array(
                repeating: PomodoroPhase.shortBreak,
                count: Self.rhythmLengthRange.lowerBound - normalizedCycle.count
            ))
        }

        if normalizedCycle.count > Self.rhythmLengthRange.upperBound {
            normalizedCycle = Array(normalizedCycle.prefix(Self.rhythmLengthRange.upperBound))
        }

        if !normalizedCycle.contains(.longBreak) {
            normalizedCycle[normalizedCycle.count - 1] = .longBreak
        }

        return normalizedCycle
    }

    private func persistRestCycle() {
        defaults.set(restCycle.map(\.rawValue).joined(separator: ","), forKey: restCycleKey)
    }

    private static var defaultRestCycle: [PomodoroPhase] {
        [.shortBreak, .shortBreak, .shortBreak, .longBreak]
    }
}
