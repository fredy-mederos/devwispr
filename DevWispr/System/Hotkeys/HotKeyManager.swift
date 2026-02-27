//
//  HotKeyManager.swift
//  DevWispr
//

import AppKit
import Foundation
import HotKey

final class DefaultHotkeyManager: HotkeyManager {
    private var holdHotKey: HotKey?
    private var toggleHotKey: HotKey?
    private var globalFlagsMonitor: Any?
    private var globalKeyDownMonitor: Any?
    private var isHoldActive: Bool = false
    private var holdWorkItem: DispatchWorkItem?
    private var suppressHoldUntil: Date?
    private var lastNonHoldModifierKeyDownAt: Date?
    private var lastHoldModifierDownAt: Date?
    private var toggleHandler: (() -> Void)?
    private var currentToggleKeyCombo: KeyCombo?
    private var holdModifier: NSEvent.ModifierFlags = .control
    private var holdKeyCodes: Set<UInt16> = [59, 62] // left/right control

    func registerHoldToTalk(handler: @escaping (Bool) -> Void) throws {
        // Remove any existing monitors before installing new ones.
        // Without this, re-registering (e.g. after toggling shortcuts off/on)
        // leaks the old monitor — it keeps firing even after unregisterAll().
        if let existing = globalFlagsMonitor {
            NSEvent.removeMonitor(existing)
            globalFlagsMonitor = nil
        }
        if let existing = globalKeyDownMonitor {
            NSEvent.removeMonitor(existing)
            globalKeyDownMonitor = nil
        }

        // HotKey doesn't reliably handle modifier-only keys (like Control).
        // Use flagsChanged monitors to detect Control press/release.
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            DispatchQueue.main.async {
                self?.handleFlagsChanged(event, handler: handler)
            }
        }

