//
//  HistoryWindowViewModelTests.swift
//  DevWisprTests
//

import Foundation
import Testing
@testable import DevWispr

@Suite("HistoryWindowViewModel Tests")
@MainActor
struct HistoryWindowViewModelTests {

    @Test("loadInitialPage includes failed items")
    func loadInitialPageIncludesFailedItems() {
        let historyStore = MockHistoryStore()
        historyStore.items = [TranscriptItem(text: "ok", inputLanguage: .english, outputLanguage: .english)]

        let failedStore = MockFailedRecordingStore()
        failedStore.items = [
            FailedRecordingItem(audioFileName: "a.wav", fileSizeBytes: 1_000, durationSeconds: 1, lastError: "timeout")
        ]

        let viewModel = HistoryWindowViewModel(
            historyStore: historyStore,
            failedRecordingStore: failedStore,
            retryFailedAction: { _ in true },
            audioPlaybackService: MockAudioPlaybackService(),
            analyticsService: MockAnalyticsService()
        )

        #expect(viewModel.items.count == 1)
        #expect(viewModel.failedItems.count == 1)
    }

    @Test("togglePlayFailed updates playingFailedID")
    func togglePlayFailedUpdatesPlayingID() {
        let historyStore = MockHistoryStore()
        let failedStore = MockFailedRecordingStore()
        let item = FailedRecordingItem(audioFileName: "a.wav", fileSizeBytes: 1_000, durationSeconds: 1, lastError: "timeout")
        failedStore.items = [item]
        let playback = MockAudioPlaybackService()

        let viewModel = HistoryWindowViewModel(
            historyStore: historyStore,
            failedRecordingStore: failedStore,
            retryFailedAction: { _ in true },
            audioPlaybackService: playback,
            analyticsService: MockAnalyticsService()
        )

        viewModel.togglePlayFailed(item)
        #expect(viewModel.playingFailedID == item.id)

        viewModel.togglePlayFailed(item)
        #expect(viewModel.playingFailedID == nil)
        #expect(playback.stopCallCount == 1)
    }

    @Test("playing another failed item switches active playback")
    func playSecondItemSwitchesActivePlayback() {
        let historyStore = MockHistoryStore()
        let failedStore = MockFailedRecordingStore()
        let first = FailedRecordingItem(audioFileName: "a.wav", fileSizeBytes: 1_000, durationSeconds: 1, lastError: "timeout")
        let second = FailedRecordingItem(audioFileName: "b.wav", fileSizeBytes: 2_000, durationSeconds: 2, lastError: "network")
        failedStore.items = [first, second]
        let playback = MockAudioPlaybackService()

        let viewModel = HistoryWindowViewModel(
            historyStore: historyStore,
            failedRecordingStore: failedStore,
            retryFailedAction: { _ in true },
            audioPlaybackService: playback,
            analyticsService: MockAnalyticsService()
        )

        viewModel.togglePlayFailed(first)
        viewModel.togglePlayFailed(second)

        #expect(viewModel.playingFailedID == second.id)
        #expect(playback.currentURL?.lastPathComponent == "b.wav")
        #expect(playback.playCallCount == 2)
    }

    @Test("retryFailed refreshes data")
    func retryFailedRefreshesLists() async {
        let historyStore = MockHistoryStore()
        let failedStore = MockFailedRecordingStore()
        let item = FailedRecordingItem(audioFileName: "a.wav", fileSizeBytes: 1_000, durationSeconds: 1, lastError: "timeout")
        failedStore.items = [item]

        var retriedIDs: [UUID] = []
        let viewModel = HistoryWindowViewModel(
            historyStore: historyStore,
            failedRecordingStore: failedStore,
            retryFailedAction: { id in
                retriedIDs.append(id)
                return true
            },
            audioPlaybackService: MockAudioPlaybackService(),
            analyticsService: MockAnalyticsService()
        )

        viewModel.retryFailed(item)
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(retriedIDs == [item.id])
        #expect(viewModel.retryingIDs.isEmpty)
    }

    @Test("clearAll clears both stores and stops playback")
    func clearAllClearsBothStoresAndStopsPlayback() {
        let historyStore = MockHistoryStore()
        historyStore.items = [TranscriptItem(text: "ok", inputLanguage: .english, outputLanguage: .english)]
        let failedStore = MockFailedRecordingStore()
        let item = FailedRecordingItem(audioFileName: "a.wav", fileSizeBytes: 1_000, durationSeconds: 1, lastError: "timeout")
        failedStore.items = [item]
        let playback = MockAudioPlaybackService()

        let viewModel = HistoryWindowViewModel(
            historyStore: historyStore,
            failedRecordingStore: failedStore,
            retryFailedAction: { _ in true },
            audioPlaybackService: playback,
            analyticsService: MockAnalyticsService()
        )

        viewModel.togglePlayFailed(item)
        viewModel.clearAll()

        #expect(historyStore.items.isEmpty)
        #expect(failedStore.items.isEmpty)
        #expect(playback.stopCallCount >= 1)
        #expect(viewModel.items.isEmpty)
        #expect(viewModel.failedItems.isEmpty)
    }
}
