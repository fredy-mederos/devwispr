//
//  AnalyticsEvent.swift
//  DevWispr
//

import Foundation

enum AnalyticsEvent {
    // App lifecycle
    case appLaunched(version: String)

    // Recording pipeline
    case recordingStarted(mode: String)
    case recordingCompleted(durationMs: Int, mode: String)
    case recordingDiscarded(durationMs: Int)
    case transcriptionSucceeded(inputLanguage: String)
    case transcriptionFailed(error: String)
    case failedRecordingSaved
    case failedRecordingRetryStarted
    case failedRecordingRetrySucceeded
    case failedRecordingRetryFailed
    case failedRecordingPlaybackStarted
    case failedRecordingPlaybackStopped
    case failedRecordingDeleted
    case failedRecordingsCleared
    case translationTriggered(from: String, to: String)
    case translationSkipped
    case translationFailed(error: String)
    case textInserted(method: String)
    case textInsertionFailed(error: String)

    // Settings changes
    case autoTranslateToggled(enabled: Bool)
    case holdModifierKeyChanged(key: String)
    case toggleShortcutChanged
    case shortcutsToggled(enabled: Bool)
    case autoPasteToggled(enabled: Bool)
    case apiProviderChanged(provider: String)
    case launchAtLoginToggled(enabled: Bool)

    // User actions
    case historyOpened
    case historyCleared
    case updateCheckTriggered
    case updateAvailable(version: String)
    case permissionResult(type: String, granted: Bool)
    case apiKeyMissing

    var name: String {
        switch self {
        case .appLaunched: return "app_launched"
        case .recordingStarted: return "recording_started"
        case .recordingCompleted: return "recording_completed"
        case .recordingDiscarded: return "recording_discarded"
        case .transcriptionSucceeded: return "transcription_succeeded"
        case .transcriptionFailed: return "transcription_failed"
        case .failedRecordingSaved: return "failed_recording_saved"
        case .failedRecordingRetryStarted: return "failed_recording_retry_started"
        case .failedRecordingRetrySucceeded: return "failed_recording_retry_succeeded"
        case .failedRecordingRetryFailed: return "failed_recording_retry_failed"
        case .failedRecordingPlaybackStarted: return "failed_recording_playback_started"
        case .failedRecordingPlaybackStopped: return "failed_recording_playback_stopped"
        case .failedRecordingDeleted: return "failed_recording_deleted"
        case .failedRecordingsCleared: return "failed_recordings_cleared"
        case .translationTriggered: return "translation_triggered"
        case .translationSkipped: return "translation_skipped"
        case .translationFailed: return "translation_failed"
        case .textInserted: return "text_inserted"
        case .textInsertionFailed: return "text_insertion_failed"
        case .autoTranslateToggled: return "auto_translate_toggled"
        case .holdModifierKeyChanged: return "hold_modifier_key_changed"
        case .toggleShortcutChanged: return "toggle_shortcut_changed"
        case .shortcutsToggled: return "shortcuts_toggled"
        case .autoPasteToggled: return "auto_paste_toggled"
        case .apiProviderChanged: return "api_provider_changed"
        case .launchAtLoginToggled: return "launch_at_login_toggled"
        case .historyOpened: return "history_opened"
        case .historyCleared: return "history_cleared"
        case .updateCheckTriggered: return "update_check_triggered"
        case .updateAvailable: return "update_available"
        case .permissionResult: return "permission_result"
        case .apiKeyMissing: return "api_key_missing"
        }
    }

    var parameters: [String: Any] {
        switch self {
        case .appLaunched(let version):
            return ["version": version]
        case .recordingStarted(let mode):
            return ["mode": mode]
        case .recordingCompleted(let durationMs, let mode):
            return ["duration_ms": durationMs, "mode": mode]
        case .recordingDiscarded(let durationMs):
            return ["duration_ms": durationMs]
        case .transcriptionSucceeded(let inputLanguage):
            return ["input_language": inputLanguage]
        case .transcriptionFailed(let error):
            return ["error": error]
        case .failedRecordingSaved:
            return [:]
        case .failedRecordingRetryStarted:
            return [:]
        case .failedRecordingRetrySucceeded:
            return [:]
        case .failedRecordingRetryFailed:
            return [:]
        case .failedRecordingPlaybackStarted:
            return [:]
        case .failedRecordingPlaybackStopped:
            return [:]
        case .failedRecordingDeleted:
            return [:]
        case .failedRecordingsCleared:
            return [:]
        case .translationTriggered(let from, let to):
            return ["from_language": from, "to_language": to]
        case .translationSkipped:
            return [:]
        case .translationFailed(let error):
            return ["error": error]
        case .textInserted(let method):
            return ["method": method]
        case .textInsertionFailed(let error):
            return ["error": error]
        case .autoTranslateToggled(let enabled):
            return ["enabled": enabled]
        case .holdModifierKeyChanged(let key):
            return ["key": key]
        case .toggleShortcutChanged:
            return [:]
        case .shortcutsToggled(let enabled):
            return ["enabled": enabled]
        case .autoPasteToggled(let enabled):
            return ["enabled": enabled]
        case .apiProviderChanged(let provider):
            return ["provider": provider]
        case .launchAtLoginToggled(let enabled):
            return ["enabled": enabled]
        case .historyOpened, .historyCleared:
            return [:]
        case .updateCheckTriggered:
            return [:]
        case .updateAvailable(let version):
            return ["version": version]
        case .permissionResult(let type, let granted):
            return ["type": type, "granted": granted]
        case .apiKeyMissing:
            return [:]
        }
    }
}
