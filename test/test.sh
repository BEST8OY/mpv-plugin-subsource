#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "======================================"
echo "   SubSource mpv Test Suite"
echo "======================================"

# 1. Luac syntax check
echo "[1/3] Checking subsource.lua syntax with luac..."
if command -v luac >/dev/null 2>&1; then
    luac -p subsource.lua
    echo "  ✔ Syntax check passed"
else
    echo "  ⚠ luac not found, skipping syntax check"
fi

# 2. Lua unit tests
echo "[2/3] Running pure Lua unit tests..."
if command -v lua >/dev/null 2>&1; then
    lua test/test_units.lua
    echo "  ✔ Unit tests passed"
elif command -v lua5.4 >/dev/null 2>&1; then
    lua5.4 test/test_units.lua
    echo "  ✔ Unit tests passed"
elif command -v lua5.3 >/dev/null 2>&1; then
    lua5.3 test/test_units.lua
    echo "  ✔ Unit tests passed"
elif command -v luajit >/dev/null 2>&1; then
    luajit test/test_units.lua
    echo "  ✔ Unit tests passed"
else
    echo "  ✖ Lua interpreter not found!"
    exit 1
fi

# 3. mpv headless smoke test
echo "[3/3] Testing subsource.lua loading in mpv..."
if command -v mpv >/dev/null 2>&1; then
    TMP_QUIT=$(mktemp /tmp/mpv_test_quit_XXXXXX.lua)
    echo 'mp.msg.info("MPV_TEST_LOAD_OK"); mp.command("quit 0")' > "$TMP_QUIT"
    trap 'rm -f "$TMP_QUIT"' EXIT

    MPV_OUT=$(mpv --no-config --vo=null --ao=null --idle=yes \
        --script=subsource.lua \
        --script="$TMP_QUIT" \
        --script-opts=subsource-debug=yes 2>&1)

    if echo "$MPV_OUT" | grep -q "MPV_TEST_LOAD_OK" && echo "$MPV_OUT" | grep -q "SubSource plugin"; then
        echo "  ✔ mpv load smoke test passed"
    else
        echo "  ✖ mpv load smoke test failed!"
        echo "$MPV_OUT"
        exit 1
    fi
else
    echo "  ⚠ mpv not found in PATH, skipping runtime smoke test"
fi

echo ""
echo "======================================"
echo "   All tests completed successfully!"
echo "======================================"
