//
//  IndicatorPanelPreview.swift
//  DevWispr
//
//  SwiftUI preview replica of the floating indicator NSPanel.
//  The real panel is pure AppKit (IndicatorPanelController), so we replicate
//  its visual here for Xcode canvas previews only.
//

import SwiftUI
import AppKit

// MARK: - NSViewRepresentable wrapper for AudioWaveformView

private struct AudioWaveformRepresentable: NSViewRepresentable {
    /// Optional sample levels (0‥1). When nil, shows flat bars (level 0).
    var levels: [Double]

    func makeNSView(context: Context) -> AudioWaveformView {
        let view = AudioWaveformView()
        applyLevels(to: view)
        return view
    }

    func updateNSView(_ nsView: AudioWaveformView, context: Context) {
        nsView.reset()
        applyLevels(to: nsView)
    }

    private func applyLevels(to view: AudioWaveformView) {
        for level in levels {
            view.pushLevel(level)
        }
    }
}

// MARK: - SwiftUI replica of the indicator panel

private struct IndicatorPanelPreviewView: View {
    var statusText: String
    var buttonTitle: String
    var showWaveform: Bool
    var levels: [Double] = []

    var body: some View {
        ZStack {
            // Approximate NSGlassEffectView with a frosted material
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)

            VStack(spacing: 10) {
                Text(statusText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(maxWidth: 220 - 32)

                if showWaveform {
                    AudioWaveformRepresentable(levels: levels)
                        .frame(
                            width: AudioWaveformView.totalWidth,
                            height: AudioWaveformView.totalHeight
                        )
                }

                Button(buttonTitle) {}
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .controlSize(.regular)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
        }
        .frame(width: 220, height: 190)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Previews

#Preview("Starting — audio not ready yet") {
    IndicatorPanelPreviewView(
        statusText: "Starting…",
        buttonTitle: "Stop",
        showWaveform: false
    )
    .padding(32)
    .background(Color.black.opacity(0.6))
}

#Preview("Listening — waveform active") {
    // Simulate a mid-recording waveform with varied levels
    let levels: [Double] = (0..<40).map { i in
        let t = Double(i) / 39.0
        return 0.2 + 0.6 * abs(sin(t * .pi * 5)) + Double.random(in: 0...0.15)
    }
    IndicatorPanelPreviewView(
        statusText: "Listening…",
        buttonTitle: "Stop",
        showWaveform: true,
        levels: levels
    )
    .padding(32)
    .background(Color.black.opacity(0.6))
}

#Preview("Transcribing") {
    IndicatorPanelPreviewView(
        statusText: "Transcribing…",
        buttonTitle: "Cancel",
        showWaveform: false
    )
    .padding(32)
    .background(Color.black.opacity(0.6))
}

#Preview("Translating") {
    IndicatorPanelPreviewView(
        statusText: "Translating…",
        buttonTitle: "Cancel",
        showWaveform: false
    )
    .padding(32)
    .background(Color.black.opacity(0.6))
}

#Preview("Inserting text") {
    IndicatorPanelPreviewView(
        statusText: "Inserting text…",
        buttonTitle: "Cancel",
        showWaveform: false
    )
    .padding(32)
    .background(Color.black.opacity(0.6))
}

#Preview("Error — long message") {
    IndicatorPanelPreviewView(
        statusText: "API key is invalid or expired. Please update it in Settings.",
        buttonTitle: "Dismiss",
        showWaveform: false
    )
    .padding(32)
    .background(Color.black.opacity(0.6))
}
