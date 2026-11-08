#!/usr/bin/env bash
# Installs, updates or removes the AZERTY Digits keyboard layout for the current user.
# Usage: ./install.sh [install|update|uninstall|status]

set -euo pipefail

LAYOUT_NAME="AZERTY-Digits.keylayout"
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$SOURCE_DIR/$LAYOUT_NAME"
DEST_DIR="$HOME/Library/Keyboard Layouts"
DEST="$DEST_DIR/$LAYOUT_NAME"

usage() {
    echo "Usage: $0 [install|update|uninstall|status]"
    echo "  install    Copy the layout into ~/Library/Keyboard Layouts"
    echo "  update     Copy the layout again if the project file has changed"
    echo "  uninstall  Remove the layout from ~/Library/Keyboard Layouts"
    echo "  status     Show whether the installed layout matches the project file"
}

require_source() {
    if [ ! -f "$SOURCE" ]; then
        echo "Error: $LAYOUT_NAME not found next to this script ($SOURCE_DIR)." >&2
        exit 1
    fi
}

finish_note() {
    echo ""
    echo "Next steps:"
    echo "  1. Log out and back in (or restart) so macOS picks up the layout."
    echo "  2. System Settings > Keyboard > Input Sources > + > Others > AZERTY Digits."
}

cmd_install() {
    require_source
    if [ -f "$DEST" ]; then
        echo "Already installed at $DEST. Use 'update' to refresh it."
        exit 0
    fi
    mkdir -p "$DEST_DIR"
    cp "$SOURCE" "$DEST"
    echo "Installed $LAYOUT_NAME to $DEST_DIR"
    finish_note
}

cmd_update() {
    require_source
    if [ ! -f "$DEST" ]; then
        echo "Not installed yet. Running install instead."
        cmd_install
        return
    fi
    if cmp -s "$SOURCE" "$DEST"; then
        echo "Already up to date."
        exit 0
    fi
    cp "$SOURCE" "$DEST"
    echo "Updated $LAYOUT_NAME in $DEST_DIR"
    finish_note
}

cmd_uninstall() {
    if [ ! -f "$DEST" ]; then
        echo "Not installed; nothing to remove."
        exit 0
    fi
    rm "$DEST"
    echo "Removed $DEST"
    echo ""
    echo "Also remove 'AZERTY Digits' from System Settings > Keyboard > Input Sources if it is listed."
}

cmd_status() {
    if [ ! -f "$DEST" ]; then
        echo "Not installed."
    elif [ -f "$SOURCE" ] && cmp -s "$SOURCE" "$DEST"; then
        echo "Installed and up to date: $DEST"
    else
        echo "Installed but differs from the project file (run 'update'): $DEST"
    fi
}

case "${1:-}" in
    install)   cmd_install ;;
    update)    cmd_update ;;
    uninstall) cmd_uninstall ;;
    status)    cmd_status ;;
    *)         usage; exit 1 ;;
esac
