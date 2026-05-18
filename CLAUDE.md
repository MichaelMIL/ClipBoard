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

History and favorites live under `~/Library/Application Support/ClipboardApp/{history.json,favorites.json}`. The support directory is created `0o700` and persistence files are written `0o600`. `ClipboardPersistenceCrypto` recognizes three on-disk envelopes:
- **`CLP2`** (current): `magic | AES.GCM.SealedBox.combined`, AAD bound to file role (`Data("CLP2|history|v1")` or `…|favorites|v1`). Swap/downgrade resistant.
- **`CLP1`** (legacy, read-only): old envelope with no AAD. Loaded for migration; on read the store flags a format mismatch via `formatMismatch(_:)` and rewrites the file as CLP2 on the next save.
- **Plain JSON**: no magic prefix; used when `encryptClipboardDataAtRest` is off.

The 256-bit key is stored in the **login Keychain** as a generic password (`service = ClipboardApp.persistence`, `account = clipboard-store-v1`, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, `kSecAttrSynchronizable = false`). Keychain semantics in `loadOrCreateSymmetricKey` distinguish `errSecItemNotFound` (generate a new key) from other failures (throw); a present-but-wrong-size entry throws `keychainCorrupted` rather than silently overwriting — destroying the key destroys all encrypted history.

Load errors are surfaced rather than swallowed: when `ClipboardHistoryStore.loadCollection` hits a decrypt or JSON-decode failure (vs. a transient Keychain failure), the file is renamed to `<name>.unreadable-<iso8601>` before the next save runs — so a one-off corruption does not result in silent overwrite. Transient Keychain failures leave the file intact.

**Keychain scoping caveat.** Because local builds use ad-hoc codesigning, the Keychain item is scoped only by `service`/`account`, not by Team ID — another ad-hoc binary claiming the same `service` could read it. The mitigation is Developer ID signing for release builds (see [Versioning + signing](#versioning--signing)). The encrypted backup files are not portable without the Keychain entry from the originating Mac.

### Overlay panel

`OverlayPanelController` (singleton) hosts `OverlayContentView` inside an `NSPanel` with `.isFloatingPanel`, `.canJoinAllSpaces`, `.fullScreenAuxiliary`. Before show, it captures `NSWorkspace.shared.frontmostApplication`; on hide it re-activates that app so the user's `⌘V` lands in the originating app. `windowDidResignKey` dismisses on click-outside / app switch.

### Global hotkey

`GlobalHotKey` uses Carbon `RegisterEventHotKey` (not `CGEvent` taps) so the app **does not require Accessibility or Input Monitoring** for the overlay shortcut. `AppSettings` stores key code + Carbon modifier mask + a single lowercase character used only for the SwiftUI menu hint (`HotKeyBridge.overlayMenuKeyboardShortcut`). When the user records a new shortcut, `AppDelegate` re-registers via a `debounce(120ms)` Combine sink.

The separate "favorite selection" path in `ForegroundFavoriteShortcut.swift` *does* need Accessibility (preferred: `AXUIElementCopyAttributeValue` for `kAXSelectedTextAttribute`) and falls back to a synthetic `⌘C` posted to `.cgSessionEventTap`, which may need Input Monitoring.

### Versioning + signing

`scripts/bundle-app.sh` signs the inner resource bundle first, then the app with Hardened Runtime (`--options runtime`) and `Supporting/ClipboardApp.entitlements`. Locally this uses the ad-hoc identity (`-`), so the resulting bundle has `flags=0x10002(adhoc,runtime)` and `TeamIdentifier=not set`. For tagged releases, swap `-` for a Developer ID Application certificate and add `--timestamp` + `xcrun notarytool` + `xcrun stapler staple` (see the comment block in the script).

`--deep` is no longer used; nested bundles are signed explicitly so Apple's deprecation warning does not regress over time.

### Versioning

`Sources/ClipboardApp/Version.txt` is the source of truth. `build-and-open.sh` bumps it and writes the same string into `ExecutableInfo.plist`'s `CFBundleShortVersionString`. `AppVersion.string` reads the running bundle's `CFBundleShortVersionString` at runtime — **not** the resource bundle's `Version.txt` (reading it would trigger a Documents privacy prompt when the app lives under `~/Documents/`).

### Update check

`UpdateAvailableNotifier` runs ~1.5s after launch, hits `https://api.github.com/repos/MichaelMIL/ClipBoard/releases/latest`, compares tags via `GitHubUpdateCheck.compareVersions` (strips leading `v`, splits on `.`, drops anything after `-`), and posts at most one notification per release tag (deduped via `UserDefaults` key `lastNotifiedGitHubReleaseTag`). Clicking the banner opens the release page (handled in `AppDelegate.userNotificationCenter(_:didReceive:...)`).

## Conventions

- `Info.plist` for the executable is `Sources/ClipboardApp/ExecutableInfo.plist`, embedded into the binary as a `__TEXT,__info_plist` section via `unsafeFlags` in `Package.swift`. `bundle-app.sh` *also* copies it to `Contents/Info.plist`. When you change app metadata (bundle id, `LSUIElement`, min OS), edit `ExecutableInfo.plist` — both code paths read it.
- `LSUIElement = true` makes this a menu bar–only app. The `UNUserNotificationCenterDelegate.willPresent` override in `AppDelegate` is necessary or copy banners never appear because the OS treats menu-bar apps as foreground.
- SwiftPM resource bundles are flat by default; `bundle-app.sh` reshapes `ClipboardApp_ClipboardApp.bundle` into `Contents/{Info.plist,Resources/…}` so per-component `codesign` accepts it.
- Persisted `ClipboardItem` uses a custom `Codable` with `text` / `filePaths` keys (not the enum's automatic encoding) — preserve this if you change the model, or write a migration.
- History size is clamped to **10…200** via `AppSettings.clampHistoryCount`; favorites are stored separately and are **not** trimmed when history shrinks.
