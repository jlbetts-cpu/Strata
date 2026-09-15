# Your Week and Your Month

A replay. Every win from a week, or a month, falls into one tower in the order
you did them, at full size, with the camera rising to follow the top. When the
last one lands the camera pulls out and the whole tower stands on the screen,
small, long enough to be looked at, saved as a video and shared.

Status: Built on 2026-09-14. Approved direction from the owner on 2026-09-13,
with his additions (Settings preview, Your Month, a Replays section in
Memories, save to camera roll as a video). This document describes what was
built; where the build ruled differently from the first draft, the text below
says what shipped.

Revised on 2026-09-15 after the owner watched it on his phone: "the loading
is slow and there isn't an indicator", simpler dates ("6/7-6/13"), a way to
replay it, a better text animation, Share should share the video, and during
the build only the win count, counting up, with "Your week" and the range
arriving at the end. The same day he removed the busiest-day sentence: a
replay is shared with friends, and that line means nothing to them. The text
below describes the revised build.

## Why this is the feature

Strata's tower is a day. At midnight it resets, and everything you built lives
on only as a month block or a map pin. Nothing in the app shows you a week or
a month as one object, and those are the units people plan and remember in.
The replay is the payoff for the whole loop: log something small every day,
and at the end of the week and the month the app hands you back the shape of
what you did.

It rests on well supported ideas: revisiting good things from the day (Three
Good Things), noticing small progress (the progress principle), and a replay
people want to post (Wrapped, Memories). It adds no new data about the user.

## One engine, two lengths

Week and month are the same replay with different inputs. Everything below
applies to both unless a table says otherwise.

| | Your Week | Your Month |
| --- | --- | --- |
| Covers | Monday to Sunday, the week ending on the Sunday | The calendar month |
| Title at the reveal | Your week 9/7-9/13 | Your month September |
| Build phase | about 10s, capped at 12.5s | about 18s, capped at 22s |
| Air before a day's first drop | 0.35s | 0.12s |
| Whole replay | at most 18s, a hard cap (a light week is shorter, never padded) | at most 28s, a hard cap |
| Available as an event | Sunday 5pm to end of Monday | Last day of the month 5pm to end of the 2nd |
| Notification | Sunday 6pm | The 1st at 10am |

## What it is, in one shot

One continuous take. No pages, no swiping.

1. **Open.** Warm ground, empty, "0 wins" top left, fading in.
2. **The build.** Only the count sits top left, set as the Wins tab's header,
   and it counts up by one as each block lands. Wins fall one after another
   in the order they were logged, each with the real gravity drop and the real
   landing, at the same size as on the Wins tab. First-fit, the same packer the
   tower runs, so this is the app's arrangement and not a lookalike.
3. **The camera follows.** While the tower fits, the camera holds still. Once
   the next landing would be above the frame, the camera rises smoothly so the
   top of the tower stays at a fixed line. It never jumps and never waits for a
   block to leave the frame.
4. **The last win lands.** A short hold on the top of the tower.
5. **The reveal.** One long pull-out, about 1.4s, that zooms out until the
   whole tower fits, with the top of the tower travelling to its fitted
   position rather than the view shrinking about a fixed point. This is the
   moment the replay exists for: you have watched it built piece by piece,
   and now you see the whole thing at once. As it starts, the title arrives
   under the count: "Your week" in the quiet weight and "9/7-9/13" beside it
   ("Your month September").
6. **The dance.** The tower dances once (the existing dance, one wave).
7. **The close.** Replay, Save Video and Share arrive under the tower. No
   sentence, and the count is not repeated: it has been at the top all along.

After the close the tower stays live: tap a block to open that win's photo in
the app's photo viewer, growing out of the block. Before the close a tap
anywhere is still the skip. Sample wins (bundled pictures) open nothing, and
nor does a block whose photograph has been deleted since the replay opened:
the replay keeps drawing the picture it decoded, but there is no file to
open.

## Motion, precisely

