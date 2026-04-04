import AppKit
import ClipboardAppLib
import SwiftUI

/// Hosts the overlay in an `NSPanel` and restores the previously frontmost app when closed.
final class OverlayPanelController: NSObject, NSWindowDelegate {
    static let shared = OverlayPanelController()

    private var panel: NSPanel?
    private var hosting: NSViewController?
    private weak var store: ClipboardHistoryStore?
    private var previousApp: NSRunningApplication?

    private override init() {
        super.init()
    }

    func attach(store: ClipboardHistoryStore) {
        self.store = store
    }

    func toggle() {
        guard let panel else {
            createPanelIfNeeded()
            show()
            return
        }
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    private func createPanelIfNeeded() {
        guard panel == nil, let store else { return }

        let root = OverlayContentView(
            store: store,
            onSelect: { [weak self] content in
                store.copyContentToPasteboard(content)
                // Let the pasteboard commit before switching apps so ⌘V in the prior app sees this content.
                DispatchQueue.main.async {
                    self?.hide()
                }
            },
            onDismiss: { [weak self] in
                self?.hide()
            }
        )

        let host = NSHostingController(rootView: root)
        hosting = host

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 340),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.title = ""
        p.titlebarAppearsTransparent = true
        p.isFloatingPanel = true
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isReleasedWhenClosed = false
        p.hidesOnDeactivate = false
        p.delegate = self
        p.contentViewController = host
        p.standardWindowButton(.closeButton)?.isHidden = false
        p.center()

        panel = p
    }

    private func show() {
        createPanelIfNeeded()
        guard let panel else { return }

        previousApp = NSWorkspace.shared.frontmostApplication
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        guard let panel else { return }
        panel.orderOut(nil)
        let prev = previousApp
        previousApp = nil
        prev?.activate(options: [.activateAllWindows])
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hide()
        return false
    }

    func windowDidResignKey(_ notification: Notification) {
        // Click-outside / switch app: dismiss without stealing focus again.
        guard let w = notification.object as? NSWindow, w == panel, w.isVisible else { return }
        hide()
    }
}