        // If another key is pressed while Control is down, cancel hold-to-talk
        // to allow combos like Control+Space to work.
        globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            DispatchQueue.main.async {
                self?.handleKeyDown(event, handler: handler)
            }
        }
    }

    func registerToggle(handler: @escaping () -> Void) throws {
        toggleHandler = handler
        installToggleHotKey(keyCombo: KeyCombo(key: .space, modifiers: [.control]))
    }

    func updateToggleShortcut(_ binding: ShortcutBinding?) throws {
        if let binding, let key = Key(carbonKeyCode: binding.keyCode) {
            let modifiers = NSEvent.ModifierFlags(rawValue: binding.modifierFlags)
            let keyCombo = KeyCombo(key: key, modifiers: modifiers)
            installToggleHotKey(keyCombo: keyCombo)
        } else {
            installToggleHotKey(keyCombo: KeyCombo(key: .space, modifiers: [.control]))
        }
    }

    func updateHoldModifier(_ modifier: HoldModifierKey) {
        holdModifier = modifier.modifierFlag
        holdKeyCodes = modifier.physicalKeyCodes
    }

    func suspendToggle() {
        toggleHotKey = nil
    }

    func resumeToggle() {
        guard let keyCombo = currentToggleKeyCombo else { return }
        installToggleHotKey(keyCombo: keyCombo)
    }

    private func installToggleHotKey(keyCombo: KeyCombo) {
        // Skip reinstall if the combo hasn't changed — avoids a HotKey deregister/register
        // race that causes the shortcut to stop working (observable with Control+Space).
        if let existing = currentToggleKeyCombo,
           existing.key == keyCombo.key,
           existing.modifiers == keyCombo.modifiers,
           toggleHotKey != nil {
            return
        }
        currentToggleKeyCombo = keyCombo
        toggleHotKey = nil
        let hotKey = HotKey(keyCombo: keyCombo)
        hotKey.keyDownHandler = { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async {
                self.suppressHoldUntil = Date().addingTimeInterval(0.35)
                self.toggleHandler?()
            }
        }
        toggleHotKey = hotKey
    }

    func unregisterAll() {
        holdHotKey = nil
        toggleHotKey = nil
        if let globalFlagsMonitor {
            NSEvent.removeMonitor(globalFlagsMonitor)
            self.globalFlagsMonitor = nil
        }
        if let globalKeyDownMonitor {
            NSEvent.removeMonitor(globalKeyDownMonitor)
            self.globalKeyDownMonitor = nil
        }
        isHoldActive = false
        holdWorkItem?.cancel()
        holdWorkItem = nil
        lastHoldModifierDownAt = nil
    }

    private func handleFlagsChanged(_ event: NSEvent, handler: @escaping (Bool) -> Void) {
        let isHoldModifierOnly = event.modifierFlags.intersection([.control, .option, .command, .shift, .capsLock, .function]) == [holdModifier]
        let isHoldModifierDown = event.modifierFlags.contains(holdModifier)

        let now = Date()
        let suppressActive = (suppressHoldUntil ?? .distantPast) > now
        debugLog("flagsChanged keyCode=\(event.keyCode) holdModifierDown=\(isHoldModifierDown) holdModifierOnly=\(isHoldModifierOnly) isHoldActive=\(isHoldActive) suppressHold=\(suppressActive)")
        if isHoldModifierDown && isHoldModifierOnly {
            lastHoldModifierDownAt = now
            if suppressActive {
                return
            }
            if holdWorkItem == nil && !isHoldActive {
                debugLog("Scheduling hold-to-talk activation")
                let workItem = DispatchWorkItem { [weak self] in
                    guard let self, !self.isHoldActive else { return }
                    // If a toggle shortcut fired recently, don't activate hold-to-talk.
                    // This handles the case where the global keyDown monitor doesn't
                    // receive the event (consumed by the HotKey tap) so the work item
                    // was never cancelled.
                    let nowCheck = Date()
                    if (self.suppressHoldUntil ?? .distantPast) > nowCheck {
                        debugLog("Hold-to-talk suppressed due to active suppress window")
                        return
                    }
                    if let lastKeyDown = self.lastNonHoldModifierKeyDownAt,
                       now.timeIntervalSince(lastKeyDown) < 0.25 {
                        debugLog("Hold-to-talk suppressed due to recent keyDown")
                        return
                    }
                    if let lastHoldModifierDownAt = self.lastHoldModifierDownAt,
                       Date().timeIntervalSince(lastHoldModifierDownAt) < 0.2 {
                        debugLog("Hold-to-talk suppressed due to short modifier hold")
                        return
                    }
                    self.isHoldActive = true
                    debugLog("Hold-to-talk activated")
                    handler(true)
                }
                holdWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
            }
        } else {
            if holdWorkItem != nil {
                debugLog("Cancelling pending hold-to-talk")
            }
            holdWorkItem?.cancel()
            holdWorkItem = nil
            lastHoldModifierDownAt = nil
            if isHoldActive {
                // Only deactivate if the suppress window is not active.
                // A toggle shortcut sets suppressHoldUntil to prevent the
                // hold modifier key-release from prematurely stopping a toggle recording.
                let suppressActive = (suppressHoldUntil ?? .distantPast) > now
                if suppressActive {
                    debugLog("Hold-to-talk release suppressed (toggle recently fired)")
                    isHoldActive = false
                    return
                }
                isHoldActive = false
                debugLog("Hold-to-talk deactivated")
                handler(false)
            }
        }
    }

    private func handleKeyDown(_ event: NSEvent, handler: @escaping (Bool) -> Void) {
        if holdKeyCodes.contains(event.keyCode) {
            return
        }

        debugLog("keyDown keyCode=\(event.keyCode) modifiers=\(event.modifierFlags.rawValue)")
        // Suppress hold-to-talk when any key is pressed while the hold modifier is down.
        // This ensures toggle shortcuts (which share the hold modifier) don't also trigger hold-to-talk.
        if event.modifierFlags.contains(holdModifier) {
            suppressHoldUntil = Date().addingTimeInterval(0.5)
            debugLog("Suppressing hold-to-talk due to key combo with hold modifier")
        }
        lastNonHoldModifierKeyDownAt = Date()
        if holdWorkItem != nil {
            debugLog("Cancelling pending hold-to-talk due to other key")
            holdWorkItem?.cancel()
            holdWorkItem = nil
        }

        if isHoldActive {
            isHoldActive = false
            debugLog("Hold-to-talk deactivated due to other key")
            handler(false)
        }
    }
}
