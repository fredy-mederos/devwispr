//
//  OpenAIModels.swift
//  DevWispr
//

import Foundation

// MARK: - Whisper Transcription

struct WhisperTranscriptionResponse: Decodable {
    let text: String
}

// MARK: - Responses API (Translation)

struct ResponsesAPIRequest: Encodable {
    let model: String
    let input: String
}

struct ResponsesAPIResponse: Decodable {
    let output: [ResponsesAPIOutput]?
    let outputText: String?

    enum CodingKeys: String, CodingKey {
        case output
        case outputText = "output_text"
    }

    var extractedText: String? {
        // Try structured output path first
        if let output {
            let chunks = output.compactMap { item -> String? in
                guard let content = item.content else { return nil }
                let texts = content.compactMap { contentItem -> String? in
                    guard contentItem.type == "output_text" else { return nil }
                    return contentItem.text
                }
                return texts.isEmpty ? nil : texts.joined()
            }
            let combined = chunks.joined()
            if !combined.isEmpty {
                return combined.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        // Fallback to top-level output_text
        return outputText
    }
}

struct ResponsesAPIOutput: Decodable {
    let content: [ResponsesAPIContent]?
}

struct ResponsesAPIContent: Decodable {
    let type: String?
    let text: String?
}

// MARK: - Error Response

struct OpenAIErrorResponse: Decodable {
    struct ErrorDetail: Decodable {
        let message: String?
    }
    let error: ErrorDetail?
}
