//
//  FakeTranslationService.swift
//  DevWispr
//

import Foundation

#if DEBUG
final class FakeTranslationService: TranslationService {
    func translate(text: String, to outputLanguage: Language) async throws -> TranslationResult {
        let translated = "[Translated to \(outputLanguage.displayName)] " + text
        return TranslationResult(text: translated, outputLanguage: outputLanguage)
    }
}
#endif
