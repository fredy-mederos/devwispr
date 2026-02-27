//
//  DeepLinkHandler.swift
//  DevWispr
//

import AppKit
import Foundation

struct DeepLinkHandler {
    @MainActor
    static func handle(_ url: URL, appState: AppState) {
        guard url.scheme == "devwispr", url.host == "configure" else { return }
        let params = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems

        if let baseURL = params?.first(where: { $0.name == "baseURL" })?.value, !baseURL.isEmpty {
            let apiKeyURL = params?.first(where: { $0.name == "apiKeyURL" })?.value
            showConfirmation(baseURL: baseURL, apiKeyURL: apiKeyURL, appState: appState)
        }
    }

    @MainActor
    private static func showConfirmation(baseURL: String, apiKeyURL: String?, appState: AppState) {
        var message = String(localized: "DevWispr received a configuration request.\n\nSet API base URL to:\n\(baseURL)")
        if let apiKeyURL, !apiKeyURL.isEmpty {
            message += String(localized: "\n\nAPI key URL:\n\(apiKeyURL)")
        }

        let alert = NSAlert()
        alert.messageText = String(localized: "Configure DevWispr")
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "Apply"))
        alert.addButton(withTitle: String(localized: "Cancel"))

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            appState.apiProvider = .custom
            appState.customBaseURL = baseURL
            appState.customApiKeyURL = apiKeyURL ?? ""
        }
    }
}
