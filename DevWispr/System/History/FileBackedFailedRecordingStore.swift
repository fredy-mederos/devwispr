//
//  FileBackedFailedRecordingStore.swift
//  DevWispr
//

import AVFoundation
import Foundation

enum FailedRecordingStoreError: LocalizedError {
    case itemNotFound

    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return String(localized: "Failed recording not found.")
        }
    }
}

final class FileBackedFailedRecordingStore: FailedRecordingStore {
    private let metadataURL: URL
    private let audioDirectoryURL: URL
    private let lock = NSLock()
    private var cachedItems: [FailedRecordingItem]?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directory: URL? = nil) {
        let rootDirectory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("com.auto1.wispr")
        self.metadataURL = rootDirectory.appendingPathComponent("failed_recordings.json")
        self.audioDirectoryURL = rootDirectory.appendingPathComponent("failed_recordings")

        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        try? FileManager.default.createDirectory(at: audioDirectoryURL, withIntermediateDirectories: true)
    }

    func addFromTemporaryFile(sourceURL: URL, lastError: String) throws -> FailedRecordingItem {
        lock.lock()
        defer { lock.unlock() }

        var items = try loadItemsLocked()

        let id = UUID()
        let ext = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension
        let destinationName = "\(id.uuidString).\(ext)"
        let destinationURL = audioDirectoryURL.appendingPathComponent(destinationName)

        let duration = try durationInSeconds(for: sourceURL)
        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)

        let fileSize = (try FileManager.default.attributesOfItem(atPath: destinationURL.path)[.size] as? NSNumber)?.int64Value ?? 0
        let now = Date()
        let item = FailedRecordingItem(
            id: id,
            createdAt: now,
            updatedAt: now,
            audioFileName: destinationName,
            fileSizeBytes: fileSize,
            durationSeconds: duration,
            lastError: lastError,
            retryCount: 0
        )
        items.insert(item, at: 0)
        try storeLocked(items)
        return item
    }

    func list() throws -> [FailedRecordingItem] {
        lock.lock()
        defer { lock.unlock() }

        let items = try loadItemsLocked()
        return items.sorted { $0.updatedAt > $1.updatedAt }
    }

    func updateFailure(id: UUID, lastError: String) throws {
        lock.lock()
        defer { lock.unlock() }

        var items = try loadItemsLocked()
        guard let idx = items.firstIndex(where: { $0.id == id }) else {
            throw FailedRecordingStoreError.itemNotFound
        }

        items[idx].updatedAt = Date()
        items[idx].lastError = lastError
        items[idx].retryCount += 1

        try storeLocked(items)
    }

    func delete(id: UUID) throws {
        lock.lock()
        defer { lock.unlock() }

        var items = try loadItemsLocked()
        guard let idx = items.firstIndex(where: { $0.id == id }) else {
            throw FailedRecordingStoreError.itemNotFound
        }

        let fileURL = audioDirectoryURL.appendingPathComponent(items[idx].audioFileName)
        try? FileManager.default.removeItem(at: fileURL)
        items.remove(at: idx)
        try storeLocked(items)
    }

    func deleteAll() throws {
        lock.lock()
        defer { lock.unlock() }

        let items = try loadItemsLocked()
        for item in items {
            let fileURL = audioDirectoryURL.appendingPathComponent(item.audioFileName)
            try? FileManager.default.removeItem(at: fileURL)
        }

        try storeLocked([])
    }

    func url(for id: UUID) throws -> URL {
        lock.lock()
        defer { lock.unlock() }

        let items = try loadItemsLocked()
        guard let item = items.first(where: { $0.id == id }) else {
            throw FailedRecordingStoreError.itemNotFound
        }

        return audioDirectoryURL.appendingPathComponent(item.audioFileName)
    }

    func markResolved(id: UUID) throws {
        try delete(id: id)
    }

    // MARK: - Private

    private func loadItemsLocked() throws -> [FailedRecordingItem] {
        if let cached = cachedItems {
            return cached
        }

        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            cachedItems = []
            return []
        }

        let data = try Data(contentsOf: metadataURL)
        let items = try decoder.decode([FailedRecordingItem].self, from: data)
        cachedItems = items
        return items
    }

    private func storeLocked(_ items: [FailedRecordingItem]) throws {
        let data = try encoder.encode(items)
        try data.write(to: metadataURL, options: .atomic)
        cachedItems = items
    }

    private func durationInSeconds(for fileURL: URL) throws -> TimeInterval {
        let audio = try AVAudioFile(forReading: fileURL)
        guard audio.fileFormat.sampleRate > 0 else { return 0 }
        return TimeInterval(audio.length) / audio.fileFormat.sampleRate
    }
}
