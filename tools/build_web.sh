#!/usr/bin/env bash
# One command from project to itch.io upload:
#   tools/build_web.sh
# Exports the Web build to build/web/ and zips it to build/flop-siege-web.zip,
# with index.html at the top of the zip — the way itch.io requires.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
rm -rf build/web build/flop-siege-web.zip
mkdir -p build/web
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Web" build/web/index.html >/dev/null 2>&1
(cd build/web && zip -qr ../flop-siege-web.zip .)
echo "Zip: build/flop-siege-web.zip ($(du -h build/flop-siege-web.zip | cut -f1))  <- upload this to itch.io"
