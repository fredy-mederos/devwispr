//
//  PopoverContentView.swift
//  DevWispr
//

import SwiftUI
import AppKit

// MARK: - Main Popover

struct PopoverContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: WisprTheme.sectionSpacing) {
                headerSection
                statusCard
                historyCard
                permissionWarnings
                sectionLabel("Settings")
                languageCard
                insertionModeCard
                launchAtLoginCard
                shortcutsCard
                sectionLabel("API Configuration")
                proxyURLCard
                apiKeyCard
                Spacer(minLength: 4)
                footerSection
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .frame(width: WisprTheme.popoverWidth)
        .fixedSize(horizontal: true, vertical: true)
        .background(WisprTheme.background)
        .sheet(isPresented: $appState.showApiKeySetup) {
            PopoverApiKeySetupView()
                .environmentObject(appState)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "mic.badge.plus")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(WisprTheme.statusRecording)

            Text("DevWispr")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(WisprTheme.textPrimary)

            Spacer()

            Circle()
                .fill(statusDotColor)
                .frame(width: 7, height: 7)

            Text(appState.status.localizedName)
                .font(.system(size: 11))
                .foregroundStyle(WisprTheme.textSecondary)
                .accessibilityIdentifier("popover_status_label")
                .accessibilityLabel(appState.status.localizedName)
        }
        .padding(.horizontal, 4)
    }

    private var statusDotColor: Color {
        guard appState.lastError == nil else { return WisprTheme.statusError }
        switch appState.status {
        case .idle:                          return WisprTheme.statusOK
        case .recording:                     return WisprTheme.statusRecording
        case .transcribing, .translating:    return WisprTheme.statusWarning
        case .inserting:                     return WisprTheme.statusOK
        case .error:                         return WisprTheme.statusError
        }
    }



    // MARK: - Status / Recording Card

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let error = appState.lastError {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(WisprTheme.statusWarning)
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(WisprTheme.statusWarning)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                Task { await appState.toggleRecording() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: appState.status == .recording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 14))
                    Text(appState.status == .recording ? "Stop" : "Record")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(appState.status == .recording ? WisprTheme.statusError : WisprTheme.statusRecording)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    (appState.status == .recording ? WisprTheme.statusError : WisprTheme.statusRecording)
                        .opacity(0.15)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("popover_record_button")

        }
        .wisprCard()
    }

    // MARK: - History Card

    @ViewBuilder
    private var historyCard: some View {
        if appState.historyCount > 0 {
            Button {
                appState.openHistory()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 14))
                        .foregroundStyle(WisprTheme.historyAccent)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("History")
                                .font(.system(size: 13))
                                .foregroundStyle(WisprTheme.textPrimary)
                            Text("\(appState.historyCount)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(WisprTheme.historyAccent)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(WisprTheme.historyAccent.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        Text(appState.historyItems[0].text)
                            .font(.system(size: 10))
                            .foregroundStyle(WisprTheme.textTertiary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(WisprTheme.textTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .wisprCard()
        }
    }

    // MARK: - Permission Warnings

    @ViewBuilder
    private var permissionWarnings: some View {
        if appState.showMicrophoneSettings {
            HStack(spacing: 8) {
                Image(systemName: "mic.slash.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(WisprTheme.statusError)
                Text("Microphone access required")
                    .font(.system(size: 11))
                    .foregroundStyle(WisprTheme.textSecondary)
                Spacer()
                Button("Open Settings") {
                    appState.openMicrophoneSettings()
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundStyle(WisprTheme.statusRecording)
            }
            .wisprCard()
        }

        if appState.showAccessibilitySettings {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.slash.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(WisprTheme.statusWarning)
                Text("Accessibility access recommended")
                    .font(.system(size: 11))
                    .foregroundStyle(WisprTheme.textSecondary)
                Spacer()
                Button("Open Settings") {
                    appState.openAccessibilitySettings()
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundStyle(WisprTheme.statusRecording)
            }
            .wisprCard()
        }
    }

    // MARK: - Translation Toggle Card

    private var languageCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe")
                .font(.system(size: 14))
                .foregroundStyle(appState.autoTranslateToEnglish ? WisprTheme.settingsAccent : WisprTheme.textTertiary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text("Auto-translate to English")
                    .font(.system(size: 13))
                    .foregroundStyle(WisprTheme.textPrimary)
                Text(appState.autoTranslateToEnglish ? "Translates all output to English" : "No translation")
                    .font(.system(size: 10))
                    .foregroundStyle(WisprTheme.textTertiary)
            }

            Spacer()

            Toggle("", isOn: $appState.autoTranslateToEnglish)
                .toggleStyle(.switch)
                .tint(WisprTheme.statusRecording)
                .labelsHidden()
        }
        .wisprCard()
    }

    // MARK: - Insertion Mode Card

    private var insertionModeCard: some View {
        HStack(spacing: 8) {
            Image(systemName: appState.useClipboardOnly ? "doc.on.clipboard" : "text.cursor")
                .font(.system(size: 14))
                .foregroundStyle(WisprTheme.settingsAccent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text("Auto-paste")
                    .font(.system(size: 13))
                    .foregroundStyle(WisprTheme.textPrimary)
                Text((!appState.useClipboardOnly && !appState.showAccessibilitySettings) ? "Inserts via Accessibility" : "Clipboard only")
                    .font(.system(size: 10))
                    .foregroundStyle(WisprTheme.textTertiary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { !appState.useClipboardOnly && appState.showAccessibilitySettings == false },
                set: { newValue in
                    if newValue {
                        // User wants to enable auto-paste — require accessibility first
                        if appState.showAccessibilitySettings {
                            appState.openAccessibilitySettings()
                        } else {
                            appState.useClipboardOnly = false
                        }
                    } else {
                        appState.useClipboardOnly = true
                    }
                }
            ))
            .toggleStyle(.switch)
            .tint(WisprTheme.statusRecording)
            .labelsHidden()
        }
        .wisprCard()
    }

    // MARK: - Launch at Login Card

    private var launchAtLoginCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "power")
                .font(.system(size: 14))
                .foregroundStyle(WisprTheme.settingsAccent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text("Open at Login")
                    .font(.system(size: 13))
                    .foregroundStyle(WisprTheme.textPrimary)
                Text("Start automatically after you log in")
                    .font(.system(size: 10))
                    .foregroundStyle(WisprTheme.textTertiary)
            }

            Spacer()

            Toggle("", isOn: $appState.launchAtLogin)
                .toggleStyle(.switch)
                .tint(WisprTheme.statusRecording)
                .labelsHidden()
        }
        .wisprCard()
    }

    // MARK: - Shortcuts Card

    private var shortcutsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "keyboard")
                    .font(.system(size: 14))
                    .foregroundStyle(appState.shortcutsEnabled ? WisprTheme.settingsAccent : WisprTheme.textTertiary)
                    .frame(width: 22)
                Text("Shortcuts")
                    .font(.system(size: 13))
                    .foregroundStyle(WisprTheme.textPrimary)
                Spacer()
                if appState.hasCustomShortcuts && appState.shortcutsEnabled {
                    Button("Reset") {
                        appState.resetShortcuts()
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.plain)
                    .foregroundStyle(WisprTheme.textTertiary)
                }
                Toggle("", isOn: $appState.shortcutsEnabled)
                    .toggleStyle(.switch)
                    .tint(WisprTheme.statusRecording)
                    .labelsHidden()
                    .fixedSize()
                    .accessibilityIdentifier("popover_shortcuts_toggle")
            }

            if appState.shortcutsEnabled {
                Divider()
                    .background(WisprTheme.divider)

                // Hold to Talk — configurable modifier key
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hold to Talk")
                            .font(.system(size: 11))
                            .foregroundStyle(WisprTheme.textSecondary)
                        Text("Hold down, release to stop")
                            .font(.system(size: 9))
                            .foregroundStyle(WisprTheme.textTertiary)
                    }
                    Spacer()
                    Picker("", selection: $appState.holdModifierKey) {
                        ForEach(HoldModifierKey.allCases) { key in
                            Text(key.displayName).tag(key)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(WisprTheme.textTertiary)
                    .labelsHidden()
                    .fixedSize()
                }

                // Toggle — configurable via ShortcutRecorderView
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Toggle Recording")
                            .font(.system(size: 11))
                            .foregroundStyle(WisprTheme.textSecondary)
                        Text("Tap to start, tap again to stop")
                            .font(.system(size: 9))
                            .foregroundStyle(WisprTheme.textTertiary)
                    }
                    Spacer()
                    ShortcutRecorderView(
                        binding: $appState.currentToggleShortcut,
                        onChange: { binding in appState.updateToggleShortcut(binding) },
                        onRecordingStateChanged: { isRecording in
                            if isRecording { appState.suspendHotkeys() } else { appState.resumeHotkeys() }
                        }
                    )
                }
            }
        }
        .wisprCard()
    }

    // MARK: - Proxy URL Card

    private var proxyURLCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "server.rack")
                .font(.system(size: 14))
                .foregroundStyle(WisprTheme.apiAccent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text("Proxy URL")
                    .font(.system(size: 13))
                    .foregroundStyle(WisprTheme.textPrimary)
                if appState.apiProvider == .custom {
                    Text(appState.customBaseURL.isEmpty ? "Not configured" : appState.customBaseURL)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(WisprTheme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("OpenAI (default)")
                        .font(.system(size: 10))
                        .foregroundStyle(WisprTheme.textTertiary)
                }
            }

            Spacer()

            if appState.apiProvider == .custom {
                Button("Reset") {
                    appState.resetToOpenAI()
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundStyle(WisprTheme.textTertiary)
                .accessibilityIdentifier("popover_resetProvider_button")
            }
        }
        .wisprCard()
        .accessibilityIdentifier("popover_proxyURL_card")
    }

    // MARK: - API Key Card

    private var apiKeyCard: some View {
        HStack(spacing: 8) {
            Image(systemName: apiKeyIcon)
                .font(.system(size: 14))
                .foregroundStyle(apiKeyIconColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text("API Key")
                    .font(.system(size: 13))
                    .foregroundStyle(WisprTheme.textPrimary)
                Text(apiKeyStatusText)
                    .font(.system(size: 10))
                    .foregroundStyle(apiKeyStatusColor)
                    .accessibilityIdentifier("popover_apiKey_status")
                    .accessibilityLabel(apiKeyStatusText)
            }

            Spacer()

            Button(appState.apiKeySaved ? "Change" : "Set Up") {
                appState.showAPIKeySheet()
            }
            .font(.system(size: 11, weight: .medium))
            .buttonStyle(.plain)
            .foregroundStyle(appState.apiKeySaved ? WisprTheme.textTertiary : WisprTheme.statusRecording)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.white.opacity(appState.apiKeySaved ? 0.06 : 0.0))
            .background(appState.apiKeySaved ? Color.clear : WisprTheme.statusRecording.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityIdentifier("popover_apiKey_button")
            .accessibilityLabel(appState.apiKeySaved ? "Change" : "Set Up")
        }
        .wisprCard()
    }

    private var apiKeyIcon: String {
        switch appState.apiKeySource {
        case .none:     return "exclamationmark.triangle.fill"
        case .settings: return "checkmark.seal.fill"
        }
    }

    private var apiKeyIconColor: Color {
        appState.apiKeySource == .none ? WisprTheme.statusWarning : WisprTheme.apiAccent
    }

    private var apiKeyStatusText: String {
        switch appState.apiKeySource {
        case .none:     return String(localized: "Not set — tap to set up")
        case .settings: return String(localized: "Configured")
        }
    }

    private var apiKeyStatusColor: Color {
        appState.apiKeySource == .none ? WisprTheme.statusWarning : WisprTheme.textTertiary
    }

    // MARK: - Section Label

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(WisprTheme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.top, 2)
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 8) {
            Divider()
                .background(WisprTheme.divider)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Button {
                        if let url = URL(string: AppConfig.gitHubURL) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            GitHubMark()
                                .fill(WisprTheme.textSecondary)
                                .frame(width: 12, height: 12)
                            Text("Source Code on GitHub")
                                .font(.system(size: 10))
                                .foregroundStyle(WisprTheme.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 8) {
                        Text("v\(appVersion)")
                            .font(.system(size: 10))
                            .foregroundStyle(WisprTheme.textTertiary)

                        Button(updateButtonLabel) {
                            if let update = appState.availableUpdate {
                                NSWorkspace.shared.open(update.releaseURL)
                            } else {
                                Task { await appState.checkForUpdates(userInitiated: true) }
                            }
                        }
                        .font(.system(size: 10))
                        .buttonStyle(.plain)
                        .foregroundStyle(updateButtonColor)
                        .disabled(appState.updateCheckStatus == .checking)
                    }
                }

                Spacer()

                Button {
                    NSApp.terminate(nil)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "power")
                            .font(.system(size: 10))
                        Text("Quit")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(WisprTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
    }

    private var updateButtonLabel: String {
        switch appState.updateCheckStatus {
        case .idle:      return String(localized: "Check for Updates")
        case .checking:  return String(localized: "Checking...")
        case .upToDate:  return String(localized: "Up to Date")
        case .available: return String(localized: "Update Available")
        }
    }

    private var updateButtonColor: Color {
        switch appState.updateCheckStatus {
        case .idle:      return WisprTheme.textSecondary
        case .checking:  return WisprTheme.textTertiary
        case .upToDate:  return WisprTheme.textSecondary
        case .available: return WisprTheme.statusOK
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        #if DEBUG
        return "\(version) - debug"
        #else
        return version
        #endif
    }
}

// MARK: - GitHub Mark Shape

/// GitHub mark from the official Octicons SVG (primer/octicons mark-github-16.svg).
/// viewBox 0 0 16 16, scaled to fit the given rect.
private struct GitHubMark: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 16
        let sy = rect.height / 16

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }
        func c(_ x: CGFloat, _ y: CGFloat) -> CGPoint { pt(x, y) }

        var p = Path()
        // Converted from the official Octicons mark-github-16.svg path
        p.move(to: pt(6.766, 11.695))
        p.addCurve(to: pt(3.25, 7.92),
                   control1: c(4.703, 11.437), control2: c(3.25, 9.904))
        p.addCurve(to: pt(4.0, 5.662),
                   control1: c(3.25, 7.114), control2: c(3.531, 6.243))
        p.addCurve(to: pt(4.062, 3.533),
                   control1: c(3.797, 5.13), control2: c(3.828, 4.0))
        p.addCurve(to: pt(6.031, 4.259),
                   control1: c(4.688, 3.452), control2: c(5.531, 3.791))
        p.addCurve(to: pt(8.016, 3.968),
                   control1: c(6.625, 4.065), control2: c(7.25, 3.968))
        p.addCurve(to: pt(9.969, 4.242),
                   control1: c(8.781, 3.968), control2: c(9.406, 4.065))
        p.addCurve(to: pt(11.938, 3.533),
                   control1: c(10.453, 3.791), control2: c(11.281, 3.452))
        p.addCurve(to: pt(11.984, 5.646),
                   control1: c(12.156, 3.968), control2: c(12.188, 5.097))
        p.addCurve(to: pt(12.75, 7.92),
                   control1: c(12.484, 6.259), control2: c(12.75, 7.082))
        p.addCurve(to: pt(9.203, 11.679),
                   control1: c(12.75, 9.904), control2: c(11.297, 11.405))
        p.addCurve(to: pt(10.094, 13.695),
                   control1: c(9.734, 12.034), control2: c(10.094, 12.808))
        p.addLine(to: pt(10.094, 15.373))
        p.addCurve(to: pt(10.953, 15.937),
                   control1: c(10.094, 15.857), control2: c(10.484, 16.131))
        p.addCurve(to: pt(16.0, 8.291),
                   control1: c(13.781, 14.824), control2: c(16.0, 11.905))
        p.addCurve(to: pt(7.984, 0),
                   control1: c(16.0, 3.726), control2: c(12.406, 0))
        p.addCurve(to: pt(0, 8.291),
                   control1: c(3.562, 0), control2: c(0, 3.726))
        p.addCurve(to: pt(5.172, 15.954),
                   control1: c(0, 11.872), control2: c(2.203, 14.841))
        p.addCurve(to: pt(6.0, 15.389),
                   control1: c(5.359, 16.117), control2: c(5.766, 15.937))
        p.addLine(to: pt(6.0, 14.098))
        p.addCurve(to: pt(5.25, 14.26),
                   control1: c(5.781, 14.195), control2: c(5.5, 14.26))
        p.addCurve(to: pt(3.172, 12.598),
                   control1: c(4.219, 14.26), control2: c(3.609, 13.679))
        p.addCurve(to: pt(2.453, 11.856),
                   control1: c(3.0, 12.163), control2: c(2.812, 11.905))
        p.addCurve(to: pt(2.203, 11.663),
                   control1: c(2.266, 11.84), control2: c(2.203, 11.759))
        p.addCurve(to: pt(2.828, 11.324),
                   control1: c(2.203, 11.469), control2: c(2.516, 11.324))
        p.addCurve(to: pt(4.078, 12.211),
                   control1: c(3.281, 11.324), control2: c(3.672, 11.614))
        p.addCurve(to: pt(5.109, 12.889),
                   control1: c(4.391, 12.679), control2: c(4.719, 12.889))
        p.addCurve(to: pt(6.109, 12.373),
                   control1: c(5.5, 12.889), control2: c(5.75, 12.743))
        p.addCurve(to: pt(6.766, 11.695),
                   control1: c(6.375, 12.098), control2: c(6.578, 11.856))
        p.closeSubpath()
        return p
    }
}

