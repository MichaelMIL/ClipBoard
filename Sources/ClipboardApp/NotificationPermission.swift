import AppKit
import ClipboardAppLib
import UserNotifications

enum NotificationPermission {

    private static let lsRegisterTool =
        "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

    /// Running inside a `.app` bundle (required for reliable Launch Services / notification registration).
    static var isEmbeddedApplicationBundle: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    static func requestForCopyAlertsIfEnabled(_ enabled: Bool) {
        guard enabled else { return }

        let startAuthorization: () -> Void = {
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    requestAuthorization(skipFurtherLaunchServicesRepair: false)
                }
            }
        }

        if isEmbeddedApplicationBundle {
            let path = Bundle.main.bundleURL.path
            DispatchQueue.global(qos: .utility).async {
                _ = runLSRegister(arguments: ["-f", path])
                startAuthorization()
            }
        } else {
            startAuthorization()
        }
    }

    /// Full unregister/re-register, then ask again. Use when Clipboard never appears under System Settings → Notifications (common after replacing dev builds).
    static func repairLaunchServicesAndRequestAuthorization() {
        guard isEmbeddedApplicationBundle else { return }
        let path = Bundle.main.bundleURL.path
        DispatchQueue.global(qos: .utility).async {
            _ = runLSRegister(arguments: ["-u", path])
            _ = runLSRegister(arguments: ["-f", path])
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    requestAuthorization(skipFurtherLaunchServicesRepair: true)
                }
            }
        }
    }

    static func openSystemNotificationSettings() {
        let urls = [
            URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension"),
            URL(string: "x-apple.systempreferences:com.apple.preference.notifications"),
        ]
        for u in urls {
            guard let u, NSWorkspace.shared.open(u) else { continue }
            return
        }
    }

    private static func requestAuthorization(skipFurtherLaunchServicesRepair: Bool) {
        UNUserNotificationCenter.current().requestAuthorization(options: ClipboardNotifications.authorizationOptions) { granted, error in
            DispatchQueue.main.async {
                guard !granted, !skipFurtherLaunchServicesRepair, isEmbeddedApplicationBundle else { return }
                guard let error else { return }
                let ns = error as NSError
                guard ns.domain == UNError.errorDomain, ns.code == UNError.Code.notificationsNotAllowed.rawValue else {
                    return
                }
                repairLaunchServicesAndRequestAuthorization()
            }
        }
    }

    @discardableResult
    private static func runLSRegister(arguments: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: lsRegisterTool)
        p.arguments = arguments
        do {
            try p.run()
            p.waitUntilExit()
            return p.terminationStatus
        } catch {
            return -1
        }
    }
}
