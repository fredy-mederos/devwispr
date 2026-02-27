//
//  IndicatorPanelController.swift
//  DevWispr
//

import AppKit
import Combine
import Foundation

@MainActor
final class IndicatorPanelController {
    private let panel: NSPanel
    private let statusLabel = NSTextField(labelWithString: "Listening…")
    private let actionButton = NSButton(title: "Stop", target: nil, action: nil)
    private let waveformView = AudioWaveformView()

    private static let panelSize = NSSize(width: 220, height: 190)

    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()
    private var currentStatus: AppStatus = .idle
    private var currentError: String?
    private var actionHandler: (() -> Void)?
    private let soundFeedback: SoundFeedbackService
    private var isAudioReady: Bool = false
    private var minDelayElapsed: Bool = false
    private var readyWorkItem: DispatchWorkItem?

    init(appState: AppState, soundFeedback: SoundFeedbackService) {
        self.appState = appState
        self.soundFeedback = soundFeedback

        let size = Self.panelSize
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
        panel.appearance = NSAppearance(named: .darkAqua)
        // Lock size — error text wraps instead of growing the panel.
        panel.contentMinSize = size
        panel.contentMaxSize = size

        // Wrapping label — long errors show on multiple lines, never expand panel.
        statusLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        statusLabel.textColor = .white
        statusLabel.alignment = .center
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 3
        statusLabel.preferredMaxLayoutWidth = size.width - 32  // 16pt margin each side

        actionButton.target = self
        actionButton.action = #selector(primaryButtonTapped)
        actionButton.bezelStyle = .rounded
        actionButton.isBordered = true
        actionButton.contentTintColor = .white
        actionButton.wantsLayer = true
        actionButton.layer?.cornerRadius = 7

        waveformView.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [statusLabel, waveformView, actionButton])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        // The inner content view that goes inside NSGlassEffectView (or plain view on macOS < 26).
        let innerContentView = NSView()
        innerContentView.translatesAutoresizingMaskIntoConstraints = false
        innerContentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: innerContentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: innerContentView.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: innerContentView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: innerContentView.trailingAnchor, constant: -12),
            waveformView.widthAnchor.constraint(equalToConstant: AudioWaveformView.totalWidth),
            waveformView.heightAnchor.constraint(equalToConstant: AudioWaveformView.totalHeight),
        ])

        // Wrap in NSGlassEffectView (macOS 26+ is the minimum deployment target).
        let glassView = NSGlassEffectView()
        glassView.cornerRadius = 20
        glassView.style = .regular
        glassView.contentView = innerContentView
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

        appState.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.currentStatus = status
                self?.refreshPanel()
            }
            .store(in: &cancellables)

        appState.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.currentError = error
                self?.refreshPanel()
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
    }

    @objc private func primaryButtonTapped() {
        actionHandler?()
    }

    private func refreshPanel() {
        switch currentStatus {
        case .recording:
            showPanel(text: "Starting…", buttonTitle: "Stop") { [weak self] in
                self?.appState.stopRecordingAndProcess()
                self?.hidePanel()
            }
            waveformView.isHidden = true
            scheduleReadyDelay()
        case .transcribing:
            showPanel(text: "Transcribing…", buttonTitle: "Cancel") { [weak self] in
                self?.appState.cancelProcessing()
                self?.hidePanel()
            }
            waveformView.isHidden = true
        case .translating:
            showPanel(text: "Translating…", buttonTitle: "Cancel") { [weak self] in
                self?.appState.cancelProcessing()
                self?.hidePanel()
            }
            waveformView.isHidden = true
        case .inserting:
            showPanel(text: "Inserting text…", buttonTitle: "Cancel") { [weak self] in
                self?.appState.cancelProcessing()
                self?.hidePanel()
            }
            waveformView.isHidden = true
        case .error:
            guard let error = currentError, !error.isEmpty else {
                hidePanel()
                return
            }
            showPanel(text: error, buttonTitle: "Dismiss") { [weak self] in
                self?.hidePanel()
            }
        default:
            hidePanel()
        }
    }

    private func showPanel(text: String, buttonTitle: String, action: @escaping () -> Void) {
        statusLabel.stringValue = text
        actionButton.title = buttonTitle
        actionButton.isHidden = false
        actionHandler = action
        if currentStatus != .recording {
            waveformView.isHidden = true
        }

        if !panel.isVisible {
            // Always reset to fixed size before showing so a previous state never leaks.
            panel.setContentSize(Self.panelSize)

            if let screen = NSScreen.main {
                let frame = screen.visibleFrame
                let origin = NSPoint(
                    x: frame.maxX - Self.panelSize.width - 24,
                    y: frame.maxY - Self.panelSize.height - 48
                )
                panel.setFrameOrigin(origin)
            }
            panel.orderFrontRegardless()
        }
    }

    private func hidePanel() {
        if panel.isVisible {
            panel.orderOut(nil)
        }
    }

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
        statusLabel.stringValue = "Listening…"
        waveformView.isHidden = false
        soundFeedback.playRecordingStarted()
    }

    private func resetReadyState() {
        isAudioReady = false
        minDelayElapsed = false
        readyWorkItem?.cancel()
        readyWorkItem = nil
        waveformView.reset()
    }
}
