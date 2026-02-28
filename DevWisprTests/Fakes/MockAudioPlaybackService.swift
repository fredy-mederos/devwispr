//
//  MockAudioPlaybackService.swift
//  DevWisprTests
//

import Foundation
@testable import DevWispr

final class MockAudioPlaybackService: AudioPlaybackService {
    var shouldThrow: Error?
    var playCallCount = 0
    var stopCallCount = 0
    private(set) var isPlaying: Bool = false
    private(set) var currentURL: URL?

    func play(url: URL) throws {
        playCallCount += 1
        if let error = shouldThrow { throw error }
        currentURL = url
        isPlaying = true
    }

    func stop() {
        stopCallCount += 1
        currentURL = nil
        isPlaying = false
    }
}
