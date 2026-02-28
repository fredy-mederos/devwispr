//
//  OpenAITranscriptionService.swift
//  DevWispr
//

import Foundation
import AVFoundation

protocol AudioTranscoding {
    func transcodeToM4A(sourceURL: URL, timeRange: CMTimeRange?) async throws -> URL
    func durationSeconds(sourceURL: URL) throws -> TimeInterval
}

struct DefaultAudioTranscoder: AudioTranscoding {
    func durationSeconds(sourceURL: URL) throws -> TimeInterval {
        let asset = AVURLAsset(url: sourceURL)
        let seconds = CMTimeGetSeconds(asset.duration)
        guard seconds.isFinite, seconds > 0 else {
            throw OpenAITranscriptionService.PreprocessingError.preprocessingFailed("Could not determine audio duration")
        }
        return seconds
    }

    func transcodeToM4A(sourceURL: URL, timeRange: CMTimeRange?) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw OpenAITranscriptionService.PreprocessingError.preprocessingFailed("Could not create export session")
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        exporter.outputURL = outputURL
        exporter.outputFileType = .m4a
        if let timeRange {
            exporter.timeRange = timeRange
        }

        try await withCheckedThrowingContinuation { continuation in
            exporter.exportAsynchronously {
                switch exporter.status {
                case .completed:
                    continuation.resume(returning: ())
                case .failed:
                    continuation.resume(throwing: exporter.error ?? OpenAITranscriptionService.PreprocessingError.preprocessingFailed("Export failed"))
                case .cancelled:
                    continuation.resume(throwing: CancellationError())
                default:
                    continuation.resume(throwing: OpenAITranscriptionService.PreprocessingError.preprocessingFailed("Export did not complete"))
                }
            }
        }

        return outputURL
    }
}

final class OpenAITranscriptionService: TranscriptionService {
    private struct PreparedUpload {
        let fileURL: URL
        let shouldCleanup: Bool
    }

    enum PreprocessingError: LocalizedError {
        case recordingTooLarge
        case preprocessingFailed(String)

        var errorDescription: String? {
            switch self {
            case .recordingTooLarge:
                return String(localized: "Recording is too large to transcribe. Please record a shorter clip.")
            case .preprocessingFailed(let message):
                return String(localized: "Audio preprocessing failed: \(message)")
            }
        }
    }

    private let client: OpenAIClient
    private let model: String
    private let languageDetector: LanguageDetector
    private let maxUploadBytes: Int
    private let targetUploadBytes: Int
    private let minimumChunkDurationSeconds: TimeInterval
    private let audioTranscoder: any AudioTranscoding

    init(
        client: OpenAIClient,
        model: String = "whisper-1",
        languageDetector: LanguageDetector,
        maxUploadBytes: Int = AppConfig.whisperMaxUploadBytes,
        targetUploadBytes: Int = AppConfig.whisperTargetUploadBytes,
        minimumChunkDurationSeconds: TimeInterval = 10,
        audioTranscoder: any AudioTranscoding = DefaultAudioTranscoder()
    ) {
        self.client = client
        self.model = model
        self.languageDetector = languageDetector
        self.maxUploadBytes = maxUploadBytes
        self.targetUploadBytes = targetUploadBytes
        self.minimumChunkDurationSeconds = minimumChunkDurationSeconds
        self.audioTranscoder = audioTranscoder
    }

    func transcribe(audioFileURL: URL) async throws -> TranscriptionResult {
        let uploads: [PreparedUpload]
        do {
            uploads = try await prepareUploads(audioFileURL: audioFileURL)
        } catch let error as PreprocessingError {
            throw error
        } catch {
            throw PreprocessingError.preprocessingFailed(error.localizedDescription)
        }

        defer {
            for upload in uploads {
                guard upload.shouldCleanup else { continue }
                try? FileManager.default.removeItem(at: upload.fileURL)
            }
        }

        let chunks = try await uploads.asyncMap { upload in
            try await transcribeSingleFile(upload: upload)
        }
        let finalText = chunks.joined(separator: AppConfig.transcriptionChunkJoinSeparator)
        let detected = languageDetector.detectLanguage(for: finalText) ?? .english
        return TranscriptionResult(text: finalText, inputLanguage: detected)
    }

