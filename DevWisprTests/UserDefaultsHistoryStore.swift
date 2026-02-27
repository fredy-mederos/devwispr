//
//  UserDefaultsHistoryStore.swift
//  DevWisprTests
//
//  UserDefaultsHistoryStore is dead production code — AppContainer always uses
//  FileBackedHistoryStore. Kept in the test target only, for its own tests.
//

import Foundation
@testable import DevWispr

final class UserDefaultsHistoryStore: HistoryStore {
    private enum Keys {
        static let items = "history.items"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func add(_ item: TranscriptItem) throws {
        var items = try loadItems()
        items.insert(item, at: 0)
        try store(items)
    }

    func list(page: Int, pageSize: Int) throws -> [TranscriptItem] {
        let items = try loadItems()
        return paginate(items, page: page, pageSize: pageSize)
    }

    func search(query: String, page: Int, pageSize: Int) throws -> [TranscriptItem] {
        let items = try loadItems()
        let filtered = items.filter { $0.text.localizedCaseInsensitiveContains(query) }
        return paginate(filtered, page: page, pageSize: pageSize)
    }

    func count(query: String) throws -> Int {
        let items = try loadItems()
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            return items.count
        }
        return items.filter { $0.text.localizedCaseInsensitiveContains(query) }.count
    }

    func clearAll() throws {
        defaults.removeObject(forKey: Keys.items)
    }

    private func loadItems() throws -> [TranscriptItem] {
        guard let data = defaults.data(forKey: Keys.items) else { return [] }
        return try decoder.decode([TranscriptItem].self, from: data)
            .sorted(by: { $0.createdAt > $1.createdAt })
    }

    private func store(_ items: [TranscriptItem]) throws {
        let data = try encoder.encode(items)
        defaults.set(data, forKey: Keys.items)
    }
}
