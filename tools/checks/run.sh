#!/usr/bin/env bash
# Run one check headless, killed after 90 seconds if it hangs:
#   tools/checks/run.sh stand_check
cd "$(dirname "$0")/../.."
exec perl -e 'alarm shift; exec @ARGV' 90 /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s "tools/checks/$1.gd" --fixed-fps 60 -- "${@:2}"
