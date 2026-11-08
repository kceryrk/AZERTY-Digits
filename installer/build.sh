#!/bin/bash
# Builds "AZERTY Digits Installer.app" next to this script.
set -euo pipefail

cd "$(dirname "$0")"
ROOT="$(cd .. && pwd)"
APP="AZERTY Digits Installer.app"
APP_ICON="$ROOT/icons/green-terminal-7.png"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O main.swift -o "$APP/Contents/MacOS/AZERTY-Digits-Installer"
cp Info.plist "$APP/Contents/Info.plist"
cp "$ROOT/AZERTY-Digits.keylayout" "$APP/Contents/Resources/"
swift render-menubar-icons.swift menubar
cp menubar/fr.icns menubar/123.icns menubar/frpc.icns menubar/dg.icns menubar/digit.icns "$APP/Contents/Resources/"

ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$APP_ICON" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) "$APP_ICON" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$(dirname "$ICONSET")"

echo "Built $APP"
