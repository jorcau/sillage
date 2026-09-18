#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_PATH="${1:-$PROJECT_DIR/.build/icon}"
mkdir -p "$BUILD_PATH/clang-cache"
export CLANG_MODULE_CACHE_PATH="$BUILD_PATH/clang-cache"
swiftc -parse-as-library "$PROJECT_DIR/Sources/SillageApp/SillageMark.swift" \
    "$PROJECT_DIR/scripts/generate-icon.swift" -o "$BUILD_PATH/generate-icon"
"$BUILD_PATH/generate-icon" "$BUILD_PATH/AppIcon.iconset"
iconutil -c icns "$BUILD_PATH/AppIcon.iconset" -o "$PROJECT_DIR/Resources/AppIcon.icns"
cp "$BUILD_PATH/AppIcon.iconset/icon_512x512@2x.png" "$PROJECT_DIR/docs/assets/sillage-icon.png"
printf 'Generated Sillage app icon.\n'
