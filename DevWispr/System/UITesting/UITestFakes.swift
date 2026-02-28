//
//  UITestFakes.swift
//  DevWispr
//

#if DEBUG
import Combine
import Foundation

final class UITestPermissionsManager: PermissionsManager {
    func requestMicrophoneAccess() async -> Bool { true }
    func requestAccessibilityAccess() async -> Bool { true }
    func hasMicrophoneAccess() -> Bool { true }
    func hasAccessibilityAccess() -> Bool { true }
}

final class UITestAudioRecorder: AudioRecorder {
    var isRecording: Bool { false }
    var isEngineRunning: Bool { false }
    var audioLevelPublisher: AnyPublisher<Double, Never> { Empty().eraseToAnyPublisher() }
    var recordingReadyPublisher: AnyPublisher<Void, Never> { Empty().eraseToAnyPublisher() }
    var recordingStoppedPublisher: AnyPublisher<Void, Never> { Empty().eraseToAnyPublisher() }
    func startEngine() throws {}
    func stopEngine() {}
    func startRecording() throws {}
    func stopRecording() throws -> URL { URL(fileURLWithPath: "/dev/null") }
}

final class UITestHotkeyManager: HotkeyManager {
    func registerHoldToTalk(handler: @escaping (Bool) -> Void) throws {}
    func registerToggle(handler: @escaping () -> Void) throws {}
    func updateToggleShortcut(_ binding: ShortcutBinding?) throws {}
    func updateHoldModifier(_ modifier: HoldModifierKey) {}
    func suspendToggle() {}
    func resumeToggle() {}
    func unregisterAll() {}
}

final class UITestTextInserter: TextInserter {
    func insertText(_ text: String) async throws {}
}

final class UITestHistoryStore: HistoryStore {
    private var items: [TranscriptItem] = []

    func add(_ item: TranscriptItem) throws {
        items.insert(item, at: 0)
    }

    func list(page: Int, pageSize: Int) throws -> [TranscriptItem] {
        paginate(items, page: page, pageSize: pageSize)
    }

    func search(query: String, page: Int, pageSize: Int) throws -> [TranscriptItem] {
        let filtered = items.filter { $0.text.localizedCaseInsensitiveContains(query) }
        return paginate(filtered, page: page, pageSize: pageSize)
    }

    func count(query: String) throws -> Int {
        query.isEmpty ? items.count : items.filter { $0.text.localizedCaseInsensitiveContains(query) }.count
    }

    func clearAll() throws {
        items.removeAll()
    }
}

final class UITestFailedRecordingStore: FailedRecordingStore {
    private var items: [FailedRecordingItem] = []

    func addFromTemporaryFile(sourceURL: URL, lastError: String) throws -> FailedRecordingItem {
        let item = FailedRecordingItem(
            audioFileName: sourceURL.lastPathComponent,
            fileSizeBytes: 0,
            durationSeconds: 0,
            lastError: lastError
        )
        items.insert(item, at: 0)
        return item
    }

    func list() throws -> [FailedRecordingItem] { items }
    func updateFailure(id: UUID, lastError: String) throws {}
    func delete(id: UUID) throws { items.removeAll { $0.id == id } }
    func deleteAll() throws { items.removeAll() }
    func url(for id: UUID) throws -> URL { URL(fileURLWithPath: "/dev/null") }
    func markResolved(id: UUID) throws { items.removeAll { $0.id == id } }
}

final class UITestAudioPlaybackService: AudioPlaybackService {
    var isPlaying: Bool = false
    var currentURL: URL?

    func play(url: URL) throws {
        currentURL = url
        isPlaying = true
    }

    func stop() {
        currentURL = nil
        isPlaying = false
    }
}

final class UITestUpdateChecker: UpdateChecker {
    func checkForUpdate() async throws -> UpdateInfo? { nil }
}
#endif