// MARK: - API Key Setup Sheet

private struct PopoverApiKeySetupView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "key.fill")
                    .font(.title2)
                    .foregroundStyle(WisprTheme.statusWarning)
                Text("API Key")
                    .font(.title2.bold())
                    .foregroundStyle(WisprTheme.textPrimary)
            }

            Text("Enter your API key to enable transcription.")
                .font(.callout)
                .foregroundStyle(WisprTheme.textSecondary)

            SecureField("API Key", text: $appState.apiKeyInput)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("sheet_apiKey_field")

            HStack(spacing: 12) {
                Button("Save") {
                    appState.saveAPIKey()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("sheet_save_button")

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(WisprTheme.textTertiary)
                .accessibilityIdentifier("sheet_cancel_button")

                Spacer()

                if appState.hasApiKeyURL {
                    Button("Get API key") {
                        appState.openEnvSetupDocs()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(WisprTheme.statusRecording)
                }
            }
        }
        .frame(minWidth: 380)
        .padding(24)
        .background(WisprTheme.background)
        .preferredColorScheme(.dark)
    }
}

#if DEBUG
private func makeState(
    status: AppStatus = .idle,
    apiKeySource: APIKeySource = .settings,
    lastOutput: String = "",
    lastError: String? = nil,
    showMic: Bool = false,
    showAccessibility: Bool = false,
    toggleShortcut: ShortcutBinding? = nil,
    holdModifier: HoldModifierKey = .control,
    clipboardOnly: Bool = false,
    launchAtLogin: Bool = false,
    historyItems: [TranscriptItem] = TranscriptItem.previewItems
) -> AppState {
    let s = AppState(container: AppContainer())
    s.status = status
    s.apiKeySource = apiKeySource
    s.lastOutput = lastOutput
    s.lastError = lastError
    s.showMicrophoneSettings = showMic
    s.showAccessibilitySettings = showAccessibility
    s.currentToggleShortcut = toggleShortcut
    s.holdModifierKey = holdModifier
    s.useClipboardOnly = clipboardOnly
    s.syncLaunchAtLogin(launchAtLogin)
    s.historyItems = historyItems
    return s
}

