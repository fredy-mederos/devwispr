//
//  RecordingCoordinatorTests.swift
//  DevWisprTests
//

import Foundation
import Testing
@testable import DevWispr

// MARK: - Helpers

@MainActor
private func makeSUT(
    audioRecorder: MockAudioRecorder = MockAudioRecorder(),
    transcription: MockTranscriptionService = MockTranscriptionService(),
    translation: MockTranslationService = MockTranslationService(),
    textInserter: MockTextInserter = MockTextInserter(),
    historyStore: MockHistoryStore = MockHistoryStore(),
    failedRecordingStore: MockFailedRecordingStore = MockFailedRecordingStore(),
    permissions: MockPermissionsManager = MockPermissionsManager(),
    analytics: AnalyticsService = MockAnalyticsService(),
    apiKey: String? = "test-key"
) -> (RecordingCoordinator, AppState, MockAudioRecorder) {
    let settingsStore = MockSettingsStore()
    settingsStore.apiKey = apiKey

    let container = AppContainer(
        audioRecorder: audioRecorder,
        transcriptionService: transcription,
        translationService: translation,
        textInserter: textInserter,
        historyStore: historyStore,
        failedRecordingStore: failedRecordingStore,
        permissionsManager: permissions,
        hotkeyManager: MockHotkeyManager(),
        settingsStore: settingsStore,
        analyticsService: analytics
    )

    let appState = AppState(container: container)
    // RecordingCoordinator is bound inside AppState.init via container
    // We access it through the container to match production wiring.
    // AppState.init calls recordingCoordinator.bind(to: self), so binding is done.
    return (container.recordingCoordinator, appState, audioRecorder)
}

// MARK: - Tests

@Suite("RecordingCoordinator Tests")
struct RecordingCoordinatorTests {

    // MARK: startRecording

    @Test("startRecording sets status to recording when permissions and API key are available")
    @MainActor
    func startRecordingSetsRecordingStatus() async {
        let (coordinator, appState, _) = makeSUT()
        await coordinator.startRecording()
        #expect(appState.status == .recording)
    }

    @Test("startRecording calls audioRecorder.startRecording exactly once")
    @MainActor
    func startRecordingCallsAudioRecorder() async {
        let recorder = MockAudioRecorder()
        let (coordinator, _, _) = makeSUT(audioRecorder: recorder)
        await coordinator.startRecording()
        #expect(recorder.startRecordingCallCount == 1)
    }

    @Test("startRecording does nothing when no API key is set")
    @MainActor
    func startRecordingNoAPIKey() async {
        let (coordinator, appState, recorder) = makeSUT(apiKey: nil)
        await coordinator.startRecording()
        #expect(appState.status == .error)
        #expect(recorder.startRecordingCallCount == 0)
    }

    @Test("startRecording does nothing when already recording")
    @MainActor
    func startRecordingWhileAlreadyRecording() async {
        let recorder = MockAudioRecorder()
        let (coordinator, _, _) = makeSUT(audioRecorder: recorder)
        await coordinator.startRecording()
        let countAfterFirst = recorder.startRecordingCallCount
        await coordinator.startRecording()
        #expect(recorder.startRecordingCallCount == countAfterFirst)
    }

    @Test("startRecording sets error status when audioRecorder throws")
    @MainActor
    func startRecordingAudioRecorderThrows() async {
        let recorder = MockAudioRecorder()
        recorder.shouldThrow = AudioRecorderError.engineNotReady
        let (coordinator, appState, _) = makeSUT(audioRecorder: recorder)
        await coordinator.startRecording()
        #expect(appState.status == .error)
        #expect(appState.lastError != nil)
    }

    @Test("startRecording shows restart guidance for CoreAudio format error -10868")
    @MainActor
    func startRecordingCoreAudio10868ShowsFriendlyMessage() async {
        let recorder = MockAudioRecorder()
        recorder.shouldThrow = NSError(
            domain: "com.apple.coreaudio.avaudio",
            code: -10868,
            userInfo: [NSLocalizedDescriptionKey: "The operation couldn’t be completed."]
        )
        let (coordinator, appState, _) = makeSUT(audioRecorder: recorder)

        await coordinator.startRecording()

        #expect(appState.status == .error)
        #expect(appState.lastError == "Error initializing recording. Please restart DevWispr and try again.")
    }

