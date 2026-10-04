#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
RELEASE_DIR="${1:?Usage: bash test-release.sh <prepared-release-directory>}"
RELEASE_DIR="$(cd "$RELEASE_DIR" && pwd)"
FIXTURE=$(mktemp -d "$PROJECT_DIR/build/release-tests.XXXXXX")
TEST_APP="$FIXTURE/ReleaseTests.app"
mkdir -p "$TEST_APP/Contents/MacOS"
cp "$RELEASE_DIR/Polisher.app/Contents/Info.plist" "$TEST_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set CFBundleExecutable ReleaseTests' "$TEST_APP/Contents/Info.plist"
SOURCES=$(find "$PROJECT_DIR/Polisher" -name '*.swift' ! -name main.swift -type f)
swiftc -target arm64-apple-macosx14.0 $SOURCES "$PROJECT_DIR/Tests/UpdateApplicationTests.swift" -o "$TEST_APP/Contents/MacOS/ReleaseTests"
codesign --force --sign 'Polisher Code Signing' --identifier com.triplewhale.polisher --options runtime "$TEST_APP"
ditto "$RELEASE_DIR/Polisher.app" "$FIXTURE/Tampered.app"
printf '\nmodified resource\n' >> "$FIXTURE/Tampered.app/Contents/Resources/models.json"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$TEST_APP/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$TEST_APP/Contents/Info.plist")
"$TEST_APP/Contents/MacOS/ReleaseTests" "$RELEASE_DIR/update.json" "$RELEASE_DIR/Polisher-$VERSION-$BUILD.zip" "$RELEASE_DIR/Polisher.app" "$FIXTURE/Tampered.app"
