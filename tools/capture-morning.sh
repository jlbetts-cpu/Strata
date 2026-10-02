#!/bin/bash
#
# Every screen in every state that has a grade, in both schemes, for the gallery.
#
#   SIM=<udid> APP=<Strata.app> OUT=/tmp/morning tools/capture-morning.sh
#   tools/gallery.py /tmp/morning docs/gallery.html --grades docs/screen-audit.md
#
# `capture-screens.sh` is the audit's fixed set and is light only. This is the
# set a person looks at: each state the audit grades, and its dark twin named
# `<name>-dark.png` so the gallery can pair them. Built on `settle-shot.py`, so a
# frame is only accepted once it has settled AND the app is actually running.
#
# Empty stores use `-strataSeedWins 0` and never `-strataResetStore`: the second
# makes `-strataStartTab` ignored, which is recorded in docs/screen-audit.md.
set -u
SIM="${SIM:?set SIM}"; APP="${APP:?set APP}"; OUT="${OUT:-/tmp/morning}"
BID="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Info.plist")"
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$OUT"
xcrun simctl install "$SIM" "$APP" >/dev/null || exit 1

shot() {
  name="$1"; shift
  SHOT_SIM="$SIM" SHOT_BID="$BID" SHOT_OUT="$OUT/$name.png" SHOT_FLOOR=8 \
    python3 "$HERE/settle-shot.py" "$@"
}

run_set() {
  local sfx="$1"
  shot "01-wins-empty$sfx"        -strataStartTab tower -strataSeedWins 0
  shot "02-wins-one$sfx"          -strataStartTab tower -strataSeedWins 1
  shot "03-wins-forty$sfx"        -strataStartTab tower -strataSeedWins 40 -strataSeedRealPhotos 1
  shot "04-add-a-win$sfx"         -strataStartTab tower -strataSeedWins 0 -strataOpenSheet add
  shot "05-block-card$sfx"        -strataStartTab tower -strataSeedWins 8 -strataOpenSheet block
  shot "06-plan-empty$sfx"        -strataStartTab tower -strataSeedWins 0 -strataOpenSheet plan
  shot "07-plan-lines$sfx"        -strataStartTab tower -strataSeedWins 1 -strataSeedPlan 5 -strataOpenSheet plan
  shot "08-memories-empty$sfx"    -strataStartTab memories -strataSeedWins 0
  shot "09-memories-one$sfx"      -strataStartTab memories -strataSeedWins 1
  shot "10-memories-full$sfx"     -strataStartTab memories -strataSeedHistory 30 -strataSeedRealPhotos 1
  shot "11-map$sfx"               -strataStartTab memories -strataSeedHistory 4 -strataSeedPlaces 1 -strataOpenMap 1
  shot "12-day-album$sfx"         -strataStartTab memories -strataSeedHistory 6 -strataSeedRealPhotos 1 -strataOpenDay 0
  shot "13-place$sfx"             -strataStartTab memories -strataSeedHistory 30 -strataSeedPlaces 1 -strataSeedRealPhotos 1 -strataOpenCurated 0
  shot "14-profile-empty$sfx"     -strataStartTab tower -strataSeedWins 0 -strataOpenSheet profile
  shot "15-profile$sfx"           -strataStartTab tower -strataSeedHistory 6 -strataOpenSheet profile
  shot "16-settings$sfx"          -strataStartTab tower -strataOpenSheet settings
  shot "17-restore$sfx"           -strataSeedBackup 40 -strataRestoreFrom strata-debug-backup.zip -strataOpenSheet settings
  for stage in restoring done failed; do
    shot "17-restore-$stage$sfx" -strataSeedBackup 40 -strataRestoreFrom strata-debug-backup.zip -strataRestoreStage "$stage" -strataOpenSheet settings
  done
  shot "18a-head-picker$sfx"      -strataStartTab tower -strataSeedMadeHead 1 -strataSeedHeads 3 -strataOpenSheet profile -strataScrollProfile head
  shot "18-head-maker$sfx"        -strataStartTab tower -strataOpenSheet profile -strataOpenHeadMaker preview
  # The replay opens from MEMORIES, so it is captured from there. Without a
  # start tab the app opens on the camera, whose window is pinned dark, and
  # the replay inherits that: every "light" replay in the audit was dark, and
  # the light one, which is the one a person sees, had never been photographed.
  shot "19-replay$sfx"            -strataStartTab memories -strataOpenReplay sampleWeek -strataReplayAt 16.0
  for i in 0 1 2 3 4 5; do
    shot "2$i-onboarding-$((i + 1))$sfx" -strataShowOnboarding 1 -strataOnboardingStep "$i"
  done
  shot "26-store-unavailable$sfx" -strataFailStore both
}

xcrun simctl ui "$SIM" appearance light; run_set ""
xcrun simctl ui "$SIM" appearance dark;  run_set "-dark"
xcrun simctl ui "$SIM" appearance light
# The camera is dark in both schemes by design, so it is captured once.
shot "27-camera"                  -strataStartTab camera
shot "28-camera-refused"          -strataStartTab camera -strataCameraDenied 1

echo; echo "Layout signatures; two that agree are one screen photographed twice:"
python3 "$HERE/page-room.py" --signature "$OUT"/*.png | grep -B1 "SAME LAYOUT" || echo "  none"
