#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_PATH="${1:-$PROJECT_DIR/.build}"
export CLANG_MODULE_CACHE_PATH="$BUILD_PATH/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_PATH/clang-cache"
DEVELOPER_DIR_PATH="$(xcode-select -p)"
TEST_FRAMEWORKS="$DEVELOPER_DIR_PATH/Library/Developer/Frameworks"
TEST_FLAGS=()
if [ -d "$TEST_FRAMEWORKS/Testing.framework" ]; then
    # Some standalone Command Line Tools omit this search path from SwiftPM test targets.
    TEST_FLAGS=(-Xswiftc -F -Xswiftc "$TEST_FRAMEWORKS" -Xlinker -F -Xlinker "$TEST_FRAMEWORKS" -Xlinker -rpath -Xlinker "$TEST_FRAMEWORKS")
fi
swift test --package-path "$PROJECT_DIR" --scratch-path "$BUILD_PATH" \
    --cache-path "$BUILD_PATH/cache" --config-path "$BUILD_PATH/config" --security-path "$BUILD_PATH/security" \
    --build-system native --disable-sandbox --disable-xctest --enable-swift-testing \
    --configuration release "${TEST_FLAGS[@]}"
