#!/usr/bin/env bash
# Bump Version.txt (optional), build, bundle, and open ClipboardApp.app.
# Usage: ./scripts/build-and-open.sh --major | --minor | --alpha | --beta
#        ./scripts/build-and-open.sh --skip-version
#        Add --release to write releases/<ver>/ClipboardApp-<ver>.zip: the zip contains ClipboardApp.app
#        and ClipboardApp-<ver>.txt (MD5 of a PKZip of the app alone from ditto). Staging uses a temp dir;
#        older releases under releases/<other-ver>/ are left unchanged.
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
  ver="$(head -n 1 "$VERSION_FILE" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  version_dir="$RELEASES_DIR/$ver"
  zip_name="ClipboardApp-${ver}.zip"
  zip_path="$version_dir/$zip_name"
  sidecar="ClipboardApp-${ver}_md5.txt"

  rm -rf "$version_dir"
  mkdir -p "$version_dir"

  stage="$(mktemp -d "${TMPDIR:-/tmp}/clipboard-release.XXXXXX")"
  trap 'rm -rf "$stage"' EXIT

  cp -R "$APP" "$stage/ClipboardApp.app"

  app_zip_tmp="$(mktemp "${TMPDIR:-/tmp}/clipboard-app-only.XXXXXX.zip")"
  ditto -c -k --keepParent --sequesterRsrc "$stage/ClipboardApp.app" "$app_zip_tmp"
  md5 -q "$app_zip_tmp" > "$stage/$sidecar"
  rm -f "$app_zip_tmp"

  rm -f "$zip_path"
  ( cd "$stage" && COPYFILE_DISABLE=1 zip -r -y "$zip_path" "ClipboardApp.app" "$sidecar" )

  zip_md5="$(md5 -q "$zip_path")"
  rm -rf "$stage"
  trap - EXIT

  echo "Release: $zip_path"
  echo "MD5 (zip): $zip_md5"
fi

open "$APP"
