//
//  Protocols.swift
//  DevWispr
//

import AppKit
import Combine
import Foundation

protocol AudioRecorder {
    func startEngine() throws
    func stopEngine()
    func startRecording() throws
    func stopRecording() throws -> URL
    var isRecording: Bool { get }
    /// Whether the audio engine is currently running (microphone is active).
    var isEngineRunning: Bool { get }
    /// Emits the current RMS audio level (0–1) on the main thread while recording.
    var audioLevelPublisher: AnyPublisher<Double, Never> { get }
    /// Fires once on the main thread when the first audio buffer is captured after `startRecording()`.
    var recordingReadyPublisher: AnyPublisher<Void, Never> { get }
    /// Fires once on the main thread when recording stops.
    var recordingStoppedPublisher: AnyPublisher<Void, Never> { get }
}

protocol TranscriptionService {
    func transcribe(audioFileURL: URL) async throws -> TranscriptionResult
}

protocol TranslationService {
    func translate(text: String, to outputLanguage: Language) async throws -> TranslationResult
}

protocol HistoryStore {
    func add(_ item: TranscriptItem) throws
    func list(page: Int, pageSize: Int) throws -> [TranscriptItem]
    func search(query: String, page: Int, pageSize: Int) throws -> [TranscriptItem]
    func count(query: String) throws -> Int
    func clearAll() throws
}

protocol FailedRecordingStore {
    func addFromTemporaryFile(sourceURL: URL, lastError: String) throws -> FailedRecordingItem
    func list() throws -> [FailedRecordingItem]
    func updateFailure(id: UUID, lastError: String) throws
    func delete(id: UUID) throws
    func deleteAll() throws
    func url(for id: UUID) throws -> URL
    func markResolved(id: UUID) throws
}

extension HistoryStore {
    func paginate(_ items: [TranscriptItem], page: Int, pageSize: Int) -> [TranscriptItem] {
        guard pageSize > 0 else { return [] }
        let start = page * pageSize
        guard start < items.count else { return [] }
        let end = min(items.count, start + pageSize)
        return Array(items[start..<end])
    }
}

protocol HotkeyManager {
    func registerHoldToTalk(handler: @escaping (Bool) -> Void) throws
    func registerToggle(handler: @escaping () -> Void) throws
    func updateToggleShortcut(_ binding: ShortcutBinding?) throws
    func updateHoldModifier(_ modifier: HoldModifierKey)
    /// Temporarily disables the toggle hotkey (e.g. while a shortcut recorder is active).
    func suspendToggle()
    /// Re-enables the toggle hotkey after a suspension.
    func resumeToggle()
    func unregisterAll()
}

protocol TextInserter {
    func insertText(_ text: String) async throws
}

protocol PermissionsManager {
    func requestMicrophoneAccess() async -> Bool
    func requestAccessibilityAccess() async -> Bool
    func hasMicrophoneAccess() -> Bool
    func hasAccessibilityAccess() -> Bool
}

protocol SettingsStore: AnyObject {
    var toggleShortcutBinding: ShortcutBinding? { get set }
    var holdModifierKey: HoldModifierKey { get set }
    var shortcutsEnabled: Bool { get set }
    var autoTranslateToEnglish: Bool { get set }
    var useClipboardOnly: Bool { get set }
    var apiKey: String? { get set }
    var apiProvider: APIProvider { get set }
    var customBaseURL: String? { get set }
    var customApiKeyURL: String? { get set }
    func resetShortcuts()
}

extension SettingsStore {
    var resolvedApiKeyURL: String? {
        switch apiProvider {
        case .openAI:
            return APIProvider.openAI.apiKeyURL
        case .custom:
            return customApiKeyURL
        }
    }
}

protocol LanguageDetector {
    func detectLanguage(for text: String) -> Language?
}

protocol TranslationUseCase {
    func translateIfNeeded(text: String, inputLanguage: Language, outputLanguage: Language) async throws -> TranslationResult
}

protocol SoundFeedbackService {
    func playRecordingStarted()
}

protocol AudioPlaybackService {
    func play(url: URL) throws
    func stop()
    var isPlaying: Bool { get }
    var currentURL: URL? { get }
}

protocol UpdateChecker {
    func checkForUpdate() async throws -> UpdateInfo?
}

protocol AnalyticsService {
    func logEvent(_ event: AnalyticsEvent)
    func setUserProperty(_ property: AnalyticsUserProperty, value: String?)
}
