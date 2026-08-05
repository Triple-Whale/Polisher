#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_BINARY="${TMPDIR:-/tmp}/polisher-keyboard-layout-tests"

swiftc \
    "$PROJECT_DIR/Polisher/TextProcessing/KeyboardLayoutRecovery.swift" \
    "$PROJECT_DIR/Tests/KeyboardLayoutRecoveryTests.swift" \
    -o "$TEST_BINARY"

"$TEST_BINARY"
