import SwiftUI

struct LegacyStatusLabelView: View {
    @ObservedObject var store: LegacyPomodoroTimerStore

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: store.phase.menuBarSymbol(progress: store.displayedProgress))
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
        min(100, max(0, Int((store.displayedProgress * 100).rounded())))
    }
}
