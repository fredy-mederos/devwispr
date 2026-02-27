//
//  TranslationUseCaseTests.swift
//  DevWisprTests
//

import Foundation
import Testing
@testable import DevWispr

@Suite("TranslationUseCase Tests")
struct TranslationUseCaseTests {
    @Test("Same language returns original text without calling service")
    func sameLanguageSkipsService() async throws {
        let service = MockTranslationService()
        let useCase = DefaultTranslationUseCase(service: service)

        let result = try await useCase.translateIfNeeded(
            text: "Hello",
            inputLanguage: .english,
            outputLanguage: .english
        )

        #expect(result.text == "Hello")
        #expect(result.outputLanguage == .english)
        #expect(service.translateCallCount == 0)
    }

    @Test("Different language calls service and returns translated result")
    func differentLanguageCallsService() async throws {
        let service = MockTranslationService()
        service.result = TranslationResult(text: "Hola", outputLanguage: .spanish)
        let useCase = DefaultTranslationUseCase(service: service)

        let result = try await useCase.translateIfNeeded(
            text: "Hello",
            inputLanguage: .english,
            outputLanguage: .spanish
        )

        #expect(result.text == "Hola")
        #expect(result.outputLanguage == .spanish)
        #expect(service.translateCallCount == 1)
    }

    @Test("Service error propagates")
    func serviceErrorPropagates() async {
        let service = MockTranslationService()
        service.shouldThrow = NSError(domain: "test", code: 1)
        let useCase = DefaultTranslationUseCase(service: service)

        do {
            _ = try await useCase.translateIfNeeded(
                text: "Hello",
                inputLanguage: .english,
                outputLanguage: .spanish
            )
            #expect(Bool(false), "Should have thrown")
        } catch {
            #expect(service.translateCallCount == 1)
        }
    }
}
