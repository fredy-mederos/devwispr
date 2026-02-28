//
//  OpenAITranscriptionServiceTests.swift
//  DevWisprTests
//

import Foundation
import AVFoundation
import Testing
@testable import DevWispr

@Suite("OpenAITranscriptionService Tests")
struct OpenAITranscriptionServiceTests {
    @Test("small upload is transcoded to m4a and sent with audio/mp4 mime")
    func smallUploadUsesCompressedMimeType() async throws {
        let testID = UUID().uuidString
        URLProtocolStub.registerHandler(testID: testID) { _ in
            let response = HTTPURLResponse(url: URL(string: "https://example.test/v1/audio/transcriptions")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("{\"text\":\"hello\"}".utf8))
        }

        let client = makeClient(testID: testID)
        let sourceURL = try makeTempSourceFile()
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let service = OpenAITranscriptionService(
            client: client,
            languageDetector: StubLanguageDetector(language: .english),
            maxUploadBytes: 1_000_000,
            targetUploadBytes: 900_000,
            audioTranscoder: StubAudioTranscoder(
                duration: 30,
                transcode: { _ in try makeTempM4AFile(sizeBytes: 1_024) }
            )
        )

        let result = try await service.transcribe(audioFileURL: sourceURL)

        #expect(result.text == "hello")
        let requests = URLProtocolStub.requests(for: testID)
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        let body = try #require(requestBodyData(for: request))
        #expect(data(body, containsASCII: "Content-Type: audio/mp4"))
        #expect(data(body, containsASCII: "filename=\""))
        #expect(data(body, containsASCII: ".m4a\""))
    }

    @Test("oversized upload is split and merged in order")
    func oversizedUploadSplitsAndMerges() async throws {
        let testID = UUID().uuidString
        var responseIndex = 0
        URLProtocolStub.registerHandler(testID: testID) { _ in
            responseIndex += 1
            let text = "chunk-\(responseIndex)"
            let response = HTTPURLResponse(url: URL(string: "https://example.test/v1/audio/transcriptions")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("{\"text\":\"\(text)\"}".utf8))
        }

        let client = makeClient(testID: testID)
        let sourceURL = try makeTempSourceFile()
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let service = OpenAITranscriptionService(
            client: client,
            languageDetector: StubLanguageDetector(language: .english),
            maxUploadBytes: 25_000,
            targetUploadBytes: 20_000,
            audioTranscoder: StubAudioTranscoder(
                duration: 30,
                transcode: { timeRange in
                    if timeRange == nil {
                        return try makeTempM4AFile(sizeBytes: 50_000)
                    }
                    return try makeTempM4AFile(sizeBytes: 10_000)
                }
            )
        )

        let result = try await service.transcribe(audioFileURL: sourceURL)

        #expect(URLProtocolStub.requests(for: testID).count == 3)
        #expect(result.text == "chunk-1\n\nchunk-2\n\nchunk-3")
    }

    @Test("recursive split path succeeds when first-level chunks remain oversized")
    func recursiveSplitSucceeds() async throws {
        let testID = UUID().uuidString
        var responseIndex = 0
        URLProtocolStub.registerHandler(testID: testID) { _ in
            responseIndex += 1
            let text = "part-\(responseIndex)"
            let response = HTTPURLResponse(url: URL(string: "https://example.test/v1/audio/transcriptions")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("{\"text\":\"\(text)\"}".utf8))
        }

        let client = makeClient(testID: testID)
        let sourceURL = try makeTempSourceFile()
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let service = OpenAITranscriptionService(
            client: client,
            languageDetector: StubLanguageDetector(language: .english),
            maxUploadBytes: 25_000,
            targetUploadBytes: 20_000,
            minimumChunkDurationSeconds: 1,
            audioTranscoder: StubAudioTranscoder(
                duration: 40,
                transcode: { timeRange in
                    guard let timeRange else {
                        return try makeTempM4AFile(sizeBytes: 80_000) // forces initial split into 4
                    }
                    let seconds = CMTimeGetSeconds(timeRange.duration)
                    if seconds >= 9.5 {
                        return try makeTempM4AFile(sizeBytes: 30_000) // still > max => recurse
                    }
                    return try makeTempM4AFile(sizeBytes: 15_000) // recursive chunk <= max
                }
            )
        )

        _ = try await service.transcribe(audioFileURL: sourceURL)

        #expect(URLProtocolStub.requests(for: testID).count == 8)
    }

