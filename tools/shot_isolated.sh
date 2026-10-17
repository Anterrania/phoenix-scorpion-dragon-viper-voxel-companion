#!/usr/bin/env bash
# Run a headless screenshot/test script with a throwaway user:// (XDG_DATA_HOME), so runs never leave
# test proposals, memories or brains in the real app data. Copies v*_*.png outputs to $OUT (default /workspace/builds).
#   tools/shot_isolated.sh tests/screenshot_v12.gd [timeout_s]
set -u
SCRIPT=$1; T=${2:-480}; OUT=${OUT:-/workspace/builds}; GODOT=${GODOT:-$HOME/tools/godot47}
TMP=$(mktemp -d); mkdir -p "$TMP/godot/app_userdata" "$OUT"
cd "$(dirname "$0")/.."
# reuse the import cache, not the app data
PHX_ISOLATED=1 XDG_DATA_HOME="$TMP" timeout "$T" xvfb-run -a -s "-screen 0 720x1280x24" "$GODOT" --path . --resolution 720x1280 --rendering-driver opengl3 -s "$SCRIPT"
rc=$?
find "$TMP" -name 'v*_*.png' -exec cp {} "$OUT/" \;
rm -rf "$TMP"; exit $rc
