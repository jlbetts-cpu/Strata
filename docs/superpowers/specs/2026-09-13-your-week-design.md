# Your Week

A Sunday replay. Every win from the last seven days falls into one tower, in
the order you did them, and the finished week stands on the screen long enough
to be looked at and shared.

Status: design, awaiting the owner's approval. No code until then.

## Why this is the feature

Strata's tower is a day. At midnight it resets, and everything you built lives
on only as a month block or a map pin. Nothing in the app ever shows you the
week as one object, which is the unit people actually plan and remember in.
The replay is the payoff for the whole loop: log something small every day,
and once a week the app hands you back the shape of what you did.

It rests on three things that are well supported: writing down good things
from the day and revisiting them (Three Good Things), noticing small progress
(the progress principle), and a replay people want to post (Wrapped, Memories).
It adds no new data and asks nothing new of the user.

## What it is, in one shot

One continuous take, 12 to 16 seconds, no pages, no swiping.

1. **Open.** Warm ground, empty. The date range fades in at the top,
   "7 to 13 September", with "Your week" above it in the quiet weight.
2. **Monday.** The weekday name sits top left. Monday's wins fall, one after
   another, in the order they were logged, each with the real gravity drop and
   the real landing.
3. **The week builds.** The weekday name changes in place as each day begins.
   Blocks keep stacking on the same tower: first-fit, exactly the packer the
   Wins tab runs, so this is the app's arrangement and not a lookalike.
4. **The pull-back.** The tower starts at full block size and the view pulls
   back continuously as it grows, so every landing is visible and the finished
   week ends fully in frame. Never a jump, never a scroll.
5. **Sunday lands.** A short hold, then the tower dances once (the existing
   dance, one wave). The weekday name leaves.
6. **The close.** The count arrives under the tower in the owner's numerals,
   one true sentence under it, and two controls: Share and Done.

After the close, the tower stays live: tap a block to open that win's photo,
the same way a block opens anywhere else.

## Motion, precisely

**The whole replay is a function of time.** A pure `WeekReplay.Script`
computes, for any moment `t`, where every block is, the pull-back scale, and
which label is showing. The view draws that inside a `TimelineView`. This is
the one decision that makes it clean:

- Nothing stacks. Thirty `withAnimation` calls in a row, each retargeting a
  spring on the pull-back, is exactly how a sequence starts to shudder. A curve
  sampled from a clock cannot.
- It can be paused (press and hold) and skipped (tap) without any state going
  out of step, because there is no state, only `t`.
- It can be tested: render the script at fixed times and assert positions.
- A video export later is the same function written to frames.

**Drops.** Each block falls on `t = sqrt(2d/g)` with `GridConstants.dropGravity`
and the clamp in `dropDurationRange`, arrives at full speed, and deforms on
landing by the squash values in `design-system.md` §6, scaled by mass. Same
numbers as the tower, taken from the same constants.

**Spacing between drops** is solved from the week, not fixed: the build phase
gets about 10 seconds, divided across the wins, clamped between 0.14s and
0.55s apart. A week of 6 wins feels unhurried; a week of 60 still ends on time
and reads as a downpour rather than a queue. Overlapping falls are fine and
look right; they already happen on the tower.

**Day boundaries** get 0.35s of air before the next day's first drop. An empty
day shows its name for 0.45s and nothing falls. It is not skipped (that would
misstate the week) and it is not remarked on.

**The pull-back** is precomputed: for each landing, the scale at which the
tower's new height fits the frame. Those points are joined by a smooth,
monotonic curve (never zooms back in), eased so it leads the growth slightly
and the top block is never clipped on arrival. Anchored at the base.

**Type changes** (weekday name) are a vertical 8pt slide plus opacity, 0.22s,
outgoing and incoming overlapping, numerals and names never crossfading through
each other in the same spot.

**The close** comes in on `gentleReveal`, count first, sentence 80ms later,
controls 80ms after that.

**Reduce Motion:** no falls, no pull-back, no dance. The finished tower is laid
out at its fitted size and each day's blocks fade in together, day by day,
over about 4 seconds. Same close.

## Sound and haptics

One soft `HapticsEngine.tick()` per landing, rate-limited to 12 a second, a
heavier `squish` for a 2x2. `SoundEngine.blockImpact` per landing at reduced
level, following the Sounds & Haptics setting, with the same rate limit so a
busy week is a patter, not noise. The dance gets the success haptic. Nothing
else makes a sound.

## Layout

- Full screen cover over the app, `WarmBackground`, status bar visible.
- Header: "Your week" (quiet weight) over the date range (regular weight),
  leading-aligned to the page margin, the same header line as other screens.
- Weekday name: under the header, top left, large but lighter than the tower.
- Tower: centred horizontally, base at a fixed line about a third up from the
  bottom, so the close has room under it and the base never moves.
- Close: the count in `Typography.tally`, the word "wins" beside it at
  `tallyWord`, the sentence in secondary ink, Share and Done as the app's glass
  controls. Done top right from the start (so leaving never waits on the
  animation); Share appears only at the close.
- Blocks are drawn with the real `FlippableBlockView`, photos and all.
  **No merged runs**, for the reason the month tower gives: two touching blocks
  are two different wins, and fusing them mid-replay would re-key and hard-cut.

## Words

Every string it can show. No long dashes, nothing that reads as being watched.

