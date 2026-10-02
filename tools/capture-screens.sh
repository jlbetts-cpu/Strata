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
# **A FIXED SLEEP IS NOT A SETTLE, AND IT WAS TRAP 2 ALL ALONG (2026-10-01,
# evening).** `07-memories-empty`, `08-memories-map` and `15-place` were written
# down as broken fixtures whose FLAGS were wrong. Re-run with the same flags and
# a settle poll, two of the three land on the right screen on the first attempt:
# `-strataResetStore 1` does empty the store and `-strataOpenMap 1` does open the
# map. Nothing was wrong with either. What was wrong was the sleep. With four
# simulators running on this Mac at once, `simctl launch` took 11 to 45 seconds
# to RETURN and the app then needed another 36 to 66 seconds to seed and draw, so
# a 16 or 22 second sleep measured from the end of `launch` photographed the
# launch screen — rgb(8, 8, 8), uniform, standard deviation of nothing.
#
# So `shot` no longer sleeps a stated amount. It shoots every 6 seconds and keeps
# the first frame that has real structure (standard deviation over 12, which the
# launch screen cannot reach) AND matches the frame before it, which is what
# "settled" means. The number each shot used to carry is kept as a FLOOR, so a
# screen whose subject arrives late still gets its time. Each line prints how
# long `launch` took and how long the settle took: those two numbers are what
# tell you the Mac is loaded rather than the app being broken.
#
# The third, `15-place`, was a real fixture fault and is fixed at its line.
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
  out="$OUT/$1.png"; floor="$2"; shift 2
  xcrun simctl terminate "$SIM" "$BID" >/dev/null 2>&1
  SHOT_SIM="$SIM" SHOT_BID="$BID" SHOT_OUT="$out" SHOT_FLOOR="$floor" \
    python3 "$(dirname "$0")/settle-shot.py" "$@"
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
# **The lower half, which had never been captured.** This screen is seven
# sections and about 1,500pt tall, so every capture of it in `docs/space.md`
# was of the top third, and the footers under Camera, How Strata Works, Data
# and Privacy had never been looked at on a built screen.
# `-strataScrollSettings` opens it already scrolled (`SettingsView`, DEBUG).
shot 13b-settings-lower 16 -strataStartTab tower -strataOpenSheet settings -strataScrollSettings camera
shot 13c-settings-data  16 -strataStartTab tower -strataOpenSheet settings -strataScrollSettings data
shot 14-day-album       22 -strataStartTab memories -strataSeedHistory 6 -strataSeedRealPhotos 1 -strataOpenDay 0
# **A REAL FIXTURE FAULT, and the only one of the three.** This was
# `-strataSeedHistory 4`, and a curated album is impossible at four days: it
# needs five photographs of one title (`Album.minPhotos`) across four distinct
# days (`minPhotoDays`) spanning two week keys (`minSpanWeeks`), and four days
# cannot span two weeks except by luck. So `-strataOpenCurated 0` had nothing to
# open and the capture stayed on the Memories month — which is exactly the file
# `docs/space.md` §0 lists as unverified. Thirty days clears every threshold: the
# seeded "Read a chapter" comes out with nine photographs, verified on a build.
# **The seed makes a screen reachable as much as the flag does.**
shot 15-place           22 -strataStartTab memories -strataSeedHistory 30 -strataSeedPlaces 1 -strataSeedRealPhotos 1 -strataOpenCurated 0
shot 16-photo-viewer    22 -strataStartTab memories -strataSeedHistory 6 -strataSeedRealPhotos 1 -strataOpenPhoto 0
shot 17-replay          26 -strataOpenReplay sampleWeek -strataReplayAt 16.0
shot 18-head-maker      18 -strataStartTab tower -strataOpenSheet profile -strataOpenHeadMaker preview
# **The head picker had never been photographed, and this line is why.** It
# reached Profile and stopped there: the picker is a row inside Profile's head
# section, which on a page carrying the identity block, the streak, the chart
# and the switches sits below the fold. Measured, the capture this line used to
# produce had a layout signature identical to `12-profile` to a tenth of a
# point, which is the "two screens that agree are one screen photographed
# twice" check catching its own set. Nothing on this Mac can scroll a
# simulator, so the page has to arrive already scrolled:
# `-strataScrollProfile head` does that (`ProfileView`, DEBUG only).
shot 19-head-picker     18 -strataStartTab tower -strataSeedMadeHead 1 -strataOpenSheet profile -strataScrollProfile head
shot 20-onboarding-1    14 -strataShowOnboarding 1 -strataOnboardingStep 0
shot 20-onboarding-2    14 -strataShowOnboarding 1 -strataOnboardingStep 1
shot 20-onboarding-3    14 -strataShowOnboarding 1 -strataOnboardingStep 2
shot 20-onboarding-4    14 -strataShowOnboarding 1 -strataOnboardingStep 3
# **Pages 5 and 6 were missing from this set entirely** until 2026-10-01, which
# is why `docs/space.md` could measure four of the six and says so. The
# walkthrough is six pages (`OnboardingView.lastStep` is 5) and the two that
# were never photographed are the only two with a control stacked above the
# primary pill: the head page carries "Not now" and the thank-you page carries
# the LinkedIn button, so they are the two whose action band is a different
# shape from the other four. Measuring four of six and generalising was exactly
# the wrong four to pick.
#
# **And the flag does reach all six, verified rather than assumed** (2026-10-01).
# `DebugHarness.onboardingStep` is read once into `OnboardingView.debugStep` and
# assigned straight to `step` with no clamp, so 4 and 5 are not a special case —
# but its own doc comment still says "0...3", which is the kind of thing that
# makes a capture look wrong when it is right. The proof is the signature pass
# below: all six come back with different band structures, so no two of these
# lines photographed one screen twice, which is the failure a filename cannot
# show.
shot 20-onboarding-5    14 -strataShowOnboarding 1 -strataOnboardingStep 4
shot 20-onboarding-6    14 -strataShowOnboarding 1 -strataOnboardingStep 5
# **A REAL FIXTURE FAULT, and it is the one `docs/space.md` §0 names.** This
# read `-strataRestoreFrom 1`, and `-strataRestoreFrom` does not take a count,
# it takes a FILE NAME in Documents (`SettingsView.swift`, the task on it, and
# `DebugHarness.writeDebugBackup` which spells the call out). So the app looked
# for a file called "1", did not find one, set `restoreFailure` and never
# opened the sheet — and the capture was Settings, which is exactly the file the
# audit listed as broken. The `1` came from this script's own rule that a bare
# flag must carry a value; that rule is right for a BOOLEAN flag and wrong for
# one with a real argument, and this is the only line where the two met.
# Fixed: 21-restore now has its own layout signature, sharing none with 13.
shot 21-restore         18 -strataSeedBackup 40 -strataRestoreFrom strata-debug-backup.zip -strataOpenSheet settings
shot 22-store           14 -strataFailStore both

echo
echo "Layout signatures. Two screens that agree here are one screen photographed twice:"
python3 "$(dirname "$0")/page-room.py" --signature "$OUT"/*.png
