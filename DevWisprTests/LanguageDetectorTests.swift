//
//  LanguageDetectorTests.swift
//  DevWisprTests
//

import Testing
@testable import DevWispr

@Suite("LanguageDetector Tests")
struct LanguageDetectorTests {
    private let detector = DefaultLanguageDetector()

    @Test("Detects English text")
    func detectsEnglish() {
        let lang = detector.detectLanguage(for: "This is a long English sentence that should be easily recognizable by the language detector.")
        #expect(lang == .english)
    }

    @Test("Detects Spanish text")
    func detectsSpanish() {
        let lang = detector.detectLanguage(for: "Esta es una oración larga en español que debería ser fácilmente reconocible por el detector de idiomas.")
        #expect(lang == .spanish)
    }

    @Test("Detects German text")
    func detectsGerman() {
        let lang = detector.detectLanguage(for: "Dies ist ein langer deutscher Satz, der vom Sprachdetektor leicht erkennbar sein sollte.")
        #expect(lang == .german)
    }

    @Test("Detects French text")
    func detectsFrench() {
        let lang = detector.detectLanguage(for: "Ceci est une longue phrase en français qui devrait être facilement reconnaissable par le détecteur de langue.")
        #expect(lang == .french)
    }

    @Test("Chinese text returns nil (not in supported languages)")
    func chineseReturnsNil() {
        let lang = detector.detectLanguage(for: "这是一个很长的中文句子，语言检测器应该能够轻松识别它。")
        #expect(lang == nil)
    }

    @Test("Empty string returns nil")
    func emptyStringReturnsNil() {
        let lang = detector.detectLanguage(for: "")
        #expect(lang == nil)
    }
}
