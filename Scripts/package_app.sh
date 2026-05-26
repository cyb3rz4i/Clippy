#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/debug"
APP_DIR="$ROOT_DIR/Build/Clippy.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

cd "$ROOT_DIR"
swift build --product Clippy

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BUILD_DIR/Clippy" "$MACOS_DIR/Clippy"
cp "$ROOT_DIR/Config/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Sources/ClippyApp/Resources/PrivacyInfo.xcprivacy" "$RESOURCES_DIR/PrivacyInfo.xcprivacy"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - --entitlements "$ROOT_DIR/Config/Clippy.entitlements" "$APP_DIR"
fi

echo "$APP_DIR"
