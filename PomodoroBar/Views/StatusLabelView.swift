import SwiftUI

struct StatusLabelView: View {
    let store: PomodoroTimerStore

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: store.phase.menuBarSymbol(progress: store.progress))
                .imageScale(.medium)

            Text(store.formattedRemainingTime)
                .monospacedDigit()

            Text("\(progressPercent)%")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 12, weight: .semibold))
        .help("\(store.phase.title) \(store.formattedRemainingTime)")
    }

    private var progressPercent: Int {
        min(100, max(0, Int((store.progress * 100).rounded())))
    }
}
