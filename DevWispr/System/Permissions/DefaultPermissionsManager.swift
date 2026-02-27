//
//  DefaultPermissionsManager.swift
//  DevWispr
//

import AppKit
import AVFAudio
import Foundation

final class DefaultPermissionsManager: PermissionsManager {
    func requestMicrophoneAccess() async -> Bool {
        let before = AVAudioApplication.shared.recordPermission
        infoLog("requestMicrophoneAccess() — current status before request: \(permissionName(before))")
        let granted = await AVAudioApplication.requestRecordPermission()
        let after = AVAudioApplication.shared.recordPermission
        infoLog("requestMicrophoneAccess() — granted=\(granted), status after: \(permissionName(after))")
        return granted
    }

    func requestAccessibilityAccess() async -> Bool {
        infoLog("requestAccessibilityAccess() called")
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options)
        infoLog("requestAccessibilityAccess() — trusted=\(trusted)")
        return trusted
    }

    func hasMicrophoneAccess() -> Bool {
        let permission = AVAudioApplication.shared.recordPermission
        infoLog("hasMicrophoneAccess() — recordPermission=\(permissionName(permission)), granted=\(permission == .granted)")
        return permission == .granted
    }

    func hasAccessibilityAccess() -> Bool {
        let trusted = AXIsProcessTrusted()
        infoLog("hasAccessibilityAccess() — trusted=\(trusted)")
        return trusted
    }

    private func permissionName(_ permission: AVAudioApplication.recordPermission) -> String {
        switch permission {
        case .granted: return "granted"
        case .denied: return "denied"
        case .undetermined: return "undetermined"
        @unknown default: return "unknown(\(permission.rawValue))"
        }
    }
}
