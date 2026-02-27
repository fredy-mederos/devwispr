//
//  SettingsStoreTests.swift
//  DevWisprTests
//

import Foundation
import Testing
@testable import DevWispr

@Suite("UserDefaultsSettingsStore Tests")
struct SettingsStoreTests {
    private func makeSUT() -> (UserDefaultsSettingsStore, UserDefaults) {
        let suiteName = "test.settings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = UserDefaultsSettingsStore(defaults: defaults)
        return (store, defaults)
    }

    @Test("Default autoTranslateToEnglish is false")
    func defaultAutoTranslateToEnglish() {
        let (store, _) = makeSUT()
        #expect(store.autoTranslateToEnglish == false)
    }

    @Test("Round-trip autoTranslateToEnglish")
    func roundTripAutoTranslateToEnglish() {
        let (store, _) = makeSUT()
        store.autoTranslateToEnglish = true
        #expect(store.autoTranslateToEnglish == true)
    }

    @Test("Migration: non-English outputLanguage migrates to autoTranslateToEnglish true")
    func migrationFromNonEnglishOutputLanguage() {
        let (store, defaults) = makeSUT()
        defaults.set("de", forKey: "settings.outputLanguage")
        #expect(store.autoTranslateToEnglish == true)
        // Legacy key should be removed after migration
        #expect(defaults.object(forKey: "settings.outputLanguage") == nil)
    }

    @Test("Migration: English outputLanguage migrates to autoTranslateToEnglish false")
    func migrationFromEnglishOutputLanguage() {
        let (store, defaults) = makeSUT()
        defaults.set("en", forKey: "settings.outputLanguage")
        #expect(store.autoTranslateToEnglish == false)
        #expect(defaults.object(forKey: "settings.outputLanguage") == nil)
    }

    @Test("toggleShortcutBinding defaults to nil")
    func toggleBindingDefaultsNil() {
        let (store, _) = makeSUT()
        #expect(store.toggleShortcutBinding == nil)
    }

    @Test("Round-trip toggleShortcutBinding")
    func roundTripToggleBinding() {
        let (store, _) = makeSUT()
        let binding = ShortcutBinding(keyCode: 49, modifierFlags: 0)
        store.toggleShortcutBinding = binding
        #expect(store.toggleShortcutBinding == binding)
    }

    @Test("Setting toggleShortcutBinding to nil clears it")
    func clearToggleBinding() {
        let (store, _) = makeSUT()
        store.toggleShortcutBinding = ShortcutBinding(keyCode: 49, modifierFlags: 0)
        store.toggleShortcutBinding = nil
        #expect(store.toggleShortcutBinding == nil)
    }

    @Test("Default useClipboardOnly is false")
    func defaultUseClipboardOnly() {
        let (store, _) = makeSUT()
        #expect(store.useClipboardOnly == false)
    }

    @Test("Round-trip useClipboardOnly")
    func roundTripUseClipboardOnly() {
        let (store, _) = makeSUT()
        store.useClipboardOnly = true
        #expect(store.useClipboardOnly == true)
    }

    @Test("resetShortcuts clears toggleShortcutBinding")
    func resetShortcuts() {
        let (store, _) = makeSUT()
        store.toggleShortcutBinding = ShortcutBinding(keyCode: 49, modifierFlags: 0)
        store.resetShortcuts()
        #expect(store.toggleShortcutBinding == nil)
    }

    @Test("holdModifierKey defaults to control")
    func defaultHoldModifierKey() {
        let (store, _) = makeSUT()
        #expect(store.holdModifierKey == .control)
    }

    @Test("Round-trip holdModifierKey option")
    func roundTripHoldModifierKeyOption() {
        let (store, _) = makeSUT()
        store.holdModifierKey = .option
        #expect(store.holdModifierKey == .option)
    }

    @Test("resetShortcuts resets holdModifierKey to control")
    func resetShortcutsResetsHoldModifier() {
        let (store, _) = makeSUT()
        store.holdModifierKey = .option
        store.resetShortcuts()
        #expect(store.holdModifierKey == .control)
    }
}
