import AppKit
import Carbon
import os

private let hotKeyLog = Logger(subsystem: "ClipboardApp", category: "HotKey")

/// Global shortcut via Carbon `RegisterEventHotKey` (key code + Carbon modifier mask).
/// Typically does **not** require Accessibility or Input Monitoring (unlike CGEvent taps).
final class GlobalHotKey {
    static let shared = GlobalHotKey()

    var onHotKey: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    private let hotKeyID = EventHotKeyID(signature: OSType(0x434C5042), id: 1) // 'CLPB'

    private init() {}

    func register(keyCode: UInt32, carbonModifiers: UInt32) {
        installHandlerIfNeeded()

        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        let regStatus = RegisterEventHotKey(keyCode, carbonModifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if regStatus != noErr {
            hotKeyLog.error(
                "RegisterEventHotKey failed: status=\(regStatus, privacy: .public) keyCode=\(keyCode, privacy: .private) modifiers=\(carbonModifiers, privacy: .private)"
            )
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            guard let event else { return OSStatus(eventNotHandledErr) }
            var hk = EventHotKeyID()
            let err = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hk
            )
            guard err == noErr, hk.id == 1 else { return OSStatus(eventNotHandledErr) }
            DispatchQueue.main.async {
                GlobalHotKey.shared.onHotKey?()
            }
            return noErr
        }

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            nil,
            &eventHandler
        )
        if installStatus != noErr {
            hotKeyLog.error("InstallEventHandler failed: status=\(installStatus, privacy: .public)")
        }
    }

    deinit {
        unregister()
    }
}
