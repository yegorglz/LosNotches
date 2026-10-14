#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if xcode-select -p | grep -q "Xcode.app"; then exec swift test "$@"; fi
DEV=/Library/Developer/CommandLineTools/Library/Developer
exec swift test -Xswiftc -F -Xswiftc "$DEV/Frameworks" \
  -Xlinker -rpath -Xlinker "$DEV/Frameworks" -Xlinker -rpath -Xlinker "$DEV/usr/lib" "$@"
