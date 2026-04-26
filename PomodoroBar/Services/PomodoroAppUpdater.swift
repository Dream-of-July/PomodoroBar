@preconcurrency import AppKit
import Combine
@preconcurrency import Sparkle
import WebKit

@MainActor
final class PomodoroAppUpdater: NSObject, ObservableObject {
    static let shared = PomodoroAppUpdater()

    @Published private(set) var readyUpdateTitle: String?

    private var updater: SPUUpdater?
    private var currentUpdate: SUAppcastItem?
    private var releaseNotesHTML: String?
    private var pendingReadyReply: ((SPUUserUpdateChoice) -> Void)?
    #if DEBUG
    private var debugReadyUpdateVersion: String?
    #endif

    private override init() {
        super.init()

        #if DEBUG
        if Self.shouldPreviewReadyUpdate {
            showDebugReadyUpdate()
        }
        #endif

        guard Self.hasConfiguredFeed,
              Self.hasConfiguredPublicKey else {
            return
        }

        let updater = SPUUpdater(
            hostBundle: .main,
            applicationBundle: .main,
            userDriver: self,
            delegate: nil
        )
        self.updater = updater

        do {
            try updater.start()
            #if DEBUG
            if Self.shouldCheckForUpdatesNow {
                updater.checkForUpdates()
            }
            #endif
        } catch {
            self.updater = nil
        }
    }

    var hasReadyUpdate: Bool {
        readyUpdateTitle != nil
    }

    func presentReadyUpdate() {
        guard hasReadyUpdate else {
            return
        }

        let displayVersion = readyUpdateDisplayVersion
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = String(
            format: String(localized: "update.ready.titleFormat"),
            displayVersion
        )
        alert.informativeText = String(localized: "update.ready.message")
        alert.addButton(withTitle: String(localized: "update.install"))
        alert.addButton(withTitle: String(localized: "action.cancel"))
        alert.accessoryView = releaseNotesView()

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        let pendingReadyReply = pendingReadyReply
        clearReadyUpdate()
        pendingReadyReply?(.install)
    }

    private static var hasConfiguredFeed: Bool {
        guard let feedURL = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              let url = URL(string: feedURL),
              let scheme = url.scheme else {
            return false
        }

        if scheme == "https" {
            return true
        }

        return scheme == "http" && ["127.0.0.1", "localhost"].contains(url.host)
    }

    private static var hasConfiguredPublicKey: Bool {
        guard let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String else {
            return false
        }

        return !publicKey.isEmpty && publicKey != "REPLACE_WITH_SPARKLE_PUBLIC_ED_KEY"
    }

    private func storeReadyUpdate(
        _ update: SUAppcastItem?,
        reply: @escaping (SPUUserUpdateChoice) -> Void
    ) {
        currentUpdate = update ?? currentUpdate
        readyUpdateTitle = String(localized: "update.ready.button")
        pendingReadyReply = reply
    }

    private func clearReadyUpdate() {
        readyUpdateTitle = nil
        pendingReadyReply = nil
    }

    private var readyUpdateDisplayVersion: String {
        if let displayVersion = currentUpdate?.displayVersionString {
            return displayVersion
        }

        #if DEBUG
        if let debugReadyUpdateVersion {
            return debugReadyUpdateVersion
        }
        #endif

        return "1.0 RC"
    }

    private func resetUpdateSession() {
        readyUpdateTitle = nil
        currentUpdate = nil
        releaseNotesHTML = nil
        pendingReadyReply = nil
    }

