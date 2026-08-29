#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build/release"
APP_DIR="$PROJECT_DIR/QuickClip.app"
MODULE_CACHE="${TMPDIR:-/private/tmp}/quickclip-module-cache"

cd "$PROJECT_DIR"
mkdir -p "$MODULE_CACHE"
CLANG_MODULE_CACHE_PATH="$MODULE_CACHE" SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE" swift build -c release --disable-sandbox
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILD_DIR/QuickClip" "$APP_DIR/Contents/MacOS/QuickClip"
cp "$PROJECT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$PROJECT_DIR/Assets/QuickClipIcon.icns" "$APP_DIR/Contents/Resources/QuickClipIcon.icns"
cp "$PROJECT_DIR/Assets/QuickClipIcon.png" "$APP_DIR/Contents/Resources/QuickClipIcon.png"
cp "$PROJECT_DIR/PkgInfo" "$APP_DIR/Contents/PkgInfo"
codesign --force --deep --sign - -r='designated => identifier "com.local.quickclip"' "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
echo "Built: $APP_DIR"
