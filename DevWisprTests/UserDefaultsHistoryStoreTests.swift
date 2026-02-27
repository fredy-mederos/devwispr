//
//  UserDefaultsHistoryStoreTests.swift
//  DevWisprTests
//

import Foundation
import Testing
@testable import DevWispr

@Suite("UserDefaultsHistoryStore Tests")
struct UserDefaultsHistoryStoreTests {
    private func makeSUT() -> UserDefaultsHistoryStore {
        let suiteName = "test.history.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return UserDefaultsHistoryStore(defaults: defaults)
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
        let store = makeSUT()
        let item = makeItem()
        try store.add(item)
        let items = try store.list(page: 0, pageSize: 10)
        #expect(items.count == 1)
        #expect(items.first?.text == "Hello")
    }

    @Test("Items returned in reverse chronological order")
    func reverseChronologicalOrder() throws {
        let store = makeSUT()
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
        let store = makeSUT()
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
        let store = makeSUT()
        try store.add(makeItem())
        let page = try store.list(page: 10, pageSize: 10)
        #expect(page.isEmpty)
    }

    @Test("Search case-insensitive match")
    func searchMatch() throws {
        let store = makeSUT()
        try store.add(makeItem(text: "Hello World"))
        try store.add(makeItem(text: "Goodbye"))
        let results = try store.search(query: "hello", page: 0, pageSize: 10)
        #expect(results.count == 1)
        #expect(results.first?.text == "Hello World")
    }

    @Test("Search no match returns empty")
    func searchNoMatch() throws {
        let store = makeSUT()
        try store.add(makeItem(text: "Hello World"))
        let results = try store.search(query: "zzzzz", page: 0, pageSize: 10)
        #expect(results.isEmpty)
    }

    @Test("clearAll removes everything")
    func clearAll() throws {
        let store = makeSUT()
        try store.add(makeItem())
        try store.add(makeItem())
        try store.clearAll()
        let items = try store.list(page: 0, pageSize: 10)
        #expect(items.isEmpty)
    }
}
