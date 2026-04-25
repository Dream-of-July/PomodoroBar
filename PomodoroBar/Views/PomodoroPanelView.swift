import AppKit
import SwiftUI

struct PomodoroPanelView: View {
    let store: PomodoroTimerStore
    @Namespace private var phaseSelectorNamespace
    @GestureState private var isPhaseSelectorPressed = false
    @State private var pendingPhase: PomodoroPhase?
    @State private var isHoveringTodayCompletedCount = false

    private let panelWidth: CGFloat = 336
    private let panelPadding: CGFloat = 18
    private let controlHeight: CGFloat = 36
    private let iconButtonWidth: CGFloat = 54

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 14) {
                phaseHeader
                timerReadout
                ProgressView(value: store.progress)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                metadataRow
            }
            .padding(.top, 2)

            controls
            Divider()
            footer
        }
        .padding(panelPadding)
        .frame(width: panelWidth)
    }

    private var phaseHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: store.phase.statusIcon)
                .font(.title2.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(store.phase.title)
                    .font(.headline)
                Text(store.status.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(String(format: String(localized: "timer.roundFormat"), store.completedFocusRounds % 4 + 1))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.quaternary, in: Capsule())
        }
    }

    private var timerReadout: some View {
        VStack(spacing: 6) {
            Text(store.formattedRemainingTime)
                .font(.system(size: 56, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())

            Text(store.nextPhaseSummary)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var metadataRow: some View {
        HStack {
            Button {
                guard store.todayCompletedCount > 0 else { return }

                if confirmClearTodayCompletedCount() {
                    store.clearTodayCompletedCount()
                }
            } label: {
                Label(
                    todayCompletedCountTitle,
                    systemImage: todayCompletedCountSystemImage
                )
                .frame(height: metadataActionHeight)
                .padding(.horizontal, 7)
                .background {
                    if isShowingClearTodayAction {
                        Capsule()
                            .fill(Color.red.opacity(0.12))
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(store.todayCompletedCount == 0)
            .foregroundStyle(todayCompletedCountForegroundStyle)
            .help(String(localized: "stats.clearToday.help"))
            .onHover { isHovering in
                isHoveringTodayCompletedCount = isHovering
            }

            Spacer()
            Label(
                String(format: String(localized: "stats.minutesFormat"), store.totalSeconds / 60),
                systemImage: "clock.fill"
            )
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(height: metadataActionHeight)
    }

    private let metadataActionHeight: CGFloat = 22

    private var todayCompletedCountTitle: String {
        if isShowingClearTodayAction {
            return String(localized: "stats.clearToday.inlineAction")
        }

        return String(format: String(localized: "stats.todayCompletedFormat"), store.todayCompletedCount)
    }

    private var todayCompletedCountSystemImage: String {
        isShowingClearTodayAction ? "trash.fill" : "checkmark.circle.fill"
    }

    private var todayCompletedCountForegroundStyle: AnyShapeStyle {
        if isShowingClearTodayAction {
            return AnyShapeStyle(Color.red)
        }

        return AnyShapeStyle(.secondary)
    }

    private var isShowingClearTodayAction: Bool {
        isHoveringTodayCompletedCount && store.todayCompletedCount > 0
    }

    private func confirmClearTodayCompletedCount() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(localized: "stats.clearToday.confirmTitle")
        alert.informativeText = String(localized: "stats.clearToday.confirmMessage")
        alert.addButton(withTitle: String(localized: "stats.clearToday.confirmAction"))
        alert.addButton(withTitle: String(localized: "action.cancel"))

        return alert.runModal() == .alertFirstButtonReturn
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button {
                store.startPause()
            } label: {
                Label(store.primaryActionTitle, systemImage: store.primaryActionSystemImage)
                    .frame(maxWidth: .infinity)
                    .frame(height: controlHeight)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .keyboardShortcut(.space, modifiers: [])

            Button {
                store.reset()
            } label: {
                Label(String(localized: "action.reset"), systemImage: "arrow.counterclockwise")
                    .labelStyle(.iconOnly)
                    .frame(width: iconButtonWidth, height: controlHeight)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .help(String(localized: "action.reset"))

            Button {
                store.skip()
            } label: {
                Label(String(localized: "action.skip"), systemImage: "forward.end.fill")
                    .labelStyle(.iconOnly)
                    .frame(width: iconButtonWidth, height: controlHeight)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .help(String(localized: "action.skip"))
        }
        .controlSize(.large)
        .font(.title3.weight(.semibold))
    }

    private var footer: some View {
        HStack(spacing: 8) {
            phaseSelector
                .frame(width: 214)

            Spacer(minLength: 0)

            Button(role: .destructive) {
                store.quit()
            } label: {
                Label(String(localized: "action.quit"), systemImage: "power.circle.fill")
            }
            .font(.callout.weight(.semibold))
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .fixedSize()
        }
    }

    private var phaseSelector: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                ForEach(Array(PomodoroPhase.allCases.enumerated()), id: \.element.id) { index, phase in
                    phaseSelectorItem(for: phase)

                    if index < PomodoroPhase.allCases.count - 1 {
                        Divider()
                            .frame(height: 18)
                            .opacity(shouldShowPhaseDivider(after: phase) ? 0.45 : 0)
                    }
                }
            }
            .padding(4)
            .background(.quaternary, in: Capsule())
            .contentShape(Capsule())
            .gesture(phaseSelectionGesture(width: proxy.size.width))
        }
        .frame(height: 38)
        .animation(.easeInOut(duration: 0.18), value: store.phase)
        .animation(.easeInOut(duration: 0.12), value: pendingPhase)
    }

    private func phaseSelectorItem(for phase: PomodoroPhase) -> some View {
        let isSelected = selectedPhaseForDisplay == phase

        return HStack(spacing: 5) {
            Image(systemName: phase.statusIcon)
                .font(.callout.weight(isSelected ? .semibold : .medium))
                .symbolRenderingMode(.hierarchical)

            Text(phase.shortTitle)
                .font(.callout.weight(isSelected ? .semibold : .medium))
                .lineLimit(1)
        }
        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
        .frame(maxWidth: .infinity)
        .frame(height: 30)
        .padding(.horizontal, 3)
        .background {
            if isSelected {
                Capsule()
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.84))
                    .shadow(
                        color: .black.opacity(isPhaseSelectorPressed ? 0.18 : 0.07),
                        radius: isPhaseSelectorPressed ? 5 : 2,
                        x: 0,
                        y: isPhaseSelectorPressed ? 2 : 1
                    )
                    .matchedGeometryEffect(id: "selectedPhase", in: phaseSelectorNamespace)
            }
        }
        .contentShape(Capsule())
    }

    private var selectedPhaseForDisplay: PomodoroPhase {
        pendingPhase ?? store.phase
    }

    private func phaseSelectionGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isPhaseSelectorPressed) { _, state, _ in
                state = true
            }
            .onChanged { value in
                if let phase = phase(atX: value.location.x, width: width) {
                    pendingPhase = phase
                }
            }
            .onEnded { value in
                if let phase = phase(atX: value.location.x, width: width) {
                    store.selectPhase(phase)
                }

                pendingPhase = nil
            }
    }

    private func phase(atX locationX: CGFloat, width: CGFloat) -> PomodoroPhase? {
        guard width > 0 else { return nil }

        let phases = PomodoroPhase.allCases
        let clampedX = min(max(locationX, 0), width - 0.1)
        let segmentWidth = width / CGFloat(phases.count)
        let index = min(phases.count - 1, max(0, Int(clampedX / segmentWidth)))

        return phases[index]
    }

    private func shouldShowPhaseDivider(after phase: PomodoroPhase) -> Bool {
        guard let currentIndex = PomodoroPhase.allCases.firstIndex(of: phase),
              currentIndex + 1 < PomodoroPhase.allCases.count else {
            return false
        }

        let nextPhase = PomodoroPhase.allCases[currentIndex + 1]
        return selectedPhaseForDisplay != phase && selectedPhaseForDisplay != nextPhase
    }

}
