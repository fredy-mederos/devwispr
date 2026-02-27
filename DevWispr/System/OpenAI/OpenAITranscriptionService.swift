//
//  OpenAITranscriptionService.swift
//  DevWispr
//

import Foundation

final class OpenAITranscriptionService: TranscriptionService {
    private let client: OpenAIClient
    private let model: String
    private let languageDetector: LanguageDetector

    init(client: OpenAIClient, model: String = "whisper-1", languageDetector: LanguageDetector) {
        self.client = client
        self.model = model
        self.languageDetector = languageDetector
    }

    func transcribe(audioFileURL: URL) async throws -> TranscriptionResult {
        let fileData = try Data(contentsOf: audioFileURL)
        let filename = audioFileURL.lastPathComponent
        debugLog("Audio file size: \(fileData.count) bytes (\(fileData.count / 1024) KB)")

        var builder = MultipartFormBuilder()
        builder.field(name: "model", value: model)
        builder.field(name: "response_format", value: "json")
        builder.file(name: "file", filename: filename, mimeType: "audio/wav", data: fileData)

        let headers = [
            "Content-Type": builder.contentType,
        ]

        let request = try client.makeRequest(
            path: "audio/transcriptions",
            method: "POST",
            headers: headers,
            body: builder.finalize()
        )

        let data = try await client.perform(request)
        let decoded = try JSONDecoder().decode(WhisperTranscriptionResponse.self, from: data)

        let detected = languageDetector.detectLanguage(for: decoded.text) ?? .english
        return TranscriptionResult(text: decoded.text, inputLanguage: detected)
    }
}
