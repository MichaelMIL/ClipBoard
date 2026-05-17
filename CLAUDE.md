# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build / run

This is a SwiftPM project that ships as a `.app` bundle, not a plain executable. **Always run via the bundled `ClipboardApp.app`**, not `swift run` — `LSUIElement` (menu bar), `UNUserNotificationCenter`, `SMAppService` (launch-at-login), and Launch Services registration all require a real bundle.

- `./scripts/bundle-app.sh` — release build via `swift build -c release`, produces `ClipboardApp.app` at the repo root, generates `AppIcon.icns` from `Sources/ClipboardApp/Resources/logo.png`, copies `ExecutableInfo.plist` → `Contents/Info.plist`, syncs `CFBundleShortVersionString` from `Sources/ClipboardApp/Version.txt`, and ad-hoc codesigns (`codesign --force --deep --sign -`).
- `./scripts/build-and-open.sh --skip-version` — bundle + `open ClipboardApp.app` (use during development to skip version bump).
- `./scripts/build-and-open.sh --major|--minor|--alpha|--beta [--release]` — bump `Version.txt` (semver, with optional `-alpha.N`/`-beta.N` prerelease), rebuild, bundle, and optionally produce `releases/<ver>/ClipboardApp-<ver>.zip` with an MD5 sidecar.
- `swift build` — fine for type-checking; the resulting binary will not have a usable menu bar/notifications experience.

There is no test target.

## Architecture

Two SwiftPM targets with a clear seam:

- **`ClipboardAppLib`** (library) — pure, AppKit-only, no SwiftUI. Owns the model and persistence: `ClipboardItem`, `ClipboardHistoryStore` (pasteboard polling + history/favorites + JSON persistence), `AppSettings` (UserDefaults-backed `@Published` preferences), `ClipboardPersistenceCrypto` (AES-GCM envelope), `ClipboardCopyNotifier` (copy banner).
- **`ClipboardApp`** (executable) — SwiftUI `@main` + AppKit glue. Owns the menu bar (`MenuBarExtra`), overlay (`NSPanel` + `OverlayContentView`), global hotkey, preferences, About, and update checker.

Keep cross-cutting model/persistence/settings logic in `ClipboardAppLib`; keep UI, hotkeys, and AppKit integration in `ClipboardApp`.

### Clipboard capture loop

`ClipboardHistoryStore` polls `NSPasteboard.general.changeCount` every **0.35s** via a `Timer` on the main run loop. On change it tries files first (`readObjects(forClasses: [NSURL.self])`), then text. Duplicates are filtered by a "fingerprint" (length + hashValue) and by matching the head item, so re-copying the same content does not insert a new row. Inserts go to `items[0]`. Writes are debounced ~0.45s via `DispatchQueue.main.asyncAfter` + `DispatchWorkItem`.

### Persistence + encryption envelope

History and favorites live under `~/Library/Application Support/ClipboardApp/{history.json,favorites.json}`. `ClipboardPersistenceCrypto` writes a `CLP1` magic prefix followed by `AES.GCM.SealedBox.combined` when encryption is on; without the prefix the file is plain JSON. Reads auto-detect via `isEncryptedFileFormat`. The 256-bit key is stored in the **login Keychain** as a generic password (`service = ClipboardApp.persistence`, `account = clipboard-store-v1`, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`).

When the user toggles encryption, `persistenceFormatMismatch` causes the store to rewrite both files immediately so the envelope matches the setting (see the `encryptClipboardDataAtRest` Combine sink in `ClipboardHistoryStore.init`). Encrypted backups are not portable without the Keychain entry.

### Overlay panel

`OverlayPanelController` (singleton) hosts `OverlayContentView` inside an `NSPanel` with `.isFloatingPanel`, `.canJoinAllSpaces`, `.fullScreenAuxiliary`. Before show, it captures `NSWorkspace.shared.frontmostApplication`; on hide it re-activates that app so the user's `⌘V` lands in the originating app. `windowDidResignKey` dismisses on click-outside / app switch.

### Global hotkey

`GlobalHotKey` uses Carbon `RegisterEventHotKey` (not `CGEvent` taps) so the app **does not require Accessibility or Input Monitoring** for the overlay shortcut. `AppSettings` stores key code + Carbon modifier mask + a single lowercase character used only for the SwiftUI menu hint (`HotKeyBridge.overlayMenuKeyboardShortcut`). When the user records a new shortcut, `AppDelegate` re-registers via a `debounce(120ms)` Combine sink.

The separate "favorite selection" path in `ForegroundFavoriteShortcut.swift` *does* need Accessibility (preferred: `AXUIElementCopyAttributeValue` for `kAXSelectedTextAttribute`) and falls back to a synthetic `⌘C` posted to `.cgSessionEventTap`, which may need Input Monitoring.

### Versioning

`Sources/ClipboardApp/Version.txt` is the source of truth. `build-and-open.sh` bumps it and writes the same string into `ExecutableInfo.plist`'s `CFBundleShortVersionString`. `AppVersion.string` reads the running bundle's `CFBundleShortVersionString` at runtime — **not** the resource bundle's `Version.txt` (reading it would trigger a Documents privacy prompt when the app lives under `~/Documents/`).

### Update check

`UpdateAvailableNotifier` runs ~1.5s after launch, hits `https://api.github.com/repos/MichaelMIL/ClipBoard/releases/latest`, compares tags via `GitHubUpdateCheck.compareVersions` (strips leading `v`, splits on `.`, drops anything after `-`), and posts at most one notification per release tag (deduped via `UserDefaults` key `lastNotifiedGitHubReleaseTag`). Clicking the banner opens the release page (handled in `AppDelegate.userNotificationCenter(_:didReceive:...)`).

## Conventions

- `Info.plist` for the executable is `Sources/ClipboardApp/ExecutableInfo.plist`, embedded into the binary as a `__TEXT,__info_plist` section via `unsafeFlags` in `Package.swift`. `bundle-app.sh` *also* copies it to `Contents/Info.plist`. When you change app metadata (bundle id, `LSUIElement`, min OS), edit `ExecutableInfo.plist` — both code paths read it.
- `LSUIElement = true` makes this a menu bar–only app. The `UNUserNotificationCenterDelegate.willPresent` override in `AppDelegate` is necessary or copy banners never appear because the OS treats menu-bar apps as foreground.
- SwiftPM resource bundles are flat by default; `bundle-app.sh` reshapes `ClipboardApp_ClipboardApp.bundle` into `Contents/{Info.plist,Resources/…}` so `codesign --deep` accepts it.
- Persisted `ClipboardItem` uses a custom `Codable` with `text` / `filePaths` keys (not the enum's automatic encoding) — preserve this if you change the model, or write a migration.
- History size is clamped to **10…200** via `AppSettings.clampHistoryCount`; favorites are stored separately and are **not** trimmed when history shrinks.
