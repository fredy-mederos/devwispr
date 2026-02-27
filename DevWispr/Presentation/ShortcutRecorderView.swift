//
//  ShortcutRecorderView.swift
//  DevWispr
//

import AppKit
import SwiftUI

struct ShortcutRecorderView: View {
    @Binding var binding: ShortcutBinding?
    var onChange: (ShortcutBinding?) -> Void
    /// Called with `true` when recording starts, `false` when it ends (captured or cancelled).
    var onRecordingStateChanged: ((Bool) -> Void)?

    @State private var isRecording = false

    private var displayText: String {
        if isRecording {
            return "Press a key combo..."
        }
        return binding?.displayString ?? "Control + Space"
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(displayText)
                .font(.system(size: 10))
                .foregroundStyle(isRecording ? WisprTheme.statusRecording : WisprTheme.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isRecording ? WisprTheme.statusRecording.opacity(0.12) : Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isRecording ? WisprTheme.statusRecording.opacity(0.5) : Color.clear, lineWidth: 1)
                )
                .onTapGesture {
                    isRecording = true
                    onRecordingStateChanged?(true)
                }
                .background(
                    ShortcutRecorderHelper(isRecording: $isRecording, binding: $binding, onChange: onChange, onRecordingStateChanged: onRecordingStateChanged)
                )

        }
    }
}

private struct ShortcutRecorderHelper: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var binding: ShortcutBinding?
    var onChange: (ShortcutBinding?) -> Void
    var onRecordingStateChanged: ((Bool) -> Void)?

    func makeNSView(context: Context) -> NSView {
        let view = ShortcutCapturingView()
        view.delegate = context.coordinator
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? ShortcutCapturingView else { return }
        context.coordinator.isRecording = isRecording
        if isRecording {
            view.window?.makeFirstResponder(view)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject {
        var parent: ShortcutRecorderHelper
        var isRecording = false

        init(parent: ShortcutRecorderHelper) {
            self.parent = parent
        }

        func handleKeyDown(_ event: NSEvent) {
            guard isRecording else { return }

            if event.keyCode == 53 { // Escape
                parent.isRecording = false
                parent.onRecordingStateChanged?(false)
                return
            }

            let modifiers = event.modifierFlags.intersection([.control, .option, .shift, .command])
            guard !modifiers.isEmpty else { return }

            let newBinding = ShortcutBinding(
                keyCode: UInt32(event.keyCode),
                modifierFlags: modifiers.rawValue
            )
            parent.binding = newBinding
            parent.isRecording = false
            parent.onRecordingStateChanged?(false)
            parent.onChange(newBinding)
        }
    }
}

// MARK: - Preview

#Preview("No binding (default)") {
    ShortcutRecorderView(binding: .constant(nil), onChange: { _ in })
        .padding(12)
        .background(WisprTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: WisprTheme.cardCornerRadius))
        .padding(20)
        .background(WisprTheme.background)
        .preferredColorScheme(.dark)
}

#Preview("Custom binding set") {
    // Control + Command + R (keyCode 15)
    let binding = ShortcutBinding(
        keyCode: 15,
        modifierFlags: NSEvent.ModifierFlags([.control, .command]).rawValue
    )
    ShortcutRecorderView(binding: .constant(binding), onChange: { _ in })
        .padding(12)
        .background(WisprTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: WisprTheme.cardCornerRadius))
        .padding(20)
        .background(WisprTheme.background)
        .preferredColorScheme(.dark)
}

#Preview("Recording — waiting for key") {
    // Replicate the recording chip state visually (isRecording is @State so can't be preset externally)
    Text("Press a key combo...")
        .font(.system(size: 10))
        .foregroundStyle(WisprTheme.statusRecording)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(WisprTheme.statusRecording.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5)
            .stroke(WisprTheme.statusRecording.opacity(0.5), lineWidth: 1))
        .padding(12)
        .background(WisprTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: WisprTheme.cardCornerRadius))
        .padding(20)
        .background(WisprTheme.background)
        .preferredColorScheme(.dark)
}

private final class ShortcutCapturingView: NSView {
    weak var delegate: ShortcutRecorderHelper.Coordinator?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if let delegate {
            delegate.handleKeyDown(event)
        } else {
            super.keyDown(with: event)
        }
    }

    // Command+key combos are intercepted by NSWindow's performKeyEquivalent
    // before they reach keyDown. Override here so the recorder captures them too.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard let delegate, delegate.isRecording else {
            return super.performKeyEquivalent(with: event)
        }
        delegate.handleKeyDown(event)
        return true
    }
}
