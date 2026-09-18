#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$PROJECT_DIR/dist/Sillage.app}"
BUILD_PATH="${2:-$PROJECT_DIR/.build}"
mkdir -p "$BUILD_PATH/cache" "$BUILD_PATH/config" "$BUILD_PATH/security"
export CLANG_MODULE_CACHE_PATH="$BUILD_PATH/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_PATH/clang-cache"
swift build --package-path "$PROJECT_DIR" --scratch-path "$BUILD_PATH" \
    --cache-path "$BUILD_PATH/cache" --config-path "$BUILD_PATH/config" \
    --security-path "$BUILD_PATH/security" --build-system native --disable-sandbox \
    --configuration release --arch arm64
BIN_PATH="$(swift build --package-path "$PROJECT_DIR" --scratch-path "$BUILD_PATH" --cache-path "$BUILD_PATH/cache" --config-path "$BUILD_PATH/config" --security-path "$BUILD_PATH/security" --disable-sandbox --build-system native --configuration release --arch arm64 --show-bin-path)"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$BIN_PATH/Sillage" "$APP_PATH/Contents/MacOS/Sillage"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_PATH/Contents/Info.plist"
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_PATH/Contents/Resources/AppIcon.icns"
# Embed SwiftPM resources so the app works outside the build directory.
for RESOURCE_BUNDLE in "$BIN_PATH"/*.bundle; do
    [ -d "$RESOURCE_BUNDLE" ] || continue
    ditto "$RESOURCE_BUNDLE" "$APP_PATH/Contents/Resources/$(basename "$RESOURCE_BUNDLE")"
done
for LOCALIZATION in "$PROJECT_DIR/Resources/"*.lproj; do
    ditto "$LOCALIZATION" "$APP_PATH/Contents/Resources/$(basename "$LOCALIZATION")"
done
# Keep the prototype's existing bundle identity when changing its visible name.
codesign --force --sign - --identifier audio.nocturne.prototype "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"
printf 'App ready: %s\n' "$APP_PATH"