    @Test("startRecording logs audio diagnostics for CoreAudio format error -10868")
    @MainActor
    func startRecordingCoreAudio10868LogsAudioDiagnostics() async {
        let recorder = MockAudioRecorder()
        recorder.diagnostics = AudioInputDiagnostics(deviceName: "Test BT Headset", sampleRateHz: 16_000, channelCount: 1)
        recorder.shouldThrow = NSError(
            domain: "com.apple.coreaudio.avaudio",
            code: -10868,
            userInfo: [NSLocalizedDescriptionKey: "The operation couldn’t be completed."]
        )
        let analytics = MockAnalyticsService()
        let (coordinator, _, _) = makeSUT(audioRecorder: recorder, analytics: analytics)

        await coordinator.startRecording()

        let event = analytics.loggedEvents.first { $0.name == "recording_start_coreaudio_format_error" }
        #expect(event != nil)
        if case let .some(.recordingStartCoreAudioFormatError(
            errorCode,
            errorDomain,
            inputDevice,
            inputSampleRateHz,
            inputChannelCount
        )) = event {
            #expect(errorCode == -10868)
            #expect(errorDomain == "com.apple.coreaudio.avaudio")
            #expect(inputDevice == "Test BT Headset")
            #expect(inputSampleRateHz == 16_000)
            #expect(inputChannelCount == 1)
        } else {
            Issue.record("Expected recording_start_coreaudio_format_error event")
        }
    }

    // MARK: stopRecordingAndProcess

    @Test("stopRecordingAndProcess runs full pipeline and ends at idle with lastOutput set")
    @MainActor
    func fullPipelineSucceeds() async throws {
        let recorder = MockAudioRecorder()
        let transcription = MockTranscriptionService()
        transcription.result = TranscriptionResult(text: "hello world", inputLanguage: .english)
        let (coordinator, appState, _) = makeSUT(audioRecorder: recorder, transcription: transcription)

        await coordinator.startRecording()
        #expect(appState.status == .recording)
        try await Task.sleep(nanoseconds: 1_100_000_000)

        coordinator.stopRecordingAndProcess(autoTranslateToEnglish: false)

        // Wait for the async processing task to finish
        try await Task.sleep(nanoseconds: 500_000_000)

        #expect(appState.status == .idle)
        #expect(appState.lastOutput.isEmpty == false)
        #expect(appState.lastError == nil)
    }

    @Test("stopRecordingAndProcess sets error when transcription fails")
    @MainActor
    func pipelineTranscriptionFailure() async throws {
        let recorder = MockAudioRecorder()
        let transcription = MockTranscriptionService()
        transcription.shouldThrow = URLError(.badServerResponse)
        let failedStore = MockFailedRecordingStore()
        let (coordinator, appState, _) = makeSUT(
            audioRecorder: recorder,
            transcription: transcription,
            failedRecordingStore: failedStore
        )

        await coordinator.startRecording()
        try await Task.sleep(nanoseconds: 1_100_000_000)
        coordinator.stopRecordingAndProcess(autoTranslateToEnglish: false)

        try await Task.sleep(nanoseconds: 500_000_000)

        #expect(appState.status == .error)
        #expect(appState.lastError != nil)
        #expect(failedStore.addCallCount == 1)
    }

    @Test("stopRecordingAndProcess does nothing when not recording")
    @MainActor
    func stopWhenNotRecording() {
        let transcription = MockTranscriptionService()
        let (coordinator, appState, _) = makeSUT(transcription: transcription)
        coordinator.stopRecordingAndProcess(autoTranslateToEnglish: false)
        #expect(appState.status == .idle)
        #expect(transcription.transcribeCallCount == 0)
    }

    // MARK: stopHoldRecording

    @Test("stopHoldRecording is ignored when session was started by toggle")
    @MainActor
    func stopHoldIgnoredInToggleSession() async {
        let recorder = MockAudioRecorder()
        let (coordinator, appState, _) = makeSUT(audioRecorder: recorder)

        await coordinator.toggleRecording()  // starts toggle session
        coordinator.stopHoldRecording(autoTranslateToEnglish: false)

        // Still recording — hold stop was ignored
        #expect(recorder.isRecording == true)
        #expect(appState.status == .recording)
    }

