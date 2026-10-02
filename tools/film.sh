#!/bin/bash
#
# Film the app doing something, then print its motion trace.
#
#   SIM=<udid> tools/film.sh <name> <seconds> [launch flags...]
#
# Launches the installed app with the flags, records the screen at the
# simulator's own frame rate for <seconds>, and writes /tmp/film/<name>.mp4
# and /tmp/film/<name>.trace (time, change from the frame before; see
# tools/frames.swift). Input during the recording comes from whoever is
# driving: a debug flag, or a tap through the simulator.
set -u
SIM="${SIM:?set SIM}"; NAME="$1"; SECS="$2"; shift 2
OUT=/tmp/film; mkdir -p "$OUT"
FRAMES=/tmp/frames
[ -x "$FRAMES" ] || swiftc -O "$(dirname "$0")/frames.swift" -o "$FRAMES" 2>/dev/null
xcrun simctl terminate "$SIM" JaydenBetts.Strata >/dev/null 2>&1
rm -f "$OUT/$NAME.mp4"
xcrun simctl io "$SIM" recordVideo --codec h264 --force "$OUT/$NAME.mp4" >/dev/null 2>&1 &
REC=$!
sleep 1
xcrun simctl launch "$SIM" JaydenBetts.Strata "$@" >/dev/null
sleep "$SECS"
kill -INT $REC; wait $REC 2>/dev/null
"$FRAMES" "$OUT/$NAME.mp4" > "$OUT/$NAME.trace"
echo "$OUT/$NAME.mp4  $(wc -l < "$OUT/$NAME.trace") frames"
