//
//  UpdateCheckStatus.swift
//  DevWispr
//

enum UpdateCheckStatus {
    case idle        // "Check for Updates"
    case checking    // "Checking..."
    case upToDate    // "Up to Date" (resets to idle after 3s)
    case available   // "Update Available" (green text)
}