**The whole replay is a function of time.** A pure `Replay.Script` computes,
for any moment `t`, where every block is, the camera's offset and scale, which
label is showing, and which phase it is in. The live view draws it inside a
`TimelineView`; the video exporter draws the same function to frames.

- Nothing stacks. A run of `withAnimation` calls, each retargeting a spring on
  the camera, is exactly how a sequence starts to shudder. A curve sampled from
  a clock cannot.
- Pause (press and hold) and skip to the close (tap) cannot put anything out of
  step, because there is no state, only `t`.
- It is testable: evaluate the script at fixed times and assert positions.
- The saved video is frame-for-frame the thing you watched.

**Drops.** Each block falls on `t = sqrt(2d/g)` with `GridConstants.dropGravity`
and the clamp in `dropDurationRange`, arrives at full speed, and squashes on
landing by `design-system.md` §6's values, scaled by mass
(`GridConstants.squashScaleY` / `squashScaleX`, the tower's own tokens). The fall distance is
from just above the top of the frame to the block's slot in screen space, so a
block always enters from off screen, as CLAUDE.md requires of the tower.

**Spacing between drops** is solved from the count: the build phase divided
across the wins, clamped between 0.14s and 0.55s apart. A week of 6 wins is
unhurried; a month of 150 reads as a downpour, not a queue.

**The caps are hard.** If the whole replay would run past 18s or 28s, the
script compresses the build: the gaps between drops, the air between days and
the empty days' holds are scaled together by one factor, solved so the
replay ends on the cap. Falls are not shortened and may overlap. The reveal,
dance and close are never compressed. So a 600 win month is denser, never
longer, and the shape of the build (busy days, quiet days) is kept.

**Day boundaries** get a moment of air before the next day's first drop (table above). An empty
day holds for 0.45s in a week and 0.2s in a month, and nothing falls. Not
skipped (that would misstate the record) and not remarked on. A trailing
empty day (a quiet weekend, a month ending quietly) has no landing to wait
for, so the reveal starts no earlier than that day has had its own moment.

**The camera during the build** is precomputed from a corridor. Every block
sets two limits: a floor (by the time it lands, less a 0.25s lead, the camera
has risen far enough that the block lands at or below the follow line) and a
ceiling (when its fall starts, the camera has not risen so far that the
block is already on screen). The camera does not start rising earlier than
0.75s before the first landing that needs it. The keys are the corners of the
shortest path through the corridor, joined by a monotone curve (no
overshoot, never moves down), and a repair pass pins the curve back to the
straight path wherever its rounding strays outside, up to 12 passes. A debug
build logs a warning if the passes run out with the curve still outside.

Two simpler cameras were built and failed: one key per landing turned two
landings a fraction of a second apart into a lurch, and a fixed 0.5s grid of
envelope keys let blocks start on screen and still stepped 21pt in a frame.
The corridor camera climbs at the tower's own rate.

**The reveal** is a geometric zoom, 1.4s for a month and 1.0s for a week. On
one ease-in-out progress `e`, scale is `fitScale^e`, and the rise is solved
from it so the tower's top on screen moves from the follow line to its
fitted line along `e`. Interpolating scale and offset separately multiplies
two curves into a bulge. A tower the camera never had to follow and that
already fits skips the reveal and holds; one that rose during the build but
fits at scale 1 still gets the reveal, easing the rise back to 0, because a
jump is exactly what this must never do.

**The count** is the number of landings at or before `t`. Each change rolls:
only the digit positions that change move, the old digit rising 0.4 of the
type's size out as the new one rises in from below, crossing in opacity, on
an ease-out over 0.18s. A roll is cut short to the time before the next
landing, so in a busy month, where landings are 50ms apart, rolls are quick
and always finish rather than jumping mid-slide. Landings at one instant (a
day under Reduce Motion) are one change. It is computed by the script
(`countRoll`, `digitSlots`), not a `numericText` transition, so the video
rolls exactly as the screen did.

**The title and the controls** arrive by the script, not by `withAnimation`,
so the saved video matches frame for frame: each rises 8pt with opacity over
0.45s on an ease-out cubic (most of the travel early, a long soft settle),
the range 80ms behind "Your week", from the reveal's start; the controls from
the close's start.

**Reduce Motion:** no falls, no camera, no dance. The finished tower is laid
out at its fitted size and each day's blocks fade in together, day by day,
over about 4s (6s for a month). The count's digits and the title cross-fade
in place, without their slide; the title arrives with the close. A
day's blocks land at one instant, so the day makes one sound and one haptic,
at its heaviest block, not one per block in a single frame.
Same close. Filmed on 2026-09-14 with Reduce Motion on: days fade in place,
nothing falls, no camera, no zoom.

## Sound and haptics

One soft `HapticsEngine.tick()` per landing, rate-limited to 12 a second, a
heavier `squish` for a 2x2. `SoundEngine.blockImpact` per landing at reduced
level with the same limit, following the Sounds & Haptics setting. Success
haptic on the dance. Nothing else makes a sound.

## Layout

- Full screen cover over the app, `WarmBackground`, status bar visible.
- Count, top left on the Wins tab's cap line: `Typography.tally` in the
  owner's numerals with "wins" in `Typography.screenSubtitle` as a quieter
  caption beside it. Under it, laid out from the first frame and invisible
  until the reveal, the title line: "Your week" in `screenSubtitle`,
  `inkQuiet`, and the range in `headerMedium`, `inkPrimary`. Close button (the
  app's `GlassIconButton`, xmark) top right from the first frame, so leaving
  never waits on the animation.
- The follow line sits at 0.24 of the frame, under the count.
- The tower's base sits at 0.79 of the frame (0.75 before the close lost its
  count and sentence) and the finished tower's top at no higher than 0.18,
  clear of the title line.
- Close: Replay (`GlassIconButton`, arrow.counterclockwise), Save Video and
  Share as the app's glass controls, hung 32pt under the base and kept above
  the home indicator.
- The count and title are drawn beneath the tower, so a falling block passes
  in front of the type rather than the type printing across it.
- Blocks use the real block surface, photos and all, through `BlockFace`,
  the one view the tower also draws a block's face with. **No merged runs**,
  for the month tower's reason: touching blocks are different wins, and
  fusing them mid-replay would re-key and hard-cut.
- Block titles fade out across camera scale 0.55 to 0.45, where they stop
  being words, rather than cutting. A tower that comes to rest at or above
  0.45 keeps its titles throughout.
- Dynamic Type is capped at xxLarge inside the replay: its lines are
  fractions of the frame and cannot grow with the type. The close is bounded
  above the home indicator.
- Replay, Save Video and Share sit in one row. At extreme type sizes Save
  Video's and Share's words may shrink to 80%; Replay is a glyph. Stacking
  them pushed the close into the tower's bottom row on an iPhone SE.

## Loading

Measured in the simulator from presenting the cover to the first drawn frame
(`[REPLAY-OPEN]`, DEBUG): the replay used to decode every photograph, then
start, then render the Share still on the main actor before the first frame
was committed. Now:

- **It starts once the photographs of the blocks that appear in its first 2s
  are decoded** (`ReplayImageLoad`). Those decode first, on their own; the
  rest follow in drop order. A block whose photograph is
  not in yet draws its colour, as blocks always do, and the picture fades in
  over 0.25s when it arrives. That fade runs on the wall clock and is live
  only.
- **The video still waits for every photograph**: Save Video and Share
  export from the complete set, so no frame has a blank. A frozen frame
  (`-strataReplayAt`) also waits for all of them.
- **No Share still at open.** Share shares the video, so the still that was
  rendered on every open is gone from the path.
- **The script is made once** per frame size, not on every body.
- **Past 150ms without a start, an indicator.** The tower's own dashed slot,
  in `slotInk`, breathes where the tower will stand. It fades out as the
  replay starts. Under 150ms nothing flashes.
- Decode sizes are unchanged: 4/3 of the largest block's span in pixels,
  capped at two cells, for the larger of the screen's cell and the card's at
  3x, so the video stays sharp.

## Words

Every string it can show. No long dashes, nothing that reads as being watched.

| Where | Text |
| --- | --- |
| Title | Your week / Your month |
| Range | 9/7-9/13 in the reader's month and day order (07/09-13/09 in the UK), 12/29/25-1/4/26 when not this year / September (September 2025 when not this year) |
| Count | 0 wins, 1 win, 31 wins |
| Controls | Replay (a glyph) · Save Video · Share |
| Saving | Saving… then Saved to Photos |
| Save failed | Couldn't save |
| Share preparing | Share, with the export's ring (VoiceOver: Preparing the video, 40 percent) |
| Share failed | Couldn't share |
| Entry pill on the Wins tab | Your week / Your month |
| Notification, week | Your week is ready · Seven days of wins, stacked into one tower. |
| Notification, month | September is ready · A month of wins, stacked into one tower. |
| Replays section heading | REPLAYS |
| Replays card | Two lines in the ALBUMS caption style: September over 142 wins / 9/7-9/13 over 31 wins |
| Settings, Replays section | Replays · Preview Your Week · Preview Your Month |
| Settings, Notifications section | Weekly and monthly replays (a switch, beside the daily reminder) |
| Preview badge | Sample, on the count's line: 31 wins · Sample |
| Accessibility, at the close | Your week, 7 to 13 September. 31 wins. |
| Accessibility, shelf card | Your week, 7 to 13 September, 31 wins |
| Loading | Loading the replay (VoiceOver, on the slot) |

No sentence about the period. It was one fact ("Thursday was your biggest
day."), and it was removed on 2026-09-15: a replay is shared with friends,
and a fact about your busiest day means nothing to them. VoiceOver keeps the
range in words ("7 to 13 September"), since it reads "9/7-9/13" as numbers
and slashes. No streaks, no comparison with other weeks, no score.

## Where it lives

**As an event.** In its window (table above), if the period has at least one
win, a small glass pill appears in the Wins tab header beside the Plan button,
set as the replay's Share control (`Typography.headerMedium`, one line).
When the header row does not fit (an accessibility text size on an iPhone SE:
"12" broke one digit per line and the pill read "Yo..."), the pill drops to
its own line under the count at full size; the count never wraps.
If both are live on the same day, the month wins. The pill stays for the whole
window even after watching, so it can be shown to someone.

While the app stays open the pill is re-decided once at the next window edge
(Sunday 5pm, Tuesday as it starts, the last day 5pm, the 3rd), by one sleep to
that moment rather than a polling timer, as well as whenever the app becomes
active, a win lands, or the number of wins changes (a win deleted or undone
takes the pill with it when it was the period's last). Tapping a pill whose
period turns out to be empty plays nothing and re-decides the pill instead.
Reset All Data removes the replay notifications and re-decides the pill.

**What counts.** The tower's own rule (`TowerViewModel.buildTower`): a log
completed or skipped, with its habit. `Replay.wins(from:)`, the replay fetch
and the pill's `hasWins` all use it (`Replay.isBlock`), so the replay never
disagrees with the Wins tab about what stands in it.

**Notification.** Only if the user already allowed reminders, only if the
period has a win, scheduled or cancelled when the app becomes active the way
`DailyReminder` tops itself up. One Settings switch, "Weekly and monthly
replays", on by default, in the Notifications section beside the daily
reminder.

**Replays in Memories.** A new section in the Memories drawer, between the month
tower and Albums, headed REPLAYS in the existing `SectionHeading` style.

- **Months:** a horizontal shelf, newest first, of those of the last 12
  finished months that had a win, plus the current month once its window
  opens. Each card is a 9:16
  poster of the finished tower ALONE on the warm ground (no header, label or
  close), with the name and count as two caption lines under it. Every
  poster in a row is drawn at one shared scale, set so the row's tallest
  tower fills its poster, so towers stand in proportion. Side by side, the
  shelf is a row of towers you can compare by eye, which is what makes it
  memorable rather than a list. Posters are drawn in the viewer's colour
  scheme; the video stays light.
- **Recent weeks:** a smaller row under it: those of the last four finished
  weeks that had a win, plus the current week once its window opens, same
  card at a smaller size.
- Tapping a card plays that replay from the start, out of the card with the
  zoom transition the app already uses for photos.
- Nothing is drawn when there is nothing finished to show. No heading over a
  gap. The shelf still shows when the rest of the page is empty, and the
  page's empty state ("Your first month starts here") waits until the shelf
  has loaded, so a person with a past replay never sees it flash.
- Cards are rendered once per period and cached in memory in
  `ReplayShelfModel`, not `ThumbnailStore` (which is keyed by photo file and
  width). The key is the period and the colour scheme; a card redraws when a
  signature of everything it draws changes (each block's id, photo, size,
  colour, title and crop, plus the row's tallest tower and the pixel scale),
  so an edit to a past week, or a taller month joining the row, redraws it.

**Preview in Settings.** A Replays section with Preview Your Week and Preview
Your Month. Each plays the real replay view with a sample set of wins: the
app's own bundled demo photographs (the onboarding set) and plausible names,
sizes and colours, spread across the period with one empty day and one busy
day, so every part of the choreography shows. "Sample" sits on the title's
own line ("Your week · Sample") in its ink, and says it is not your data.
Save Video and Share work here too, so the export can be checked, and every
frame of the video carries the same "Sample" mark, so a made-up week cannot
be posted as a real one.

## Save Video

A 1080x1920 H.264 video at 30fps, tagged BT.709, with sound, saved to the camera roll through
`PhotoLibrarySaver`'s add-only permission (the app already has the usage
string; it gets reworded to cover videos: "Strata saves your photos and
replays to your camera roll.").

- **Same script, drawn to frames.** For each frame time, the replay's frame
  view is rendered with `ImageRenderer` at 3x into a pixel buffer and appended
  with `AVAssetWriter`. Every frame is `ReplayCard.sharedFrame` at that `t`:
  the light scheme, `.large` type, a story-safe top inset and the full-motion
  script, whatever the phone's own text size or Reduce Motion setting. The
  count rolls, the title arrives and the tower dances exactly as on screen;
  the controls are not drawn. The video holds the finished tower for 2s at
  the end.
- **Photos must render synchronously.** `ImageRenderer` does not wait for
  `CachedImageView`'s async decode, so the exporter takes a complete
  `ReplayImages` dictionary of decoded thumbnails (`ReplayImageLoad.all()`),
  and the block view reads from it. Live and exported frames are drawn by the same
  view from the same images, which is what makes them identical. Each
  photograph is decoded once, for the largest block that shows it: its
  longest side is 4/3 of that block's span in pixels (a 3:4 picture filling
  a square still meets it 1:1), capped at the two cells every photograph got
  before. The live replay decodes for the larger of its own cell and the
  card's at 3x, so the video is as sharp as it was.
- **Sound** is mixed offline: the script lists every landing's time and mass,
  `SoundEngine` renders each impact to PCM as it already does for playback,
  and they are summed into one AAC track. Same rate limit as live, by the
  same rule (`ReplayAudioMix.landingTimes`). **The video always carries the
  sound, even with Sounds off in Settings**: the in-app mute is about the
  phone making noise, and a silent file would not be the replay it came
  from.
- **Progress:** the Save Video control becomes a thin progress ring with
  "Saving…". Closing the replay, or the app going to the background, cancels
  the export, deletes the partial file and returns the control to "Save
  Video" with no error: the person chose it. Closing while the finished file
  is being written to Photos lets that write finish, since the file is made
  and Save Video was pressed. A month takes roughly 25 to 40s on a recent
  iPhone; stated as an estimate until measured on device.
- **Share shares the video.** The same export as Save Video, made once per
  replay: whichever is pressed first starts it, the other waits on it or uses
  the finished file. While it exports, Share shows the same progress ring as
  Save Video; then the system share sheet opens with the file,
  "Your week.mp4". Closing the replay cancels an export and deletes the file
  (a write to Photos already in progress finishes first); leaving the app
  cancels an export but keeps a finished file. The still image is gone from
  the replay; the shelf's posters are the only stills.
- **Privacy docs:** the privacy policy and `docs/privacy.html` gain one line
  that replays can be saved to the camera roll on request. Nothing leaves the
  device, so `PrivacyInfo.xcprivacy` does not change.

## VoiceOver

The build is visual, so with VoiceOver running the replay opens at the close,
where the words and controls are reachable at once, and it announces the close
once per play as it arrives: "Your week, 7 to 13 September. 31 wins."
(`Replay.announcement`); Replay says it again. A double tap on the count and
title skips to the close through an accessibility action, not the tap
gesture: an activation never passes through the hold gesture, so the tap's
memory of an earlier physical hold could otherwise swallow it. Save Video
reads "Saving…" and "Saved to Photos" as words, not buttons, with the export
percentage as its value.

## Architecture

| Unit | Kind | Does |
| --- | --- | --- |
| `ReplayPeriod` | pure | A week or a month: its days, printed and spoken range, window, notification date |
| `Replay` | pure | Orders a period's wins by time, packs them with `GridPacker.firstFit`, per-day counts, the announcement |
| `ReplayScript` | pure | For time `t`: block offsets and squash, camera offset and scale, the count and its digit roll, the title's and controls' arrival, phase, landing events; the corridor camera and its repair pass; cap compression; the Reduce Motion variant; total duration |
| `MonotoneCurve` | pure | The build camera's curve through its keys: no overshoot, never down |
| `ReplaySample` | pure | The sample wins for the Settings preview, deterministic |
| `ReplayImages` | service | Decoded thumbnails, per photograph at its block's size, in drop order |
| `ReplayImageLoad` | model | The live replay's photographs arriving: when it may start, late photos' fades, the complete set for the video |
| `BlockFace` | view | A block's face, shared by the tower and the replay |
| `ReplayFrame` | view | Draws one moment of a script: count, title, blocks, controls, or a poster's tower alone. No timers |
| `ReplayView` | view | `TimelineView` around `ReplayFrame`; `ReplayClock` skip, pause and restart, haptics and sound, the loading slot, controls, the photo viewer, VoiceOver |
| `ReplayVideo` | model | One export per replay for Save Video and Share, its progress, cancel and cleanup; `ReplayShareSheet` presents the file |
| `ReplayLoader` | service | The `FetchDescriptor`s: whether a period has a win, and its replay |
| `ReplayAudioMix` | service | Which landings sound (live and in the video), and the video's mixed track |
| `ReplayVideoExporter` | service | Frames plus mixed audio into an `.mp4`, progress, cancellation, then `PhotoLibrarySaver` |
| `ReplayCard` | view | The frame the video draws; the shelf's tower-only posters |
| `ReplayShelfModel` | model | The shelf's periods, the shared row scale, and the in-memory card cache |
| `ReplayShelf` | view | The Memories section |
| `ReplayReminder` | service | Schedules or cancels the week and month notifications |
| Pill, Settings rows, drawer slot | small edits | `MainAppView`, `SettingsView`, `MemoriesView` |

Data is fetched when a replay or the shelf opens, with `FetchDescriptor`s over
`dateString` ranges as `MemoriesViewModel` does. Never `@Query`, and never
through `MainAppView`'s narrowed query.

Debug flags, because none of this is reachable by tap in the simulator:
`-strataOpenReplay week|month|lastWeek|sampleWeek|sampleMonth`,
`-strataReplayAt <s>` (freeze at a time, for screenshots),
`-strataReplayWindow week|month` (force the pill), `-strataExportReplay`
(write the video, the still and a timing report to Documents for checking),
`-strataReplayProbe` (the clock as an accessibility label for UI tests),
`-strataReplayHoldLoad <s>` (hold the start, to photograph the loading slot),
`-strataSeedHistoryPerDay <n>` (a busy month to measure).

## Edge cases

- **No wins in a period:** no pill, no notification, no card.
- **One win:** it plays; one block, "1 win".
- **A win edited or deleted during a replay:** the replay uses the snapshot it
  opened with.
- **A thumbnail fails to load:** that block shows its colour, as blocks do.
- **A photograph deleted from a block's viewer:** the viewer closes, the replay
  stays open (Memories, under it, reloads its photographs and shelf), and the
  block opens nothing again.
- **Midnight inside a window:** the period is fixed by the window, not today.
- **Time zones and DST:** days come from `Calendar`, never 86,400s steps.
- **Camera roll permission denied:** "Couldn't save", and the control
  returns. No nagging.
- **Export interrupted by backgrounding or closing:** cancelled cleanly,
  partial file deleted, the control returns to "Save Video" with no error.

## Build order

Each step ships something that works on its own.

1. `ReplayPeriod`, `Replay`, `Replay.Script` with tests.
2. `ReplayFrame` and `ReplayView`, Your Week with real data, verified with
   frozen frames and a filmed run.
3. Settings preview with sample data (both lengths).
4. Your Month (label, timings, reveal verified on a 150 win fixture).
5. Replays shelf in Memories and the card still.
6. Wins header pill and notifications.
7. Save Video with sound, and the privacy wording.

## Testing

- `ReplayPeriodTests`: week across a month boundary and DST, month lengths,
  windows at their edges (Sunday 4:59pm closed, 5pm open, Tuesday closed; the
  2nd 11:59pm open, the 3rd closed), numeric ranges in two locales and across
  New Year, spoken ranges, no long dashes.
- `ReplayTests`: order by time, packing matches the tower packer, the
  announcement.
- `ReplayScriptTests`: every block at rest before the reveal; every fall starts
  above the frame; the camera never moves down during the build and the top
  block is never clipped at its landing; the reveal ends with the whole tower
  in frame; durations never above the caps for 1, 6, 30, 150 and 400 wins, and never padded; Reduce
  Motion has no offsets.
- `ReplayScriptTests` also: the corridor holds for every count from 1 to 400
  and hard-heavy mixes; the camera starts rising no earlier than 0.75s ahead;
  no lurch over 12pt a frame unless the tower grows faster; the reveal never
  bulges; a compressed build that ends on empty days stays under the cap and
  still gives the last day its moment; the count at every landing; the digit
  roll's timing and which positions move; the title's and controls' arrival
  order, easing and Reduce Motion's lack of slide.
- `ReplaySampleTests`: deterministic, includes an empty day and a 2x2.
- `ReplayShelfModelTests`: finished periods, short week names, signatures,
  the shared row scale, hit testing of blocks at the close, and the shelf's
  loaded state.
- `ReplayAudioMixTests`, `ReplayClockTests`: the sounding rule and the mix;
  pause, resume, skip and restart.
- `ReplayGestureTests` (UI): tap skips, hold pauses, a short hold's release
  is not a skip, the close button, Share (exports, then the sheet) and Save
  Video are not skips, Replay restarts the clock, a block
  opens its photo after the close, a deleted photo's block opens nothing,
  Save Video survives opening a photo, leaving the app cancels quietly.
- `ReplayReminderTests`: scheduled with wins, cancelled without, month wins
  over week on a shared day.
- Exporter: a DEBUG export of a short sample, read back with `AVAsset` to check
  duration, size, frame rate and an audio track, and frames extracted and
  compared with the live frozen frames.
- Visual: frozen frames at the open, mid-build, camera following, mid-reveal
  and the close, light and dark; a filmed simulator run checked frame by frame
  for any jump in the camera.
- Unverifiable here: haptics, sound on device, real export time and frame
  pacing on a phone, the camera roll prompt, the notifications firing, and
  VoiceOver itself (the announcement's words are tested; its speech and the
  open-at-the-close path are not heard in the simulator). Stated, not
  implied.

## Not in this version

Comparisons between periods, streaks, per-category breakdowns, captions over
photos during the replay, music, a year replay. Each is something a person
might ask for and each dilutes the one thing this is.
