#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$PROJECT_DIR/Polisher"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/Polisher.app"

echo "==> Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Collecting Swift source files..."
SWIFT_FILES=$(find "$SRC_DIR" -name "*.swift" -type f)

echo "Found source files:"
echo "$SWIFT_FILES" | while read f; do echo "  $(basename "$f")"; done

echo ""
echo "==> Compiling Polisher..."
swiftc \
    -o "$BUILD_DIR/Polisher" \
    -target arm64-apple-macosx14.0 \
    -sdk "$(xcrun --show-sdk-path)" \
    -framework Cocoa \
    -framework Carbon \
    -framework Security \
    -framework UserNotifications \
    -framework SwiftUI \
    -parse-as-library \
    $SWIFT_FILES

echo "==> Creating .app bundle..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/Polisher" "$APP_BUNDLE/Contents/MacOS/Polisher"
cp "$SRC_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo ""
echo "==> Build complete!"
echo "    App bundle: $APP_BUNDLE"
echo ""
echo "To run:"
echo "    open $APP_BUNDLE"
echo ""
echo "To install to /Applications:"
echo "    cp -r $APP_BUNDLE /Applications/"
