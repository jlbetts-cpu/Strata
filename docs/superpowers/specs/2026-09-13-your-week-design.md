# Your Week and Your Month

A replay. Every win from a week, or a month, falls into one tower in the order
you did them, at full size, with the camera rising to follow the top. When the
last one lands the camera pulls out and the whole tower stands on the screen,
small, long enough to be looked at, saved as a video and shared.

Status: approved direction from the owner on 2026-09-13, with his additions
(Settings preview, Your Month, a Replays section in Memories, save to camera
roll as a video). Revised from the first draft accordingly.

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
| Running label | Weekday name: Monday … Sunday | Day number in the owner's numerals: 1 … 30 |
| Build phase | about 10s | about 18s |
| Whole replay | 13 to 18s | 20 to 28s |
| Available as an event | Sunday 5pm to end of Monday | Last day of the month 5pm to end of the 2nd |
| Notification | Sunday 6pm | The 1st at 10am |

## What it is, in one shot

One continuous take. No pages, no swiping.

1. **Open.** Warm ground, empty. "Your week" (or "Your month") in the quiet
   weight, the range under it: "7 to 13 September", or "September".
2. **The build.** The running label sits top left. Wins fall one after another
   in the order they were logged, each with the real gravity drop and the real
   landing, at the same size as on the Wins tab. First-fit, the same packer the
   tower runs, so this is the app's arrangement and not a lookalike.
3. **The camera follows.** While the tower fits, the camera holds still. Once
   the next landing would be above the frame, the camera rises smoothly so the
   top of the tower stays at a fixed line. It never jumps and never waits for a
   block to leave the frame.
4. **The last win lands.** A short hold on the top of the tower.
5. **The reveal.** One long pull-out, about 1.4s, that shrinks the view about
   its base until the whole tower fits. This is the moment the replay exists
   for: you have watched it built piece by piece, and now you see the whole
   thing at once. The running label leaves as it starts.
6. **The dance.** The tower dances once (the existing dance, one wave).
7. **The close.** The count arrives under the tower in the owner's numerals,
   one true sentence under it, then Save Video and Share.

After the close the tower stays live: tap a block to open that win's photo.

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
landing by `design-system.md` §6's values, scaled by mass. The fall distance is
from just above the top of the frame to the block's slot in screen space, so a
block always enters from off screen, as CLAUDE.md requires of the tower.

**Spacing between drops** is solved from the count: the build phase divided
across the wins, clamped between 0.14s and 0.55s apart. A week of 6 wins is
unhurried; a month of 150 reads as a downpour, not a queue. Past the duration
cap the spacing goes below 0.14s rather than the replay getting longer.

**Day boundaries** get 0.35s of air before the next day's first drop. An empty
day shows its label for 0.45s in a week and 0.2s in a month, and nothing falls.
Not skipped (that would misstate the record) and not remarked on.

**The camera during the build** targets "top of the tower at the follow line"
and is precomputed per landing. Consecutive targets are joined with a
critically damped curve evaluated analytically (no overshoot, never moves
down), and the target is taken from the landing that is 0.25s ahead, so the
camera is already rising when a block that would be clipped arrives.

**The reveal** interpolates scale from 1 to the fit scale, and offset from the
follow position to base-anchored, on one ease-in-out curve, 1.4s for a month
and 1.0s for a week. A week that already fits skips the reveal and holds.

**Label changes** are an 8pt vertical slide plus opacity, 0.22s, outgoing and
incoming overlapping.

**The close** comes in on `gentleReveal`: count, sentence 80ms later, controls
80ms after that.

**Reduce Motion:** no falls, no camera, no dance. The finished tower is laid
out at its fitted size and each day's blocks fade in together, day by day,
over about 4s (6s for a month). Same close.

## Sound and haptics

One soft `HapticsEngine.tick()` per landing, rate-limited to 12 a second, a
heavier `squish` for a 2x2. `SoundEngine.blockImpact` per landing at reduced
level with the same limit, following the Sounds & Haptics setting. Success
haptic on the dance. Nothing else makes a sound.

## Layout

