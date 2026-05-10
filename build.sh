#!/bin/bash
set -e

SWIFT=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc
SDK=$(ls -d /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX*.sdk 2>/dev/null | sort -V | tail -1)
SRC=Sources/ClipNotice
MODE=${1:-debug}

case "$MODE" in
  release)
    OUT=.build/release
    OPT="-O"
    ;;
  debug|*)
    OUT=.build/debug
    OPT=""
    ;;
esac

mkdir -p "$OUT"

$SWIFT \
  -sdk "$SDK" \
  -target arm64-apple-macosx13.0 \
  -module-name clipnotice \
  $OPT \
  -framework AppKit \
  -framework Foundation \
  -o "$OUT/clipnotice" \
  "$SRC"/*.swift

echo "Built: $OUT/clipnotice"
