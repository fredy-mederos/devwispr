//
//  TranslationUseCase.swift
//  DevWispr
//

import Foundation

final class DefaultTranslationUseCase: TranslationUseCase {
    private let service: TranslationService

    init(service: TranslationService) {
        self.service = service
    }

    func translateIfNeeded(text: String, inputLanguage: Language, outputLanguage: Language) async throws -> TranslationResult {
        if inputLanguage == outputLanguage {
            return TranslationResult(text: text, outputLanguage: outputLanguage)
        }
        return try await service.translate(text: text, to: outputLanguage)
    }
}
