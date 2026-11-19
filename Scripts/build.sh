#!/bin/bash
#
# Builds build/Folio.app: an optimised, Apple silicon (arm64) native bundle.
#
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
APP="$ROOT/build/Folio.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)

echo "==> Building Folio $VERSION (arm64, release)"
swift build -c release --product Folio -Xcc -DNDEBUG -Xcc -O3 -Xswiftc -target -Xswiftc arm64-apple-macos12.0 2>&1 | grep -vE '^\[[0-9]+/[0-9]+\]' || true
BIN="$(swift build -c release --show-bin-path)/Folio"
[ -x "$BIN" ] || { echo "build failed"; exit 1; }

if [ ! -f Resources/Folio.icns ] || [ Scripts/make-icon.swift -nt Resources/Folio.icns ]; then
    echo "==> Drawing icon"
    swift Scripts/make-icon.swift Resources
    iconutil -c icns Resources/Folio.iconset -o Resources/Folio.icns
    rm -rf Resources/Folio.iconset
fi

echo "==> Assembling bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Folio"
strip -x "$APP/Contents/MacOS/Folio"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/Folio.icns "$APP/Contents/Resources/"
cp -R Resources/web "$APP/Contents/Resources/web"
find "$APP/Contents/Resources/web" -name '*.LICENSE' -o -name LICENSE | xargs rm -f   # licences stay in the repo

echo "==> Signing (ad-hoc)"
codesign --force --sign - --options runtime "$APP" >/dev/null

echo
echo "Built: $APP"
lipo -info "$APP/Contents/MacOS/Folio" | sed 's/^/    /'
du -sh "$APP" | awk '{print "    bundle size: " $1}'
ls -l "$APP/Contents/MacOS/Folio" | awk '{printf "    executable: %.0f KB\n", $5/1024}'
