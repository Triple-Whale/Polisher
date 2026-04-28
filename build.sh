#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$PROJECT_DIR/Polisher"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/Polisher.app"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/tmp/polisher-clang-cache}"

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
    $SWIFT_FILES

echo "==> Creating .app bundle..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/Polisher" "$APP_BUNDLE/Contents/MacOS/Polisher"
cp "$SRC_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$SRC_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
cp "$PROJECT_DIR/models.json" "$APP_BUNDLE/Contents/Resources/models.json"

echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

SIGNING_IDENTITY="Polisher Code Signing"
if security find-identity -v -p codesigning | grep -q "$SIGNING_IDENTITY"; then
    echo ""
    echo "==> Code signing with '$SIGNING_IDENTITY'..."
    codesign --force --sign "$SIGNING_IDENTITY" \
        --identifier "com.triplewhale.polisher" \
        --options runtime \
        "$APP_BUNDLE"
    echo "    Signed successfully"
else
    echo ""
    echo "==> WARNING: Signing identity '$SIGNING_IDENTITY' not found, skipping code signing."
    echo "    To set up signing, see the README for certificate setup instructions."
fi

echo ""
echo "==> Build complete!"
echo "    App bundle: $APP_BUNDLE"
echo ""
echo "To run:"
echo "    open $APP_BUNDLE"
echo ""
echo "To install to /Applications:"
echo "    cp -r $APP_BUNDLE /Applications/"
