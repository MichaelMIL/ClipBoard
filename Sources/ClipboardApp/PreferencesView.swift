import AppKit
import ClipboardAppLib
import SwiftUI

struct PreferencesView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("History") {
                Stepper(value: $settings.maxHistoryItems, in: 10...200, step: 10) {
                    Text("Keep up to \(settings.maxHistoryItems) items")
                }
                Toggle("Encrypt history and favorites on disk", isOn: $settings.encryptClipboardDataAtRest)
                Text(historyStorageCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Notifications") {
                Toggle("Show notification when you copy", isOn: $settings.showCopyNotifications)
                Toggle("Hide copied content in notifications", isOn: $settings.hideCopiedPreviews)
                Button("Open Notifications settings…") {
                    NotificationPermission.openSystemNotificationSettings()
                }
                Button("Fix registration (Launch Services)…") {
                    NotificationPermission.repairLaunchServicesAndRequestAuthorization()
                }
                .disabled(!NotificationPermission.isEmbeddedApplicationBundle)
                Text("When hiding content, only a generic message is shown. Overlay rows still show full text so you can choose an item.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                // Text("Use ClipboardApp.app from scripts/bundle-app.sh, not only swift run, so Launch Services can register the app. If Clipboard still never appears in the notifications list, use Fix registration, then allow alerts in System Settings.")
                //     .font(.caption)
                //     .foregroundStyle(.secondary)
            }

            Section("Login") {
                Toggle("Open at login", isOn: $settings.launchAtLogin)
                if let err = settings.launchAtLoginError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Text("Uses the system login item (SMAppService). Unsigned local builds may need to allow the app under Login Items.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Shortcuts") {
                LabeledContent("Open overlay") {
                    OverlayShortcutRecorder(settings: settings)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            focusPreferencesWindow()
            NotificationPermission.requestForCopyAlertsIfEnabled(settings.showCopyNotifications)
        }
        .onChange(of: settings.showCopyNotifications) { _, enabled in
            NotificationPermission.requestForCopyAlertsIfEnabled(enabled)
        }
    }

    private var historyStorageCaption: String {
        var base = "Older entries are removed when the limit is lowered. History and favorites are saved under Application Support"
        if settings.encryptClipboardDataAtRest {
            base += " as encrypted JSON (AES-256-GCM; key in Keychain)."
        } else {
            base += " as readable JSON (not encrypted—anyone with access to your Mac user folder can read the files)."
        }
        return base
    }

    private func focusPreferencesWindow() {
        NSApp.activate(ignoringOtherApps: true)
        let bringForward = {
            if let window = NSApp.orderedWindows.first(where: { $0.isVisible && !($0 is NSPanel) }) {
                window.makeKeyAndOrderFront(nil)
            }
        }
        DispatchQueue.main.async {
            bringForward()
            DispatchQueue.main.async(execute: bringForward)
        }
    }
}
