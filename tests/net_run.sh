#!/bin/sh
# Two-player test over LAN on this machine: a host and a client, both headless.
# Prints every check; exits 1 if any failed or a side did not finish.
GODOT="${GODOT:-C:/Users/erlen/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
LOG="${NET_LOG:-.superpowers}"
mkdir -p "$LOG"
timeout 300 "$GODOT" --headless --path . -s tests/boot.gd -- net_host > "$LOG/net_host.log" 2>&1 &
HOST=$!
sleep 12
timeout 280 "$GODOT" --headless --path . -s tests/boot.gd -- net_client > "$LOG/net_client.log" 2>&1
wait $HOST
grep -h "^NET\|SCRIPT ERROR" "$LOG/net_host.log" "$LOG/net_client.log"
grep -q "NET host DONE fails=0" "$LOG/net_host.log" && grep -q "NET client DONE fails=0" "$LOG/net_client.log"
