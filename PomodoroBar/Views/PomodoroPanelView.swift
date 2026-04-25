import AppKit
import SwiftUI

struct PomodoroPanelView: View {
    let store: PomodoroTimerStore
    @State private var progressDraft: Double?
    @State private var isHoveringTodayCompletedCount = false
    @State private var isShowingDurationEditor = false
    @State private var isShowingRhythmEditor = false
    @State private var draggingRestIndex: Int?
    @State private var hoveredTimelinePosition: Int?
    @State private var isTimelinePointerInside = false
    @State private var timelineCenterGeneration = 0
    @State private var centeredTimelinePosition: Int?

    private let panelWidth: CGFloat = 336
    private let panelPadding: CGFloat = 18
    private let controlHeight: CGFloat = 36
    private let iconButtonWidth: CGFloat = 54
    private let rhythmChipWidth: CGFloat = 68
    private let rhythmDragStepWidth: CGFloat = 88
    private let timelineItemWidth: CGFloat = 70
    private let timelineItemSpacing: CGFloat = 4

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 14) {
                phaseHeader
                timerReadout
                adjustableProgressBar
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
            Image(systemName: store.phase.statusIcon(progress: store.displayedProgress))
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

            Button {
                isShowingRhythmEditor.toggle()
            } label: {
                Text(String(format: String(localized: "timer.roundFormat"), store.currentRoundInCycle, store.rhythmLength))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.quaternary, in: Capsule())
            }
            .buttonStyle(.plain)
            .help(String(localized: "rhythm.edit.help"))
            .popover(isPresented: $isShowingRhythmEditor, arrowEdge: .bottom) {
                rhythmEditor
            }
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

    private var adjustableProgressBar: some View {
        Slider(value: progressBinding, in: 0...1, onEditingChanged: { isEditing in
            if !isEditing {
                store.commitProgress(progressDraft ?? store.displayedProgress)
                progressDraft = nil
            }
        })
            .labelsHidden()
            .tint(.accentColor)
            .controlSize(.small)
            .frame(height: 18)
        .help(String(localized: "timer.progress.help"))
    }

    private var progressBinding: Binding<Double> {
        Binding {
            progressDraft ?? store.displayedProgress
        } set: { newProgress in
            progressDraft = newProgress
            store.previewProgress(newProgress)
        }
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
            Button {
                isShowingDurationEditor.toggle()
            } label: {
                Label(
                    String(format: String(localized: "stats.minutesFormat"), store.totalSeconds / 60),
                    systemImage: "clock.fill"
                )
                .frame(height: metadataActionHeight)
                .padding(.horizontal, 7)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help(String(localized: "duration.edit.help"))
            .popover(isPresented: $isShowingDurationEditor, arrowEdge: .bottom) {
                durationEditor
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(height: metadataActionHeight)
    }

    private var durationEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "duration.editor.title"))
                .font(.headline)

            VStack(spacing: 10) {
                ForEach(PomodoroPhase.allCases) { phase in
                    durationEditorRow(for: phase)
                }
            }

            Divider()

            Button {
                store.resetDurationPreferences()
            } label: {
                Label(String(localized: "duration.resetDefaults"), systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .controlSize(.regular)
        }
        .padding(14)
        .frame(width: 244)
    }

    private func durationEditorRow(for phase: PomodoroPhase) -> some View {
        HStack(spacing: 10) {
            Image(systemName: phaseSelectorIcon(for: phase))
                .font(.callout.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(phase == store.phase ? Color.accentColor : .secondary)
                .frame(width: 18)

            Text(phase.shortTitle)
                .font(.callout)

            Spacer()

            Text(String(format: String(localized: "stats.minutesFormat"), store.durationMinutes(for: phase)))
                .monospacedDigit()
                .frame(width: 54, alignment: .trailing)

            Stepper(String(localized: "duration.editor.title"), value: durationBinding(for: phase), in: 1...180)
            .labelsHidden()
        }
    }

    private func durationBinding(for phase: PomodoroPhase) -> Binding<Int> {
        Binding {
            store.durationMinutes(for: phase)
        } set: { newMinutes in
            store.setDurationMinutes(newMinutes, for: phase)
        }
    }

    private var rhythmEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(String(localized: "rhythm.editor.title"))
                    .font(.headline)

                Spacer()

                Text(String(format: String(localized: "rhythm.sequenceLengthFormat"), store.rhythmLength))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Color.accentColor)
            }

            rhythmTimeline

            VStack(spacing: 6) {
                Slider(value: rhythmLengthBinding, in: Double(PomodoroTimerStore.rhythmLengthRange.lowerBound)...Double(PomodoroTimerStore.rhythmLengthRange.upperBound), step: 1)
                    .labelsHidden()
                    .tint(.accentColor)
                    .controlSize(.regular)
                    .padding(.vertical, 3)

                HStack {
                    Text(String(format: String(localized: "rhythm.minFormat"), PomodoroTimerStore.rhythmLengthRange.lowerBound))
                    Spacer()
                    Text(String(format: String(localized: "rhythm.maxFormat"), PomodoroTimerStore.rhythmLengthRange.upperBound))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }

            Text(String(localized: "rhythm.timelineHint"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                store.resetRestCycle()
            } label: {
                Label(String(localized: "rhythm.resetDefaults"), systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .controlSize(.regular)
        }
        .padding(14)
        .frame(width: 304)
    }

    private var rhythmTimeline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: String(localized: "rhythm.longBreakFrequencyFormat"), store.rhythmLength))
                .font(.callout)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(store.restCycle.indices), id: \.self) { index in
                        rhythmFocusChip(index: index)
                        rhythmConnector
                        rhythmRestChip(index: index, phase: store.restCycle[index])
                        if index < store.restCycle.count - 1 {
                            rhythmConnector
                        }
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    private func rhythmFocusChip(index: Int) -> some View {
        VStack(spacing: 5) {
            Image(systemName: PomodoroPhase.focus.statusIcon(progress: store.displayedProgress))
                .font(.callout.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
            Text(PomodoroPhase.focus.shortTitle)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
            Text("\(index + 1)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(index == store.currentRoundInCycle - 1 ? Color.accentColor : .secondary)
        .frame(width: rhythmChipWidth)
        .frame(height: 62)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func rhythmRestChip(index: Int, phase: PomodoroPhase) -> some View {
        VStack(spacing: 5) {
            Image(systemName: phase.statusIcon)
                .font(.callout.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
            Text(phase.shortTitle)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
            Image(systemName: "arrow.left.and.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .foregroundStyle(phase == .longBreak ? Color.accentColor : .secondary)
        .frame(width: rhythmChipWidth)
        .frame(height: 62)
        .background(
            (draggingRestIndex == index ? Color.accentColor.opacity(0.16) : Color(nsColor: .controlBackgroundColor).opacity(0.64)),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(draggingRestIndex == index ? Color.accentColor.opacity(0.55) : Color.secondary.opacity(0.16), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            store.toggleRestPhase(at: index)
        }
        .gesture(restReorderGesture(for: index))
        .help(String(localized: "rhythm.toggleBreak.help"))
    }

    private var rhythmConnector: some View {
        Image(systemName: "chevron.right")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.tertiary)
    }

    private func restReorderGesture(for index: Int) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { _ in
                draggingRestIndex = index
            }
            .onEnded { value in
                let offset = Int((value.translation.width / rhythmDragStepWidth).rounded())
                store.moveRestPhase(from: index, to: index + offset)
                draggingRestIndex = nil
            }
    }

    private var rhythmLengthBinding: Binding<Double> {
        Binding {
            Double(store.rhythmLength)
        } set: { newFrequency in
            store.setRhythmLength(Int(newFrequency.rounded()))
        }
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
                store.reset()
            } label: {
                Label(String(localized: "action.reset"), systemImage: "arrow.counterclockwise")
                    .labelStyle(.iconOnly)
                    .font(.title2.weight(.bold))
                    .frame(width: iconButtonWidth, height: controlHeight)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .help(String(localized: "action.reset"))

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
            syncedTimeline
                .frame(width: 224)

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

    private var syncedTimeline: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: timelineItemSpacing) {
                    ForEach(0..<store.timelinePositionCount, id: \.self) { position in
                        timelineItem(at: position)
                            .id(position)
                    }
                }
                .padding(4)
                .contentShape(Capsule())
                .simultaneousGesture(timelineSelectionGesture())
            }
            .background(.quaternary, in: Capsule())
            .onAppear {
                let position = store.currentTimelinePositionInCycle
                centeredTimelinePosition = position
                proxy.scrollTo(position, anchor: .center)
            }
            .onChange(of: store.currentTimelinePositionInCycle) { _, position in
                scheduleTimelineCenter(position, proxy: proxy, delay: isTimelinePointerInside ? 1.6 : 0)
            }
            .onHover { isHovering in
                isTimelinePointerInside = isHovering
                hoveredTimelinePosition = isHovering ? hoveredTimelinePosition : nil

                if !isHovering {
                    scheduleTimelineCenter(store.currentTimelinePositionInCycle, proxy: proxy, delay: 0.5)
                }
            }
        }
        .frame(height: 38)
    }

    private func timelineItem(at position: Int) -> some View {
        let phase = store.phaseForTimelinePosition(position)
        let isSelected = position == store.currentTimelinePositionInCycle
        let isHovering = position == hoveredTimelinePosition

        return Button {
            snapTimeline(to: position)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: phaseIconForTimeline(phase, isSelected: isSelected))
                    .font(.caption.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)

                Text(timelineTitle(for: phase))
                    .font(.caption.weight(isSelected ? .semibold : .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            .frame(width: timelineItemWidth, height: 30)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.84))
                        .shadow(color: .black.opacity(0.07), radius: 2, x: 0, y: 1)
                } else if isHovering {
                    Capsule()
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.32))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            hoveredTimelinePosition = isHovering ? position : nil
        }
    }

    private func phaseSelectorIcon(for phase: PomodoroPhase) -> String {
        guard phase == .focus, store.phase == .focus else {
            return phase.statusIcon
        }

        return PomodoroPhase.focusHourglassSymbol(progress: store.displayedProgress)
    }

    private func phaseIconForTimeline(_ phase: PomodoroPhase, isSelected: Bool) -> String {
        guard phase == .focus, isSelected else { return phase.statusIcon }
        return PomodoroPhase.focusHourglassSymbol(progress: store.displayedProgress)
    }

    private func timelineTitle(for phase: PomodoroPhase) -> String {
        phase.shortTitle
    }

    private func snapTimeline(to position: Int) {
        guard position != store.currentTimelinePositionInCycle else { return }
        store.moveToTimelinePositionInCurrentCycle(position)
    }

    private func timelineSelectionGesture() -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard let position = timelinePosition(atX: value.location.x) else { return }
                snapTimeline(to: position)
            }
    }

    private func timelinePosition(atX locationX: CGFloat) -> Int? {
        guard store.timelinePositionCount > 0 else { return nil }

        let contentX = locationX - 4
        let stride = timelineItemWidth + timelineItemSpacing
        let maxIndex = store.timelinePositionCount - 1
        let rawIndex = Int((contentX / stride).rounded(.down))

        return min(max(rawIndex, 0), maxIndex)
    }

    private func scheduleTimelineCenter(_ position: Int, proxy: ScrollViewProxy, delay: Double) {
        timelineCenterGeneration += 1
        let generation = timelineCenterGeneration
        let duration = timelineCenterDuration(to: position)

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard generation == timelineCenterGeneration else { return }

            withAnimation(.easeInOut(duration: duration)) {
                proxy.scrollTo(position, anchor: .center)
            }
            centeredTimelinePosition = position
        }
    }

    private func timelineCenterDuration(to position: Int) -> Double {
        guard let centeredTimelinePosition else { return 1.20 }

        let distance = abs(position - centeredTimelinePosition)
        switch distance {
        case 0:
            return 0.90
        case 1:
            return 2.10
        case 2:
            return 1.65
        case 3:
            return 1.25
        default:
            return 0.95
        }
    }

}
