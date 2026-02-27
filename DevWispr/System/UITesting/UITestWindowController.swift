//
//  UITestWindowController.swift
//  DevWispr
//

#if DEBUG
import AppKit
import SwiftUI

@MainActor
final class UITestWindowController {
    private var window: NSWindow?
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func showWindow() {
        let hostingController = NSHostingController(
            rootView: PopoverContentView().environmentObject(appState)
        )
        hostingController.sizingOptions = .preferredContentSize

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 700),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DevWispr"
        window.contentViewController = hostingController
        window.center()
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)

        self.window = window
        window.makeKeyAndOrderFront(nil)
    }
}
#endif
