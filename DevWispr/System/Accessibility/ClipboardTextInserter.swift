//
//  ClipboardTextInserter.swift
//  DevWispr
//

import AppKit
import Foundation

final class ClipboardTextInserter: TextInserter {
    func insertText(_ text: String) async throws {
        let pasteboard = NSPasteboard.general
        let originalString = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        try sendPasteCommand()

        // Give the target app time to consume the pasteboard before restoring.
        try? await Task.sleep(for: .milliseconds(200))

        pasteboard.clearContents()
        if let originalString {
            pasteboard.setString(originalString, forType: .string)
        }
    }

    private func sendPasteCommand() throws {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw TextInsertionError.eventSourceCreationFailed
        }

        let keyVDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        keyVDown?.flags = .maskCommand

        let keyVUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyVUp?.flags = .maskCommand

        guard let keyVDown, let keyVUp else {
            throw TextInsertionError.keyEventCreationFailed
        }

        keyVDown.post(tap: .cghidEventTap)
        keyVUp.post(tap: .cghidEventTap)
    }
}
