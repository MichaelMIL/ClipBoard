import ClipboardAppLib
import SwiftUI

private enum AuxiliaryWindowID: String {
    case about = "aboutClipboard"
}

@main
struct ClipboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Clipboard", systemImage: "doc.on.clipboard") {
            MenuBarCommandsContent(settings: appDelegate.settings)
        }

        Settings {
            PreferencesView(settings: appDelegate.settings)
                .frame(width: 480, height: 560)
        }

        Window("About Clipboard", id: AuxiliaryWindowID.about.rawValue) {
            AboutView()
        }
        .defaultSize(width: 440, height: 520)
    }
}

private struct MenuBarCommandsContent: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
       
        Button("Open overlay") {
            OverlayPanelController.shared.toggle()
        }
        .overlayMenuKeyboardShortcut(settings)

        Divider()
 SettingsLink {
            Text("Preferences…")
        }
        .keyboardShortcut(",", modifiers: .command)

        Button("About…") {
            openWindow(id: AuxiliaryWindowID.about.rawValue)
        }

        Button("Quit Clipboard") {
            NSApp.terminate(nil)
        }
    }
}