    // MARK: cancelProcessing

    @Test("cancelProcessing while processing returns status to idle")
    @MainActor
    func cancelProcessingReturnsIdle() async throws {
        let recorder = MockAudioRecorder()
        let transcription = MockTranscriptionService()
        // Make transcription slow so we can cancel before it finishes
        transcription.shouldThrow = CancellationError()
        let (coordinator, appState, _) = makeSUT(audioRecorder: recorder, transcription: transcription)

        await coordinator.startRecording()
        coordinator.stopRecordingAndProcess(autoTranslateToEnglish: false)
        coordinator.cancelProcessing()

        try await Task.sleep(nanoseconds: 200_000_000)

        #expect(appState.status == .idle)
    }

    @Test("retryFailedRecording succeeds and removes failed item")
    @MainActor
    func retryFailedRecordingSuccess() async throws {
        let recorder = MockAudioRecorder()
        let transcription = MockTranscriptionService()
        transcription.result = TranscriptionResult(text: "retried text", inputLanguage: .english)
        let failedStore = MockFailedRecordingStore()
        let failed = FailedRecordingItem(
            audioFileName: "retry.wav",
            fileSizeBytes: 1200,
            durationSeconds: 3,
            lastError: "network"
        )
        failedStore.items = [failed]
        let (coordinator, appState, _) = makeSUT(
            audioRecorder: recorder,
            transcription: transcription,
            failedRecordingStore: failedStore
        )

        let didSucceed = await coordinator.retryFailedRecording(id: failed.id)

        #expect(didSucceed == true)
        #expect(failedStore.markResolvedCallCount == 1)
        #expect(appState.status == .idle)
        #expect(appState.lastOutput == "retried text")
    }

    @Test("retryFailedRecording failure updates existing failed item")
    @MainActor
    func retryFailedRecordingFailure() async throws {
        let recorder = MockAudioRecorder()
        let transcription = MockTranscriptionService()
        transcription.shouldThrow = URLError(.cannotConnectToHost)
        let failedStore = MockFailedRecordingStore()
        let failed = FailedRecordingItem(
            audioFileName: "retry.wav",
            fileSizeBytes: 1200,
            durationSeconds: 3,
            lastError: "old"
        )
        failedStore.items = [failed]
        let (coordinator, appState, _) = makeSUT(
            audioRecorder: recorder,
            transcription: transcription,
            failedRecordingStore: failedStore
        )

        let didSucceed = await coordinator.retryFailedRecording(id: failed.id)

        #expect(didSucceed == false)
        #expect(failedStore.updateFailureCallCount == 1)
        #expect(failedStore.markResolvedCallCount == 0)
        #expect(appState.status == .error)
        #expect(appState.lastError != nil)
    }

    @Test("retryFailedRecording is ignored while processing is active")
    @MainActor
    func retryIgnoredWhileProcessing() async throws {
        let recorder = MockAudioRecorder()
        let transcription = MockTranscriptionService()
        transcription.delayNanoseconds = 700_000_000
        transcription.result = TranscriptionResult(text: "done", inputLanguage: .english)
        let failedStore = MockFailedRecordingStore()
        let failed = FailedRecordingItem(
            audioFileName: "retry.wav",
            fileSizeBytes: 1200,
            durationSeconds: 3,
            lastError: "old"
        )
        failedStore.items = [failed]

        let (coordinator, _, _) = makeSUT(
            audioRecorder: recorder,
            transcription: transcription,
            failedRecordingStore: failedStore
        )

        await coordinator.startRecording()
        try await Task.sleep(nanoseconds: 1_100_000_000)
        coordinator.stopRecordingAndProcess(autoTranslateToEnglish: false)

        let didSucceed = await coordinator.retryFailedRecording(id: failed.id)

        #expect(didSucceed == false)
        #expect(failedStore.markResolvedCallCount == 0)
        #expect(failedStore.updateFailureCallCount == 0)
    }
}
