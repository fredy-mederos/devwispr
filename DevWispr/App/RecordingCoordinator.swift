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
    private let failedRecordingStore: FailedRecordingStore
    private let permissionsManager: PermissionsManager
    private let analyticsService: AnalyticsService
    private weak var appState: AppState?
    private var processingTask: Task<Bool, Never>?
    private enum RecordingMode { case hold, toggle }
    private var recordingMode: RecordingMode?
    private var recordingStartTime: Date?

    private enum PipelineFailure: Error {
        case transcription(Error)
        case translation(Error)
        case insertion(Error)
        case persistence(Error)

        var underlyingError: Error {
            switch self {
            case .transcription(let error), .translation(let error), .insertion(let error), .persistence(let error):
                return error
            }
        }
    }

    init(
        audioRecorder: AudioRecorder,
        transcriptionService: TranscriptionService,
        translationUseCase: TranslationUseCase,
        textInserter: TextInserter,
        historyStore: HistoryStore,
        failedRecordingStore: FailedRecordingStore,
        permissionsManager: PermissionsManager,
        analyticsService: AnalyticsService
    ) {
        self.audioRecorder = audioRecorder
        self.transcriptionService = transcriptionService
        self.translationUseCase = translationUseCase
        self.textInserter = textInserter
        self.historyStore = historyStore
        self.failedRecordingStore = failedRecordingStore
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

        guard processingTask == nil else {
            debugLog("stopRecordingAndProcess ignored: processing already in progress")
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
                guard let self, let appState = self.appState else { return false }
                var shouldDeleteAudioFile = true
                defer {
                    if shouldDeleteAudioFile {
                        try? FileManager.default.removeItem(at: audioURL)
                    }
                    self.processingTask = nil
                }

                do {
                    try await self.runProcessingPipeline(audioURL: audioURL, autoTranslateToEnglish: autoTranslateToEnglish)

                    let totalDurationMs = capturedStartTime.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0
                    self.analyticsService.logEvent(.recordingCompleted(durationMs: totalDurationMs, mode: capturedMode))
                    return true
                } catch is CancellationError {
                    debugLog("Processing cancelled.")
                    if appState.status != .recording {
                        appState.status = .idle
                    }
                    return false
                } catch {
                    self.logPipelineFailureIfNeeded(error)
                    let errorMessage = self.userFacingErrorMessage(from: error)

                    do {
                        _ = try self.failedRecordingStore.addFromTemporaryFile(sourceURL: audioURL, lastError: errorMessage)
                        self.analyticsService.logEvent(.failedRecordingSaved)
                    } catch {
                        shouldDeleteAudioFile = false
                        debugLog("Failed to save failed recording: \(error)")
                    }

                    appState.status = .error
                    if shouldDeleteAudioFile {
                        appState.lastError = String(localized: "Processing failed: \(errorMessage)")
                    } else {
                        appState.lastError = String(localized: "Processing failed: \(errorMessage). Audio file kept at \(audioURL.path)")
                    }
                    debugLog("Processing failed: \(error)")
                    return false
                }
            }
        } catch {
            recordingMode = nil
            appState.status = .error
            appState.lastError = String(localized: "Failed to stop recording: \(error.localizedDescription)")
            debugLog("Failed to stop recording: \(error)")
        }
    }

    func retryFailedRecording(id: UUID) async -> Bool {
        guard processingTask == nil else {
            debugLog("retryFailedRecording ignored: processing already in progress")
            return false
        }
        guard !audioRecorder.isRecording else {
            debugLog("retryFailedRecording ignored: recording in progress")
            return false
        }
        guard let appState else { return false }

        analyticsService.logEvent(.failedRecordingRetryStarted)

        let task = Task { [weak self] in
            guard let self, let appState = self.appState else { return false }
            defer { self.processingTask = nil }

            do {
                let audioURL = try self.failedRecordingStore.url(for: id)
                try await self.runProcessingPipeline(audioURL: audioURL, autoTranslateToEnglish: appState.autoTranslateToEnglish)
                try self.failedRecordingStore.markResolved(id: id)
                self.analyticsService.logEvent(.failedRecordingRetrySucceeded)
                return true
            } catch is CancellationError {
                if appState.status != .recording {
                    appState.status = .idle
                }
                return false
            } catch {
                self.logPipelineFailureIfNeeded(error)
                let errorMessage = self.userFacingErrorMessage(from: error)
                try? self.failedRecordingStore.updateFailure(id: id, lastError: errorMessage)
                self.analyticsService.logEvent(.failedRecordingRetryFailed)

                appState.status = .error
                appState.lastError = String(localized: "Retry failed: \(errorMessage)")
                debugLog("Retry failed for failed recording \(id): \(error)")
                return false
            }
        }

        processingTask = task
        return await task.value
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
            appState.failedHistoryCount = try failedRecordingStore.list().count
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

    private func runProcessingPipeline(audioURL: URL, autoTranslateToEnglish: Bool) async throws {
        guard let appState else { return }

        appState.status = .transcribing

        let transcription: TranscriptionResult
        do {
            transcription = try await transcriptionService.transcribe(audioFileURL: audioURL)
        } catch {
            throw PipelineFailure.transcription(error)
        }
        try Task.checkCancellation()

        debugLog("Transcription complete. Input language: \(transcription.inputLanguage.code)")
        debugLog("Transcription text (first 120): \(String(transcription.text.prefix(120)))")
        analyticsService.logEvent(.transcriptionSucceeded(inputLanguage: transcription.inputLanguage.code))

        let finalText: String
        let outputLanguage: Language

        if autoTranslateToEnglish {
            appState.status = .translating
            do {
                let translation = try await translationUseCase.translateIfNeeded(
                    text: transcription.text,
                    inputLanguage: transcription.inputLanguage,
                    outputLanguage: .english
                )
                try Task.checkCancellation()
                debugLog("Translation complete. Output language: \(translation.outputLanguage.code)")
                debugLog("Translation text (first 120): \(String(translation.text.prefix(120)))")
                if transcription.inputLanguage == .english {
                    analyticsService.logEvent(.translationSkipped)
                } else {
                    analyticsService.logEvent(.translationTriggered(
                        from: transcription.inputLanguage.code,
                        to: translation.outputLanguage.code
                    ))
                }
                finalText = translation.text
                outputLanguage = .english
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                analyticsService.logEvent(.translationFailed(error: error.localizedDescription))
                throw PipelineFailure.translation(error)
            }
        } else {
            debugLog("Auto-translate disabled, skipping translation.")
            analyticsService.logEvent(.translationSkipped)
            finalText = transcription.text
            outputLanguage = transcription.inputLanguage
        }

        appState.status = .inserting
        let preferClipboard = appState.useClipboardOnly
        if !preferClipboard && permissionsManager.hasAccessibilityAccess() {
            debugLog("Accessibility granted. Inserting via paste.")
            do {
                try await textInserter.insertText(finalText)
                analyticsService.logEvent(.textInserted(method: "paste"))
            } catch {
                analyticsService.logEvent(.textInsertionFailed(error: error.localizedDescription))
                throw PipelineFailure.insertion(error)
            }
            debugLog("Paste insertion complete.")
        } else {
            debugLog("Copying to clipboard only (preferClipboard=\(preferClipboard)).")
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(finalText, forType: .string)
            analyticsService.logEvent(.textInserted(method: "clipboard"))
            if !preferClipboard {
                appState.lastError = String(localized: "Copied to clipboard. Enable Accessibility to auto-paste.")
            }
            debugLog("Clipboard copy complete.")
        }
        try Task.checkCancellation()

        do {
            try persistHistory(
                text: finalText,
                input: transcription.inputLanguage,
                output: outputLanguage
            )
        } catch {
            throw PipelineFailure.persistence(error)
        }

        debugLog("History persisted.")
        appState.lastOutput = finalText
        appState.status = .idle
        appState.lastError = nil
    }

    private func userFacingErrorMessage(from error: Error) -> String {
        switch error {
        case let pipelineFailure as PipelineFailure:
            return pipelineFailure.underlyingError.localizedDescription
        default:
            return error.localizedDescription
        }
    }

    private func logPipelineFailureIfNeeded(_ error: Error) {
        if let pipelineFailure = error as? PipelineFailure {
            switch pipelineFailure {
            case .translation, .insertion:
                return
            case .transcription, .persistence:
                break
            }
        }
        analyticsService.logEvent(.transcriptionFailed(error: userFacingErrorMessage(from: error)))
    }
}
