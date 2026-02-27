//
//  ShortcutBindingTests.swift
//  DevWisprTests
//

import AppKit
import Testing
@testable import DevWispr

@Suite("ShortcutBinding Tests")
struct ShortcutBindingTests {

    @Test("displayString for Control + Space")
    func controlSpace() {
        let binding = ShortcutBinding(keyCode: 49, modifierFlags: NSEvent.ModifierFlags([.control]).rawValue)
        #expect(binding.displayString == "Control + Space")
    }

    @Test("displayString for Option + Return")
    func optionReturn() {
        let binding = ShortcutBinding(keyCode: 36, modifierFlags: NSEvent.ModifierFlags([.option]).rawValue)
        #expect(binding.displayString == "Option + Return")
    }

    @Test("displayString for Command + Space")
    func commandSpace() {
        let binding = ShortcutBinding(keyCode: 49, modifierFlags: NSEvent.ModifierFlags([.command]).rawValue)
        #expect(binding.displayString == "Command + Space")
    }

    @Test("Equatable: same values are equal")
    func equatableSameValues() {
        let a = ShortcutBinding(keyCode: 49, modifierFlags: NSEvent.ModifierFlags([.control]).rawValue)
        let b = ShortcutBinding(keyCode: 49, modifierFlags: NSEvent.ModifierFlags([.control]).rawValue)
        #expect(a == b)
    }

    @Test("Equatable: different keyCode are not equal")
    func equatableDifferentKeyCode() {
        let a = ShortcutBinding(keyCode: 49, modifierFlags: NSEvent.ModifierFlags([.control]).rawValue)
        let b = ShortcutBinding(keyCode: 36, modifierFlags: NSEvent.ModifierFlags([.control]).rawValue)
        #expect(a != b)
    }

    @Test("HoldModifierKey control displayName")
    func holdModifierKeyControlDisplayName() {
        #expect(HoldModifierKey.control.displayName == "Control")
    }

    @Test("HoldModifierKey option displayName")
    func holdModifierKeyOptionDisplayName() {
        #expect(HoldModifierKey.option.displayName == "Option")
    }

    @Test("HoldModifierKey control modifierFlag is .control")
    func holdModifierKeyControlFlag() {
        #expect(HoldModifierKey.control.modifierFlag == .control)
    }

    @Test("HoldModifierKey option modifierFlag is .option")
    func holdModifierKeyOptionFlag() {
        #expect(HoldModifierKey.option.modifierFlag == .option)
    }

    @Test("HoldModifierKey physicalKeyCodes are non-empty for all cases")
    func holdModifierKeyPhysicalKeyCodes() {
        for key in HoldModifierKey.allCases {
            #expect(!key.physicalKeyCodes.isEmpty)
        }
    }
}
