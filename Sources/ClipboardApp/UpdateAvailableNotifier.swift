import AppKit
import ClipboardAppLib
import Foundation
import UserNotifications

/// Startup check: compares the running app to the latest GitHub release and posts one notification per new release tag.
enum UpdateAvailableNotifier {
    static let releasePageURLUserInfoKey = "releasePageURL"

    private static let lastNotifiedKey = "lastNotifiedGitHubReleaseTag"
    private static let notificationIdentifier = "com.clipboard.app.updateAvailable"

    static func checkAndNotifyIfNeeded() async {
        let v = AppVersion.string
        let current = (v == "—") ? "0" : v
        let outcome = await GitHubUpdateCheck.check(currentVersion: current)
        guard case let .updateAvailable(latest, pageURL) = outcome else { return }

        if UserDefaults.standard.string(forKey: lastNotifiedKey) == latest {
            return
        }

        await postUpdateNotification(latestVersion: latest, pageURL: pageURL)
    }

    private static func postUpdateNotification(latestVersion: String, pageURL: URL) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        let canDeliver: Bool
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            canDeliver = true
        case .notDetermined:
            canDeliver = await withCheckedContinuation { continuation in
                DispatchQueue.main.async {
                    NSApp.activate(ignoringOtherApps: true)
                    UNUserNotificationCenter.current().requestAuthorization(
                        options: ClipboardNotifications.authorizationOptions
                    ) { granted, _ in
                        continuation.resume(returning: granted)
                    }
                }
            }
        case .denied:
            UserDefaults.standard.set(latestVersion, forKey: lastNotifiedKey)
            return
        @unknown default:
            return
        }

        guard canDeliver else {
            UserDefaults.standard.set(latestVersion, forKey: lastNotifiedKey)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Clipboard update available"
        content.body = "Version \(latestVersion) is available on GitHub."
        content.sound = .default
        content.userInfo = [Self.releasePageURLUserInfoKey: pageURL.absoluteString]

        let request = UNNotificationRequest(identifier: notificationIdentifier, content: content, trigger: nil)
        do {
            try await center.add(request)
            UserDefaults.standard.set(latestVersion, forKey: lastNotifiedKey)
        } catch {
            // Leave lastNotified unset so a later launch can retry.
        }
    }
}
