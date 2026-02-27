//
//  TranslationResult.swift
//  DevWispr
//

import Foundation

struct TranslationResult: Equatable, Hashable, Codable {
    let text: String
    let outputLanguage: Language
}
