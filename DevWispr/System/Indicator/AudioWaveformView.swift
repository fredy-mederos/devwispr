//
//  AudioWaveformView.swift
//  DevWispr
//

import AppKit

final class AudioWaveformView: NSView {
    private static let sampleCount = 40
    private static let barWidth: CGFloat = 3
    private static let barSpacing: CGFloat = 2
    static let totalWidth: CGFloat = CGFloat(sampleCount) * (barWidth + barSpacing) - barSpacing
    static let totalHeight: CGFloat = 32

    private var levels: [Double] = Array(repeating: 0, count: sampleCount)

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.totalWidth, height: Self.totalHeight)
    }

    override var isFlipped: Bool { false }

    func pushLevel(_ level: Double) {
        levels.removeFirst()
        levels.append(level)
        needsDisplay = true
    }

    func reset() {
        levels = Array(repeating: 0, count: Self.sampleCount)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let color = NSColor.controlAccentColor
        let midY = bounds.midY

        for (index, level) in levels.enumerated() {
            let clampedLevel = min(max(level, 0), 1)
            let barHeight = max(2, CGFloat(clampedLevel) * Self.totalHeight)
            let x = CGFloat(index) * (Self.barWidth + Self.barSpacing)
            let y = midY - barHeight / 2
            let rect = NSRect(x: x, y: y, width: Self.barWidth, height: barHeight)
            let opacity = 0.4 + 0.6 * clampedLevel

            color.withAlphaComponent(opacity).setFill()
            let path = NSBezierPath(roundedRect: rect, xRadius: Self.barWidth / 2, yRadius: Self.barWidth / 2)
            path.fill()
        }
    }
}
