import UserNotifications

/// Shared authorization flags for copy alerts (macOS has no `.banner` / `.list` in `UNAuthorizationOptions`).
public enum ClipboardNotifications {
    public static let authorizationOptions: UNAuthorizationOptions = [.alert, .sound, .badge]
}
