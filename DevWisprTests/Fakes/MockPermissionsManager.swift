//
//  MockPermissionsManager.swift
//  DevWisprTests
//

import Foundation
@testable import DevWispr

final class MockPermissionsManager: PermissionsManager {
    var microphoneAccess = true
    var accessibilityAccess = true

    func requestMicrophoneAccess() async -> Bool { microphoneAccess }
    func requestAccessibilityAccess() async -> Bool { accessibilityAccess }
    func hasMicrophoneAccess() -> Bool { microphoneAccess }
    func hasAccessibilityAccess() -> Bool { accessibilityAccess }
}
