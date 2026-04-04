#!/usr/bin/env bash
# Bump Version.txt (optional), build, bundle, and open ClipboardApp.app.
# Usage: ./scripts/build-and-open.sh --major | --minor | --alpha | --beta
#        ./scripts/build-and-open.sh --skip-version
#        Add --release to copy the built app to releases/ and write ClipboardApp-<ver>.app.md5
#        (MD5 is of a PKZip produced by ditto -c -k --keepParent of the bundle).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="$ROOT/Sources/ClipboardApp/Version.txt"
APP="$ROOT/ClipboardApp.app"

usage() {
  echo "Usage: $0 --major | --minor | --alpha | --beta [--release]" >&2
  echo "       $0 --skip-version [--release]" >&2
  exit 1
}

MODE=""
SKIP_VERSION=0
RELEASE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --major)  MODE=major; shift ;;
    --minor)  MODE=minor; shift ;;
    --alpha)  MODE=alpha; shift ;;
    --beta)   MODE=beta; shift ;;
    --skip-version) SKIP_VERSION=1; shift ;;
    --release) RELEASE=1; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

if (( SKIP_VERSION )); then
  if [[ -n "$MODE" ]]; then
    echo "Cannot combine --skip-version with --major/--minor/--alpha/--beta" >&2
    exit 1
  fi
else
  [[ -n "$MODE" ]] || usage
fi

bump_version() {
  local v="$1" mode="$2"
  local M m p pre_type pre_num

  if [[ ! "$v" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(-(alpha|beta)\.([0-9]+))?$ ]]; then
    echo "Invalid version in Version.txt (first line): '$v'" >&2
    echo "Expected MAJOR.MINOR.PATCH or MAJOR.MINOR.PATCH-alpha.N / -beta.N" >&2
    exit 1
  fi

  M="${BASH_REMATCH[1]}"
  m="${BASH_REMATCH[2]}"
  p="${BASH_REMATCH[3]}"
  pre_type="${BASH_REMATCH[5]:-}"
  pre_num="${BASH_REMATCH[6]:-}"

  case "$mode" in
    major) echo "$((M + 1)).0.0" ;;
    minor) echo "$M.$((m + 1)).0" ;;
    alpha)
      if [[ "$pre_type" == alpha ]]; then
        echo "$M.$m.$p-alpha.$((pre_num + 1))"
      elif [[ "$pre_type" == beta ]]; then
        echo "$M.$m.$p-alpha.1"
      else
        echo "$M.$m.$p-alpha.1"
      fi
      ;;
    beta)
      if [[ "$pre_type" == beta ]]; then
        echo "$M.$m.$p-beta.$((pre_num + 1))"
      elif [[ "$pre_type" == alpha ]]; then
        echo "$M.$m.$p-beta.1"
      else
        echo "$M.$m.$p-beta.1"
      fi
      ;;
  esac
}

if (( ! SKIP_VERSION )); then
  first_line="$(head -n 1 "$VERSION_FILE")"
  trimmed="$(echo "$first_line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  new_ver="$(bump_version "$trimmed" "$MODE")"

  {
    printf '%s\n' "$new_ver"
    tail -n +2 "$VERSION_FILE"
  } > "${VERSION_FILE}.tmp"
  mv "${VERSION_FILE}.tmp" "$VERSION_FILE"

  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${new_ver}" \
    "$ROOT/Sources/ClipboardApp/ExecutableInfo.plist"

  echo "Version: $trimmed -> $new_ver"
fi

cd "$ROOT"
swift build
./scripts/bundle-app.sh

if (( RELEASE )); then
  RELEASES_DIR="$ROOT/releases"
  mkdir -p "$RELEASES_DIR"
  ver="$(head -n 1 "$VERSION_FILE" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  dest_name="ClipboardApp-${ver}.app"
  dest="$RELEASES_DIR/$dest_name"
  rm -rf "$dest"
  cp -R "$APP" "$dest"
  zip_tmp="$(mktemp "${TMPDIR:-/tmp}/clipboard-release.XXXXXX.zip")"
  cleanup_zip() { rm -f "$zip_tmp"; }
  trap cleanup_zip EXIT
  ditto -c -k --keepParent --sequesterRsrc "$dest" "$zip_tmp"
  md5 -q "$zip_tmp" > "$RELEASES_DIR/${dest_name}.md5"
  trap - EXIT
  cleanup_zip
  echo "Release: $dest"
  echo "MD5: $(cat "$RELEASES_DIR/${dest_name}.md5") ($RELEASES_DIR/${dest_name}.md5)"
fi

open "$APP"
