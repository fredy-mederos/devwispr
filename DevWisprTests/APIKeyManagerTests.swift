//
//  APIKeyManagerTests.swift
//  DevWisprTests
//

import Foundation
import Testing
@testable import DevWispr

// MARK: - Helpers

@MainActor
private func makeSUT(
    settings: MockSettingsStore = MockSettingsStore()
) -> (AppState, MockSettingsStore) {
    let container = AppContainer(
        audioRecorder: MockAudioRecorder(),
        transcriptionService: MockTranscriptionService(),
        translationService: MockTranslationService(),
        permissionsManager: MockPermissionsManager(),
        hotkeyManager: MockHotkeyManager(),
        settingsStore: settings
    )
    let appState = AppState(container: container)
    return (appState, settings)
}

// MARK: - Tests

@Suite("APIKeyManager Tests")
struct APIKeyManagerTests {

    // MARK: - ensureAPIKey

    @Test("ensureAPIKey returns true when settingsStore has a key")
    @MainActor
    func ensureAPIKey_settingsStoreHasKey() {
        let settings = MockSettingsStore()
        settings.apiKey = "sk-stored"
        let (appState, _) = makeSUT(settings: settings)

        let result = appState.ensureAPIKey()

        #expect(result == true)
    }

    @Test("ensureAPIKey returns false and sets error when no key")
    @MainActor
    func ensureAPIKey_noKey() {
        let (appState, _) = makeSUT()

        let result = appState.ensureAPIKey()

        #expect(result == false)
        #expect(appState.status == .error)
        #expect(appState.lastError != nil)
    }

    @Test("ensureAPIKey returns false when settingsStore key is empty string")
    @MainActor
    func ensureAPIKey_settingsStoreEmptyString() {
        let settings = MockSettingsStore()
        settings.apiKey = ""
        let (appState, _) = makeSUT(settings: settings)

        let result = appState.ensureAPIKey()

        #expect(result == false)
    }

    @Test("ensureAPIKey dismisses setup sheet when key exists")
    @MainActor
    func ensureAPIKey_dismissesSetupSheet() {
        let settings = MockSettingsStore()
        settings.apiKey = "sk-stored"
        let (appState, _) = makeSUT(settings: settings)
        appState.showApiKeySetup = true

        _ = appState.ensureAPIKey()

        #expect(appState.showApiKeySetup == false)
    }

    // MARK: - saveAPIKey

    @Test("saveAPIKey persists trimmed input to settingsStore")
    @MainActor
    func saveAPIKey_persistsTrimmedInput() {
        let settings = MockSettingsStore()
        let (appState, _) = makeSUT(settings: settings)
        appState.apiKeyInput = "  sk-test-key  "

        appState.saveAPIKey()

        #expect(settings.apiKey == "sk-test-key")
    }

    @Test("saveAPIKey trims whitespace and newlines")
    @MainActor
    func saveAPIKey_trimsWhitespaceAndNewlines() {
        let settings = MockSettingsStore()
        let (appState, _) = makeSUT(settings: settings)
        appState.apiKeyInput = "\n  sk-trimmed \t\n"

        appState.saveAPIKey()

        #expect(settings.apiKey == "sk-trimmed")
    }

    @Test("saveAPIKey sets apiKeySource to .settings, dismisses sheet, clears error, sets idle")
    @MainActor
    func saveAPIKey_setsExpectedState() {
        let (appState, _) = makeSUT()
        appState.apiKeyInput = "sk-valid"
        appState.showApiKeySetup = true
        appState.lastError = "some old error"
        appState.status = .error

        appState.saveAPIKey()

        #expect(appState.apiKeySource == .settings)
        #expect(appState.apiKeySaved == true)
        #expect(appState.showApiKeySetup == false)
        #expect(appState.lastError == nil)
        #expect(appState.status == .idle)
    }

    @Test("saveAPIKey with empty input sets error and does not persist")
    @MainActor
    func saveAPIKey_emptyInputSetsError() {
        let settings = MockSettingsStore()
        let (appState, _) = makeSUT(settings: settings)
        appState.apiKeyInput = ""

        appState.saveAPIKey()

        #expect(appState.status == .error)
        #expect(appState.lastError != nil)
        #expect(settings.apiKey == nil)
    }

    @Test("saveAPIKey with whitespace-only input sets error and does not overwrite existing key")
    @MainActor
    func saveAPIKey_whitespaceOnlyDoesNotOverwrite() {
        let settings = MockSettingsStore()
        settings.apiKey = "sk-existing"
        let (appState, _) = makeSUT(settings: settings)
        appState.apiKeyInput = "   \n\t  "

        appState.saveAPIKey()

        #expect(appState.status == .error)
        #expect(appState.lastError != nil)
        #expect(settings.apiKey == "sk-existing")
    }

    // MARK: - loadAPIKey (via AppState.init)

    @Test("loadAPIKey sets apiKeySource to .settings when settingsStore has key")
    @MainActor
    func loadAPIKey_settingsStoreHasKey() {
        let settings = MockSettingsStore()
        settings.apiKey = "sk-stored"
        let (appState, _) = makeSUT(settings: settings)

        #expect(appState.apiKeySource == .settings)
    }

    @Test("loadAPIKey sets apiKeySource to .none when no key")
    @MainActor
    func loadAPIKey_noKey() {
        let (appState, _) = makeSUT()

        #expect(appState.apiKeySource == .none)
    }

    @Test("loadAPIKey sets apiKeySource to .none when settingsStore key is empty")
    @MainActor
    func loadAPIKey_settingsStoreEmptyKey() {
        let settings = MockSettingsStore()
        settings.apiKey = ""
        let (appState, _) = makeSUT(settings: settings)

        #expect(appState.apiKeySource == .none)
    }

    @Test("reloadAPIKeyState picks up changes made after init")
    @MainActor
    func reloadAPIKeyState_picksUpChanges() {
        let settings = MockSettingsStore()
        let (appState, _) = makeSUT(settings: settings)

        #expect(appState.apiKeySource == .none)

        settings.apiKey = "sk-added-later"
        appState.reloadAPIKeyState()

        #expect(appState.apiKeySource == .settings)
    }

    // MARK: - clearSavedAPIKey

    @Test("clearSavedAPIKey removes settings key and goes to .none")
    @MainActor
    func clearSavedAPIKey_goesToNone() {
        let settings = MockSettingsStore()
        settings.apiKey = "sk-stored"
        let (appState, _) = makeSUT(settings: settings)

        #expect(appState.apiKeySource == .settings)

        appState.clearSavedAPIKey()

        #expect(settings.apiKey == nil)
        #expect(appState.apiKeySource == .none)
    }

    // MARK: - showAPIKeySheet

    @Test("showAPIKeySheet sets showApiKeySetup to true")
    @MainActor
    func showAPIKeySheet_setsFlag() {
        let (appState, _) = makeSUT()

        #expect(appState.showApiKeySetup == false)

        appState.showAPIKeySheet()

        #expect(appState.showApiKeySetup == true)
    }
}
