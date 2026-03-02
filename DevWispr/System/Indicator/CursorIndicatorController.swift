//
//  CursorIndicatorController.swift
//  DevWispr
//
//  A minimalistic pill-shaped floating indicator that appears near the mouse
//  cursor during recording. Alternative to IndicatorPanelController which
//  places a larger panel at the top-right of the screen.
//
//  Enabled via the DEBUG-only `useCursorIndicator` setting.
//

import AppKit
import Combine
import Foundation

@MainActor
final class CursorIndicatorController {

    // MARK: - Layout constants

    private static let pillSize = NSSize(width: 126, height: 30)
    private static let waveformVisibleWidth: CGFloat = 70
    private static let stopButtonSize: CGFloat = 18
    private static let iconSize: CGFloat = 14
    private static let feedbackForegroundColor = NSColor.systemGray

    // MARK: - Views

    private let panel: NSPanel
    private let waveformView = AudioWaveformView()
    private let waveformContainer = NSView()
    private let stopButton = NSButton()
    private let spinner = NSProgressIndicator()
    private let iconView = NSImageView()
    private let copiedLabel = NSTextField(labelWithString: "Copied")

    // MARK: - State

    private let appState: AppState
    private let soundFeedback: SoundFeedbackService
    private var cancellables = Set<AnyCancellable>()

    private var currentStatus: AppStatus = .idle
    private var previousStatus: AppStatus = .idle
    private var isToggleMode: Bool = false
    private var isAudioReady: Bool = false
    private var minDelayElapsed: Bool = false
    private var readyWorkItem: DispatchWorkItem?
    private var autoDismissWorkItem: DispatchWorkItem?
    private var panelOrigin: NSPoint?

    // MARK: - Init

    init(appState: AppState, soundFeedback: SoundFeedbackService) {
        self.appState = appState
        self.soundFeedback = soundFeedback

        let size = Self.pillSize
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.contentMinSize = size
        panel.contentMaxSize = size

        setupViews()
        setupBindings()
    }

    // MARK: - View Hierarchy

    private func setupViews() {
        let size = Self.pillSize

        // Waveform in a clipping container — pin trailing edge so the most
        // recent bars (rightmost) are always visible inside the narrower pill.
        waveformView.translatesAutoresizingMaskIntoConstraints = false
        waveformContainer.translatesAutoresizingMaskIntoConstraints = false
        waveformContainer.wantsLayer = true
        waveformContainer.layer?.masksToBounds = true
        waveformContainer.addSubview(waveformView)

        NSLayoutConstraint.activate([
            waveformView.trailingAnchor.constraint(equalTo: waveformContainer.trailingAnchor),
            waveformView.centerYAnchor.constraint(equalTo: waveformContainer.centerYAnchor),
            waveformView.widthAnchor.constraint(equalToConstant: AudioWaveformView.totalWidth),
            waveformView.heightAnchor.constraint(equalToConstant: AudioWaveformView.totalHeight),
            waveformContainer.widthAnchor.constraint(equalToConstant: Self.waveformVisibleWidth),
            waveformContainer.heightAnchor.constraint(equalToConstant: AudioWaveformView.totalHeight),
        ])

        // Stop button — small circular red button shown only during listening
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        stopButton.isBordered = false
        stopButton.wantsLayer = true
        stopButton.layer?.cornerRadius = Self.stopButtonSize / 2
        stopButton.layer?.backgroundColor = NSColor.systemRed.cgColor
        let stopIcon = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: "Stop")
        let cfg = NSImage.SymbolConfiguration(pointSize: 7, weight: .bold)
        stopButton.image = stopIcon?.withSymbolConfiguration(cfg)
        stopButton.imageScaling = .scaleProportionallyDown
        stopButton.contentTintColor = .white
        stopButton.target = self
        stopButton.action = #selector(stopButtonTapped)
        stopButton.isHidden = true
        NSLayoutConstraint.activate([
            stopButton.widthAnchor.constraint(equalToConstant: Self.stopButtonSize),
            stopButton.heightAnchor.constraint(equalToConstant: Self.stopButtonSize),
        ])

        // Spinner for transcribing / processing states
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isIndeterminate = true
        spinner.isHidden = true

