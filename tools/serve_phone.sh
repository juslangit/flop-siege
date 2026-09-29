#!/usr/bin/env bash
# Serve the web build on the Wi-Fi for the iPhone (same Wi-Fi; Ctrl+C stops it):
#   tools/serve_phone.sh
exec python3 "$(dirname "$0")/serve_phone.py" "$@"
