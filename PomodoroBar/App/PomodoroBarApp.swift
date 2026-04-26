import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        _ = PomodoroAppUpdater.shared
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            PomodoroNotifier.shared.requestAuthorization()
            MenuBarOnboardingTipPresenter.shared.showIfNeeded()
        }
    }
}

@MainActor
final class MenuBarOnboardingTipPresenter {
    static let shared = MenuBarOnboardingTipPresenter()

    private let hasShownKey = "hasShownMenuBarOnboardingTip"
    private var panel: NSPanel?

    private init() {}

    func showIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: hasShownKey) else { return }

        UserDefaults.standard.set(true, forKey: hasShownKey)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(850))
            show()
        }
    }

    private func show() {
        guard panel == nil,
              let screenFrame = NSScreen.main?.visibleFrame else {
            return
        }

        let panelSize = NSSize(width: 312, height: 104)
        let origin = NSPoint(
            x: screenFrame.maxX - panelSize.width - 18,
            y: screenFrame.maxY - panelSize.height - 12
        )

        let tipPanel = NSPanel(
            contentRect: NSRect(origin: origin, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        tipPanel.isOpaque = false
        tipPanel.backgroundColor = .clear
        tipPanel.hasShadow = true
        tipPanel.level = .floating
        tipPanel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        tipPanel.hidesOnDeactivate = false

        tipPanel.contentView = NSHostingView(
            rootView: MenuBarOnboardingTip {
                tipPanel.close()
                self.panel = nil
            }
        )

        panel = tipPanel
        tipPanel.orderFrontRegardless()

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard self.panel === tipPanel else { return }
            tipPanel.close()
            self.panel = nil
        }
    }
}

private struct MenuBarOnboardingTip: View {
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "menubar.rectangle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "onboarding.menuBarTip.title"))
                        .font(.headline)
                    Text(String(localized: "onboarding.menuBarTip.message"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text(String(localized: "onboarding.menuBarTip.dismiss"))
                        .font(.callout.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.0, green: 0.48, blue: 1.0))
                        )
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.28), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.16), radius: 4, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(width: 312, height: 104)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Triangle()
                .fill(.regularMaterial)
                .frame(width: 18, height: 10)
                .offset(x: -42, y: -9)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        )
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

@main
struct PomodoroBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var timerStore = PomodoroTimerStore()

    var body: some Scene {
        MenuBarExtra {
            PomodoroPanelView(store: timerStore)
        } label: {
            StatusLabelView(store: timerStore)
        }
        .menuBarExtraStyle(.window)
    }
}
