#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
NOTES="${1:?Usage: bash prepare-update.sh <release-notes.txt>}"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$PROJECT_DIR/Polisher/Resources/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$PROJECT_DIR/Polisher/Resources/Info.plist")
OUTPUT="$PROJECT_DIR/build/releases/$VERSION-$BUILD"
APP="$OUTPUT/Polisher.app"
ARCHIVE="$OUTPUT/Polisher-$VERSION-$BUILD.zip"

[[ -f "$NOTES" ]] || { echo "Release notes not found: $NOTES" >&2; exit 1; }
POLISHER_BUILD_DIR="$OUTPUT" bash "$PROJECT_DIR/build.sh"
codesign --verify --deep --strict "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ARCHIVE"
swiftc \
    "$PROJECT_DIR/Polisher/Updates/UpdateRelease.swift" \
    "$PROJECT_DIR/scripts/release-update.swift" \
    -o "$OUTPUT/release-update"
codesign --force --sign 'Polisher Code Signing' --identifier com.triplewhale.polisher.release-update "$OUTPUT/release-update"
"$OUTPUT/release-update" prepare "$APP" "$ARCHIVE" "$NOTES" "$OUTPUT/update.json"
echo "Ready for review in $OUTPUT. No files have been published."
