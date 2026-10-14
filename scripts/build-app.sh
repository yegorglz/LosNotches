#!/bin/bash
# Usage: scripts/build-app.sh [debug|release]  → build/LosNotches.app
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIG="${1:-debug}"
APP=build/LosNotches.app
SIGN_ID="${LOSNOTCHES_SIGN_ID:--}"

build_binary() {
  if [ "$CONFIG" = release ]; then
    swift build -c release --product LosNotches --triple arm64-apple-macosx14.0
    if swift build -c release --product LosNotches --triple x86_64-apple-macosx14.0; then
      lipo -create .build/arm64-apple-macosx/release/LosNotches .build/x86_64-apple-macosx/release/LosNotches -output build/LosNotches.bin
    else
      echo "warning: x86_64 build failed, shipping arm64 only" >&2
      cp .build/arm64-apple-macosx/release/LosNotches build/LosNotches.bin
    fi
  else
    swift build -c debug --product LosNotches
    cp "$(swift build -c debug --show-bin-path)/LosNotches" build/LosNotches.bin
  fi
}

build_adapter() { scripts/build-adapter.sh; }

assemble_bundle() {
  rm -rf "$APP"
  mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
  mv build/LosNotches.bin "$APP/Contents/MacOS/LosNotches"
  cp Resources/Info.plist "$APP/Contents/Info.plist"
  [ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/" || true
  if [ -d build/adapter/MediaRemoteAdapter.framework ]; then
    cp -R build/adapter/MediaRemoteAdapter.framework "$APP/Contents/Frameworks/"
    cp Vendor/mediaremote-adapter/bin/mediaremote-adapter.pl "$APP/Contents/Resources/"
  fi
}

sign_bundle() {
  if [ -d "$APP/Contents/Frameworks/MediaRemoteAdapter.framework" ]; then
    codesign --force --options runtime --sign "$SIGN_ID" "$APP/Contents/Frameworks/MediaRemoteAdapter.framework"
  fi
  codesign --force --options runtime --entitlements Resources/LosNotches.entitlements --sign "$SIGN_ID" "$APP"
}

mkdir -p build
build_binary
[ -x scripts/build-adapter.sh ] && build_adapter
assemble_bundle
sign_bundle
echo "built $APP"
