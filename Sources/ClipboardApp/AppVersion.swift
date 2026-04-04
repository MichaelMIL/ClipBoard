import Foundation

/// Marketing version from the main bundle’s `CFBundleShortVersionString` (no extra file reads).
///
/// When the app lives under the user’s Documents folder, reading `Version.txt` from the resource bundle
/// triggers a Documents privacy prompt. `bundle-app.sh` copies the first line of `Sources/ClipboardApp/Version.txt`
/// into `Info.plist` at bundle time so About stays accurate without filesystem access on window open.
enum AppVersion {
    static var string: String {
        let s = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return s.isEmpty ? "—" : s
    }
}
