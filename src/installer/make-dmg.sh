#!/bin/bash
# Builds a beautifully styled DMG for AZERTY Digits Installer with
# directional arrow background, positioned icons, and /Applications symlink.

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

if [ ! -f "$BG_IMAGE" ]; then
    echo "DMG background missing. Generating..."
    swift -e '
    import Cocoa
    let width: CGFloat = 600, height: CGFloat = 400
    let size = NSSize(width: width, height: height)
    let image = NSImage(size: size, flipped: false) { rect in
        let gradient = NSGradient(colors: [NSColor(calibratedRed: 0.12, green: 0.13, blue: 0.16, alpha: 1.0),
                                           NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.10, alpha: 1.0)],
                                  atLocations: [0.0, 1.0], colorSpace: .deviceRGB)
        gradient?.draw(in: rect, angle: -45)
        let accent = NSBezierPath(rect: NSRect(x: 0, y: height - 3, width: width, height: 3))
        NSColor(calibratedRed: 0.0, green: 0.48, blue: 1.0, alpha: 0.8).setFill()
        accent.fill()
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 22, weight: .bold), .foregroundColor: NSColor.white]
        let title = "AZERTY Digits"
        (title as NSString).draw(at: NSPoint(x: (width - (title as NSString).size(withAttributes: titleAttrs).width) / 2.0, y: height - 56), withAttributes: titleAttrs)
        let subAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .regular), .foregroundColor: NSColor(white: 0.65, alpha: 1.0)]
        let sub = "Drag to Applications to install"
        (sub as NSString).draw(at: NSPoint(x: (width - (sub as NSString).size(withAttributes: subAttrs).width) / 2.0, y: height - 78), withAttributes: subAttrs)
        let arrowY: CGFloat = 190, arrowStart: CGFloat = 230, arrowEnd: CGFloat = 360, headSize: CGFloat = 16
        let arrowPath = NSBezierPath()
        arrowPath.move(to: NSPoint(x: arrowStart, y: arrowY))
        arrowPath.line(to: NSPoint(x: arrowEnd, y: arrowY))
        arrowPath.lineWidth = 4.5
        arrowPath.lineCapStyle = .round
        NSColor(calibratedRed: 0.35, green: 0.55, blue: 0.95, alpha: 0.85).setStroke()
        arrowPath.stroke()
        let head = NSBezierPath()
        head.move(to: NSPoint(x: arrowEnd + 4, y: arrowY))
        head.line(to: NSPoint(x: arrowEnd - headSize + 4, y: arrowY + headSize * 0.75))
        head.line(to: NSPoint(x: arrowEnd - headSize + 4, y: arrowY - headSize * 0.75))
        head.close()
        NSColor(calibratedRed: 0.35, green: 0.55, blue: 0.95, alpha: 0.85).setFill()
        head.fill()
        return true
    }
    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    let png = rep.representation(using: .png, properties: [:])!
    try png.write(to: URL(fileURLWithPath: "'"$BG_IMAGE"'"))
    '
fi

STAGE_DIR="$(mktemp -d /tmp/azerty-dmg-stage.XXXXXX)"

cleanup() {
    rm -rf "$STAGE_DIR" 2>/dev/null || true
}
trap cleanup EXIT

echo "Staging DMG contents..."
cp -R "$APP_PATH" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"
mkdir -p "$STAGE_DIR/.background"
cp "$BG_IMAGE" "$STAGE_DIR/.background/background.png"

echo "Writing native Finder .DS_Store layout..."
python3 - << 'PY' "$STAGE_DIR" ".background/background.png"
import sys, os
from ds_store import DSStore
from mac_alias import Bookmark

folder = sys.argv[1]
bg_rel = sys.argv[2]
ds_path = os.path.join(folder, ".DS_Store")
bg_path = os.path.join(folder, bg_rel)

bmk = Bookmark.for_file(bg_path)
icvp_dict = {
    'viewStyle': 'icnv',
    'iconSize': 110.0,
    'gridSpacing': 100.0,
    'textSize': 12.0,
    'labelOnBottom': True,
    'showItemInfo': False,
    'showIconPreview': True,
    'backgroundColorRed': 1.0,
    'backgroundColorGreen': 1.0,
    'backgroundColorBlue': 1.0,
    'backgroundType': 2,
    'backgroundImageAlias': bmk.to_bytes()
}

with DSStore.open(ds_path, "w+") as d:
    d['.']['bwsp'] = {
        'ShowToolbar': False,
        'ShowStatusBar': False,
        'ShowPathbar': False,
        'ShowSidebar': False,
        'ContainerShowSidebar': False,
        'WindowBounds': '{{350, 150}, {600, 400}}'
    }
    d['.']['icvp'] = icvp_dict
    d['AZERTY Digits Installer.app']['Iloc'] = (140, 205)
    d['Applications']['Iloc'] = (460, 205)
PY

echo "Creating compressed release DMG with hdiutil..."
rm -f "$FINAL_DMG"
hdiutil create -srcfolder "$STAGE_DIR" -volname "$VOL_NAME" -fs HFS+ \
    -format UDZO -imagekey zlib-level=9 "$FINAL_DMG" >/dev/null

echo "Created beautiful DMG at: $FINAL_DMG"
