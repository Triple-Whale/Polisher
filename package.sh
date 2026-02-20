#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/Polisher.app"
DMG_DIR="$BUILD_DIR/dmg-staging"
DMG_OUTPUT="$BUILD_DIR/Polisher.dmg"
VERSION="1.0.0"

echo "==> Step 1: Building app..."
bash "$PROJECT_DIR/build.sh"

echo ""
echo "==> Step 2: Creating DMG staging area..."
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"

cp -R "$APP_BUNDLE" "$DMG_DIR/"

ln -s /Applications "$DMG_DIR/Applications"

echo ""
echo "==> Step 3: Creating DMG..."
rm -f "$DMG_OUTPUT"
hdiutil create \
    -volname "Polisher" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDZO \
    "$DMG_OUTPUT"

rm -rf "$DMG_DIR"

DMG_SIZE=$(du -h "$DMG_OUTPUT" | cut -f1 | xargs)

echo ""
echo "================================================"
echo "  Polisher v${VERSION} packaged successfully!"
echo "  DMG: $DMG_OUTPUT"
echo "  Size: $DMG_SIZE"
echo "================================================"
echo ""
echo "To install: Open the DMG and drag Polisher to Applications."
echo "To share: Send the DMG file to users internally."
