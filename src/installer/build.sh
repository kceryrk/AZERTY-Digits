#!/bin/bash
# Builds "AZERTY Digits Installer.app" next to this script.
set -euo pipefail

cd "$(dirname "$0")"
ROOT="$(cd .. && pwd)"
APP="AZERTY Digits Installer.app"
APP_ICON="$ROOT/icons/green-terminal-7.png"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O Localization.swift main.swift -o "$APP/Contents/MacOS/AZERTY-Digits-Installer"
cp Info.plist "$APP/Contents/Info.plist"
cp "$ROOT/AZERTY-Digits.keylayout" "$APP/Contents/Resources/"
cp Belgian.keylayout "$APP/Contents/Resources/"
cp French.keylayout "$APP/Contents/Resources/"
cp French-PC.keylayout "$APP/Contents/Resources/"
cp kluchrtoxml "$APP/Contents/Resources/"
chmod +x "$APP/Contents/Resources/kluchrtoxml"
swift render-menubar-icons.swift menubar
cp menubar/*.icns "$APP/Contents/Resources/"
swift make-app-icon.swift "$APP_ICON" "$APP/Contents/Resources/AppIcon.icns"

echo "Built $APP"
