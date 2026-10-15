#!/bin/bash
# Renders the icon and packs Resources/AppIcon.icns (+ docs/icon.png for the README).
set -euo pipefail
cd "$(dirname "$0")/../.."
TMP=$(mktemp -d)
swift scripts/icon/render-icon.swift "$TMP/icon-1024.png" >/dev/null
SET="$TMP/AppIcon.iconset"; mkdir -p "$SET"
for s in 16 32 128 256 512; do
  sips -z $s $s "$TMP/icon-1024.png" --out "$SET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) "$TMP/icon-1024.png" --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o Resources/AppIcon.icns
mkdir -p docs && sips -z 512 512 "$TMP/icon-1024.png" --out docs/icon.png >/dev/null
rm -rf "$TMP"
echo "wrote Resources/AppIcon.icns and docs/icon.png"
