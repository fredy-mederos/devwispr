//
//  FileBackedHistoryStore.swift
//  DevWispr
//

import Foundation

final class FileBackedHistoryStore: HistoryStore {
    private let fileURL: URL
    private let maxItems = 1000
    private let lock = NSLock()
    private var cachedItems: [TranscriptItem]?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private static let migrationKey = "history.migratedToFile"
    private static let legacyKey = "history.items"

    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("com.auto1.wispr")
        self.fileURL = dir.appendingPathComponent("history.json")

        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        if directory == nil {
            migrateFromUserDefaultsIfNeeded()
        }
    }

    func add(_ item: TranscriptItem) throws {
        lock.lock()
        defer { lock.unlock() }

        var items = try loadItemsLocked()
        items.insert(item, at: 0)
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }
        try storeLocked(items)
    }

    func list(page: Int, pageSize: Int) throws -> [TranscriptItem] {
        lock.lock()
        defer { lock.unlock() }

        let items = try loadItemsLocked()
        return paginate(items, page: page, pageSize: pageSize)
    }

    func search(query: String, page: Int, pageSize: Int) throws -> [TranscriptItem] {
        lock.lock()
        defer { lock.unlock() }

        let items = try loadItemsLocked()
        let filtered = items.filter { $0.text.localizedCaseInsensitiveContains(query) }
        return paginate(filtered, page: page, pageSize: pageSize)
    }

    func count(query: String) throws -> Int {
        lock.lock()
        defer { lock.unlock() }

        let items = try loadItemsLocked()
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            return items.count
        }
        return items.filter { $0.text.localizedCaseInsensitiveContains(query) }.count
    }

    func clearAll() throws {
        lock.lock()
        defer { lock.unlock() }

        cachedItems = []
        try storeLocked([])
    }

    // MARK: - Private

    private func loadItemsLocked() throws -> [TranscriptItem] {
        if let cached = cachedItems { return cached }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            cachedItems = []
            return []
        }

        let data = try Data(contentsOf: fileURL)
        let items = try decoder.decode([TranscriptItem].self, from: data)
            .sorted { $0.createdAt > $1.createdAt }
        cachedItems = items
        return items
    }

    private func storeLocked(_ items: [TranscriptItem]) throws {
        let data = try encoder.encode(items)
        try data.write(to: fileURL, options: .atomic)
        cachedItems = items
    }

    // MARK: - Migration

    private func migrateFromUserDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.migrationKey) else { return }
        defer { defaults.set(true, forKey: Self.migrationKey) }

        guard let data = defaults.data(forKey: Self.legacyKey) else { return }

        do {
            let items = try decoder.decode([TranscriptItem].self, from: data)
                .sorted { $0.createdAt > $1.createdAt }
            let capped = Array(items.prefix(maxItems))

            lock.lock()
            try storeLocked(capped)
            lock.unlock()

            defaults.removeObject(forKey: Self.legacyKey)
            debugLog("Migrated \(capped.count) history items from UserDefaults to file.")
        } catch {
            debugLog("History migration failed: \(error)")
        }
    }
}
