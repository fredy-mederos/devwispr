//
//  FakeTranscriptionService.swift
//  DevWispr
//

import Foundation

#if DEBUG
final class FakeTranscriptionService: TranscriptionService {
    func transcribe(audioFileURL: URL) async throws -> TranscriptionResult {
        let text = "This is a fake transcription result."
        return TranscriptionResult(text: text, inputLanguage: .english)
    }
}
#endif
