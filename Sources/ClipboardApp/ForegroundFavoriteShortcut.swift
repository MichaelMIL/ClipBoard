import AppKit
import ApplicationServices
import ClipboardAppLib
import CoreGraphics
import os

private let favoriteShortcutLog = Logger(subsystem: "ClipboardApp", category: "FavoriteShortcut")

/// Remembers the last app that was frontmost other than this process (for “favorite selection” when the overlay is closed).
final class LastForegroundAppTracker {
    private(set) var lastOtherApp: NSRunningApplication?
    private var observer: NSObjectProtocol?
    private let selfPID = ProcessInfo.processInfo.processIdentifier

    /// If another app is already frontmost (e.g. at login), use it until the first activation notification.
    func seedFromFrontmostIfNeeded() {
        guard lastOtherApp == nil,
              let front = NSWorkspace.shared.frontmostApplication,
              front.processIdentifier != selfPID
        else { return }
        lastOtherApp = front
    }

    /// Call at the start of any global hotkey handler, before activating ClipboardApp, to remember who had focus.
    func notePeerFromWorkspaceIfPossible() {
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.processIdentifier != selfPID,
              !front.isTerminated
        else { return }
        lastOtherApp = front
    }

    func start() {
        guard observer == nil else { return }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self,
                  let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != self.selfPID
            else { return }
            self.lastOtherApp = app
        }
    }

    deinit {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}

// MARK: - Accessibility: read selection without synthetic ⌘C

private enum AXFocusedSelectionReader {
    static func readSelectedPlainText() -> String? {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts: NSDictionary = [promptKey: false]
        guard AXIsProcessTrustedWithOptions(opts) else {
            favoriteShortcutLog.error("Accessibility trust is off — enable ClipboardApp under Privacy & Security → Accessibility.")
            return nil
        }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedObj: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedObj) == .success else {
            return nil
        }
        guard CFGetTypeID(focusedObj) == AXUIElementGetTypeID() else { return nil }
        let focused = focusedObj as! AXUIElement

        var selected: CFTypeRef?
        if AXUIElementCopyAttributeValue(focused, kAXSelectedTextAttribute as CFString, &selected) == .success,
           let str = selected as? String
        {
            let t = str.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
        }

        var rangeVal: CFTypeRef?
        var valueObj: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focused, kAXSelectedTextRangeAttribute as CFString, &rangeVal) == .success,
              AXUIElementCopyAttributeValue(focused, kAXValueAttribute as CFString, &valueObj) == .success,
              let full = valueObj as? String,
              let rangeUnwrapped = rangeVal,
              CFGetTypeID(rangeUnwrapped) == AXValueGetTypeID()
        else { return nil }

        let axRange = rangeUnwrapped as! AXValue
        guard AXValueGetType(axRange) == .cfRange else { return nil }
        var range = CFRange()
        guard AXValueGetValue(axRange, .cfRange, &range), range.length > 0, range.location >= 0 else { return nil }

        let nsFull = full as NSString
        let nsRange = NSRange(location: range.location, length: range.length)
        guard nsRange.upperBound <= nsFull.length else { return nil }
        let sub = nsFull.substring(with: nsRange).trimmingCharacters(in: .whitespacesAndNewlines)
        return sub.isEmpty ? nil : sub
    }
}

// MARK: - Foreground capture

/// When the overlay is hidden: activate the target app, read selection via Accessibility when possible, else synthetic ⌘C + pasteboard.
enum ForegroundSelectionFavoriteCapture {
    private static let ansiCKeyCode: CGKeyCode = 8

    /// Prefer the app that was frontmost when the hotkey fired; if that is already us (focus moved early), use the last known other app.
    private static func resolveTargetApp(
        frontmostAtHotkey: NSRunningApplication?,
        lastTracked: NSRunningApplication?,
        selfPID: pid_t
    ) -> NSRunningApplication? {
        func usable(_ app: NSRunningApplication?) -> NSRunningApplication? {
            guard let app, !app.isTerminated, app.processIdentifier != selfPID else { return nil }
            return app
        }
        return usable(frontmostAtHotkey) ?? usable(lastTracked) ?? usable(NSWorkspace.shared.frontmostApplication)
    }

    static func postCommandC() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: ansiCKeyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: ansiCKeyCode, keyDown: false)
        else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        // Session tap often works when HID tap is blocked without Input Monitoring.
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }

    static func captureAndFavorite(
        store: ClipboardHistoryStore,
        frontmostAtHotkey: NSRunningApplication?,
        lastTrackedApp: NSRunningApplication?
    ) {
        let selfPID = ProcessInfo.processInfo.processIdentifier
        guard let app = resolveTargetApp(frontmostAtHotkey: frontmostAtHotkey, lastTracked: lastTrackedApp, selfPID: selfPID)
        else {
            favoriteShortcutLog.error("No target app — switch to the app that has the text, then try again. (Console: subsystem ClipboardApp, category FavoriteShortcut)")
            NSSound.beep()
            return
        }

        let appLabel = app.localizedName ?? "pid \(app.processIdentifier)"
        favoriteShortcutLog.notice("Target app: \(appLabel, privacy: .public)")

        guard app.activate(options: [.activateAllWindows]) else {
            favoriteShortcutLog.error("Could not activate \(appLabel, privacy: .public)")
            NSSound.beep()
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            if let text = AXFocusedSelectionReader.readSelectedPlainText() {
                favoriteShortcutLog.notice("Added favorite via Accessibility, character count: \(text.count)")
                _ = store.addFavoriteFromCapturedContent(.text(text))
                return
            }

            favoriteShortcutLog.notice("AX had no selection; trying synthetic ⌘C (Input Monitoring may be required)")

            let beforeCount = NSPasteboard.general.changeCount
            Self.postCommandC()

            var attempts = 0
            func poll() {
                attempts += 1
                if NSPasteboard.general.changeCount != beforeCount {
                    if let content = ClipboardHistoryStore.contentFromGeneralPasteboard() {
                        _ = store.addFavoriteFromCapturedContent(content)
                        favoriteShortcutLog.notice("Added favorite from pasteboard after ⌘C")
                        return
                    }
                }
                if attempts >= 45 {
                    if NSPasteboard.general.changeCount != beforeCount {
                        favoriteShortcutLog.error("Pasteboard changed but plain text / file paths were not readable.")
                    } else {
                        favoriteShortcutLog.error("Pasteboard unchanged after ⌘C — add ClipboardApp under Input Monitoring, or select text in an app that supports Accessibility selected text.")
                    }
                    NSSound.beep()
                    return
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: poll)
            }
            poll()
        }
    }
}
