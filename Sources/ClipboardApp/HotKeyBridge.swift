import AppKit
import Carbon
import ClipboardAppLib
import SwiftUI

enum HotKeyBridge {
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var c: UInt32 = 0
        if flags.contains(.command) { c |= UInt32(cmdKey) }
        if flags.contains(.shift) { c |= UInt32(shiftKey) }
        if flags.contains(.option) { c |= UInt32(optionKey) }
        if flags.contains(.control) { c |= UInt32(controlKey) }
        return c
    }

    static func swiftUIModifiers(carbon: Int) -> SwiftUI.EventModifiers {
        let u = UInt32(truncatingIfNeeded: carbon)
        var m = SwiftUI.EventModifiers()
        if u & UInt32(cmdKey) != 0 { m.insert(.command) }
        if u & UInt32(shiftKey) != 0 { m.insert(.shift) }
        if u & UInt32(optionKey) != 0 { m.insert(.option) }
        if u & UInt32(controlKey) != 0 { m.insert(.control) }
        return m
    }

    /// Single lowercase character for `KeyEquivalent`, or nil (e.g. F-keys — menu shows no shortcut hint).
    static func keyEquivalentCharacter(from settings: AppSettings) -> Character? {
        let s = settings.overlayHotKeyMenuCharacter.trimmingCharacters(in: .whitespaces)
        guard let c = s.lowercased().first else { return nil }
        if c.isLetter || c.isNumber || "[]\\;',./`=-'".contains(c) {
            return c
        }
        return nil
    }

    static func displayString(settings: AppSettings) -> String {
        let keyPart: String
        if let c = settings.overlayHotKeyMenuCharacter.lowercased().first, c.isLetter || c.isNumber {
            keyPart = String(c).uppercased()
        } else {
            keyPart = keyGlyph(keyCode: settings.overlayHotKeyKeyCode)
        }
        return modifierPrefix(carbon: settings.overlayHotKeyCarbonModifiers) + keyPart
    }

    static func displayString(keyCode: Int, carbonModifiers: Int) -> String {
        modifierPrefix(carbon: carbonModifiers) + keyGlyph(keyCode: keyCode)
    }

    private static func modifierPrefix(carbon: Int) -> String {
        let u = UInt32(truncatingIfNeeded: carbon)
        var parts: [String] = []
        if u & UInt32(controlKey) != 0 { parts.append("⌃") }
        if u & UInt32(optionKey) != 0 { parts.append("⌥") }
        if u & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if u & UInt32(cmdKey) != 0 { parts.append("⌘") }
        return parts.joined()
    }

    private static func keyGlyph(keyCode: Int) -> String {
        switch keyCode {
        case Int(kVK_F1): return "F1"
        case Int(kVK_F2): return "F2"
        case Int(kVK_F3): return "F3"
        case Int(kVK_F4): return "F4"
        case Int(kVK_F5): return "F5"
        case Int(kVK_F6): return "F6"
        case Int(kVK_F7): return "F7"
        case Int(kVK_F8): return "F8"
        case Int(kVK_F9): return "F9"
        case Int(kVK_F10): return "F10"
        case Int(kVK_F11): return "F11"
        case Int(kVK_F12): return "F12"
        case Int(kVK_F13): return "F13"
        case Int(kVK_F14): return "F14"
        case Int(kVK_F15): return "F15"
        case Int(kVK_F16): return "F16"
        case Int(kVK_F17): return "F17"
        case Int(kVK_F18): return "F18"
        case Int(kVK_F19): return "F19"
        case Int(kVK_F20): return "F20"
        case Int(kVK_Space): return "Space"
        case Int(kVK_Return), Int(kVK_ANSI_KeypadEnter): return "↩"
        case Int(kVK_Tab): return "⇥"
        case Int(kVK_Delete): return "⌫"
        case Int(kVK_ForwardDelete): return "⌦"
        case Int(kVK_Escape): return "⎋"
        case Int(kVK_LeftArrow): return "←"
        case Int(kVK_RightArrow): return "→"
        case Int(kVK_DownArrow): return "↓"
        case Int(kVK_UpArrow): return "↑"
        default:
            return "Key \(keyCode)"
        }
    }
}

extension View {
    @ViewBuilder
    func overlayMenuKeyboardShortcut(_ settings: AppSettings) -> some View {
        if let ke = HotKeyBridge.keyEquivalentCharacter(from: settings) {
            keyboardShortcut(
                KeyEquivalent(ke),
                modifiers: HotKeyBridge.swiftUIModifiers(carbon: settings.overlayHotKeyCarbonModifiers)
            )
        } else {
            self
        }
    }
}
