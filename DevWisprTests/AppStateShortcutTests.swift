//
//  AppStateShortcutTests.swift
//  DevWisprTests
//

import AppKit
import Foundation
import Testing
@testable import DevWispr

@Suite("AppState Shortcut Tests")
struct AppStateShortcutTests {

    @MainActor
    private func makeSUT(
        settings: MockSettingsStore = MockSettingsStore(),
        hotkeys: MockHotkeyManager = MockHotkeyManager()
    ) -> (AppState, MockHotkeyManager, MockSettingsStore) {
        let container = AppContainer(
            hotkeyManager: hotkeys,
            settingsStore: settings
        )
        let appState = AppState(container: container)
        return (appState, hotkeys, settings)
    }

    // MARK: - Toggle shortcut

    @Test("updateToggleShortcut persists to settings")
    @MainActor
    func updateToggleShortcutPersistsToSettings() {
        let (appState, _, settings) = makeSUT()
        let binding = ShortcutBinding(keyCode: 15, modifierFlags: NSEvent.ModifierFlags([.option]).rawValue)

        appState.updateToggleShortcut(binding)

        #expect(settings.toggleShortcutBinding == binding)
    }

    @Test("updateToggleShortcut updates published property")
    @MainActor
    func updateToggleShortcutUpdatesPublishedProperty() {
        let (appState, _, _) = makeSUT()
        let binding = ShortcutBinding(keyCode: 15, modifierFlags: NSEvent.ModifierFlags([.option]).rawValue)

        appState.updateToggleShortcut(binding)

        #expect(appState.currentToggleShortcut == binding)
    }

    @Test("updateToggleShortcut calls hotkeyManager")
    @MainActor
    func updateToggleShortcutCallsHotkeyManager() {
        let hotkeys = MockHotkeyManager()
        let (appState, _, _) = makeSUT(hotkeys: hotkeys)
        let initialCount = hotkeys.updateToggleCallCount
        let binding = ShortcutBinding(keyCode: 15, modifierFlags: NSEvent.ModifierFlags([.option]).rawValue)

        appState.updateToggleShortcut(binding)

        #expect(hotkeys.updateToggleCallCount == initialCount + 1)
    }

    @Test("updateToggleShortcut with nil resets binding")
    @MainActor
    func updateToggleShortcutNilResetsBinding() {
        let (appState, _, settings) = makeSUT()
        let binding = ShortcutBinding(keyCode: 15, modifierFlags: NSEvent.ModifierFlags([.option]).rawValue)
        appState.updateToggleShortcut(binding)

        appState.updateToggleShortcut(nil)

        #expect(appState.currentToggleShortcut == nil)
        #expect(settings.toggleShortcutBinding == nil)
    }

    @Test("currentToggleShortcut loads from settings on init")
    @MainActor
    func currentToggleShortcutLoadsFromSettingsOnInit() {
        let settings = MockSettingsStore()
        let binding = ShortcutBinding(keyCode: 15, modifierFlags: NSEvent.ModifierFlags([.option]).rawValue)
        settings.toggleShortcutBinding = binding

        let (appState, _, _) = makeSUT(settings: settings)

        #expect(appState.currentToggleShortcut == binding)
    }

    // MARK: - Hold modifier

    @Test("holdModifierKey defaults to control on init")
    @MainActor
    func holdModifierKeyDefaultsToControl() {
        let (appState, _, _) = makeSUT()
        #expect(appState.holdModifierKey == .control)
    }

    @Test("holdModifierKey loads from settings on init")
    @MainActor
    func holdModifierKeyLoadsFromSettingsOnInit() {
        let settings = MockSettingsStore()
        settings.holdModifierKey = .option

        let (appState, _, _) = makeSUT(settings: settings)

        #expect(appState.holdModifierKey == .option)
    }

    @Test("changing holdModifierKey persists to settings")
    @MainActor
    func holdModifierKeyPersistsToSettings() {
        let (appState, _, settings) = makeSUT()

        appState.holdModifierKey = .option

        #expect(settings.holdModifierKey == .option)
    }

    @Test("changing holdModifierKey calls hotkeyManager")
    @MainActor
    func holdModifierKeyCallsHotkeyManager() {
        let hotkeys = MockHotkeyManager()
        let (appState, _, _) = makeSUT(hotkeys: hotkeys)
        let initialCount = hotkeys.updateHoldModifierCallCount

        appState.holdModifierKey = .option

        #expect(hotkeys.updateHoldModifierCallCount == initialCount + 1)
        #expect(hotkeys.lastHoldModifier == .option)
    }
}
