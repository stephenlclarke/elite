#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
MODE="${1:-run}"
case "$MODE" in run|--debug|--logs|--telemetry|--verify|--build-only) ;; *) printf 'Usage: %s [--debug|--logs|--telemetry|--verify|--build-only]\n' "$0" >&2; exit 2 ;; esac
swift build
APP_BUNDLE="$PWD/dist/Elite.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp Resources/Elite.icns "$APP_BUNDLE/Contents/Resources/Elite.icns"
cp "$(swift build --show-bin-path)/Elite" "$APP_BUNDLE/Contents/MacOS/Elite"
cp -R "$(swift build --show-bin-path)/Elite_EliteCore.bundle" "$APP_BUNDLE/Contents/Resources/"
cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Elite</string>
<key>CFBundleIdentifier</key><string>io.xyzzy.elite</string>
<key>CFBundleName</key><string>Elite</string>
<key>CFBundleIconFile</key><string>Elite.icns</string>
<key>CFBundleDisplayName</key><string>XYZZY Elite - Right-On Commander</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP_BUNDLE" >/dev/null
if [[ "$MODE" == --build-only ]]; then exit 0; fi
# Stop only this checkout's staged application before relaunching it.
APP_PID="$(pgrep -f "^$APP_BUNDLE/Contents/MacOS/Elite$" || true)"
if [[ -n "$APP_PID" ]]; then kill "$APP_PID"; fi
if [[ "$MODE" == --debug ]]; then exec lldb -- "$APP_BUNDLE/Contents/MacOS/Elite"; fi
/usr/bin/open -n "$APP_BUNDLE"
case "$MODE" in
  --logs|--telemetry) /usr/bin/log stream --info --style compact --predicate 'process == "Elite"' ;;
  --verify) sleep 1; pgrep -f "^$APP_BUNDLE/Contents/MacOS/Elite$" >/dev/null ;;
esac
