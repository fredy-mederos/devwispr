//
//  MockFailedRecordingStore.swift
//  DevWisprTests
//

import Foundation
@testable import DevWispr

final class MockFailedRecordingStore: FailedRecordingStore {
    var shouldThrow: Error?
    var items: [FailedRecordingItem] = []
    var addCallCount = 0
    var updateFailureCallCount = 0
    var deleteCallCount = 0
    var deleteAllCallCount = 0
    var markResolvedCallCount = 0
    var lastAddedError: String?
    var lastUpdatedError: String?

    func addFromTemporaryFile(sourceURL: URL, lastError: String) throws -> FailedRecordingItem {
        addCallCount += 1
        lastAddedError = lastError
        if let error = shouldThrow { throw error }
        let item = FailedRecordingItem(
            audioFileName: sourceURL.lastPathComponent,
            fileSizeBytes: 0,
            durationSeconds: 0,
            lastError: lastError
        )
        items.insert(item, at: 0)
        return item
    }

    func list() throws -> [FailedRecordingItem] {
        if let error = shouldThrow { throw error }
        return items.sorted { $0.updatedAt > $1.updatedAt }
    }

    func updateFailure(id: UUID, lastError: String) throws {
        updateFailureCallCount += 1
        lastUpdatedError = lastError
        if let error = shouldThrow { throw error }
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].updatedAt = Date()
        items[idx].lastError = lastError
        items[idx].retryCount += 1
    }

    func delete(id: UUID) throws {
        deleteCallCount += 1
        if let error = shouldThrow { throw error }
        items.removeAll { $0.id == id }
    }

    func deleteAll() throws {
        deleteAllCallCount += 1
        if let error = shouldThrow { throw error }
        items.removeAll()
    }

    func url(for id: UUID) throws -> URL {
        if let error = shouldThrow { throw error }
        guard let item = items.first(where: { $0.id == id }) else {
            throw FailedRecordingStoreError.itemNotFound
        }
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(item.audioFileName)
    }

    func markResolved(id: UUID) throws {
        markResolvedCallCount += 1
        if let error = shouldThrow { throw error }
        items.removeAll { $0.id == id }
    }
}
