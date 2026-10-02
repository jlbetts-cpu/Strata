#!/bin/bash
#
# Photograph every screen in `docs/screen-audit.md`'s inventory, then prove that
# each capture is of the screen it was asked for.
#
#   SIM=<udid> APP=<path to Strata.app> OUT=/tmp/room tools/capture-screens.sh
#
# **Two traps this exists to stop, both of which have cost a pass.**
#
# 1. **A flag with no value reads as nil.** `DebugHarness.argument(key)` returns
#    the word AFTER the key, so a bare flag given last has none and the app
#    opens on whatever it would have opened on anyway. Every bare flag below
#    therefore carries a `1`. On 2026-10-01 seven of twenty-four captures were
#    of the wrong screen for exactly this reason, and an md5 check caught only
#    two of them: photographic noise differs between two runs of one screen, so
#    the files were not byte-identical.
# 2. **Heavy seeding outruns a short sleep** and the capture is the launch
#    screen. Every shot states its own settle, and the dominant colour is
#    printed so a black frame on a light screen is visible at a glance.
#
# The signature pass at the end is the real check: it prints each capture's band
# structure, which is the layout and nothing else, and names any two that agree.
set -u

SIM="${SIM:-$(xcrun simctl list devices booted | sed -n 's/.*(\([0-9A-F-]\{36\}\)) (Booted).*/\1/p' | head -1)}"
APP="${APP:-/tmp/dd-strata/Build/Products/Debug-iphonesimulator/Strata.app}"
OUT="${OUT:-/tmp/room}"
BID="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Info.plist")"
mkdir -p "$OUT"
xcrun simctl install "$SIM" "$APP" >/dev/null || exit 1

shot() {
  out="$OUT/$1.png"; settle="$2"; shift 2
  xcrun simctl terminate "$SIM" "$BID" >/dev/null 2>&1
  xcrun simctl launch "$SIM" "$BID" "$@" >/dev/null
  sleep "$settle"
  xcrun simctl io "$SIM" screenshot --type=png "$out" >/dev/null 2>&1
  python3 - "$out" <<'PY'
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB")
print(f"  {sys.argv[1]}  {im.size}  dominant {im.resize((1, 1)).getpixel((0, 0))}")
PY
}

shot 01-wins-tower      22 -strataStartTab tower -strataSeedHistory 6 -strataSeedRealPhotos 1
shot 02-wins-empty      16 -strataStartTab tower -strataResetStore 1
shot 03-camera          14 -strataStartTab camera
shot 04-camera-refused  14 -strataStartTab camera -strataCameraDenied 1
shot 05-camera-review   18 -strataStartTab camera -strataOpenReview medium
shot 06-memories-month  22 -strataStartTab memories -strataSeedHistory 6 -strataSeedRealPhotos 1
shot 07-memories-empty  16 -strataStartTab memories -strataResetStore 1
shot 08-memories-map    22 -strataStartTab memories -strataSeedHistory 4 -strataSeedPlaces 1 -strataOpenMap 1
shot 09-add-win         16 -strataStartTab tower -strataOpenSheet add
shot 10-plan            16 -strataStartTab tower -strataOpenSheet plan -strataSeedPlan 5
shot 10b-plan-empty     16 -strataStartTab tower -strataResetStore 1 -strataOpenSheet plan
shot 11-block-card      20 -strataStartTab tower -strataSeedWins 8 -strataOpenSheet block
shot 12-profile         16 -strataStartTab tower -strataSeedHistory 6 -strataOpenSheet profile
shot 13-settings        16 -strataStartTab tower -strataOpenSheet settings
shot 14-day-album       22 -strataStartTab memories -strataSeedHistory 6 -strataSeedRealPhotos 1 -strataOpenDay 0
shot 15-place           22 -strataStartTab memories -strataSeedHistory 4 -strataSeedPlaces 1 -strataSeedRealPhotos 1 -strataOpenCurated 0
shot 16-photo-viewer    22 -strataStartTab memories -strataSeedHistory 6 -strataSeedRealPhotos 1 -strataOpenPhoto 0
shot 17-replay          26 -strataOpenReplay sampleWeek -strataReplayAt 16.0
shot 18-head-maker      18 -strataStartTab tower -strataOpenSheet profile -strataOpenHeadMaker preview
shot 19-head-picker     18 -strataStartTab tower -strataSeedMadeHead 1 -strataOpenSheet profile
shot 20-onboarding-1    14 -strataShowOnboarding 1 -strataOnboardingStep 0
shot 20-onboarding-2    14 -strataShowOnboarding 1 -strataOnboardingStep 1
shot 20-onboarding-3    14 -strataShowOnboarding 1 -strataOnboardingStep 2
shot 20-onboarding-4    14 -strataShowOnboarding 1 -strataOnboardingStep 3
shot 21-restore         18 -strataSeedBackup 40 -strataRestoreFrom 1 -strataOpenSheet settings
shot 22-store           14 -strataFailStore both

echo
echo "Layout signatures. Two screens that agree here are one screen photographed twice:"
python3 "$(dirname "$0")/page-room.py" --signature "$OUT"/*.png
