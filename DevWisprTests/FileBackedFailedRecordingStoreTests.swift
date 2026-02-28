//
//  FileBackedFailedRecordingStoreTests.swift
//  DevWisprTests
//

import AVFoundation
import Foundation
import Testing
@testable import DevWispr

@Suite("FileBackedFailedRecordingStore Tests")
struct FileBackedFailedRecordingStoreTests {

    @Test("addFromTemporaryFile moves file and persists metadata")
    func addFromTemporaryFileMovesAudio() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("source.wav")
        try makeWavFile(at: source)

        let store = FileBackedFailedRecordingStore(directory: root)
        let item = try store.addFromTemporaryFile(sourceURL: source, lastError: "network error")

        #expect(FileManager.default.fileExists(atPath: source.path) == false)

        let destination = try store.url(for: item.id)
        #expect(FileManager.default.fileExists(atPath: destination.path))
        #expect(item.fileSizeBytes > 0)
        #expect(item.durationSeconds > 0)
        #expect(try store.list().count == 1)
    }

    @Test("updateFailure increments retry count and updates message")
    func updateFailureMutatesItem() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("source.wav")
        try makeWavFile(at: source)

        let store = FileBackedFailedRecordingStore(directory: root)
        let item = try store.addFromTemporaryFile(sourceURL: source, lastError: "timeout")

        try store.updateFailure(id: item.id, lastError: "still failing")
        let updated = try #require(store.list().first)
        #expect(updated.retryCount == 1)
        #expect(updated.lastError == "still failing")
    }

    @Test("markResolved removes metadata and audio file")
    func markResolvedDeletesAudio() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("source.wav")
        try makeWavFile(at: source)

        let store = FileBackedFailedRecordingStore(directory: root)
        let item = try store.addFromTemporaryFile(sourceURL: source, lastError: "timeout")
        let destination = try store.url(for: item.id)

        try store.markResolved(id: item.id)

        #expect(FileManager.default.fileExists(atPath: destination.path) == false)
        #expect(try store.list().isEmpty)
    }

    @Test("deleteAll removes all failed recordings")
    func deleteAllClearsEverything() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source1 = root.appendingPathComponent("source1.wav")
        let source2 = root.appendingPathComponent("source2.wav")
        try makeWavFile(at: source1)
        try makeWavFile(at: source2)

        let store = FileBackedFailedRecordingStore(directory: root)
        let item1 = try store.addFromTemporaryFile(sourceURL: source1, lastError: "timeout")
        let item2 = try store.addFromTemporaryFile(sourceURL: source2, lastError: "server")
        let url1 = try store.url(for: item1.id)
        let url2 = try store.url(for: item2.id)

        try store.deleteAll()

        #expect(try store.list().isEmpty)
        #expect(FileManager.default.fileExists(atPath: url1.path) == false)
        #expect(FileManager.default.fileExists(atPath: url2.path) == false)
    }

    private func makeWavFile(at url: URL) throws {
        let sampleRate: Double = 16_000
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)

        let frameCount: AVAudioFrameCount = 16_000 // 1 second
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
