//
//  HistoryWindowViewModel.swift
//  DevWispr
//

import AppKit
import Combine
import Foundation

@MainActor
final class HistoryWindowViewModel: ObservableObject {
    @Published var items: [TranscriptItem] = []
    @Published var failedItems: [FailedRecordingItem] = []
    @Published var searchQuery: String = ""
    @Published var hasMorePages: Bool = false
    @Published var errorMessage: String?
    @Published var showClearConfirmation: Bool = false
    @Published var retryingIDs: Set<UUID> = []
    @Published var playingFailedID: UUID?

    private let historyStore: HistoryStore
    private let failedRecordingStore: FailedRecordingStore
    private let retryFailedAction: @MainActor (UUID) async -> Bool
    private let audioPlaybackService: AudioPlaybackService
    private let analyticsService: AnalyticsService
    private var currentPage: Int = 0
    private let pageSize: Int = 50
    private var cancellables = Set<AnyCancellable>()

    @Published var totalCount: Int = 0

    init(
        historyStore: HistoryStore,
        failedRecordingStore: FailedRecordingStore,
        retryFailedAction: @escaping @MainActor (UUID) async -> Bool,
        audioPlaybackService: AudioPlaybackService,
        analyticsService: AnalyticsService
    ) {
        self.historyStore = historyStore
        self.failedRecordingStore = failedRecordingStore
        self.retryFailedAction = retryFailedAction
        self.audioPlaybackService = audioPlaybackService
        self.analyticsService = analyticsService

        NotificationCenter.default.publisher(for: .audioPlaybackDidFinish)
            .sink { [weak self] _ in
                self?.playingFailedID = nil
            }
            .store(in: &cancellables)

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

        loadFailedItems()
    }

    func loadFailedItems() {
        do {
            failedItems = try failedRecordingStore.list()
            if let playingID = playingFailedID, failedItems.contains(where: { $0.id == playingID }) == false {
                playingFailedID = nil
            }
        } catch {
            errorMessage = String(localized: "Failed to load failed recordings.")
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

    func togglePlayFailed(_ item: FailedRecordingItem) {
        do {
            if playingFailedID == item.id {
                audioPlaybackService.stop()
                playingFailedID = nil
                analyticsService.logEvent(.failedRecordingPlaybackStopped)
                return
            }

            let url = try failedRecordingStore.url(for: item.id)
            try audioPlaybackService.play(url: url)
            playingFailedID = item.id
            analyticsService.logEvent(.failedRecordingPlaybackStarted)
        } catch {
            playingFailedID = nil
            errorMessage = String(localized: "Unable to play failed recording: \(error.localizedDescription)")
        }
    }

    func retryFailed(_ item: FailedRecordingItem) {
        guard !retryingIDs.contains(item.id) else { return }
        retryingIDs.insert(item.id)

        Task {
            let didSucceed = await retryFailedAction(item.id)
            retryingIDs.remove(item.id)
            if didSucceed {
                if playingFailedID == item.id {
                    audioPlaybackService.stop()
                    playingFailedID = nil
                    analyticsService.logEvent(.failedRecordingPlaybackStopped)
                }
                loadInitialPage()
            } else {
                loadFailedItems()
                errorMessage = String(localized: "Retry failed. The recording is still available.")
            }
        }
    }

    func revealFailedFile(_ item: FailedRecordingItem) {
        do {
            let url = try failedRecordingStore.url(for: item.id)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            errorMessage = String(localized: "Unable to reveal failed recording: \(error.localizedDescription)")
        }
    }

    func deleteFailed(_ item: FailedRecordingItem) {
        do {
            if playingFailedID == item.id {
                audioPlaybackService.stop()
                playingFailedID = nil
                analyticsService.logEvent(.failedRecordingPlaybackStopped)
            }
            try failedRecordingStore.delete(id: item.id)
            analyticsService.logEvent(.failedRecordingDeleted)
            loadFailedItems()
        } catch {
            errorMessage = String(localized: "Failed to delete failed recording.")
        }
    }

    func clearAll() {
        do {
            audioPlaybackService.stop()
            playingFailedID = nil

            try historyStore.clearAll()
            try failedRecordingStore.deleteAll()
            analyticsService.logEvent(.historyCleared)
            analyticsService.logEvent(.failedRecordingsCleared)

            items = []
            failedItems = []
            totalCount = 0
            hasMorePages = false
            retryingIDs = []
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Failed to clear history.")
        }
    }
}
