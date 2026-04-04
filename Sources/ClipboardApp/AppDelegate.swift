import AppKit
import ClipboardAppLib
import Combine
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let settings = AppSettings()

    private(set) lazy var historyStore: ClipboardHistoryStore = ClipboardHistoryStore(settings: settings)
    private var hotKeyCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        settings.syncLaunchAtLoginWithSystem()
        NotificationPermission.requestForCopyAlertsIfEnabled(settings.showCopyNotifications)
        OverlayPanelController.shared.attach(store: historyStore)
        GlobalHotKey.shared.onHotKey = {
            OverlayPanelController.shared.toggle()
        }
        registerOverlayHotKey()
        hotKeyCancellable = Publishers.CombineLatest(
            settings.$overlayHotKeyKeyCode,
            settings.$overlayHotKeyCarbonModifiers
        )
        .debounce(for: .milliseconds(120), scheduler: RunLoop.main)
        .dropFirst()
        .sink { [weak self] _, _ in
            self?.registerOverlayHotKey()
        }
        historyStore.start()

        Task(priority: .utility) {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await UpdateAvailableNotifier.checkAndNotifyIfNeeded()
        }
    }

    private func registerOverlayHotKey() {
        GlobalHotKey.shared.register(
            keyCode: UInt32(truncatingIfNeeded: settings.overlayHotKeyKeyCode),
            carbonModifiers: UInt32(truncatingIfNeeded: settings.overlayHotKeyCarbonModifiers)
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        GlobalHotKey.shared.unregister()
        historyStore.stop()
    }

    // Menu bar (LSUIElement) apps are treated as foreground; without this, copy banners never appear.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        let info = response.notification.request.content.userInfo
        guard let urlString = info[UpdateAvailableNotifier.releasePageURLUserInfoKey] as? String,
              let url = URL(string: urlString)
        else { return }
        NSWorkspace.shared.open(url)
    }
}
