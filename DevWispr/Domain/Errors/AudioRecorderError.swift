//
//  AudioRecorderError.swift
//  DevWispr
//

import Foundation

enum AudioRecorderError: LocalizedError {
    case notRecording
    case noRecordingURL
    case engineNotReady

    var errorDescription: String? {
        switch self {
        case .notRecording:
            return String(localized: "Not recording")
        case .noRecordingURL:
            return String(localized: "No recording URL")
        case .engineNotReady:
            return String(localized: "Microphone not ready. The audio device may have changed — please try again.")
        }
    }
}