| Where | Text |
| --- | --- |
| Header | Your week |
| Date range | 7 to 13 September (across months: 28 September to 4 October) |
| Weekday | Monday … Sunday |
| Count | 31 wins (1 win) |
| Sentence, one busiest day | Thursday was your biggest day. |
| Sentence, a tie | Thursday and Saturday were your biggest days. |
| Sentence, three or more tied | Three days tied for your biggest. (Four days, and so on) |
| Sentence, wins on one day only | All on Thursday. |
| Controls | Share · Done |
| Entry on the Wins tab | Your week |
| Notification title | Your week is ready |
| Notification body | Seven days of wins, stacked into one tower. |
| Accessibility, at the close | Your week, 7 to 13 September. 31 wins. Thursday was your biggest day. |

The sentence is deliberately one fact. No streaks, no comparison with last
week, no score, no "you could do better". A replay that grades you is one
people stop opening.

## When it appears

- **The week** is the seven days ending on the Sunday it is shown, Monday to
  Sunday, in the user's calendar. Chosen over the locale's week so a Sunday
  evening replay is never a week with one day in it.
- **Available** from Sunday 5pm until the end of Monday, if the week has at
  least one win. Outside that window there is no entry, so it stays an event.
- **Entry:** a small glass pill in the Wins tab header, "Your week", beside the
  share button. It is the only new chrome in the app.
- **Notification:** Sunday at 6pm, only if the user already allowed reminders,
  only if the week has a win by then (scheduled or cancelled when the app
  becomes active, the way `DailyReminder` tops itself up). A Settings switch,
  "Weekly replay", on by default, under the existing reminder row.
- **Seen once, still there:** watching it does not remove the pill until the
  window closes, so it can be shown to someone.

## Sharing

A still, 1080x1920, built the way `ShareTowerCard` is: the finished week tower
at full size on the warm ground, the date range small at the top, the count
under it. No watermark, no app plug, same reasoning as the existing card.
Video export is left for later; the time-based script makes it a contained
follow-up rather than a rewrite.

## Architecture

| Unit | Kind | Does | Depends on |
| --- | --- | --- | --- |
| `WeekReplay` | pure model | Picks the seven days, orders wins by time, packs them with `GridPacker.firstFit`, computes per-day counts, the busiest-day sentence and the date range string | `WinRecord`-style values, `Calendar` |
| `WeekReplay.Script` | pure model | For time `t`: each block's fall offset and squash, the pull-back scale, the visible weekday, phase (build, dance, close), total duration; a Reduce Motion variant | `WeekReplay`, `GridConstants` drop constants |
| `WeekReplayWindow` | pure | Whether now is inside Sunday 5pm to Monday end, and the week it refers to | `Calendar` |
| `WeekReplayView` | view | `TimelineView` over the script, draws blocks, label, close; tap to skip, hold to pause, haptics and sound on landings | `FlippableBlockView`, `HapticsEngine`, `SoundEngine` |
| `WeekShareCard` | view + renderer | The still for the share sheet | as `ShareTowerCard` |
| `WeeklyReplayReminder` | service | Schedules or cancels the Sunday notification | `UNUserNotificationCenter`, same shape as `DailyReminder` |
| Wins header pill, Settings switch | small edits | Entry and control | `MainAppView`, `SettingsView` |

Data is fetched once when the replay opens with a `FetchDescriptor` over the
seven `dateString` keys, the way `MemoriesViewModel` fetches a month. Never
`@Query`, and never through `MainAppView`'s narrowed query.

Debug flags, because nothing here is reachable by tap in the simulator:
`-strataOpenWeek`, `-strataWeekAt <seconds>` (freeze the script at a time, for
screenshots), `-strataWeekWindow open` (force the pill on).

## Edge cases

- **No wins in the week:** no pill, no notification, the view is unreachable.
- **One win:** it plays; the tower is one block at full size, "1 win",
  "All on Thursday."
- **Very large week (100+):** spacing floors at 0.14s so the build runs longer
  than 10s, capped at 18s total; past that the spacing goes below 0.14s and falls overlap more, which still reads as a downpour.
  The pull-back keeps it in frame at any height.
- **A win edited or deleted mid-replay:** the replay uses the snapshot it
  opened with; closing and reopening shows the change.
- **Photo not decoded yet:** the block shows its colour (already how blocks
  behave), photos are preloaded for the first day before playback starts.
- **Midnight during the window:** the week is fixed by the Sunday the window
  belongs to, not by today.
- **Time zones and DST:** days come from `Calendar`, never 86,400s steps, per
  `Streaks`.

## Testing

- `WeekReplayTests`: day selection across a month boundary and DST, order by
  time, packing matches the tower's packer, busiest-day sentence for one, two,
  three-plus ties and a single day, date range strings.
- `WeekReplayScriptTests`: every block is at rest by the close; no block's fall
  starts before its predecessor's; scale is monotonic non-increasing and the
  tower fits at every landing; total duration within 12 to 18s for 1, 6, 30 and
  150 wins; Reduce Motion script has no offsets.
- `WeekReplayWindowTests`: Sunday 4:59pm closed, 5pm open, Monday 11:59pm open,
  Tuesday closed.
- `WeeklyReplayReminderTests`: scheduled only with wins, cancelled without.
- Visual: frozen frames at 0s, mid-Wednesday, Sunday landing and the close,
  light and dark, plus a filmed simulator run checked frame by frame for any
  jump in the pull-back.
- Unverifiable here: haptics and sound on device. Stated, not implied.

## Not in this version

Video export, past weeks archive, comparisons with other weeks, streaks,
per-category breakdowns, captions over photos during the replay, music.
Each one is something a person might ask for and each one dilutes the single
thing this is.
