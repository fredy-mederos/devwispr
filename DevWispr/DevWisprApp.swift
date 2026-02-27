//
//  DevWisprApp.swift
//  DevWispr
//

import AppKit
import SwiftUI

@main
struct DevWisprApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Menu-bar only app — no window opened on launch.
        // All lifecycle and window management is handled by AppDelegate.
        Settings {
            EmptyView()
        }
    }
}
