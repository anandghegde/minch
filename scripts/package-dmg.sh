#!/usr/bin/env bash
# scripts/package-dmg.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$ROOT/.build/Minch.app"
DMG_STAGE="$ROOT/.build/dmg_stage"
DMG_PATH="$ROOT/.build/Minch.dmg"

# Detect if a valid Developer ID Application certificate is available in the Keychain
IDENTITY=$(security find-identity -p codesigning -v | grep "Developer ID Application:" | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true)

if [ -n "$IDENTITY" ]; then
    echo "» Detected valid developer identity: $IDENTITY"
else
    echo "» No Developer ID signing identity found. Falling back to ad-hoc signing."
    IDENTITY="-"
fi

# 1. Build the app in release mode
echo "» Building Minch in release mode..."
"$ROOT/scripts/build-app.sh" release

if [ ! -d "$APP_PATH" ]; then
    echo "Error: Built app not found at $APP_PATH" >&2
    exit 1
fi

# 2. Codesign the app bundle
echo "» Codesigning App bundle..."
if [ "$IDENTITY" = "-" ]; then
    codesign --force --sign - "$APP_PATH"
else
    codesign --force --options runtime --sign "$IDENTITY" --timestamp --verbose "$APP_PATH"
fi

# 3. Prepare the staging directory
echo "» Preparing DMG staging directory..."
rm -rf "$DMG_STAGE" "$DMG_PATH"
mkdir -p "$DMG_STAGE"

# Copy the app bundle
cp -R "$APP_PATH" "$DMG_STAGE/"

# Create a symlink to /Applications inside the DMG
ln -s /Applications "$DMG_STAGE/Applications"

# 4. Create the DMG using hdiutil
echo "» Generating DMG..."
hdiutil create \
  -volname "Minch" \
  -srcfolder "$DMG_STAGE" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$DMG_STAGE"

# 5. Codesign the DMG itself
echo "» Codesigning DMG..."
if [ "$IDENTITY" = "-" ]; then
    codesign --force --sign - "$DMG_PATH"
else
    codesign --force --sign "$IDENTITY" --timestamp --verbose "$DMG_PATH"
fi

echo "» DMG successfully created and signed at: $DMG_PATH"
