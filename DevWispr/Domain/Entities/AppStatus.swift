//
//  AppStatus.swift
//  DevWispr
//

import Foundation

enum AppStatus: String {
    case idle = "Idle"
    case recording = "Recording"
    case transcribing = "Transcribing"
    case translating = "Translating"
    case inserting = "Inserting"
    case error = "Error"

    var localizedName: String {
        switch self {
        case .idle:         return String(localized: "Idle")
        case .recording:    return String(localized: "Recording")
        case .transcribing: return String(localized: "Transcribing")
        case .translating:  return String(localized: "Translating")
        case .inserting:    return String(localized: "Inserting")
        case .error:        return String(localized: "Error")
        }
    }
}
