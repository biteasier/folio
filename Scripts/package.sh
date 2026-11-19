#!/bin/bash
#
# Zips build/Folio.app for a GitHub release:
#   dist/Folio-<version>-arm64.zip and dist/Folio-<version>-arm64.zip.sha256
#
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
ZIP="Folio-$VERSION-arm64.zip"

[ -d build/Folio.app ] || { echo "Run ./Scripts/build.sh first"; exit 1; }
mkdir -p dist

# ditto keeps the bundle's symlinks, permissions and code signature intact.
ditto -c -k --keepParent build/Folio.app "dist/$ZIP"
(cd dist && shasum -a 256 "$ZIP" | tee "$ZIP.sha256")
