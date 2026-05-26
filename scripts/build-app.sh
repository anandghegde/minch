#!/usr/bin/env bash
# Build Minch as a runnable .app bundle for local testing.
# PRD §13 sprint 15 prep — not signed, not notarized.
set -euo pipefail

CONFIG="${1:-debug}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/.build/Minch.app"
BIN_DIR="$APP/Contents/MacOS"
RES_DIR="$APP/Contents/Resources"

echo "» swift build -c $CONFIG"
swift build -c "$CONFIG" --package-path "$ROOT"

BUILT_BIN="$ROOT/.build/arm64-apple-macosx/$CONFIG/Minch"
if [[ ! -x "$BUILT_BIN" ]]; then
    BUILT_BIN="$ROOT/.build/$CONFIG/Minch"
fi
if [[ ! -x "$BUILT_BIN" ]]; then
    echo "Could not locate built Minch binary." >&2
    exit 1
fi

echo "» assembling $APP"
rm -rf "$APP"
mkdir -p "$BIN_DIR" "$RES_DIR"
cp "$BUILT_BIN" "$BIN_DIR/Minch"
cp "$ROOT/App/Minch/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/App/Minch/AppIcon.icns" "$RES_DIR/AppIcon.icns"

# Ad-hoc sign so macOS launch services treat this as a real app.
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "» built $APP"