    private func releaseNotesView() -> NSView {
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 420, height: 260))
        webView.setValue(false, forKey: "drawsBackground")
        webView.loadHTMLString(styledReleaseNotesHTML(), baseURL: nil)
        return webView
    }

    private func styledReleaseNotesHTML() -> String {
        let bodyHTML: String
        if let releaseNotesHTML {
            bodyHTML = releaseNotesHTML
        } else if let itemDescription = currentUpdate?.itemDescription {
            bodyHTML = itemDescription
        } else {
            bodyHTML = "<p>\(Self.escapedHTML(String(localized: "update.ready.noReleaseNotes")))</p>"
        }

        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="color-scheme" content="light dark">
        <style>
        :root {
          color-scheme: light dark;
          font: -apple-system-body;
        }
        body {
          margin: 0;
          padding: 18px 20px;
          font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
          font-size: 13px;
          line-height: 1.46;
          color: CanvasText;
          background: Canvas;
        }
        h1, h2, h3 {
          margin: 0 0 12px;
          font-weight: 700;
          line-height: 1.25;
        }
        h1 { font-size: 20px; }
        h2 { font-size: 17px; }
        h3 { font-size: 14px; }
        p {
          margin: 0 0 10px;
        }
        ul, ol {
          margin: 0 0 12px 1.25em;
          padding: 0;
        }
        li {
          margin: 0 0 7px;
          padding-left: 0.15em;
        }
        a {
          color: -apple-system-control-accent;
        }
        code {
          font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
          font-size: 12px;
        }
        </style>
        </head>
        <body>
        \(bodyHTML)
        </body>
        </html>
        """
    }

    private static func escapedHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    #if DEBUG
    private static var shouldPreviewReadyUpdate: Bool {
        ProcessInfo.processInfo.arguments.contains("--preview-ready-update") ||
        ProcessInfo.processInfo.environment["POMODOROBAR_PREVIEW_READY_UPDATE"] == "1"
    }

    private static var shouldCheckForUpdatesNow: Bool {
        ProcessInfo.processInfo.arguments.contains("--check-for-updates-now") ||
        ProcessInfo.processInfo.environment["POMODOROBAR_CHECK_FOR_UPDATES_NOW"] == "1"
    }

    private func showDebugReadyUpdate() {
        debugReadyUpdateVersion = "1.0 RC"
        releaseNotesHTML = Self.localizedDebugReleaseNotesHTML
        readyUpdateTitle = String(localized: "update.ready.button")
    }

    private static var localizedDebugReleaseNotesHTML: String {
        let preferredLanguage = Bundle.main.preferredLocalizations.first ?? Locale.preferredLanguages.first ?? "en"
        if preferredLanguage.hasPrefix("zh") {
            return """
            <html>
            <body>
            <h2>PomodoroBar 1.0 RC</h2>
            <ul>
              <li>新增 Sparkle 自动更新支持。</li>
              <li>更新下载完成后，面板顶部中央显示蓝色更新按钮。</li>
              <li>点击更新按钮后，先显示完整 Release Note，再由用户决定安装或取消。</li>
              <li>主版和 Legacy 使用独立 appcast，避免互相串版本。</li>
            </ul>
            </body>
            </html>
            """
        }

        return """
        <html>
        <body>
        <h2>PomodoroBar 1.0 RC</h2>
        <ul>
          <li>Adds Sparkle automatic update support.</li>
          <li>Shows a blue update button in the top center after an update has downloaded.</li>
          <li>Lets users review the full release notes before installing or canceling.</li>
          <li>Keeps main and Legacy builds on separate appcasts to avoid cross-updates.</li>
        </ul>
        </body>
        </html>
        """
    }
    #endif
}

extension PomodoroAppUpdater: SPUUserDriver {
    func show(
        _ request: SPUUpdatePermissionRequest,
        reply: @escaping (SUUpdatePermissionResponse) -> Void
    ) {
        reply(SUUpdatePermissionResponse(
            automaticUpdateChecks: true,
            automaticUpdateDownloading: false,
            sendSystemProfile: false
        ))
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {}

    func showUpdateFound(
        with appcastItem: SUAppcastItem,
        state: SPUUserUpdateState,
        reply: @escaping (SPUUserUpdateChoice) -> Void
    ) {
        currentUpdate = appcastItem

        guard !appcastItem.isInformationOnlyUpdate else {
            reply(.dismiss)
            return
        }

        switch state.stage {
        case .notDownloaded:
            reply(.install)
        case .downloaded, .installing:
            storeReadyUpdate(appcastItem, reply: reply)
        @unknown default:
            reply(.dismiss)
        }
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {
        releaseNotesHTML = String(data: downloadData.data, encoding: .utf8)
    }

    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {}

    func showUpdateNotFoundWithError(
        _ error: any Error,
        acknowledgement: @escaping () -> Void
    ) {
        acknowledgement()
    }

    func showUpdaterError(
        _ error: any Error,
        acknowledgement: @escaping () -> Void
    ) {
        resetUpdateSession()
        acknowledgement()
    }

    func showDownloadInitiated(cancellation: @escaping () -> Void) {}

    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {}

    func showDownloadDidReceiveData(ofLength length: UInt64) {}

    func showDownloadDidStartExtractingUpdate() {}

    func showExtractionReceivedProgress(_ progress: Double) {}

    func showReady(
        toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void
    ) {
        storeReadyUpdate(currentUpdate, reply: reply)
    }

    func showInstallingUpdate(
        withApplicationTerminated applicationTerminated: Bool,
        retryTerminatingApplication: @escaping () -> Void
    ) {
        clearReadyUpdate()
    }

    func showUpdateInstalledAndRelaunched(
        _ relaunched: Bool,
        acknowledgement: @escaping () -> Void
    ) {
        resetUpdateSession()
        acknowledgement()
    }

    func dismissUpdateInstallation() {
        resetUpdateSession()
    }

    func showUpdateInFocus() {
        presentReadyUpdate()
    }
}
