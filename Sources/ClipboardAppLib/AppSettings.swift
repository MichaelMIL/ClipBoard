import Carbon
import Combine
import Foundation
import ServiceManagement

/// User preferences stored in `UserDefaults`. `maxHistoryItems` is clamped (10…200).
/// Launch-at-login uses `SMAppService` (macOS 13+); may fail for unsigned dev builds—see `launchAtLoginError`.
public final class AppSettings: ObservableObject {
    @Published public var maxHistoryItems: Int {
        didSet {
            let clamped = Self.clampHistoryCount(maxHistoryItems)
            if clamped != maxHistoryItems {
                maxHistoryItems = clamped
                return
            }
            UserDefaults.standard.set(maxHistoryItems, forKey: Keys.maxHistory)
        }
    }

    @Published public var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
            applyLaunchAtLogin()
        }
    }

    @Published public private(set) var launchAtLoginError: String?

    /// Banner when something new is recorded from the pasteboard.
    @Published public var showCopyNotifications: Bool {
        didSet { UserDefaults.standard.set(showCopyNotifications, forKey: Keys.showCopyNotifications) }
    }

    /// When true, notifications omit text/file names (privacy). Overlay list rows still show full content.
    @Published public var hideCopiedPreviews: Bool {
        didSet { UserDefaults.standard.set(hideCopiedPreviews, forKey: Keys.hideCopiedPreviews) }
    }

    /// When true, ``ClipboardHistoryStore`` writes AES-256-GCM–wrapped files; when false, plain JSON on disk.
    @Published public var encryptClipboardDataAtRest: Bool {
        didSet { UserDefaults.standard.set(encryptClipboardDataAtRest, forKey: Keys.encryptClipboardDataAtRest) }
    }

    /// Virtual key code for the global overlay shortcut (Carbon / `NSEvent.keyCode`).
    @Published public var overlayHotKeyKeyCode: Int {
        didSet { UserDefaults.standard.set(overlayHotKeyKeyCode, forKey: Keys.overlayHotKeyKeyCode) }
    }

    /// Carbon modifier mask: `cmdKey`, `shiftKey`, `optionKey`, `controlKey`.
    @Published public var overlayHotKeyCarbonModifiers: Int {
        didSet { UserDefaults.standard.set(overlayHotKeyCarbonModifiers, forKey: Keys.overlayHotKeyCarbonModifiers) }
    }

    /// Lowercase character for the menu item keyboard shortcut when applicable (empty for F-keys, etc.).
    @Published public var overlayHotKeyMenuCharacter: String {
        didSet { UserDefaults.standard.set(overlayHotKeyMenuCharacter, forKey: Keys.overlayHotKeyMenuCharacter) }
    }

    private enum Keys {
        static let maxHistory = "maxHistoryItems"
        static let launchAtLogin = "launchAtLogin"
        static let showCopyNotifications = "showCopyNotifications"
        static let hideCopiedPreviews = "hideCopiedPreviews"
        static let encryptClipboardDataAtRest = "encryptClipboardDataAtRest"
        static let overlayHotKeyKeyCode = "overlayHotKeyKeyCode"
        static let overlayHotKeyCarbonModifiers = "overlayHotKeyCarbonModifiers"
        static let overlayHotKeyMenuCharacter = "overlayHotKeyMenuCharacter"
    }

    /// Default overlay shortcut: ⌘⇧C (`kVK_ANSI_C` + cmd + shift).
    public static let defaultOverlayKeyCode = 8
    public static let defaultOverlayCarbonModifiers = Int(UInt32(cmdKey | shiftKey))
    public static let defaultOverlayMenuCharacter = "c"

    public init() {
        let defaults = UserDefaults.standard
        let stored = defaults.object(forKey: Keys.maxHistory) as? Int ?? 50
        maxHistoryItems = Self.clampHistoryCount(stored)
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        showCopyNotifications = (defaults.object(forKey: Keys.showCopyNotifications) as? Bool) ?? true
        hideCopiedPreviews = defaults.bool(forKey: Keys.hideCopiedPreviews)
        if let enc = defaults.object(forKey: Keys.encryptClipboardDataAtRest) as? Bool {
            encryptClipboardDataAtRest = enc
        } else {
            encryptClipboardDataAtRest = false
        }
        if let code = defaults.object(forKey: Keys.overlayHotKeyKeyCode) as? Int, (0...255).contains(code) {
            overlayHotKeyKeyCode = code
        } else {
            overlayHotKeyKeyCode = Self.defaultOverlayKeyCode
        }
        if let mods = defaults.object(forKey: Keys.overlayHotKeyCarbonModifiers) as? Int, mods >= 0, mods <= 0xFFFF_FFFF {
            overlayHotKeyCarbonModifiers = mods
        } else {
            overlayHotKeyCarbonModifiers = Self.defaultOverlayCarbonModifiers
        }
        if let ch = defaults.string(forKey: Keys.overlayHotKeyMenuCharacter), ch.count <= 2 {
            overlayHotKeyMenuCharacter = ch
        } else {
            overlayHotKeyMenuCharacter = Self.defaultOverlayMenuCharacter
        }
    }

    public func resetOverlayHotKeyToDefaults() {
        overlayHotKeyKeyCode = Self.defaultOverlayKeyCode
        overlayHotKeyCarbonModifiers = Self.defaultOverlayCarbonModifiers
        overlayHotKeyMenuCharacter = Self.defaultOverlayMenuCharacter
    }

    /// Re-applies saved preference to `SMAppService` (e.g. after app update).
    public func syncLaunchAtLoginWithSystem() {
        applyLaunchAtLogin()
    }

    private func applyLaunchAtLogin() {
        launchAtLoginError = nil
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLoginError = error.localizedDescription
        }
    }

    public static func clampHistoryCount(_ n: Int) -> Int {
        min(200, max(10, n))
    }
}
