#!/bin/bash
# Builds Vendor/mediaremote-adapter into build/adapter/MediaRemoteAdapter.framework without cmake
# (source list and flags mirror the vendored CMakeLists.txt).
set -euo pipefail
cd "$(dirname "$0")/.."
SRC=Vendor/mediaremote-adapter
FW=build/adapter/MediaRemoteAdapter.framework
BIN="$FW/Versions/A/MediaRemoteAdapter"
SOURCES=(env get globals keys now_playing repeat seek send shuffle speed stream test)
FILES=()
for s in "${SOURCES[@]}"; do FILES+=("$SRC/src/adapter/$s.m"); done
FILES+=("$SRC/src/private/MediaRemote.m" "$SRC/src/utility/Debounce.m" "$SRC/src/utility/helpers.m")

# Skip rebuild when the framework is newer than every source.
if [ -f "$BIN" ] && [ -z "$(find "$SRC/src" "$SRC/include" -newer "$BIN" -type f | head -1)" ]; then exit 0; fi

rm -rf "$FW"
mkdir -p "$FW/Versions/A/Resources" "$FW/Versions/A/Headers"
xcrun clang -dynamiclib -fobjc-arc -fvisibility=default -arch arm64 -arch x86_64 -mmacosx-version-min=14.0 \
  -I"$SRC/include" -I"$SRC/src" -framework Foundation -framework AppKit -framework UniformTypeIdentifiers \
  -install_name @rpath/MediaRemoteAdapter.framework/Versions/A/MediaRemoteAdapter \
  -o "$BIN" "${FILES[@]}"
cp "$SRC/include/MediaRemoteAdapter.h" "$FW/Versions/A/Headers/"
cat > "$FW/Versions/A/Resources/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MediaRemoteAdapter</string>
<key>CFBundleIdentifier</key><string>com.vandenbe.MediaRemoteAdapter</string>
<key>CFBundleName</key><string>MediaRemoteAdapter</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleShortVersionString</key><string>$(cat $SRC/VERSION)</string>
<key>CFBundleVersion</key><string>1</string>
</dict></plist>
PLIST
ln -sfn A "$FW/Versions/Current"
ln -sfn Versions/Current/MediaRemoteAdapter "$FW/MediaRemoteAdapter"
ln -sfn Versions/Current/Resources "$FW/Resources"
ln -sfn Versions/Current/Headers "$FW/Headers"
