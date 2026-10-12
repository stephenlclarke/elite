#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift test --enable-code-coverage
BIN_DIR="$(swift build --show-bin-path)"
TEST_BINARY="$(find "$BIN_DIR" -path '*Tests.xctest/Contents/MacOS/*Tests' -type f -print -quit)"
PROFILE="$(find "$BIN_DIR" -path '*/codecov/default.profdata' -type f -print -quit)"
test -n "$TEST_BINARY" && test -n "$PROFILE"
xcrun llvm-cov export -format=lcov -instr-profile="$PROFILE" "$TEST_BINARY" --sources Sources > coverage.lcov
python3 Tools/coverage/lcov-to-sonarqube-generic.py coverage.lcov coverage.xml
python3 Tools/coverage/check-coverage.py --minimum 80 --coverage coverage.xml
