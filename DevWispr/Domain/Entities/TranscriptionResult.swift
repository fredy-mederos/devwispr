//
//  TranscriptionResult.swift
//  DevWispr
//

import Foundation

struct TranscriptionResult: Equatable, Hashable, Codable {
    let text: String
    let inputLanguage: Language
}