        // Icon for copy / error states
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown
        iconView.isHidden = true
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: Self.iconSize),
            iconView.heightAnchor.constraint(equalToConstant: Self.iconSize),
        ])

        // "Copied" / "Error" label
        copiedLabel.translatesAutoresizingMaskIntoConstraints = false
        copiedLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        copiedLabel.textColor = Self.feedbackForegroundColor
        copiedLabel.isHidden = true

        // Horizontal stack — only the active child is visible at a time
        let stack = NSStackView(views: [waveformContainer, stopButton, spinner, iconView, copiedLabel])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        let innerContent = NSView()
        innerContent.translatesAutoresizingMaskIntoConstraints = false
        innerContent.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: innerContent.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: innerContent.centerYAnchor),
        ])

        // Frosted glass pill
        let glassView = NSGlassEffectView()
        glassView.cornerRadius = size.height / 2
        glassView.style = .regular
        glassView.contentView = innerContent
        glassView.translatesAutoresizingMaskIntoConstraints = false

        let wrapper = NSView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(glassView)
        NSLayoutConstraint.activate([
            glassView.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            glassView.topAnchor.constraint(equalTo: wrapper.topAnchor),
            glassView.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
        ])
        panel.contentView = wrapper
    }

    // MARK: - Combine Bindings

    private func setupBindings() {
        appState.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.previousStatus = self?.currentStatus ?? .idle
                self?.currentStatus = status
                self?.refreshPill()
            }
            .store(in: &cancellables)

        appState.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.waveformView.pushLevel(level)
            }
            .store(in: &cancellables)

        appState.$isAudioReady
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ready in
                if ready {
                    self?.isAudioReady = true
                    self?.tryShowListening()
                } else {
                    self?.resetReadyState()
                }
            }
            .store(in: &cancellables)

        appState.$recordingMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                self?.isToggleMode = (mode == .toggle)
            }
            .store(in: &cancellables)
    }

    // MARK: - State Machine

    private func refreshPill() {
        switch currentStatus {
        case .recording:
            capturePillPosition()
            showPillIfNeeded()
            showContent(.none)
            scheduleReadyDelay()

        case .transcribing, .translating, .inserting:
            showPillIfNeeded()
            showContent(.spinner)

        case .error:
            showPillIfNeeded()
            showContent(.warning)
            scheduleAutoDismiss(after: 1.0)

        case .idle:
            if previousStatus == .inserting {
                handleCompletion()
            } else {
                hidePill()
            }
        }
    }

    @objc private func stopButtonTapped() {
        appState.stopRecordingAndProcess()
    }

    // MARK: - Content Switching

    private enum ContentMode {
        case none, waveform, spinner, icon(NSImage, NSColor), iconWithLabel(NSImage, String)
        case warning
    }

    private func showContent(_ mode: ContentMode) {
        waveformContainer.isHidden = true
        stopButton.isHidden = true
        spinner.stopAnimation(nil)
        spinner.isHidden = true
        iconView.isHidden = true
        copiedLabel.isHidden = true

        switch mode {
        case .none:
            break
        case .waveform:
            waveformContainer.isHidden = false
            stopButton.isHidden = !isToggleMode
        case .spinner:
            spinner.isHidden = false
            spinner.startAnimation(nil)
        case .icon(let image, let color):
            iconView.image = image
            iconView.contentTintColor = color
            iconView.isHidden = false
        case .iconWithLabel(let image, let label):
            iconView.image = image
            iconView.contentTintColor = Self.feedbackForegroundColor
            iconView.isHidden = false
            copiedLabel.stringValue = label
            copiedLabel.isHidden = false
        case .warning:
            let img = NSImage(systemSymbolName: "exclamationmark.triangle.fill",
                              accessibilityDescription: "Error")
            iconView.image = img
            iconView.contentTintColor = NSColor.systemOrange
            iconView.isHidden = false
            copiedLabel.stringValue = "Error"
            copiedLabel.isHidden = false
        }
    }

    // MARK: - Completion Handling

    private func handleCompletion() {
        // If the user prefers clipboard-only OR accessibility is not available,
        // clipboard was used — show "Copied" feedback before dismissing.
        let usedClipboard = appState.useClipboardOnly || appState.showAccessibilitySettings
        if usedClipboard {
            showPillIfNeeded()
            let copyImage = NSImage(systemSymbolName: "doc.on.clipboard.fill",
                                    accessibilityDescription: "Copied")
            showContent(.iconWithLabel(copyImage!, "Copied"))
            animateCopiedFeedback()
            scheduleAutoDismiss(after: 1.5)
        } else {
            hidePill()
        }
    }

    private func animateCopiedFeedback() {
        guard let layer = iconView.layer else { return }
        let anim = CAKeyframeAnimation(keyPath: "transform.scale")
        anim.values = [1.0, 1.3, 1.0]
        anim.keyTimes = [0, 0.4, 1.0]
        anim.duration = 0.4
        layer.add(anim, forKey: "copiedBounce")
    }

    // MARK: - Panel Visibility

    private func capturePillPosition() {
        guard panelOrigin == nil else { return }
        let mouse = NSEvent.mouseLocation
        let size = Self.pillSize
        let origin = NSPoint(
            x: mouse.x - size.width / 2,
            y: mouse.y + 12
        )
        // Clamp to the screen that contains the mouse cursor
        let targetScreen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
            ?? NSScreen.main
        if let frame = targetScreen?.visibleFrame {
            let clampedX = min(max(origin.x, frame.minX), frame.maxX - size.width)
            let clampedY = min(max(origin.y, frame.minY), frame.maxY - size.height)
            panelOrigin = NSPoint(x: clampedX, y: clampedY)
        } else {
            panelOrigin = origin
        }
        panel.setFrameOrigin(panelOrigin!)
    }

    private func showPillIfNeeded() {
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    private func hidePill() {
        autoDismissWorkItem?.cancel()
        autoDismissWorkItem = nil
        if panel.isVisible {
            panel.orderOut(nil)
        }
        panelOrigin = nil
        resetReadyState()
    }

    // MARK: - Ready Delay (same two-condition gate as IndicatorPanelController)

    private func scheduleReadyDelay() {
        readyWorkItem?.cancel()
        minDelayElapsed = false
        let item = DispatchWorkItem { [weak self] in
            self?.minDelayElapsed = true
            self?.tryShowListening()
        }
        readyWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
    }

    private func tryShowListening() {
        guard currentStatus == .recording, isAudioReady, minDelayElapsed else { return }
        showContent(.waveform)
        soundFeedback.playRecordingStarted()
    }

    private func resetReadyState() {
        isAudioReady = false
        minDelayElapsed = false
        readyWorkItem?.cancel()
        readyWorkItem = nil
        waveformView.reset()
    }

    // MARK: - Auto-Dismiss

    private func scheduleAutoDismiss(after seconds: Double) {
        autoDismissWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.hidePill()
        }
        autoDismissWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }
}
