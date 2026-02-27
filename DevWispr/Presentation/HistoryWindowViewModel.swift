//
//  HistoryWindowViewModel.swift
//  DevWispr
//

import Combine
import Foundation

@MainActor
final class HistoryWindowViewModel: ObservableObject {
    @Published var items: [TranscriptItem] = []
    @Published var searchQuery: String = ""
    @Published var hasMorePages: Bool = false
    @Published var errorMessage: String?
    @Published var showClearConfirmation: Bool = false

    private let historyStore: HistoryStore
    private var currentPage: Int = 0
    private let pageSize: Int = 50

    @Published var totalCount: Int = 0

    init(historyStore: HistoryStore) {
        self.historyStore = historyStore
        loadInitialPage()
    }

    func loadInitialPage() {
        currentPage = 0
        do {
            let results: [TranscriptItem]
            if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                results = try historyStore.list(page: 0, pageSize: pageSize)
            } else {
                results = try historyStore.search(query: searchQuery, page: 0, pageSize: pageSize)
            }
            items = results
            totalCount = (try? historyStore.count(query: searchQuery)) ?? results.count
            hasMorePages = results.count == pageSize
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Failed to load history.")
        }
    }

    func loadNextPage() {
        currentPage += 1
        do {
            let results: [TranscriptItem]
            if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                results = try historyStore.list(page: currentPage, pageSize: pageSize)
            } else {
                results = try historyStore.search(query: searchQuery, page: currentPage, pageSize: pageSize)
            }
            items.append(contentsOf: results)
            hasMorePages = results.count == pageSize
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Failed to load more history.")
        }
    }

    func performSearch() {
        loadInitialPage()
    }

    func clearSearch() {
        searchQuery = ""
        loadInitialPage()
    }

    func clearAll() {
        do {
            try historyStore.clearAll()
            items = []
            totalCount = 0
            hasMorePages = false
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Failed to clear history.")
        }
    }
}
