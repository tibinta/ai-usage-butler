#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
APP_NAME="UsageButler"
BUNDLE_ID="agency.lpv.UsageButler"
APP_BUNDLE="$ROOT_DIR/dist/Usage Butler.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
if [[ "$MODE" == "--diagnose" ]]; then
  swift build --product UsageDiagnostics >&2
  exec "$(swift build --show-bin-path)/UsageDiagnostics"
fi
if [[ "$MODE" == "--package" ]]; then
  VERSION="1.0.0"
  BUILD_NUMBER="1"
  SCRATCH_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ai-usage-butler-package.XXXXXX")"
  trap 'rm -rf "$SCRATCH_ROOT"' EXIT
  ARM_SCRATCH="$SCRATCH_ROOT/arm64"
  X86_SCRATCH="$SCRATCH_ROOT/x86_64"
  PACKAGE_DIR="$ROOT_DIR/dist"
  PACKAGE_APP="$PACKAGE_DIR/AI Usage Butler.app"
  PACKAGE_ZIP="$PACKAGE_DIR/AI Usage Butler-$VERSION-universal-macOS14.zip"
  if [[ -e "$PACKAGE_APP" || -e "$PACKAGE_ZIP" || -e "$PACKAGE_ZIP.sha256" ]]; then
    echo "Package output already exists; move it aside before packaging again." >&2
    exit 2
  fi
  swift build -c release --triple arm64-apple-macosx14.0 --scratch-path "$ARM_SCRATCH" --disable-index-store -Xswiftc -debug-prefix-map -Xswiftc "$ROOT_DIR=/src"
  swift build -c release --triple x86_64-apple-macosx14.0 --scratch-path "$X86_SCRATCH" --disable-index-store -Xswiftc -debug-prefix-map -Xswiftc "$ROOT_DIR=/src"
  ARM_BIN_DIR="$(swift build --show-bin-path -c release --triple arm64-apple-macosx14.0 --scratch-path "$ARM_SCRATCH")"
  X86_BIN_DIR="$(swift build --show-bin-path -c release --triple x86_64-apple-macosx14.0 --scratch-path "$X86_SCRATCH")"
  mkdir -p "$PACKAGE_APP/Contents/MacOS" "$PACKAGE_APP/Contents/Resources"
  cp Resources/UsageButler.icns "$PACKAGE_APP/Contents/Resources/"
  cp Assets/LibreBaskerville.ttf Assets/OFL.txt "$PACKAGE_APP/Contents/Resources/"
  lipo -create \
    "$ARM_BIN_DIR/$APP_NAME" \
    "$X86_BIN_DIR/$APP_NAME" \
    -output "$PACKAGE_APP/Contents/MacOS/$APP_NAME"
  /usr/bin/strip -S -x "$PACKAGE_APP/Contents/MacOS/$APP_NAME"
  cat > "$PACKAGE_APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$APP_NAME</string>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleName</key><string>AI Usage Butler</string>
<key>CFBundleDisplayName</key><string>AI Usage Butler</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleIconFile</key><string>UsageButler</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
  if [[ -n "${CODE_SIGN_IDENTITY:-}" && "$CODE_SIGN_IDENTITY" != "-" ]]; then
    /usr/bin/codesign --force --sign "$CODE_SIGN_IDENTITY" --options runtime --timestamp "$PACKAGE_APP"
  else
    /usr/bin/codesign --force --sign - --timestamp=none "$PACKAGE_APP"
  fi
  lipo -verify_arch arm64 "$PACKAGE_APP/Contents/MacOS/$APP_NAME"
  lipo -verify_arch x86_64 "$PACKAGE_APP/Contents/MacOS/$APP_NAME"
  /usr/bin/codesign --verify --deep --strict "$PACKAGE_APP"
  if strings "$PACKAGE_APP/Contents/MacOS/$APP_NAME" | /usr/bin/grep -F -e "$ROOT_DIR" -e "$HOME" >/dev/null; then
    echo "Release binary contains a local path; refusing to package it." >&2
    exit 1
  fi
  ditto -c -k --norsrc --noextattr --noqtn --keepParent "$PACKAGE_APP" "$PACKAGE_ZIP"
  (cd "$PACKAGE_DIR" && shasum -a 256 "$(basename "$PACKAGE_ZIP")" > "$(basename "$PACKAGE_ZIP").sha256")
  printf 'Packaged %s\nSHA-256: %s\n' "$PACKAGE_ZIP" "$(shasum -a 256 "$PACKAGE_ZIP" | cut -d ' ' -f 1)"
  exit 0
fi
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_CONTENTS/MacOS" "$APP_CONTENTS/Resources"
cp "$BUILD_BINARY" "$APP_CONTENTS/MacOS/$APP_NAME"
cp -R Resources/. "$APP_CONTENTS/Resources/"
cp Assets/LibreBaskerville.ttf Assets/OFL.txt "$APP_CONTENTS/Resources/"
cat > "$APP_CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$APP_NAME</string>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleName</key><string>Usage Butler</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleIconFile</key><string>UsageButler</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
/usr/bin/codesign --force --sign "${CODE_SIGN_IDENTITY:--}" --timestamp=none "$APP_BUNDLE"
case "$MODE" in
 run) /usr/bin/open -n "$APP_BUNDLE" ;;
 --preview) /usr/bin/open -n "$APP_BUNDLE" --args --preview ;;
 --debug|debug) lldb -- "$APP_CONTENTS/MacOS/$APP_NAME" ;;
 --logs|logs) /usr/bin/open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\"" ;;
 --telemetry|telemetry) /usr/bin/open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\"" ;;
 --verify|verify) /usr/bin/open -n "$APP_BUNDLE"; sleep 4; pgrep -x "$APP_NAME" >/dev/null ;;
 *) echo "usage: $0 [run|--preview|--debug|--logs|--telemetry|--verify|--diagnose|--package]" >&2; exit 2 ;;
esac
