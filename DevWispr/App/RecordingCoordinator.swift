//
//  RecordingCoordinator.swift
//  DevWispr
//

import AppKit
import Foundation

@MainActor
final class RecordingCoordinator {
    private let audioRecorder: AudioRecorder
    private let transcriptionService: TranscriptionService
    private let translationUseCase: TranslationUseCase
    private let textInserter: TextInserter
    private let historyStore: HistoryStore
    private let permissionsManager: PermissionsManager
    private let analyticsService: AnalyticsService
    private weak var appState: AppState?
    private var processingTask: Task<Void, Never>?
    private enum RecordingMode { case hold, toggle }
    private var recordingMode: RecordingMode?
    private var recordingStartTime: Date?

    init(
        audioRecorder: AudioRecorder,
        transcriptionService: TranscriptionService,
        translationUseCase: TranslationUseCase,
        textInserter: TextInserter,
        historyStore: HistoryStore,
        permissionsManager: PermissionsManager,
        analyticsService: AnalyticsService
    ) {
        self.audioRecorder = audioRecorder
        self.transcriptionService = transcriptionService
        self.translationUseCase = translationUseCase
        self.textInserter = textInserter
        self.historyStore = historyStore
        self.permissionsManager = permissionsManager
        self.analyticsService = analyticsService
    }

    func bind(to appState: AppState) {
        self.appState = appState
    }

    // MARK: - Recording Pipeline

    func toggleRecording() async {
        if audioRecorder.isRecording {
            // Only allow toggle to stop a toggle-started session.
            // A hold-to-talk session must be stopped by releasing the hold key.
            guard recordingMode == .toggle else {
                debugLog("toggleRecording() ignored: hold-to-talk session is active")
                return
            }
            stopRecordingAndProcess(autoTranslateToEnglish: appState?.autoTranslateToEnglish ?? false)
        } else {
            await startRecording(mode: .toggle)
        }
    }

    func startRecording() async {
        await startRecording(mode: .hold)
    }

    private func startRecording(mode: RecordingMode) async {
        // Ignore if already recording — don't interrupt an active session.
        guard !audioRecorder.isRecording else {
            debugLog("startRecording(\(mode)) ignored: already recording")
            return
        }
        // Ignore if a processing pipeline (transcribe/translate/insert) is still running.
        guard processingTask == nil else {
            debugLog("startRecording(\(mode)) ignored: processing in progress")
            return
        }
        cancelProcessing()
        guard let appState else { return }

        debugLog("Record requested (mode=\(mode)). isRecording=\(audioRecorder.isRecording)")
        if let bundleId = Bundle.main.bundleIdentifier {
            debugLog("Bundle ID: \(bundleId)")
        }
        let micUsage = Bundle.main.infoDictionary?["NSMicrophoneUsageDescription"] as? String
        debugLog("NSMicrophoneUsageDescription present: \(micUsage != nil)")

        guard appState.ensureAPIKey() else { return }
        guard await appState.ensurePermissions() else { return }

        do {
            try audioRecorder.startRecording()
            recordingMode = mode
            recordingStartTime = Date()
            appState.status = .recording
            appState.lastError = nil
            analyticsService.logEvent(.recordingStarted(mode: mode == .hold ? "hold" : "toggle"))
        } catch {
            appState.status = .error
            appState.lastError = String(localized: "Failed to start recording: \(error.localizedDescription)")
            debugLog("Failed to start recording: \(error)")
        }
    }

    /// Stop recording only if it was started via hold-to-talk.
    /// Prevents the hold key-release from interrupting a toggle-started session.
    func stopHoldRecording(autoTranslateToEnglish: Bool) {
        guard recordingMode == .hold else {
            debugLog("stopHoldRecording() ignored: session was not started by hold")
            return
        }
        stopRecordingAndProcess(autoTranslateToEnglish: autoTranslateToEnglish)
    }

