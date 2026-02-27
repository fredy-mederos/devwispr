//
//  PopoverController.swift
//  DevWispr
//

import AppKit
import Combine
import SwiftUI

/// Manages the NSStatusItem (menu bar icon) and the NSPopover that serves as the
/// app's primary UI. Left-click toggles the popover; right-click shows a minimal
/// context menu with "Open DevWispr" and "Quit".
@MainActor
final class PopoverController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()
    private var escapeMonitor: Any?

    init(appState: AppState) {
        self.appState = appState
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureStatusButton()
        configurePopover()
        observeState()
    }

    // MARK: - Setup

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        let image = NSImage(systemSymbolName: "mic.badge.plus", accessibilityDescription: "DevWispr")
        image?.isTemplate = true
        button.image = image
        button.toolTip = "DevWispr"
        button.target = self
        button.action = #selector(handleButtonClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configurePopover() {
        // .transient: popover auto-closes when the app loses focus, preventing
        // the sheet inside from being stranded when the user switches to another app.
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        let hostingController = NSHostingController(
            rootView: PopoverContentView()
                .environmentObject(appState)
        )
        hostingController.sizingOptions = .preferredContentSize
        hostingController.view.appearance = NSAppearance(named: .darkAqua)
        popover.contentViewController = hostingController
    }

    // MARK: - NSPopoverDelegate

    nonisolated func popoverDidClose(_ notification: Notification) {
        // Reset sheet state so it can never be left "open" inside a closed popover,
        // which would make the UI unresponsive when the popover is reopened.
        Task { @MainActor in
            self.appState.showApiKeySetup = false
            self.removeEscapeMonitor()
        }
    }

    // MARK: - Actions

    @objc private func handleButtonClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
            return
        }

        togglePopover(sender)
    }

    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            appState.refreshPermissionStatus()
            appState.reloadAPIKeyState()
            appState.refreshLaunchAtLoginState()
            appState.refreshShortcutsState()
            appState.reloadHistory()
            Task { await appState.checkForUpdates() }
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            // Force dark appearance on the popover window after it is shown.
            popover.contentViewController?.view.window?.appearance = NSAppearance(named: .darkAqua)
            NSApp.activate(ignoringOtherApps: true)
            installEscapeMonitor()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let openItem = NSMenuItem(title: String(localized: "Open DevWispr"), action: #selector(openPopover), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: String(localized: "Quit"), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        // Temporarily assign menu so the right-click shows it, then immediately remove it
        // so left-click continues to drive the popover toggle.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openPopover() {
        guard let button = statusItem.button else { return }
        togglePopover(button)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Escape Key Handling

    private func installEscapeMonitor() {
        guard escapeMonitor == nil else { return }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.popover.isShown, event.keyCode == 53 else { return event }
            // If the API key sheet is open, let Escape propagate so the sheet dismisses itself
            if self.appState.showApiKeySetup { return event }
            self.popover.performClose(nil)
            return nil
        }
    }

    private func removeEscapeMonitor() {
        if let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
            escapeMonitor = nil
        }
    }

    // MARK: - State Observation

    private func observeState() {
        appState.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                self.updateIcon(status: status, error: self.appState.lastError)
            }
            .store(in: &cancellables)

        appState.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                guard let self else { return }
                self.updateIcon(status: self.appState.status, error: error)
            }
            .store(in: &cancellables)
    }

    private func updateIcon(status: AppStatus, error: String?) {
        guard let button = statusItem.button else { return }

        let symbolName: String
        if let e = error, !e.isEmpty {
            symbolName = "exclamationmark.triangle.fill"
        } else {
            switch status {
            case .recording:               symbolName = "mic.circle.fill"
            case .transcribing, .translating: symbolName = "waveform.circle"
            case .inserting:               symbolName = "doc.on.clipboard"
            default:                       symbolName = "mic.badge.plus"
            }
        }

        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "DevWispr")
        image?.isTemplate = true
        button.image = image
        button.toolTip = "DevWispr"
    }

}
