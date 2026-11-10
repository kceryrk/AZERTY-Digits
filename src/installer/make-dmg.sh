#!/bin/bash
# Builds a beautifully styled DMG for AZERTY Digits Installer with
# directional arrow background, big icons (130pt), and /Applications symlink.

set -euo pipefail

cd "$(dirname "$0")"
PROJECT_ROOT="$(cd ../.. && pwd)"
APP_PATH="AZERTY Digits Installer.app"
VOL_NAME="AZERTY Digits Installer"
DMG_NAME="AZERTY-Digits-Installer.dmg"
FINAL_DMG="$PROJECT_ROOT/$DMG_NAME"
BG_IMAGE="$PROJECT_ROOT/media/dmg-background.png"

if [ ! -d "$APP_PATH" ]; then
    echo "App not built yet. Running build.sh..."
    ./build.sh
fi

rm -f "$FINAL_DMG"

echo "Creating DMG using create-dmg with high-res background and 130pt icons..."
create-dmg \
  --volname "$VOL_NAME" \
  --volicon "$APP_PATH/Contents/Resources/AppIcon.icns" \
  --background "$BG_IMAGE" \
  --window-pos 350 180 \
  --window-size 660 420 \
  --icon-size 130 \
  --icon "AZERTY Digits Installer.app" 160 205 \
  --hide-extension "AZERTY Digits Installer.app" \
  --app-drop-link 500 205 \
  "$FINAL_DMG" \
  "$APP_PATH"

echo "Successfully built styled DMG: $FINAL_DMG"
