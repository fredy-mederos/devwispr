//
//  MockTranscriptionService.swift
//  DevWisprTests
//

import Foundation
@testable import DevWispr

final class MockTranscriptionService: TranscriptionService {
    var shouldThrow: Error?
    var result = TranscriptionResult(text: "mock transcription", inputLanguage: .english)
    var transcribeCallCount = 0

    func transcribe(audioFileURL: URL) async throws -> TranscriptionResult {
        transcribeCallCount += 1
        if let error = shouldThrow { throw error }
        return result
    }
}
