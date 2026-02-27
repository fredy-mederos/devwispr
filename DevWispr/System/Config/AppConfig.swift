//
//  AppConfig.swift
//  DevWispr
//

import Foundation

enum AppConfig {
    static let defaultOpenAIBaseURL = "https://api.openai.com/v1"
    static let apiKeyURL = "https://platform.openai.com/api-keys"
    static let gitHubRepoOwner = "AugmentedMode"
    static let gitHubRepoName = "DevWispr"
    static let gitHubURL = "https://github.com/\(gitHubRepoOwner)/\(gitHubRepoName)"

    /// Minimum recording duration in milliseconds before audio is sent for
    /// transcription. Recordings shorter than this are silently discarded to
    /// prevent Whisper from hallucinating on near-empty audio.
    static let minimumRecordingDurationMs: Int = 1000

    /// Seconds of inactivity after recording stops before the audio engine
    /// is shut down to release the microphone indicator. Set to 0 to keep
    /// the engine always-on (disables napping).
    static let engineIdleTimeoutSeconds: TimeInterval = 15
}
