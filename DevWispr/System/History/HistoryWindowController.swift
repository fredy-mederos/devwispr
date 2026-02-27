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
    // Retained so search state and loaded pages survive window close/reopen.
    private lazy var viewModel = HistoryWindowViewModel(historyStore: historyStore)

    init(historyStore: HistoryStore) {
        self.historyStore = historyStore
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
