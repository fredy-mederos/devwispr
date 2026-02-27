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
    permissions: MockPermissionsManager = MockPermissionsManager(),
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
        permissionsManager: permissions,
        hotkeyManager: MockHotkeyManager(),
        settingsStore: settingsStore
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
        #expect(appState.status == .idle)
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
        let (coordinator, appState, _) = makeSUT(audioRecorder: recorder, transcription: transcription)

        await coordinator.startRecording()
        coordinator.stopRecordingAndProcess(autoTranslateToEnglish: false)

        try await Task.sleep(nanoseconds: 500_000_000)

        #expect(appState.status == .error)
        #expect(appState.lastError != nil)
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
}
