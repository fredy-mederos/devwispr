//
//  WisprTheme.swift
//  DevWispr
//

import AppKit
import SwiftUI

enum WisprTheme {
    // MARK: - Background
    static let background = Color(red: 0.102, green: 0.102, blue: 0.176)       // #1a1a2e
    static let backgroundNS = NSColor(red: 0.102, green: 0.102, blue: 0.176, alpha: 1)
    static let cardBackground = Color(red: 0.145, green: 0.145, blue: 0.251)   // #252540
    static let cardBorder = Color.white.opacity(0.07)
    static let divider = Color.white.opacity(0.08)

    // MARK: - Text
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary = Color.white.opacity(0.35)

    // MARK: - Status / Accent
    static let statusOK = Color(red: 0.2, green: 0.85, blue: 0.45)             // vivid green
    static let statusWarning = Color.orange
    static let statusRecording = Color(red: 0.25, green: 0.6, blue: 1.0)       // system blue-ish
    static let statusError = Color.red
    static let settingsAccent = Color(red: 0.7, green: 0.4, blue: 1.0)        // purple
    static let apiAccent = Color(red: 0.2, green: 0.71, blue: 0.9)            // teal #33b5e5
    static let historyAccent = Color(red: 0.2, green: 0.85, blue: 0.9)        // cyan

    // MARK: - Dimensions
    static let popoverWidth: CGFloat = 320
    static let cardCornerRadius: CGFloat = 12
    static let cardPadding: CGFloat = 12
    static let sectionSpacing: CGFloat = 10
}
