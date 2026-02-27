//
//  DefaultLanguageDetector.swift
//  DevWispr
//

import Foundation
import NaturalLanguage

final class DefaultLanguageDetector: LanguageDetector {
    func detectLanguage(for text: String) -> Language? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage else { return nil }
        let code = language.rawValue
        return LanguageMapper.language(from: code)
    }
}

private enum LanguageMapper {
    static func language(from code: String) -> Language? {
        let normalized = code.hasPrefix("zh") ? "zh" : code
        return Language.common.first { $0.code == normalized }
    }
}
