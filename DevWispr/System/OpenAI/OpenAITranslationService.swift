//
//  OpenAITranslationService.swift
//  DevWispr
//

import Foundation

final class OpenAITranslationService: TranslationService {
    private let client: OpenAIClient
    private let model: String

    init(client: OpenAIClient, model: String = "gpt-4o-mini") {
        self.client = client
        self.model = model
    }

    func translate(text: String, to outputLanguage: Language) async throws -> TranslationResult {
        let prompt = "Translate the following text into \(outputLanguage.displayName). Return only the translated text.\n\nText:\n\(text)"
        let payload = ResponsesAPIRequest(model: model, input: prompt)

        let body = try JSONEncoder().encode(payload)
        let headers = ["Content-Type": "application/json"]
        let request = try client.makeRequest(
            path: "responses",
            method: "POST",
            headers: headers,
            body: body
        )

        let data = try await client.perform(request)
        let decoded = try JSONDecoder().decode(ResponsesAPIResponse.self, from: data)
        guard let outputText = decoded.extractedText else {
            throw OpenAIClient.ClientError.decodingFailed
        }

        return TranslationResult(text: outputText, outputLanguage: outputLanguage)
    }
}
