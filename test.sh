#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_BINARY="${TMPDIR:-/tmp}/polisher-keyboard-layout-tests"

swiftc \
    "$PROJECT_DIR/Polisher/TextProcessing/KeyboardLayoutRecovery.swift" \
    "$PROJECT_DIR/Tests/KeyboardLayoutRecoveryTests.swift" \
    -o "$TEST_BINARY"

"$TEST_BINARY"

CAPTURE_TEST_BINARY="${TMPDIR:-/tmp}/polisher-text-capture-tests"
swiftc \
    "$PROJECT_DIR/Polisher/TextProcessing/ClipboardManager.swift" \
    "$PROJECT_DIR/Polisher/TextProcessing/TextReplacer.swift" \
    "$PROJECT_DIR/Tests/TextCaptureTests.swift" \
    -o "$CAPTURE_TEST_BINARY"

"$CAPTURE_TEST_BINARY"

UPDATE_TEST_BINARY="${TMPDIR:-/tmp}/polisher-update-release-tests"
swiftc \
    "$PROJECT_DIR/Polisher/Updates/UpdateRelease.swift" \
    "$PROJECT_DIR/Tests/UpdateReleaseTests.swift" \
    -o "$UPDATE_TEST_BINARY"

"$UPDATE_TEST_BINARY"
python3 "$PROJECT_DIR/Tests/UpdateInstallerTests.py"
