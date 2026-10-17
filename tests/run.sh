#!/bin/sh
# Runs one headless test: tests/run.sh test_inventory  -> prints PASS line or the script error.
GODOT="${GODOT:-C:/Users/erlen/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
out=$(timeout 90 "$GODOT" --headless --path . -s "tests/$1.gd" 2>&1)
echo "$out" | grep -A2 "SCRIPT ERROR\|Parse Error" | head -12
echo "$out" | grep "^PASS" || { echo "FAIL $1"; exit 1; }
