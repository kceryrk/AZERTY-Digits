#!/usr/bin/env bash
# Installs, updates or removes the AZERTY Digits keyboard layout.
# Usage: ./install.sh [install|update|uninstall|status|check-update] [--all-users|--system]

set -euo pipefail

LAYOUT_NAME="AZERTY-Digits.keylayout"
ICON_NAME="AZERTY-Digits.icns"
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$SOURCE_DIR/$LAYOUT_NAME"
SOURCE_ICON="$SOURCE_DIR/$ICON_NAME"

IS_ALL_USERS=0
for arg in "$@"; do
    if [ "$arg" = "--all-users" ] || [ "$arg" = "--system" ]; then
        IS_ALL_USERS=1
    fi
done

if [ "$IS_ALL_USERS" -eq 1 ]; then
    DEST_DIR="/Library/Keyboard Layouts"
else
    DEST_DIR="$HOME/Library/Keyboard Layouts"
fi

DEST="$DEST_DIR/$LAYOUT_NAME"
DEST_ICON="$DEST_DIR/$ICON_NAME"

sudo_cmd() {
    if [ "$IS_ALL_USERS" -eq 1 ] && [ "$EUID" -ne 0 ]; then
        sudo "$@"
    else
        "$@"
    fi
}

usage() {
    echo "Usage: $0 [install|update|uninstall|status|check-update] [--all-users]"
    echo "  install       Copy the layout into ~/Library/Keyboard Layouts (or /Library with --all-users)"
    echo "  update        Copy the layout again if the project file has changed"
    echo "  uninstall     Remove the layout"
    echo "  status        Show whether the installed layout matches the project file"
    echo "  check-update  Check GitHub for the latest release"
    echo "  --all-users   Install into /Library/Keyboard Layouts for lock screen & login window"
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
    if [ "$IS_ALL_USERS" -eq 1 ]; then
        echo "  (Installed system-wide: available on login window and lock screen)"
    fi
}

cmd_install() {
    require_source
    if [ -f "$DEST" ]; then
        echo "Already installed at $DEST. Use 'update' to refresh it."
        exit 0
    fi
    sudo_cmd mkdir -p "$DEST_DIR"
    sudo_cmd cp "$SOURCE" "$DEST"
    if [ -f "$SOURCE_ICON" ]; then
        sudo_cmd cp "$SOURCE_ICON" "$DEST_ICON"
    fi
    if [ "$IS_ALL_USERS" -eq 1 ]; then
        sudo_cmd chmod 644 "$DEST"
        [ -f "$DEST_ICON" ] && sudo_cmd chmod 644 "$DEST_ICON"
    fi
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
    sudo_cmd cp "$SOURCE" "$DEST"
    if [ -f "$SOURCE_ICON" ]; then
        sudo_cmd cp "$SOURCE_ICON" "$DEST_ICON"
    fi
    if [ "$IS_ALL_USERS" -eq 1 ]; then
        sudo_cmd chmod 644 "$DEST"
        [ -f "$DEST_ICON" ] && sudo_cmd chmod 644 "$DEST_ICON"
    fi
    echo "Updated $LAYOUT_NAME in $DEST_DIR"
    finish_note
}

cmd_uninstall() {
    if [ ! -f "$DEST" ]; then
        echo "Not installed; nothing to remove."
        exit 0
    fi
    sudo_cmd rm -f "$DEST" "$DEST_ICON"
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

cmd_check_update() {
    echo "Checking for latest release on GitHub..."
    local latest
    latest="$(curl -s -H "User-Agent: AZERTY-Digits" https://api.github.com/repos/kceryrk/AZERTY-Digits/releases/latest | grep '"tag_name":' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' || true)"
    if [ -n "$latest" ]; then
        echo "Latest release: $latest"
        echo "Release page: https://github.com/kceryrk/AZERTY-Digits/releases/tag/$latest"
    else
        echo "Could not fetch release info from GitHub."
    fi
}

case "${1:-}" in
    install)      cmd_install ;;
    update)       cmd_update ;;
    uninstall)    cmd_uninstall ;;
    status)       cmd_status ;;
    check-update) cmd_check_update ;;
    *)            usage; exit 1 ;;
esac
