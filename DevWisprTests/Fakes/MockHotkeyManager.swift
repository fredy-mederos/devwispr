//
//  MockHotkeyManager.swift
//  DevWisprTests
//

import Foundation
@testable import DevWispr

final class MockHotkeyManager: HotkeyManager {
    var shouldThrow: Error?
    var registerHoldCallCount = 0
    var registerToggleCallCount = 0
    var updateToggleCallCount = 0
    var unregisterAllCallCount = 0

    func registerHoldToTalk(handler: @escaping (Bool) -> Void) throws {
        registerHoldCallCount += 1
        if let error = shouldThrow { throw error }
    }

    func registerToggle(handler: @escaping () -> Void) throws {
        registerToggleCallCount += 1
        if let error = shouldThrow { throw error }
    }

    func updateToggleShortcut(_ binding: ShortcutBinding?) throws {
        updateToggleCallCount += 1
        if let error = shouldThrow { throw error }
    }

    var updateHoldModifierCallCount = 0
    var lastHoldModifier: HoldModifierKey?

    func updateHoldModifier(_ modifier: HoldModifierKey) {
        updateHoldModifierCallCount += 1
        lastHoldModifier = modifier
    }

    var suspendToggleCallCount = 0
    var resumeToggleCallCount = 0

    func suspendToggle() {
        suspendToggleCallCount += 1
    }

    func resumeToggle() {
        resumeToggleCallCount += 1
    }

    func unregisterAll() {
        unregisterAllCallCount += 1
    }
}
