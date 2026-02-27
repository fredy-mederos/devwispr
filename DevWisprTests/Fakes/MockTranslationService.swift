//
//  MockTranslationService.swift
//  DevWisprTests
//

import Foundation
@testable import DevWispr

final class MockTranslationService: TranslationService {
    var shouldThrow: Error?
    var result: TranslationResult?
    var translateCallCount = 0

    func translate(text: String, to outputLanguage: Language) async throws -> TranslationResult {
        translateCallCount += 1
        if let error = shouldThrow { throw error }
        return result ?? TranslationResult(text: "[translated] \(text)", outputLanguage: outputLanguage)
    }
}
