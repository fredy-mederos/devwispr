//
//  TextInsertionError.swift
//  DevWispr
//

import Foundation

enum TextInsertionError: LocalizedError {
    case eventSourceCreationFailed
    case keyEventCreationFailed

    var errorDescription: String? {
        switch self {
        case .eventSourceCreationFailed:
            return String(localized: "Unable to create event source")
        case .keyEventCreationFailed:
            return String(localized: "Unable to create key events")
        }
    }
}
