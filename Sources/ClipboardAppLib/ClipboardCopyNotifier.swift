import AppKit
import Foundation
import UserNotifications

/// Posts a local notification when a new item is recorded (respects ``AppSettings``).
public enum ClipboardCopyNotifier {
    public static func notifyIfNeeded(content: ClipboardItem.Content, settings: AppSettings) {
        guard settings.showCopyNotifications else { return }

        let hidePreview = settings.hideCopiedPreviews
        let title: String
        let body: String
        if hidePreview {
            title = "Clipboard"
            body = "New copy added to history"
        } else {
            switch content {
            case .text:
                title = "Text copied"
                body = content.previewString(maxLength: 250)
            case .files(let paths):
                title = paths.count == 1 ? "File copied" : "\(paths.count) files copied"
                body = content.previewString(maxLength: 250)
            }
        }

        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { noteSettings in
            let deliver: () -> Void = {
                Self.deliverNotification(title: title, body: body)
            }
            switch noteSettings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async(execute: deliver)
            case .notDetermined:
                DispatchQueue.main.async {
                    NSApp.activate(ignoringOtherApps: true)
                    center.requestAuthorization(options: ClipboardNotifications.authorizationOptions) { granted, _ in
                        if granted {
                            deliver()
                        }
                    }
                }
            default:
                break
            }
        }
    }

    private static func deliverNotification(title: String, body: String) {
        let n = UNMutableNotificationContent()
        n.title = title
        n.body = body
        n.sound = nil
        let id = UUID().uuidString
        let request = UNNotificationRequest(identifier: id, content: n, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
