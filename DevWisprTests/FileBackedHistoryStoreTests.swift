//
//  FileBackedHistoryStoreTests.swift
//  DevWisprTests
//

import Foundation
import Testing
@testable import DevWispr

@Suite("FileBackedHistoryStore Tests")
struct FileBackedHistoryStoreTests {
    private func makeSUT() -> (FileBackedHistoryStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = FileBackedHistoryStore(directory: dir)
        return (store, dir)
    }

    private func makeItem(text: String = "Hello", date: Date = Date()) -> TranscriptItem {
        TranscriptItem(
            createdAt: date,
            text: text,
            inputLanguage: .english,
            outputLanguage: .english
        )
    }

    @Test("Add and list returns item")
    func addAndList() throws {
        let (store, _) = makeSUT()
        let item = makeItem()
        try store.add(item)
        let items = try store.list(page: 0, pageSize: 10)
        #expect(items.count == 1)
        #expect(items.first?.text == "Hello")
    }

    @Test("Items returned in reverse chronological order")
    func reverseChronologicalOrder() throws {
        let (store, _) = makeSUT()
        let older = makeItem(text: "First", date: Date(timeIntervalSinceNow: -60))
        let newer = makeItem(text: "Second", date: Date())
        try store.add(older)
        try store.add(newer)
        let items = try store.list(page: 0, pageSize: 10)
        #expect(items.count == 2)
        #expect(items[0].text == "Second")
        #expect(items[1].text == "First")
    }

    @Test("Pagination page 0 vs page 1")
    func pagination() throws {
        let (store, _) = makeSUT()
        for i in 0..<5 {
            try store.add(makeItem(text: "Item \(i)", date: Date(timeIntervalSinceNow: Double(-i))))
        }
        let page0 = try store.list(page: 0, pageSize: 3)
        let page1 = try store.list(page: 1, pageSize: 3)
        #expect(page0.count == 3)
        #expect(page1.count == 2)
    }

    @Test("Beyond-data page returns empty")
    func beyondDataReturnsEmpty() throws {
        let (store, _) = makeSUT()
        try store.add(makeItem())
        let page = try store.list(page: 10, pageSize: 10)
        #expect(page.isEmpty)
    }

    @Test("Search case-insensitive match")
    func searchMatch() throws {
        let (store, _) = makeSUT()
        try store.add(makeItem(text: "Hello World"))
        try store.add(makeItem(text: "Goodbye"))
        let results = try store.search(query: "hello", page: 0, pageSize: 10)
        #expect(results.count == 1)
        #expect(results.first?.text == "Hello World")
    }

    @Test("Search no match returns empty")
    func searchNoMatch() throws {
        let (store, _) = makeSUT()
        try store.add(makeItem(text: "Hello World"))
        let results = try store.search(query: "zzzzz", page: 0, pageSize: 10)
        #expect(results.isEmpty)
    }

    @Test("clearAll removes everything")
    func clearAll() throws {
        let (store, _) = makeSUT()
        try store.add(makeItem())
        try store.add(makeItem())
        try store.clearAll()
        let items = try store.list(page: 0, pageSize: 10)
        #expect(items.isEmpty)
    }

    @Test("Cap at 1000 items evicts oldest")
    func capAt1000() throws {
        let (store, _) = makeSUT()
        for i in 0..<1001 {
            try store.add(makeItem(text: "Item \(i)", date: Date(timeIntervalSinceNow: Double(i))))
        }
        let items = try store.list(page: 0, pageSize: 1001)
        #expect(items.count == 1000)
        // The most recent item should be present
        #expect(items[0].text == "Item 1000")
    }

    @Test("Persistence across instances")
    func persistence() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store1 = FileBackedHistoryStore(directory: dir)
        try store1.add(makeItem(text: "Persisted"))

        let store2 = FileBackedHistoryStore(directory: dir)
        let items = try store2.list(page: 0, pageSize: 10)
        #expect(items.count == 1)
        #expect(items.first?.text == "Persisted")
    }
}
