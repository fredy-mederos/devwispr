//
//  MockAudioRecorder.swift
//  DevWisprTests
//

import Combine
import Foundation
@testable import DevWispr

final class MockAudioRecorder: AudioRecorder {
    var shouldThrow: Error?
    var isRecording: Bool = false
    var isEngineRunning: Bool = false
    var startEngineCallCount = 0
    var stopEngineCallCount = 0
    var startRecordingCallCount = 0
    var stopRecordingCallCount = 0
    var recordingURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mock.wav")

    let audioLevelSubject = PassthroughSubject<Double, Never>()
    let recordingReadySubject = PassthroughSubject<Void, Never>()
    let recordingStoppedSubject = PassthroughSubject<Void, Never>()

    var audioLevelPublisher: AnyPublisher<Double, Never> { audioLevelSubject.eraseToAnyPublisher() }
    var recordingReadyPublisher: AnyPublisher<Void, Never> { recordingReadySubject.eraseToAnyPublisher() }
    var recordingStoppedPublisher: AnyPublisher<Void, Never> { recordingStoppedSubject.eraseToAnyPublisher() }

    func startEngine() throws {
        startEngineCallCount += 1
        if let error = shouldThrow { throw error }
        isEngineRunning = true
    }

    func stopEngine() {
        stopEngineCallCount += 1
        isEngineRunning = false
    }

    func startRecording() throws {
        startRecordingCallCount += 1
        if let error = shouldThrow { throw error }
        isRecording = true
    }

    func stopRecording() throws -> URL {
        stopRecordingCallCount += 1
        if let error = shouldThrow { throw error }
        isRecording = false
        return recordingURL
    }
}
