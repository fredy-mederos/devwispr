//
//  AppDelegate.swift
//  DevWispr
//

import AppKit
import FirebaseCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var popoverController: PopoverController?
    private var cursorIndicatorController: CursorIndicatorController?
    private var container: AppContainer?
    private var appState: AppState?

    #if DEBUG
    static let isUITesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
    private var uiTestWindowController: UITestWindowController?
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if Self.isUITesting {
            launchForUITesting()
            return
        }
        #endif

        FirebaseApp.configure()

        let container = AppContainer()
        let appState = AppState(container: container)
        self.container = container
        self.appState = appState

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        container.analyticsService.logEvent(.appLaunched(version: appVersion))

        popoverController = PopoverController(appState: appState)
        cursorIndicatorController = CursorIndicatorController(
            appState: appState,
            soundFeedback: container.soundFeedbackService
        )

        // Check for updates after a short delay
        Task {
            try? await Task.sleep(for: .seconds(5))
            await appState.checkForUpdates()
        }

        // Register for URL events
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString),
              let appState else { return }
        DeepLinkHandler.handle(url, appState: appState)
    }

    // MARK: - UI Testing

    #if DEBUG
    private func launchForUITesting() {
        let suiteName = "com.devwispr.uitesting"
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        let testDefaults = UserDefaults(suiteName: suiteName)!
        let settingsStore = UserDefaultsSettingsStore(defaults: testDefaults)

        // Pre-configure an API key so popover tests start in a configured state
        settingsStore.apiKey = "sk-ui-test-key"

        // Handle custom provider launch argument
        if ProcessInfo.processInfo.arguments.contains("--ui-test-custom-provider") {
            settingsStore.apiProvider = .custom
            settingsStore.customBaseURL = "https://custom.example.com/v1"
            settingsStore.customApiKeyURL = "https://custom.example.com/keys"
        }

        let container = AppContainer(
            audioRecorder: UITestAudioRecorder(),
            transcriptionService: FakeTranscriptionService(),
            translationService: FakeTranslationService(),
            textInserter: UITestTextInserter(),
            historyStore: UITestHistoryStore(),
            failedRecordingStore: UITestFailedRecordingStore(),
            permissionsManager: UITestPermissionsManager(),
            hotkeyManager: UITestHotkeyManager(),
            settingsStore: settingsStore,
            audioPlaybackService: UITestAudioPlaybackService(),
            updateChecker: UITestUpdateChecker()
        )

        let appState = AppState(container: container)
        self.container = container
        self.appState = appState

        // Show popover content in a regular window (XCUITest can't click status items)
        let windowController = UITestWindowController(appState: appState)
        windowController.showWindow()
        self.uiTestWindowController = windowController

    }
    #endif

}