    func stopRecordingAndProcess(autoTranslateToEnglish: Bool) {
        guard audioRecorder.isRecording else { return }
        guard let appState else { return }

        // Discard recordings that are too short to produce meaningful output.
        // Whisper tends to hallucinate on near-empty audio clips.
        let minDuration = TimeInterval(AppConfig.minimumRecordingDurationMs) / 1000.0
        let elapsed = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        if elapsed < minDuration {
            debugLog("Recording too short (\\(String(format: \"%.0f\", elapsed * 1000)) ms < \\(AppConfig.minimumRecordingDurationMs) ms) — discarding silently")
            if let url = try? audioRecorder.stopRecording() {
                try? FileManager.default.removeItem(at: url)
            }
            analyticsService.logEvent(.recordingDiscarded(durationMs: Int(elapsed * 1000)))
            recordingMode = nil
            recordingStartTime = nil
            appState.status = .idle
            return
        }

        let capturedMode = recordingMode == .hold ? "hold" : "toggle"
        let capturedStartTime = recordingStartTime

        do {
            let audioURL = try audioRecorder.stopRecording()
            recordingMode = nil
            recordingStartTime = nil
            appState.status = .transcribing
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? Int) ?? 0
            debugLog("Stopped recording. Audio URL: \(audioURL.lastPathComponent), size: \(fileSize) bytes (\(fileSize / 1024) KB)")

            processingTask = Task { [weak self] in
                guard let self, let appState = self.appState else { return }
                defer {
                    try? FileManager.default.removeItem(at: audioURL)
                    self.processingTask = nil
                }

                var didLogSpecificError = false
                do {
                    let transcription = try await self.transcriptionService.transcribe(audioFileURL: audioURL)
                    try Task.checkCancellation()
                    debugLog("Transcription complete. Input language: \(transcription.inputLanguage.code)")
                    debugLog("Transcription text (first 120): \(String(transcription.text.prefix(120)))")
                    self.analyticsService.logEvent(.transcriptionSucceeded(inputLanguage: transcription.inputLanguage.code))

                    let finalText: String
                    let outputLanguage: Language

                    if autoTranslateToEnglish {
                        appState.status = .translating
                        do {
                            let translation = try await self.translationUseCase.translateIfNeeded(
                                text: transcription.text,
                                inputLanguage: transcription.inputLanguage,
                                outputLanguage: .english
                            )
                            try Task.checkCancellation()
                            debugLog("Translation complete. Output language: \(translation.outputLanguage.code)")
                            debugLog("Translation text (first 120): \(String(translation.text.prefix(120)))")
                            if transcription.inputLanguage == .english {
                                self.analyticsService.logEvent(.translationSkipped)
                            } else {
                                self.analyticsService.logEvent(.translationTriggered(
                                    from: transcription.inputLanguage.code,
                                    to: translation.outputLanguage.code
                                ))
                            }
                            finalText = translation.text
                            outputLanguage = .english
                        } catch is CancellationError {
                            throw CancellationError()
                        } catch {
                            self.analyticsService.logEvent(.translationFailed(error: error.localizedDescription))
                            didLogSpecificError = true
                            throw error
                        }
                    } else {
                        debugLog("Auto-translate disabled, skipping translation.")
                        self.analyticsService.logEvent(.translationSkipped)
                        finalText = transcription.text
                        outputLanguage = transcription.inputLanguage
                    }

                    appState.status = .inserting
                    let preferClipboard = appState.useClipboardOnly
                    if !preferClipboard && self.permissionsManager.hasAccessibilityAccess() {
                        debugLog("Accessibility granted. Inserting via paste.")
                        do {
                            try await self.textInserter.insertText(finalText)
                            self.analyticsService.logEvent(.textInserted(method: "paste"))
                        } catch {
                            self.analyticsService.logEvent(.textInsertionFailed(error: error.localizedDescription))
                            didLogSpecificError = true
                            throw error
                        }
                        debugLog("Paste insertion complete.")
                    } else {
                        debugLog("Copying to clipboard only (preferClipboard=\(preferClipboard)).")
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(finalText, forType: .string)
                        self.analyticsService.logEvent(.textInserted(method: "clipboard"))
                        if !preferClipboard {
                            appState.lastError = String(localized: "Copied to clipboard. Enable Accessibility to auto-paste.")
                        }
                        debugLog("Clipboard copy complete.")
                    }
                    try Task.checkCancellation()

                    try self.persistHistory(
                        text: finalText,
                        input: transcription.inputLanguage,
                        output: outputLanguage
                    )
                    debugLog("History persisted.")
                    appState.lastOutput = finalText
                    appState.status = .idle
                    appState.lastError = nil

                    let totalDurationMs = capturedStartTime.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0
                    self.analyticsService.logEvent(.recordingCompleted(durationMs: totalDurationMs, mode: capturedMode))
                } catch is CancellationError {
                    debugLog("Processing cancelled.")
                    if appState.status != .recording {
                        appState.status = .idle
                    }
                } catch {
                    if !didLogSpecificError {
                        self.analyticsService.logEvent(.transcriptionFailed(error: error.localizedDescription))
                    }
                    appState.status = .error
                    appState.lastError = String(localized: "Processing failed: \(error.localizedDescription)")
                    debugLog("Processing failed: \(error)")
                }
            }
        } catch {
            recordingMode = nil
            appState.status = .error
            appState.lastError = String(localized: "Failed to stop recording: \(error.localizedDescription)")
            debugLog("Failed to stop recording: \(error)")
        }
    }

    // MARK: - Cancellation

    func cancelProcessing() {
        processingTask?.cancel()
        processingTask = nil
    }

    // MARK: - Re-insert

    func insertLastOutput() async {
        guard let appState, !appState.lastOutput.isEmpty else { return }
        do {
            appState.status = .inserting
            try await textInserter.insertText(appState.lastOutput)
            appState.status = .idle
            appState.lastError = nil
        } catch {
            appState.status = .error
            appState.lastError = String(localized: "Paste failed: \(error.localizedDescription)")
        }
    }

    // MARK: - History

    func loadHistory() {
        guard let appState else { return }
        do {
            appState.historyItems = try historyStore.list(page: 0, pageSize: 1)
            appState.historyCount = try historyStore.count(query: "")
        } catch {
            appState.lastError = String(localized: "Failed to load history.")
            appState.status = .error
        }
    }

    private func persistHistory(text: String, input: Language, output: Language) throws {
        let app = NSWorkspace.shared.frontmostApplication
        let item = TranscriptItem(
            text: text,
            inputLanguage: input,
            outputLanguage: output,
            appBundleId: app?.bundleIdentifier,
            appName: app?.localizedName
        )
        try historyStore.add(item)
        loadHistory()
    }
}
