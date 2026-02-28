//
//  AVAudioPlaybackServiceTests.swift
//  DevWisprTests
//

import AVFoundation
import Foundation
import Testing
@testable import DevWispr

@Suite("AVAudioPlaybackService Tests")
struct AVAudioPlaybackServiceTests {

    @Test("play sets currentURL and isPlaying")
    func playSetsCurrentURL() throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        try makeWavFile(at: fileURL)

        let service = AVAudioPlaybackService()
        try service.play(url: fileURL)

        #expect(service.currentURL == fileURL)
        #expect(service.isPlaying == true)
    }

    @Test("stop clears currentURL")
    func stopClearsCurrentURL() throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        try makeWavFile(at: fileURL)

        let service = AVAudioPlaybackService()
        try service.play(url: fileURL)
        service.stop()

        #expect(service.currentURL == nil)
        #expect(service.isPlaying == false)
    }

    @Test("play replaces currently playing url")
    func playReplacesCurrentPlayback() throws {
        let url1 = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)-1.wav")
        let url2 = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)-2.wav")
        defer {
            try? FileManager.default.removeItem(at: url1)
            try? FileManager.default.removeItem(at: url2)
        }
        try makeWavFile(at: url1)
        try makeWavFile(at: url2)

        let service = AVAudioPlaybackService()
        try service.play(url: url1)
        try service.play(url: url2)

        #expect(service.currentURL == url2)
        #expect(service.isPlaying == true)
    }

    private func makeWavFile(at url: URL) throws {
        let sampleRate: Double = 16_000
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)

        let frameCount: AVAudioFrameCount = 8_000
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        if let channelData = buffer.floatChannelData?.pointee {
            for i in 0..<Int(frameCount) {
                channelData[i] = 0
            }
        }

        try file.write(from: buffer)
    }
}
