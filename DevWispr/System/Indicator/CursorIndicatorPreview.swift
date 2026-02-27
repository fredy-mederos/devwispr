//
//  CursorIndicatorPreview.swift
//  DevWispr
//
//  SwiftUI preview replica of the cursor pill indicator.
//  The real indicator is pure AppKit (CursorIndicatorController), so this
//  file replicates its visual for Xcode canvas previews only.
//

import SwiftUI
import AppKit

// MARK: - Pill preview view

private struct CursorPillPreviewView: View {
    enum PillState {
        case listening([Double])
        case transcribing
        case copied
        case error
    }

    var state: PillState

    // Fixed pill dimensions — all states use the same size for visual consistency.
    private static let pillWidth: CGFloat = 126
    private static let pillHeight: CGFloat = 30

    var body: some View {
        ZStack {
            Capsule()
                .fill(.ultraThinMaterial)

            content
        }
        .frame(width: Self.pillWidth, height: Self.pillHeight)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .listening(let levels):
            HStack(spacing: 6) {
                AudioWaveformRepresentable(levels: levels)
                    .frame(width: 70, height: Self.pillHeight - 12)
                    .clipped()
                // Stop button
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 18, height: 18)
                    Image(systemName: "stop.fill")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

        case .transcribing:
            ProgressView()
                .controlSize(.small)
                .tint(.white)

        case .copied:
            HStack(spacing: 6) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                Text("Copied")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
            }

        case .error:
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.orange)
                Text("Error")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Previews

#Preview("Listening — waveform active") {
    let levels: [Double] = (0..<40).map { i in
        let t = Double(i) / 39.0
        return 0.2 + 0.6 * abs(sin(t * .pi * 5)) + Double.random(in: 0...0.15)
    }
    return CursorPillPreviewView(state: .listening(levels))
        .padding(32)
        .background(Color.black.opacity(0.6))
}

#Preview("Transcribing / Processing") {
    CursorPillPreviewView(state: .transcribing)
        .padding(32)
        .background(Color.black.opacity(0.6))
}

#Preview("Copied — clipboard feedback") {
    CursorPillPreviewView(state: .copied)
        .padding(32)
        .background(Color.black.opacity(0.6))
}

#Preview("Error — warning icon") {
    CursorPillPreviewView(state: .error)
        .padding(32)
        .background(Color.black.opacity(0.6))
}

// MARK: - Reuse AudioWaveformRepresentable from the existing preview file

private struct AudioWaveformRepresentable: NSViewRepresentable {
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