#Preview("Idle — API Key set") {
    PopoverContentView()
        .environmentObject(makeState())
        .frame(width: WisprTheme.popoverWidth, height: 620)
}

#Preview("Recording") {
    PopoverContentView()
        .environmentObject(makeState(status: .recording))
        .frame(width: WisprTheme.popoverWidth, height: 620)
}

#Preview("Transcribing") {
    PopoverContentView()
        .environmentObject(makeState(status: .transcribing))
        .frame(width: WisprTheme.popoverWidth, height: 620)
}

#Preview("With history") {
    PopoverContentView()
        .environmentObject(makeState())
        .frame(width: WisprTheme.popoverWidth, height: 620)
}

#Preview("No history") {
    PopoverContentView()
        .environmentObject(makeState(historyItems: []))
        .frame(width: WisprTheme.popoverWidth, height: 620)
}

#Preview("No API Key") {
    PopoverContentView()
        .environmentObject(makeState(apiKeySource: .none))
        .frame(width: WisprTheme.popoverWidth, height: 620)
}

#Preview("API Key error") {
    PopoverContentView()
        .environmentObject(makeState(status: .error, lastError: "API key is invalid or expired. Please update it."))
        .frame(width: WisprTheme.popoverWidth, height: 620)
}

#Preview("No microphone") {
    PopoverContentView()
        .environmentObject(makeState(lastError: "Microphone permission is required.", showMic: true))
        .frame(width: WisprTheme.popoverWidth, height: 680)
}

#Preview("No accessibility") {
    PopoverContentView()
        .environmentObject(makeState(lastError: "Accessibility permission not granted. Will copy to clipboard only.", showAccessibility: true))
        .frame(width: WisprTheme.popoverWidth, height: 680)
}

#Preview("Custom toggle shortcut — Reset button visible") {
    // Option + R (keyCode 15)
    let binding = ShortcutBinding(keyCode: 15, modifierFlags: NSEvent.ModifierFlags([.option]).rawValue)
    PopoverContentView()
        .environmentObject(makeState(toggleShortcut: binding))
        .frame(width: WisprTheme.popoverWidth, height: 620)
}

#Preview("Custom hold modifier — Reset button visible") {
    PopoverContentView()
        .environmentObject(makeState(holdModifier: .option))
        .frame(width: WisprTheme.popoverWidth, height: 620)
}

#Preview("Auto-paste OFF — Clipboard only") {
    PopoverContentView()
        .environmentObject(makeState(clipboardOnly: true))
        .frame(width: WisprTheme.popoverWidth, height: 620)
}
#endif
