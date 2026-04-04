import AppKit
import Carbon
import ClipboardAppLib
import SwiftUI

final class KeyCaptureNSView: NSView {
    var isRecording = false {
        didSet {
            if isRecording {
                DispatchQueue.main.async { [weak self] in
                    self?.window?.makeFirstResponder(self)
                }
            }
        }
    }

    var onCaptured: ((UInt16, UInt32, String) -> Void)?
    var onCancelRecording: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        if event.keyCode == UInt16(kVK_Escape) {
            isRecording = false
            onCancelRecording?()
            return
        }
        let carbon = HotKeyBridge.carbonModifiers(from: event.modifierFlags)
        if carbon == 0 && !Self.allowsZeroModifiers(keyCode: event.keyCode) {
            NSSound.beep()
            return
        }
        let menuChar = Self.menuCharacter(from: event)
        onCaptured?(event.keyCode, carbon, menuChar)
        isRecording = false
    }

    private static func allowsZeroModifiers(keyCode: UInt16) -> Bool {
        let k = Int(keyCode)
        switch k {
        case Int(kVK_F1), Int(kVK_F2), Int(kVK_F3), Int(kVK_F4), Int(kVK_F5), Int(kVK_F6), Int(kVK_F7), Int(kVK_F8),
             Int(kVK_F9), Int(kVK_F10), Int(kVK_F11), Int(kVK_F12), Int(kVK_F13), Int(kVK_F14), Int(kVK_F15),
             Int(kVK_F16), Int(kVK_F17), Int(kVK_F18), Int(kVK_F19), Int(kVK_F20):
            return true
        default:
            return false
        }
    }

    private static func menuCharacter(from event: NSEvent) -> String {
        guard let s = event.charactersIgnoringModifiers, let c = s.lowercased().first else { return "" }
        if c.isLetter || c.isNumber {
            return String(c)
        }
        return ""
    }
}

struct ShortcutRecorderRepresentable: NSViewRepresentable {
    @Binding var isRecording: Bool
    var onCaptured: (UInt16, UInt32, String) -> Void
    var onCancelRecording: () -> Void

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let v = KeyCaptureNSView()
        v.onCaptured = onCaptured
        v.onCancelRecording = onCancelRecording
        return v
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.onCaptured = onCaptured
        nsView.onCancelRecording = onCancelRecording
        nsView.isRecording = isRecording
    }
}

struct OverlayShortcutRecorder: View {
    @ObservedObject var settings: AppSettings
    @State private var isRecording = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(HotKeyBridge.displayString(settings: settings))
                    .font(.body.monospaced())
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Button(isRecording ? "Cancel" : "Record…") {
                    if isRecording {
                        isRecording = false
                    } else {
                        isRecording = true
                    }
                }
                Button("Reset to default") {
                    settings.resetOverlayHotKeyToDefaults()
                }
            }
            Text("Click Record, then press the new shortcut. Include ⌘, ⌥, ⌃, and/or ⇧ unless you use a function key. Press Escape to cancel.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .background(
            ShortcutRecorderRepresentable(
                isRecording: $isRecording,
                onCaptured: { keyCode, carbon, menuChar in
                    settings.overlayHotKeyKeyCode = Int(keyCode)
                    settings.overlayHotKeyCarbonModifiers = Int(carbon)
                    settings.overlayHotKeyMenuCharacter = menuChar
                    isRecording = false
                },
                onCancelRecording: {
                    isRecording = false
                }
            )
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .accessibilityHidden(true)
        )
    }
}
