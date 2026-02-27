//
//  ShortcutBinding.swift
//  DevWispr
//

import AppKit
import Carbon
import Foundation

struct ShortcutBinding: Equatable, Codable {
    let keyCode: UInt32
    let modifierFlags: UInt

    var displayString: String {
        var parts: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: modifierFlags)
        if flags.contains(.control) { parts.append("Control") }
        if flags.contains(.option) { parts.append("Option") }
        if flags.contains(.shift) { parts.append("Shift") }
        if flags.contains(.command) { parts.append("Command") }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined(separator: " + ")
    }

    private static func keyName(for keyCode: UInt32) -> String {
        switch keyCode {
        case 49: return "Space"
        case 36: return "Return"
        case 48: return "Tab"
        case 51: return "Delete"
        case 53: return "Escape"
        case 123: return "Left"
        case 124: return "Right"
        case 125: return "Down"
        case 126: return "Up"
        default:
            // Try to get the character from the key code
            let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
            let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
            if let data = layoutData {
                let keyboardLayout = unsafeBitCast(data, to: CFData.self)
                let keyLayoutPtr = CFDataGetBytePtr(keyboardLayout)!
                var deadKeyState: UInt32 = 0
                var length = 0
                var chars = [UniChar](repeating: 0, count: 4)
                UCKeyTranslate(
                    keyLayoutPtr.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { $0 },
                    UInt16(keyCode),
                    UInt16(kUCKeyActionDisplay),
                    0,
                    UInt32(LMGetKbdType()),
                    UInt32(kUCKeyTranslateNoDeadKeysBit),
                    &deadKeyState,
                    chars.count,
                    &length,
                    &chars
                )
                if length > 0 {
                    return String(utf16CodeUnits: chars, count: length).uppercased()
                }
            }
            return "Key \(keyCode)"
        }
    }
}

enum HoldModifierKey: String, CaseIterable, Codable, Identifiable {
    case control
    case option

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .control: return "Control"
        case .option:  return "Option"
        }
    }

    var modifierFlag: NSEvent.ModifierFlags {
        switch self {
        case .control: return .control
        case .option:  return .option
        }
    }

    /// Physical key codes for left and right variants of this modifier key
    var physicalKeyCodes: Set<UInt16> {
        switch self {
        case .control: return [59, 62]  // left control, right control
        case .option:  return [58, 61]  // left option, right option
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        // "command" was a valid value in a previous version — fall back to control
        self = HoldModifierKey(rawValue: raw) ?? .control
    }
}

