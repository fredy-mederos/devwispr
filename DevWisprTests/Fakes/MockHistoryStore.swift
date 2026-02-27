//
//  MockHistoryStore.swift
//  DevWisprTests
//

import Foundation
@testable import DevWispr

final class MockHistoryStore: HistoryStore {
    var shouldThrow: Error?
    var items: [TranscriptItem] = []
    var addCallCount = 0
    var clearAllCallCount = 0

    func add(_ item: TranscriptItem) throws {
        addCallCount += 1
        if let error = shouldThrow { throw error }
        items.insert(item, at: 0)
    }

    func list(page: Int, pageSize: Int) throws -> [TranscriptItem] {
        if let error = shouldThrow { throw error }
        let sorted = items.sorted { $0.createdAt > $1.createdAt }
        return paginate(sorted, page: page, pageSize: pageSize)
    }

    func search(query: String, page: Int, pageSize: Int) throws -> [TranscriptItem] {
        if let error = shouldThrow { throw error }
        let filtered = items.filter { $0.text.localizedCaseInsensitiveContains(query) }
        return paginate(filtered, page: page, pageSize: pageSize)
    }

    func count(query: String) throws -> Int {
        if let error = shouldThrow { throw error }
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            return items.count
        }
        return items.filter { $0.text.localizedCaseInsensitiveContains(query) }.count
    }

    func clearAll() throws {
        clearAllCallCount += 1
        if let error = shouldThrow { throw error }
        items.removeAll()
    }

}
