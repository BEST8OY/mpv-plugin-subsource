#!/usr/bin/env bash
set -euo pipefail

MPV_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/mpv"
SCRIPTS_DIR="$MPV_DIR/scripts"
OPTS_DIR="$MPV_DIR/script-opts"

SCRIPT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Installing SubSource mpv plugin..."

mkdir -p "$SCRIPTS_DIR"
mkdir -p "$OPTS_DIR"

# Copy subsource.lua directly
TARGET_LUA="$SCRIPTS_DIR/subsource.lua"
rm -f "$TARGET_LUA"
cp "$SCRIPT_SRC/subsource.lua" "$TARGET_LUA"
chmod 644 "$TARGET_LUA"
echo "  [✓] Installed subsource.lua -> $TARGET_LUA"

# Copy default config if not already present
TARGET_CONF="$OPTS_DIR/subsource.conf"
if [ ! -f "$TARGET_CONF" ]; then
    cp "$SCRIPT_SRC/subsource.conf" "$TARGET_CONF"
    chmod 644 "$TARGET_CONF"
    echo "  [✓] Installed default config -> $TARGET_CONF"
else
    echo "  [i] Existing config kept at $TARGET_CONF"
fi

echo "==> Installation complete!"
echo "    Keybinding: Press 'b' in mpv to search for subtitles."
echo "    Configure your API key in: $TARGET_CONF"
