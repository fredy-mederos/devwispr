//
//  AppState.swift
//  DevWispr
//

import AppKit
import Combine
import Foundation


@MainActor
final class AppState: ObservableObject {
    enum RecordingMode { case hold, toggle }

    @Published var status: AppStatus = .idle
    @Published private(set) var recordingMode: RecordingMode?
    @Published var lastOutput: String = ""
    @Published var lastError: String? {
        didSet { scheduleErrorDismissal() }
    }
    @Published private(set) var audioLevel: Double = 0
    @Published private(set) var isAudioReady: Bool = false
    @Published var historyItems: [TranscriptItem] = []
    @Published var historyCount: Int = 0
    @Published var availableUpdate: UpdateInfo?
    @Published var updateCheckStatus: UpdateCheckStatus = .idle
    @Published var showMicrophoneSettings: Bool = false
    @Published var showAccessibilitySettings: Bool = false
    @Published var showApiKeySetup: Bool = false
    @Published var apiKeyInput: String = ""
    @Published var apiKeySource: APIKeySource = .none
    var apiKeySaved: Bool { apiKeySource != .none }
    @Published var autoTranslateToEnglish: Bool {
        didSet {
            settingsStore.autoTranslateToEnglish = autoTranslateToEnglish
            analyticsService.logEvent(.autoTranslateToggled(enabled: autoTranslateToEnglish))
            analyticsService.setUserProperty(.autoTranslateEnabled, value: String(autoTranslateToEnglish))
        }
    }
    @Published var apiProvider: APIProvider {
        didSet {
            settingsStore.apiProvider = apiProvider
            analyticsService.logEvent(.apiProviderChanged(provider: apiProvider.rawValue))
            analyticsService.setUserProperty(.apiProvider, value: apiProvider.rawValue)
        }
    }
    @Published var customBaseURL: String {
        didSet {
            settingsStore.customBaseURL = customBaseURL.isEmpty ? nil : customBaseURL
        }
    }
    @Published var customApiKeyURL: String {
        didSet {
            settingsStore.customApiKeyURL = customApiKeyURL.isEmpty ? nil : customApiKeyURL
        }
    }
    @Published var useClipboardOnly: Bool {
        didSet {
            settingsStore.useClipboardOnly = useClipboardOnly
            analyticsService.logEvent(.autoPasteToggled(enabled: !useClipboardOnly))
            analyticsService.setUserProperty(.autoPasteEnabled, value: String(!useClipboardOnly))
        }
    }
    @Published var currentToggleShortcut: ShortcutBinding?
    @Published var holdModifierKey: HoldModifierKey {
        didSet {
            settingsStore.holdModifierKey = holdModifierKey
            analyticsService.logEvent(.holdModifierKeyChanged(key: holdModifierKey.rawValue))
            if shortcutsEnabled {
                hotkeyManager.updateHoldModifier(holdModifierKey)
            }
        }
    }
    @Published var shortcutsEnabled: Bool {
        didSet {
            settingsStore.shortcutsEnabled = shortcutsEnabled
            analyticsService.logEvent(.shortcutsToggled(enabled: shortcutsEnabled))
            analyticsService.setUserProperty(.shortcutsEnabled, value: String(shortcutsEnabled))
            if shortcutsEnabled {
                configureHotkeys()
            } else {
                hotkeyManager.unregisterAll()
            }
        }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            guard !isSyncingLaunchAtLogin else { return }
            guard launchAtLogin != LoginItemService.isEnabled else { return }
            LoginItemService.setEnabled(launchAtLogin)
            analyticsService.logEvent(.launchAtLoginToggled(enabled: launchAtLogin))
        }
    }
    private var isSyncingLaunchAtLogin = false

    private let audioRecorder: AudioRecorder
    private let historyStore: HistoryStore
    private let permissionsManager: PermissionsManager
    private let hotkeyManager: HotkeyManager
    private let settingsStore: SettingsStore
    private let recordingCoordinator: RecordingCoordinator
    private let apiKeyManager: APIKeyManager
    private let updateChecker: UpdateChecker
    private let analyticsService: AnalyticsService
    private let historyWindowController: HistoryWindowController
    private var cancellables = Set<AnyCancellable>()
    private var errorDismissTask: Task<Void, Never>?
    private var updateCheckResetTask: Task<Void, Never>?

    init(container: AppContainer) {
        self.audioRecorder = container.audioRecorder
        self.historyStore = container.historyStore
        self.permissionsManager = container.permissionsManager
        self.hotkeyManager = container.hotkeyManager
        self.settingsStore = container.settingsStore
        self.apiProvider = container.settingsStore.apiProvider
        self.customBaseURL = container.settingsStore.customBaseURL ?? ""
        self.customApiKeyURL = container.settingsStore.customApiKeyURL ?? ""
        self.autoTranslateToEnglish = container.settingsStore.autoTranslateToEnglish
        self.useClipboardOnly = container.settingsStore.useClipboardOnly
        self.currentToggleShortcut = container.settingsStore.toggleShortcutBinding
        self.holdModifierKey = container.settingsStore.holdModifierKey
        self.shortcutsEnabled = container.settingsStore.shortcutsEnabled
        self.launchAtLogin = LoginItemService.isEnabled
        self.recordingCoordinator = container.recordingCoordinator
        self.apiKeyManager = container.apiKeyManager
        self.updateChecker = container.updateChecker
        self.analyticsService = container.analyticsService
        self.historyWindowController = container.historyWindowController

        recordingCoordinator.bind(to: self)
        apiKeyManager.bind(to: self)

        configureHotkeys()
        apiKeyManager.loadAPIKey()
        recordingCoordinator.loadHistory()

        Task { await self.requestAndRefreshPermissions() }

        audioRecorder.audioLevelPublisher
            .sink { [weak self] level in self?.audioLevel = level }
            .store(in: &cancellables)

        audioRecorder.recordingReadyPublisher
            .sink { [weak self] in self?.isAudioReady = true }
            .store(in: &cancellables)

        audioRecorder.recordingStoppedPublisher
            .sink { [weak self] in self?.isAudioReady = false }
            .store(in: &cancellables)

        // Set initial user properties (didSet doesn't fire during init)
        analyticsService.setUserProperty(.apiProvider, value: apiProvider.rawValue)
        analyticsService.setUserProperty(.autoPasteEnabled, value: String(!useClipboardOnly))
        analyticsService.setUserProperty(.shortcutsEnabled, value: String(shortcutsEnabled))
        analyticsService.setUserProperty(.autoTranslateEnabled, value: String(autoTranslateToEnglish))
    }

    private func configureHotkeys() {
        guard shortcutsEnabled else { return }
        do {
            try hotkeyManager.registerHoldToTalk { [weak self] isDown in
                Task { @MainActor in
                    if isDown {
                        await self?.startRecording()
                    } else {
                        self?.stopHoldRecording()
                    }
                }
            }

            try hotkeyManager.registerToggle { [weak self] in
                Task { @MainActor in
                    await self?.toggleRecording()
                }
            }

            if let binding = currentToggleShortcut {
                try hotkeyManager.updateToggleShortcut(binding)
            }
            hotkeyManager.updateHoldModifier(holdModifierKey)
        } catch {
            status = .error
            lastError = String(localized: "Hotkey registration failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Recording (forwarded to RecordingCoordinator)

    func toggleRecording() async {
        if status == .recording {
            recordingMode = nil
        } else {
            recordingMode = .toggle
        }
        await recordingCoordinator.toggleRecording()
    }

    func startRecording() async {
        recordingMode = .hold
        await recordingCoordinator.startRecording()
    }

    func stopRecordingAndProcess() {
        recordingMode = nil
        recordingCoordinator.stopRecordingAndProcess(autoTranslateToEnglish: autoTranslateToEnglish)
    }

    func stopHoldRecording() {
        recordingMode = nil
        recordingCoordinator.stopHoldRecording(autoTranslateToEnglish: autoTranslateToEnglish)
    }

    func insertLastOutput() async {
        await recordingCoordinator.insertLastOutput()
    }

    func cancelProcessing() {
        recordingMode = nil
        recordingCoordinator.cancelProcessing()
        if status != .recording {
            status = .idle
            lastError = nil
        }
    }

    // MARK: - API Key (forwarded to APIKeyManager)

    func reloadAPIKeyState() {
        apiKeyManager.loadAPIKey()
    }

    func ensureAPIKey() -> Bool {
        let result = apiKeyManager.ensureAPIKey()
        if !result {
            analyticsService.logEvent(.apiKeyMissing)
        }
        return result
    }

    func saveAPIKey() {
        apiKeyManager.saveAPIKey()
    }

    func showAPIKeySheet() {
        apiKeyManager.showAPIKeySheet()
    }

    func clearSavedAPIKey() {
        apiKeyManager.clearSavedAPIKey()
    }

    // MARK: - Updates

    func checkForUpdates(userInitiated: Bool = false) async {
        guard updateCheckStatus != .checking else { return }
        if userInitiated {
            analyticsService.logEvent(.updateCheckTriggered)
        }
        updateCheckStatus = .checking
        do {
            let result = try await updateChecker.checkForUpdate()
            if let result {
                let isNewDiscovery = availableUpdate?.latestVersion != result.latestVersion
                availableUpdate = result
                updateCheckStatus = .available
                if isNewDiscovery {
                    analyticsService.logEvent(.updateAvailable(version: result.latestVersion))
                }
            } else if availableUpdate != nil {
                // Throttled but we already know an update exists — keep showing it
                updateCheckStatus = .available
            } else {
                updateCheckStatus = .upToDate
                scheduleUpdateCheckReset()
            }
        } catch {
            debugLog("Update check failed: \(error.localizedDescription)")
            updateCheckStatus = .idle
        }
    }

    private func scheduleUpdateCheckReset() {
        updateCheckResetTask?.cancel()
        updateCheckResetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.updateCheckStatus = .idle
        }
    }

    // MARK: - Permissions

    /// Called at launch: requests microphone access (triggers system dialog on first run)
    /// and updates the permission warning flags based on the results.
    func requestAndRefreshPermissions() async {
        infoLog("requestAndRefreshPermissions() — start")
        let micGranted = await permissionsManager.requestMicrophoneAccess()
        let accessibilityGranted = permissionsManager.hasAccessibilityAccess()

        showMicrophoneSettings = !micGranted
        showAccessibilitySettings = !accessibilityGranted
        infoLog("requestAndRefreshPermissions() — micGranted=\(micGranted), accessibilityGranted=\(accessibilityGranted), showMicrophoneSettings=\(showMicrophoneSettings)")

        analyticsService.logEvent(.permissionResult(type: "microphone", granted: micGranted))
        analyticsService.logEvent(.permissionResult(type: "accessibility", granted: accessibilityGranted))
    }

    /// Re-checks permission status without prompting (safe to call when popover appears).
    func refreshPermissionStatus() {
        infoLog("refreshPermissionStatus() — start")
        let micGranted = permissionsManager.hasMicrophoneAccess()
        showMicrophoneSettings = !micGranted
        showAccessibilitySettings = !permissionsManager.hasAccessibilityAccess()
        infoLog("refreshPermissionStatus() — micGranted=\(micGranted), showMicrophoneSettings=\(showMicrophoneSettings)")
    }

    func ensurePermissions() async -> Bool {
        debugLog("Checking permissions...")
        var micGranted = permissionsManager.hasMicrophoneAccess()
        debugLog("Microphone access preflight: \(micGranted)")
        if !micGranted {
            debugLog("Requesting microphone access...")
            micGranted = await permissionsManager.requestMicrophoneAccess()
            debugLog("Microphone access result: \(micGranted)")
        }

        var accessibilityGranted = permissionsManager.hasAccessibilityAccess()
        debugLog("Accessibility access preflight: \(accessibilityGranted)")
        if !accessibilityGranted {
            debugLog("Requesting accessibility access...")
            accessibilityGranted = await permissionsManager.requestAccessibilityAccess()
            debugLog("Accessibility access result: \(accessibilityGranted)")
        }

        if !micGranted {
            status = .error
            lastError = String(localized: "Microphone permission is required.")
            showMicrophoneSettings = true
            return false
        }

        if !accessibilityGranted {
            lastError = String(localized: "Accessibility permission not granted. Will copy to clipboard only.")
            showAccessibilitySettings = true
        } else {
            showAccessibilitySettings = false
        }

        showMicrophoneSettings = false
        return true
    }

    // MARK: - Settings & Navigation

    func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func refreshLaunchAtLoginState() {
        syncLaunchAtLogin(LoginItemService.isEnabled)
    }

    /// Re-reads shortcut settings from the store. Call when the popover appears.
    func refreshShortcutsState() {
        currentToggleShortcut = settingsStore.toggleShortcutBinding
        let stored = settingsStore.holdModifierKey
        if stored != holdModifierKey {
            holdModifierKey = stored
        }
        let storedShortcutsEnabled = settingsStore.shortcutsEnabled
        if storedShortcutsEnabled != shortcutsEnabled {
            shortcutsEnabled = storedShortcutsEnabled
        }
    }

    /// Sets launchAtLogin without triggering the LoginItemService side effect.
    /// Use this for previews or other read-only sync scenarios.
    func syncLaunchAtLogin(_ value: Bool) {
        isSyncingLaunchAtLogin = true
        launchAtLogin = value
        isSyncingLaunchAtLogin = false
    }

    func openEnvSetupDocs() {
        if let urlString = settingsStore.resolvedApiKeyURL, let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    var hasApiKeyURL: Bool {
        settingsStore.resolvedApiKeyURL != nil
    }

    func resetToOpenAI() {
        apiProvider = .openAI
        customBaseURL = ""
        customApiKeyURL = ""
        clearSavedAPIKey()
        apiKeyInput = ""
    }

    var hasCustomShortcuts: Bool {
        currentToggleShortcut != nil || holdModifierKey != .control
    }

    func resetShortcuts() {
        updateToggleShortcut(nil)
        holdModifierKey = .control
    }

    func suspendHotkeys() {
        hotkeyManager.suspendToggle()
    }

    func resumeHotkeys() {
        hotkeyManager.resumeToggle()
    }

    func updateToggleShortcut(_ binding: ShortcutBinding?) {
        do {
            try hotkeyManager.updateToggleShortcut(binding)
            currentToggleShortcut = binding
            settingsStore.toggleShortcutBinding = binding
            analyticsService.logEvent(.toggleShortcutChanged)
        } catch {
            lastError = String(localized: "Failed to update shortcut: \(error.localizedDescription)")
            status = .error
        }
    }

    func openHistory() {
        analyticsService.logEvent(.historyOpened)
        historyWindowController.showWindow()
    }

    func reloadHistory() {
        recordingCoordinator.loadHistory()
    }

    func clearHistory() {
        do {
            try historyStore.clearAll()
            historyItems = []
            historyCount = 0
            analyticsService.logEvent(.historyCleared)
        } catch {
            lastError = String(localized: "Failed to clear history.")
            status = .error
        }
    }

    // MARK: - Error Auto-Dismissal

    private func scheduleErrorDismissal() {
        errorDismissTask?.cancel()
        guard lastError != nil else { return }
        errorDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.lastError = nil
            if self?.status == .error {
                self?.status = .idle
            }
        }
    }

}
