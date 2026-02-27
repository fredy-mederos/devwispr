//
//  MockSettingsStore.swift
//  DevWisprTests
//

import Foundation
@testable import DevWispr

final class MockSettingsStore: SettingsStore {
    var toggleShortcutBinding: ShortcutBinding?
    var holdModifierKey: HoldModifierKey = .control
    var shortcutsEnabled: Bool = true
    var autoTranslateToEnglish: Bool = false
    var useClipboardOnly: Bool = false
    var apiKey: String?
    var apiProvider: APIProvider = .openAI
    var customBaseURL: String?
    var customApiKeyURL: String?

    func resetShortcuts() {
        toggleShortcutBinding = nil
        holdModifierKey = .control
    }
}