    private func prepareUploads(audioFileURL: URL) async throws -> [PreparedUpload] {
        if audioFileURL.pathExtension.lowercased() == "m4a" {
            let sourceSize = try fileSizeBytes(of: audioFileURL)
            debugLog("Source m4a size: \(sourceSize) bytes (\(sourceSize / 1024) KB)")
            if sourceSize <= targetUploadBytes {
                return [PreparedUpload(fileURL: audioFileURL, shouldCleanup: false)]
            }
        }

        let fullCompressedURL = try await transcodeToM4A(sourceURL: audioFileURL, timeRange: nil)
        let fullCompressedSize = try fileSizeBytes(of: fullCompressedURL)
        debugLog("Compressed audio size: \(fullCompressedSize) bytes (\(fullCompressedSize / 1024) KB)")

        if fullCompressedSize <= targetUploadBytes {
            return [PreparedUpload(fileURL: fullCompressedURL, shouldCleanup: true)]
        }

        try? FileManager.default.removeItem(at: fullCompressedURL)

        let duration = try audioTranscoder.durationSeconds(sourceURL: audioFileURL)
        guard duration.isFinite, duration > 0 else {
            throw PreprocessingError.preprocessingFailed("Invalid source duration")
        }

        let chunkCount = max(2, Int(ceil(Double(fullCompressedSize) / Double(targetUploadBytes))))
        let fullRange = CMTimeRange(start: .zero, duration: CMTime(seconds: duration, preferredTimescale: 600))

        return try await splitRangeIntoUploads(
            sourceURL: audioFileURL,
            range: fullRange,
            chunkCount: chunkCount
        )
    }

    private func splitRangeIntoUploads(
        sourceURL: URL,
        range: CMTimeRange,
        chunkCount: Int
    ) async throws -> [PreparedUpload] {
        var outputs: [PreparedUpload] = []
        var createdURLs: [URL] = []

        do {
            let safeChunkCount = max(1, chunkCount)
            for index in 0..<safeChunkCount {
                let subrange = Self.subrange(of: range, index: index, total: safeChunkCount)
                let chunkURL = try await transcodeToM4A(sourceURL: sourceURL, timeRange: subrange)
                createdURLs.append(chunkURL)

                let size = try fileSizeBytes(of: chunkURL)
                if size <= maxUploadBytes {
                    outputs.append(PreparedUpload(fileURL: chunkURL, shouldCleanup: true))
                    continue
                }

                try? FileManager.default.removeItem(at: chunkURL)
                createdURLs.removeAll { $0 == chunkURL }

                let durationSeconds = CMTimeGetSeconds(subrange.duration)
                guard durationSeconds.isFinite, durationSeconds >= minimumChunkDurationSeconds else {
                    throw PreprocessingError.recordingTooLarge
                }

                let recursiveChunkCount = max(2, Int(ceil(Double(size) / Double(targetUploadBytes))))
                let recursiveOutputs = try await splitRangeIntoUploads(
                    sourceURL: sourceURL,
                    range: subrange,
                    chunkCount: recursiveChunkCount
                )
                outputs.append(contentsOf: recursiveOutputs)
            }
            return outputs
        } catch {
            let allURLsToDelete = Set(createdURLs + outputs.map(\.fileURL))
            for url in allURLsToDelete {
                try? FileManager.default.removeItem(at: url)
            }
            throw error
        }
    }

    private func transcribeSingleFile(upload: PreparedUpload) async throws -> String {
        let fileData = try Data(contentsOf: upload.fileURL)
        let filename = upload.fileURL.lastPathComponent
        debugLog("Transcribing chunk \(filename): \(fileData.count) bytes (\(fileData.count / 1024) KB)")

        var builder = MultipartFormBuilder()
        builder.field(name: "model", value: model)
        builder.field(name: "response_format", value: "json")
        builder.file(name: "file", filename: filename, mimeType: mimeType(for: upload.fileURL), data: fileData)

        let request = try client.makeRequest(
            path: "audio/transcriptions",
            method: "POST",
            headers: ["Content-Type": builder.contentType],
            body: builder.finalize()
        )

        let data = try await client.perform(request)
        let decoded = try JSONDecoder().decode(WhisperTranscriptionResponse.self, from: data)
        return decoded.text
    }

    private func transcodeToM4A(sourceURL: URL, timeRange: CMTimeRange?) async throws -> URL {
        do {
            return try await audioTranscoder.transcodeToM4A(sourceURL: sourceURL, timeRange: timeRange)
        } catch let error as PreprocessingError {
            throw error
        } catch {
            throw PreprocessingError.preprocessingFailed(error.localizedDescription)
        }
    }

    private func fileSizeBytes(of url: URL) throws -> Int {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        return values.fileSize ?? 0
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "m4a":
            return "audio/mp4"
        case "wav":
            return "audio/wav"
        default:
            return "application/octet-stream"
        }
    }

    private static func subrange(of range: CMTimeRange, index: Int, total: Int) -> CMTimeRange {
        let totalSeconds = CMTimeGetSeconds(range.duration)
        let chunkSeconds = totalSeconds / Double(total)
        let startSeconds = CMTimeGetSeconds(range.start) + (Double(index) * chunkSeconds)
        let isLast = index == total - 1
        let durationSeconds = isLast
            ? max(0, totalSeconds - (Double(index) * chunkSeconds))
            : chunkSeconds
        return CMTimeRange(
            start: CMTime(seconds: startSeconds, preferredTimescale: 600),
            duration: CMTime(seconds: durationSeconds, preferredTimescale: 600)
        )
    }

}

private extension Array {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async throws -> [T] {
        var output: [T] = []
        output.reserveCapacity(count)
        for element in self {
            output.append(try await transform(element))
        }
        return output
    }
}
