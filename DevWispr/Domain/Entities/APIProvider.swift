//
//  APIProvider.swift
//  DevWispr
//

import Foundation

enum APIProvider: String, CaseIterable, Identifiable, Codable {
    case openAI = "openai"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .custom: return "Custom"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .openAI: return "https://api.openai.com/v1"
        case .custom: return ""
        }
    }

    var apiKeyURL: String? {
        switch self {
        case .openAI: return "https://platform.openai.com/api-keys"
        case .custom: return nil
        }
    }
}
