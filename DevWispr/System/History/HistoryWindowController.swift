//
//  HistoryWindowController.swift
//  DevWispr
//

import AppKit
import SwiftUI

@MainActor
final class HistoryWindowController {
    private var window: NSWindow?
    private let historyStore: HistoryStore
    private let failedRecordingStore: FailedRecordingStore
    private let recordingCoordinator: RecordingCoordinator
    private let audioPlaybackService: AudioPlaybackService
    private let analyticsService: AnalyticsService
    // Retained so search state and loaded pages survive window close/reopen.
    private lazy var viewModel = HistoryWindowViewModel(
        historyStore: historyStore,
        failedRecordingStore: failedRecordingStore,
        retryFailedAction: { [weak self] id in
            guard let self else { return false }
            return await self.recordingCoordinator.retryFailedRecording(id: id)
        },
        audioPlaybackService: audioPlaybackService,
        analyticsService: analyticsService
    )

    init(
        historyStore: HistoryStore,
        failedRecordingStore: FailedRecordingStore,
        recordingCoordinator: RecordingCoordinator,
        audioPlaybackService: AudioPlaybackService,
        analyticsService: AnalyticsService
    ) {
        self.historyStore = historyStore
        self.failedRecordingStore = failedRecordingStore
        self.recordingCoordinator = recordingCoordinator
        self.audioPlaybackService = audioPlaybackService
        self.analyticsService = analyticsService
    }

    func showWindow() {
        // Always reload so newly recorded items are visible.
        viewModel.loadInitialPage()

        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: HistoryWindowView(viewModel: viewModel))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Transcription History"
        window.contentViewController = hostingController
        window.minSize = NSSize(width: 400, height: 400)
        window.center()
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.titlebarAppearsTransparent = true
        window.backgroundColor = WisprTheme.backgroundNS

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