- Full screen cover over the app, `WarmBackground`, status bar visible.
- Header: title in the quiet weight over the range, leading at the page margin.
  Close button (the app's `GlassIconButton`, xmark) top right from the first
  frame, so leaving never waits on the animation.
- Running label: under the header, top left, large but lighter than the tower.
- The follow line sits a fifth of the way down the frame, below the label.
- The tower's base sits at a fixed line with room under it for the close.
- Close: count in `Typography.tally` with "wins" at `tallyWord`, the sentence
  in secondary ink, Save Video and Share as the app's glass controls.
- Blocks use the real block surface, photos and all. **No merged runs**, for
  the month tower's reason: touching blocks are different wins, and fusing
  them mid-replay would re-key and hard-cut.

## Words

Every string it can show. No long dashes, nothing that reads as being watched.

| Where | Text |
| --- | --- |
| Title | Your week / Your month |
| Range | 7 to 13 September (28 September to 4 October) / September (September 2026 when not this year) |
| Count | 31 wins (1 win) |
| Sentence, one busiest day | Thursday was your biggest day. / The 14th was your biggest day. |
| Sentence, two tied | Thursday and Saturday were your biggest days. / The 3rd and the 14th were your biggest days. |
| Sentence, three or more tied | Three days tied for your biggest. (Four days, and so on) |
| Sentence, one day only | All on Thursday. / All on the 14th. |
| Controls | Save Video · Share |
| Saving | Saving… then Saved to Photos |
| Save failed | Couldn't save the video |
| Entry pill on the Wins tab | Your week / Your month |
| Notification, week | Your week is ready · Seven days of wins, stacked into one tower. |
| Notification, month | September is ready · A month of wins, stacked into one tower. |
| Replays section heading | REPLAYS |
| Replays card | September · 142 wins / 7 to 13 Sep · 31 wins |
| Settings section | Replays · Preview Your Week · Preview Your Month · Weekly and monthly replays |
| Preview badge | Sample |
| Accessibility, at the close | Your week, 7 to 13 September. 31 wins. Thursday was your biggest day. |

The sentence is one fact. No streaks, no comparison with other weeks, no score.
A replay that grades you is one people stop opening.

## Where it lives

**As an event.** In its window (table above), if the period has at least one
win, a small glass pill appears in the Wins tab header beside the share button.
If both are live on the same day, the month wins. The pill stays for the whole
window even after watching, so it can be shown to someone.

**Notification.** Only if the user already allowed reminders, only if the
period has a win, scheduled or cancelled when the app becomes active the way
`DailyReminder` tops itself up. One Settings switch, "Weekly and monthly
replays", on by default.

**Replays in Memories.** A new section in the Memories drawer, between the month
tower and Albums, headed REPLAYS in the existing `SectionHeading` style.

- **Months:** a horizontal shelf, newest first, of every finished month with a
  win, plus the current month once its window opens. Each card is a 9:16
  poster: the finished tower drawn small on the warm ground (the same
  still the share card renders), with the month name and count under it. Side
  by side, the shelf is a row of towers you can compare by eye, which is what
  makes it memorable rather than a list.
- **Recent weeks:** a smaller row under it, the last four finished weeks with a
  win, same card at a smaller size.
- Tapping a card plays that replay from the start, out of the card with the
  zoom transition the app already uses for photos.
- Nothing is drawn when there is nothing finished to show. No heading over a
  gap.
- Cards are rendered once per period and cached in `ThumbnailStore`, keyed by
  period and a signature of its wins (count plus newest log id), so an edit to
  a past week redraws its card.

**Preview in Settings.** A Replays section with Preview Your Week and Preview
Your Month. Each plays the real replay view with a sample set of wins: the
app's own bundled demo photographs (the onboarding set) and plausible names,
sizes and colours, spread across the period with one empty day and one busy
day, so every part of the choreography shows. A small "Sample" badge under the
title says it is not your data. Save Video works here too, so the export can
be checked.

## Save Video

A 1080x1920 H.264 video at 30fps, with sound, saved to the camera roll through
`PhotoLibrarySaver`'s add-only permission (the app already has the usage
string; it gets reworded to cover videos: "Strata saves your photos and
replays to your camera roll.").

- **Same script, drawn to frames.** For each frame time, the replay's frame
  view is rendered with `ImageRenderer` at 3x into a pixel buffer and appended
  with `AVAssetWriter`. The video holds the close for 2s at the end so it does
  not cut off as the count arrives.
- **Photos must render synchronously.** `ImageRenderer` does not wait for
  `CachedImageView`'s async decode, so the replay takes a `ReplayImages`
  dictionary of decoded thumbnails, loaded before playback starts, and the
  block view reads from it. Live and exported frames are drawn by the same
  view from the same images, which is what makes them identical.
- **Sound** is mixed offline: the script lists every landing's time and mass,
  `SoundEngine` renders each impact to PCM as it already does for playback,
  and they are summed into one AAC track. Same rate limit as live.
- **Progress:** the Save Video control becomes a thin progress ring with
  "Saving…". It can be cancelled by closing. A month takes roughly 25 to 40s
  on a recent iPhone; stated as an estimate until measured on device.
- **Share** shares the still (the card image). The video is shared by saving
  it, since that is where people post stories from.
- **Privacy docs:** the privacy policy and `docs/privacy.html` gain one line
  that replays can be saved to the camera roll on request. Nothing leaves the
  device, so `PrivacyInfo.xcprivacy` does not change.

## Architecture

| Unit | Kind | Does |
| --- | --- | --- |
| `ReplayPeriod` | pure | A week or a month: its days, range string, running labels, window, notification date |
| `Replay` | pure | Orders a period's wins by time, packs them with `GridPacker.firstFit`, per-day counts, the sentence |
| `Replay.Script` | pure | For time `t`: block offsets and squash, camera offset and scale, label, phase, landing events; the Reduce Motion variant; total duration |
| `ReplaySample` | pure | The sample wins for the Settings preview, deterministic |
| `ReplayImages` | service | Loads decoded thumbnails for a replay before it plays |
| `ReplayFrame` | view | Draws one moment of a script: blocks, label, close. No timers |
| `ReplayView` | view | `TimelineView` around `ReplayFrame`; skip, pause, haptics and sound, controls |
| `ReplayVideoExporter` | service | Frames plus mixed audio into an `.mp4`, progress, cancellation, then `PhotoLibrarySaver` |
| `ReplayCard` | view | The 9:16 still, used for Replays cards and Share |
| `ReplayShelf` | view | The Memories section |
| `ReplayReminder` | service | Schedules or cancels the week and month notifications |
| Pill, Settings rows, drawer slot | small edits | `MainAppView`, `SettingsView`, `MemoriesView` |

Data is fetched when a replay or the shelf opens, with `FetchDescriptor`s over
`dateString` ranges as `MemoriesViewModel` does. Never `@Query`, and never
through `MainAppView`'s narrowed query.

Debug flags, because none of this is reachable by tap in the simulator:
`-strataOpenReplay week|month|sampleWeek|sampleMonth`, `-strataReplayAt <s>`
(freeze at a time, for screenshots), `-strataReplayWindow week|month` (force
the pill), `-strataExportReplay` (write the video to Documents for checking).

## Edge cases

- **No wins in a period:** no pill, no notification, no card.
- **One win:** it plays; one block, "1 win", "All on Thursday."
- **A win edited or deleted during a replay:** the replay uses the snapshot it
  opened with.
- **A thumbnail fails to load:** that block shows its colour, as blocks do.
- **Midnight inside a window:** the period is fixed by the window, not today.
- **Time zones and DST:** days come from `Calendar`, never 86,400s steps.
- **Camera roll permission denied:** "Couldn't save the video", and the
  control returns. No nagging.
- **Export interrupted by backgrounding:** cancelled cleanly, partial file
  deleted, control returns.

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
  2nd 11:59pm open, the 3rd closed), range strings.
- `ReplayTests`: order by time, packing matches the tower packer, the sentence
  for one day, two tied, three tied and one-day-only, in both lengths.
- `ReplayScriptTests`: every block at rest before the reveal; every fall starts
  above the frame; the camera never moves down during the build and the top
  block is never clipped at its landing; the reveal ends with the whole tower
  in frame; durations within bounds for 1, 6, 30, 150 and 400 wins; Reduce
  Motion has no offsets.
- `ReplaySampleTests`: deterministic, includes an empty day and a 2x2.
- `ReplayReminderTests`: scheduled with wins, cancelled without, month wins
  over week on a shared day.
- Exporter: a DEBUG export of a short sample, read back with `AVAsset` to check
  duration, size, frame rate and an audio track, and frames extracted and
  compared with the live frozen frames.
- Visual: frozen frames at the open, mid-build, camera following, mid-reveal
  and the close, light and dark; a filmed simulator run checked frame by frame
  for any jump in the camera.
- Unverifiable here: haptics, sound on device, real export time on a phone, the
  camera roll prompt. Stated, not implied.

## Not in this version

Comparisons between periods, streaks, per-category breakdowns, captions over
photos during the replay, music, a year replay. Each is something a person
might ask for and each dilutes the one thing this is.
