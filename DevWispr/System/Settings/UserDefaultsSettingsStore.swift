//
//  UserDefaultsSettingsStore.swift
//  DevWispr
//

import Foundation

final class UserDefaultsSettingsStore: SettingsStore {
    private enum Keys {
        static let toggleShortcutKeyCode = "settings.toggleShortcutKeyCode"
        static let toggleShortcutModifiers = "settings.toggleShortcutModifiers"
        static let holdModifierKey = "settings.holdModifierKey"
        static let shortcutsEnabled = "settings.shortcutsEnabled"
        static let autoTranslateToEnglish = "settings.autoTranslateToEnglish"
        static let legacyOutputLanguage = "settings.outputLanguage"
        static let useClipboardOnly = "settings.useClipboardOnly"
        static let apiProvider = "settings.apiProvider"
        static let customBaseURL = "settings.customBaseURL"
        static let customApiKeyURL = "settings.customApiKeyURL"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var toggleShortcutBinding: ShortcutBinding? {
        get {
            guard defaults.object(forKey: Keys.toggleShortcutKeyCode) != nil else { return nil }
            let keyCode = UInt32(defaults.integer(forKey: Keys.toggleShortcutKeyCode))
            let modifiers = UInt(defaults.integer(forKey: Keys.toggleShortcutModifiers))
            return ShortcutBinding(keyCode: keyCode, modifierFlags: modifiers)
        }
        set {
            if let binding = newValue {
                defaults.set(Int(binding.keyCode), forKey: Keys.toggleShortcutKeyCode)
                defaults.set(Int(binding.modifierFlags), forKey: Keys.toggleShortcutModifiers)
            } else {
                defaults.removeObject(forKey: Keys.toggleShortcutKeyCode)
                defaults.removeObject(forKey: Keys.toggleShortcutModifiers)
            }
        }
    }

    var holdModifierKey: HoldModifierKey {
        get {
            guard let raw = defaults.string(forKey: Keys.holdModifierKey),
                  let key = HoldModifierKey(rawValue: raw) else {
                return .control
            }
            return key
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.holdModifierKey)
        }
    }

    var shortcutsEnabled: Bool {
        get {
            // Default to true — shortcuts are on unless explicitly disabled.
            defaults.object(forKey: Keys.shortcutsEnabled) == nil
                ? true
                : defaults.bool(forKey: Keys.shortcutsEnabled)
        }
        set { defaults.set(newValue, forKey: Keys.shortcutsEnabled) }
    }

    var autoTranslateToEnglish: Bool {
        get {
            migrateOutputLanguageIfNeeded()
            return defaults.bool(forKey: Keys.autoTranslateToEnglish)
        }
        set {
            defaults.set(newValue, forKey: Keys.autoTranslateToEnglish)
        }
    }

    /// One-time migration: if the legacy `outputLanguage` key exists and was set
    /// to a non-English language, enable `autoTranslateToEnglish` and remove the old key.
    private func migrateOutputLanguageIfNeeded() {
        guard defaults.object(forKey: Keys.legacyOutputLanguage) != nil else { return }
        let code = defaults.string(forKey: Keys.legacyOutputLanguage) ?? Language.english.code
        if code != Language.english.code {
            defaults.set(true, forKey: Keys.autoTranslateToEnglish)
        }
        defaults.removeObject(forKey: Keys.legacyOutputLanguage)
    }

    var useClipboardOnly: Bool {
        get { defaults.bool(forKey: Keys.useClipboardOnly) }
        set { defaults.set(newValue, forKey: Keys.useClipboardOnly) }
    }

    private enum KeychainConfig {
        static let service = "com.devwispr.app"
        static let apiKeyAccount = "apiKey"
    }

    var apiKey: String? {
        get {
            KeychainHelper.load(
                service: KeychainConfig.service,
                account: KeychainConfig.apiKeyAccount
            )
        }
        set {
            if let value = newValue {
                _ = KeychainHelper.save(
                    service: KeychainConfig.service,
                    account: KeychainConfig.apiKeyAccount,
                    data: value
                )
            } else {
                _ = KeychainHelper.delete(
                    service: KeychainConfig.service,
                    account: KeychainConfig.apiKeyAccount
                )
            }
        }
    }

    var apiProvider: APIProvider {
        get {
            guard let raw = defaults.string(forKey: Keys.apiProvider),
                  let provider = APIProvider(rawValue: raw) else {
                return .openAI
            }
            return provider
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.apiProvider)
        }
    }

    var customBaseURL: String? {
        get { defaults.string(forKey: Keys.customBaseURL) }
        set {
            if let value = newValue {
                defaults.set(value, forKey: Keys.customBaseURL)
            } else {
                defaults.removeObject(forKey: Keys.customBaseURL)
            }
        }
    }

    var customApiKeyURL: String? {
        get { defaults.string(forKey: Keys.customApiKeyURL) }
        set {
            if let value = newValue {
                defaults.set(value, forKey: Keys.customApiKeyURL)
            } else {
                defaults.removeObject(forKey: Keys.customApiKeyURL)
            }
        }
    }

    func resetShortcuts() {
        toggleShortcutBinding = nil
        defaults.removeObject(forKey: Keys.holdModifierKey)
    }
}
