#!/bin/bash
# Builds the `monitor` CLI and DumbMonitors.app, and installs the CLI to ~/.local/bin.
# Usage: ./build.sh            build both
#        ./build.sh install    also copy the app to /Applications
set -euo pipefail
cd "$(dirname "$0")"

echo "Building monitor CLI…"
swiftc -O Sources/Core.swift Sources/CLI/main.swift -o monitor
mkdir -p ~/.local/bin && cp monitor ~/.local/bin/monitor

echo "Building DumbMonitors.app…"
APP=DumbMonitors.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O Sources/Core.swift Sources/App/main.swift -o "$APP/Contents/MacOS/DumbMonitors"

# App icon: Icon/icon.png (1024px, made by Icon/make_icon.swift) → AppIcon.icns
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
    sips -z $s $s Icon/icon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) Icon/icon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>DumbMonitors</string>
    <key>CFBundleDisplayName</key><string>DumbMonitors</string>
    <key>CFBundleIdentifier</key><string>local.dumbmonitors</string>
    <key>CFBundleExecutable</key><string>DumbMonitors</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP" >/dev/null 2>&1

if [[ "${1:-}" == "install" ]]; then
    rm -rf "/Applications/$APP"
    cp -R "$APP" /Applications/
    echo "Installed to /Applications/$APP"
fi
echo "Done."