    @Test("throws friendly size error when chunks cannot be reduced below limit")
    func throwsFriendlyTooLargeError() async throws {
        let testID = UUID().uuidString
        URLProtocolStub.registerHandler(testID: testID) { _ in
            let response = HTTPURLResponse(url: URL(string: "https://example.test/v1/audio/transcriptions")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("{\"text\":\"unused\"}".utf8))
        }

        let client = makeClient(testID: testID)
        let sourceURL = try makeTempSourceFile()
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let service = OpenAITranscriptionService(
            client: client,
            languageDetector: StubLanguageDetector(language: .english),
            maxUploadBytes: 25_000,
            targetUploadBytes: 20_000,
            minimumChunkDurationSeconds: 6,
            audioTranscoder: StubAudioTranscoder(
                duration: 30,
                transcode: { timeRange in
                    if timeRange == nil {
                        return try makeTempM4AFile(sizeBytes: 60_000)
                    }
                    return try makeTempM4AFile(sizeBytes: 30_000)
                }
            )
        )

        do {
            _ = try await service.transcribe(audioFileURL: sourceURL)
            Issue.record("Expected transcription to fail for oversized chunks")
        } catch {
            #expect(error.localizedDescription == "Recording is too large to transcribe. Please record a shorter clip.")
        }

        #expect(URLProtocolStub.requests(for: testID).isEmpty)
    }

    @Test("temporary transcoded files are cleaned up after success")
    func temporaryFilesAreCleanedUp() async throws {
        let testID = UUID().uuidString
        URLProtocolStub.registerHandler(testID: testID) { _ in
            let response = HTTPURLResponse(url: URL(string: "https://example.test/v1/audio/transcriptions")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("{\"text\":\"ok\"}".utf8))
        }

        let client = makeClient(testID: testID)
        let sourceURL = try makeTempSourceFile()
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let createdURLs = LockedBox<[URL]>([])
        let service = OpenAITranscriptionService(
            client: client,
            languageDetector: StubLanguageDetector(language: .english),
            audioTranscoder: StubAudioTranscoder(
                duration: 10,
                transcode: { _ in
                    let url = try makeTempM4AFile(sizeBytes: 1_024)
                    createdURLs.withValue { $0.append(url) }
                    return url
                }
            )
        )

        _ = try await service.transcribe(audioFileURL: sourceURL)

        let paths = createdURLs.value
        #expect(paths.count == 1)
        for path in paths {
            #expect(FileManager.default.fileExists(atPath: path.path) == false)
        }
    }
}

private func makeClient(testID: String) -> OpenAIClient {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [URLProtocolStub.self]
    let session = URLSession(configuration: configuration)

    return OpenAIClient(
        configuration: OpenAIClientConfiguration(
            baseURLProvider: { URL(string: "https://example.test/v1/\(testID)")! },
            apiKeyProvider: { "test-key" }
        ),
        session: session
    )
}

private func makeTempSourceFile() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("wav")
    try Data("source".utf8).write(to: url)
    return url
}

private func makeTempM4AFile(sizeBytes: Int) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("m4a")
    try Data(count: max(0, sizeBytes)).write(to: url)
    return url
}

private func data(_ data: Data, containsASCII needle: String) -> Bool {
    data.range(of: Data(needle.utf8)) != nil
}

private func requestBodyData(for request: URLRequest) -> Data? {
    if let body = request.httpBody {
        return body
    }
    guard let stream = request.httpBodyStream else { return nil }
    stream.open()
    defer { stream.close() }

    var result = Data()
    let bufferSize = 16 * 1024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    while stream.hasBytesAvailable {
        let read = stream.read(buffer, maxLength: bufferSize)
        if read < 0 { return nil }
        if read == 0 { break }
        result.append(buffer, count: read)
    }
    return result
}

private final class StubLanguageDetector: LanguageDetector {
    private let language: Language

    init(language: Language) {
        self.language = language
    }

    func detectLanguage(for text: String) -> Language? {
        language
    }
}

private struct StubAudioTranscoder: AudioTranscoding {
    let duration: TimeInterval
    let transcode: (_ timeRange: CMTimeRange?) throws -> URL

    func transcodeToM4A(sourceURL: URL, timeRange: CMTimeRange?) async throws -> URL {
        try transcode(timeRange)
    }

    func durationSeconds(sourceURL: URL) throws -> TimeInterval {
        duration
    }
}

private final class URLProtocolStub: URLProtocol {
    static var handlers: [String: (URLRequest) throws -> (HTTPURLResponse, Data)] = [:]

    private static let lock = NSLock()
    private static var _requests: [URLRequest] = []

    static var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return _requests
    }

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        _requests = []
        handlers = [:]
    }

    static func registerHandler(
        testID: String,
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) {
        lock.lock()
        defer { lock.unlock() }
        handlers[testID] = handler
    }

    static func requests(for testID: String) -> [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return _requests.filter { request in
            request.url?.path.contains("/\(testID)/") == true
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self._requests.append(request)
        Self.lock.unlock()

        do {
            guard
                let path = request.url?.path,
                let testID = path.split(separator: "/").drop(while: { $0 != "v1" }).dropFirst().first.map(String.init)
            else {
                throw URLError(.badURL)
            }
            guard let provider = Self.handlers[testID] else {
                throw URLError(.badServerResponse)
            }
            let (response, data) = try provider(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class LockedBox<T> {
    private let lock = NSLock()
    private var _value: T

    init(_ value: T) {
        _value = value
    }

    func withValue(_ mutate: (inout T) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        mutate(&_value)
    }

    var value: T {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }
}
