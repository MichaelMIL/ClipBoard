#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift build -c release "$@"
BIN_DIR="$(swift build -c release --show-bin-path)"
BIN="$BIN_DIR/ClipboardApp"
APP="$ROOT/ClipboardApp.app"
CONTENTS="$APP/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
LOGO="$ROOT/Sources/ClipboardApp/Resources/logo.png"

rm -rf "$APP"
mkdir -p "$MACOS_DIR" "$RESOURCES"
cp "$BIN" "$MACOS_DIR/ClipboardApp"
chmod +x "$MACOS_DIR/ClipboardApp"

RES_BUNDLE="$(dirname "$BIN")/ClipboardApp_ClipboardApp.bundle"
if [[ -d "$RES_BUNDLE" ]]; then
    cp -R "$RES_BUNDLE" "$CONTENTS/"
fi

# SwiftPM resource bundles are flat (files at .bundle root). codesign --deep requires a real macOS bundle:
# Contents/Info.plist and resources under Contents/Resources/.
APP_RES_BUNDLE="$CONTENTS/ClipboardApp_ClipboardApp.bundle"
if [[ -d "$APP_RES_BUNDLE" && ! -d "$APP_RES_BUNDLE/Contents" ]]; then
    mkdir -p "$APP_RES_BUNDLE/Contents/Resources"
    shopt -s nullglob
    for f in "$APP_RES_BUNDLE"/*; do
        [[ "$(basename "$f")" == "Contents" ]] && continue
        mv "$f" "$APP_RES_BUNDLE/Contents/Resources/"
    done
    shopt -u nullglob
    cat > "$APP_RES_BUNDLE/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleIdentifier</key>
	<string>clipboard.ClipboardApp.resources</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>ClipboardApp_ClipboardApp</string>
	<key>CFBundlePackageType</key>
	<string>BNDL</string>
</dict>
</plist>
EOF
fi

ICONSET="$(mktemp -d "${TMPDIR:-/tmp}/clipboard.XXXXXX.iconset")"
cleanup() { rm -rf "$ICONSET"; }
trap cleanup EXIT
sips -z 16 16 "$LOGO" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$LOGO" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$LOGO" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$LOGO" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$LOGO" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$LOGO" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$LOGO" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$LOGO" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$LOGO" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$LOGO" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"

cp "$ROOT/Sources/ClipboardApp/ExecutableInfo.plist" "$CONTENTS/Info.plist"

MARKETING_VER="$(head -n 1 "$ROOT/Sources/ClipboardApp/Version.txt" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
if [[ -n "$MARKETING_VER" ]]; then
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${MARKETING_VER}" "$CONTENTS/Info.plist"
fi

xattr -cr "$APP"
codesign --force --deep --sign - "$APP"

echo "Built: $APP"
echo "Open it from Finder or run: open \"$APP\""
