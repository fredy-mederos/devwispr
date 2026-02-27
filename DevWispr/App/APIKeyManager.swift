//
//  APIKeyManager.swift
//  DevWispr
//

import Foundation

@MainActor
final class APIKeyManager {
    private let settingsStore: SettingsStore
    private weak var appState: AppState?

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    func bind(to appState: AppState) {
        self.appState = appState
    }

    func ensureAPIKey() -> Bool {
        let hasKey = settingsStore.apiKey?.isEmpty == false
        if !hasKey {
            appState?.status = .error
            appState?.lastError = "API key is required to transcribe."
            appState?.showApiKeySetup = true
            return false
        }
        appState?.showApiKeySetup = false
        return true
    }

    func saveAPIKey() {
        guard let appState else { return }
        let trimmed = appState.apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            appState.lastError = "API key cannot be empty."
            appState.status = .error
            return
        }

        settingsStore.apiKey = trimmed
        appState.apiKeySource = .settings
        appState.showApiKeySetup = false
        appState.lastError = nil
        appState.status = .idle
    }

    func loadAPIKey() {
        if settingsStore.apiKey?.isEmpty == false {
            appState?.apiKeySource = .settings
        } else {
            appState?.apiKeySource = .none
        }
    }

    func clearSavedAPIKey() {
        settingsStore.apiKey = nil
        loadAPIKey()
    }

    func showAPIKeySheet() {
        appState?.showApiKeySetup = true
    }
}
