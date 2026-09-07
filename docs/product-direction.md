# Strata — product direction

Written 2026-09-07, from the owner's brief. This is a proposal with a
recommendation, not a decision already taken. Anything marked **OPEN** needs a
yes/no; everything else follows from the brief.

## What the app is now

**Strata visualises the wins in your day.** It is a record first and a planner
second. Everything else exists to feed the tower or to look back at it.

The evidence: the owner tracks habits in a plain spreadsheet rather than in the
app, because the app asks you to plan before it lets you record. Today and Plan
are two places to schedule the same thing, and neither is where the reward is.

## The rule that decides every question below

> Recording a win must be the fastest thing in the app. Everything else is
> optional and gets out of the way.

If a screen makes logging slower, it is wrong. If a feature is not on the path
between "I did something" and "I can see it", it is optional and belongs behind
one tap, not in front of one.

## Tabs — recommendation: four, each with one job

| Tab | One job | Replaces |
|---|---|---|
| **Tower** | Today's wins, as a structure. Log one. | Tower, Wins |
| **Today** | A checklist. Tick a thing, a block drops. | Today **and** Plan |
| **Calendar** | Look back. A day, a week, a month. | — (new) |
| **Insights** | What it all adds up to. | Insights (redesigned) |

Why not five: a photo tab is a lot of permanent real estate for a capture
action, and a photo is always a photo *of* something — a win, or a day. It
belongs as an action on those, not as a peer of them. See **Photos** below.

Why not three: folding Insights into Calendar sounds minimal but puts two
different questions ("what happened on the 7th" and "how am I doing") on one
screen, which is how Today and Plan got into trouble.

## Tower — what changes

Mostly done. Remaining:

- The range picker (Day / Week / Month) is in, top right. ✅
- **OPEN:** when the range is Week or Month, should the tower show every win in
  that span as one tall stack, or one tower per day side by side? A month of
  wins in one stack is a very tall tower. Recommendation: one stack, because
  the tower's meaning is cumulative — but this is worth seeing before deciding.

## Today — the checklist

Modelled on the owner's spreadsheet, not on the current Today screen. The
spreadsheet works because it is one row per habit, one column per day, and a
checkbox at the intersection. Nothing else.

**Layout (phone):**

```
Today                                    3 / 9
─────────────────────────────────────────────
Habits
  ☐  🏋️  Gym
  ☑  🏃  Cardio
  ☐  👟  8–10k steps
  ☑  📚  Read 25 min

Today only                                  +
  ☐  Job application 3
  ☐  Call the landlord

Scheduled
  09:30  Design review
  14:00  Dentist
```

- **One row per thing. A checkbox, an optional emoji, a name.** No card, no
  rim, no frosted band — those belong to blocks (see the block identity rule).
  Rows are separated by a hairline, exactly like the spreadsheet.
- **Ticking a row drops a block on the tower.** That is the whole reward loop,
  and it is why this screen exists.
- **Three sections, in this order:** habits you keep (recurring), things you
  want to do today (one-off), and anything scheduled with a time. Scheduled
  items are *shown, not checkable* — they come from the calendar and are there
  so the day has a shape.
- The `+` adds a one-off to today. Adding a recurring habit is a secondary
  action, because you do it rarely.

**What this deletes:** the timeline, the sandbox, the split-by-verb idea, and
the whole Plan tab. Scheduling something is picking a date on an item, not a
separate place.

## Calendar — the record

From the reference images. A month grid, one cell per day, and a day sheet.

**Month grid cell** carries at most three marks, in this priority:
1. The number of wins that day, as a small numeral or a dot density.
2. A mood glyph, if one was set.
3. A reminder bell, if the day has one.

Nothing else. A cell with four kinds of information is a cell nobody reads.

**Day sheet** (tap a day) — the reference's structure is right:
- Reminders (add one inline)
- Mood — five faces, one tap
- What happened — a free text note, saves as you type
- Habits — the same checklist rows as Today, for that date
- **Wins** — the day's blocks, drawn small, and its photos

**Week view** is the spreadsheet: habits down the side, days across the top,
checkboxes at the intersections. This is the view the owner actually uses, so
it should be reachable in one tap from the month, not buried.

## Insights — redesign

The current screen is the oldest surface in the app and looks it. Direction:

- **Answer questions, do not display metrics.** "Which days do you win most?"
  "What have you kept up longest?" "What did this month look like?" Each answer
  is one block of content with a plain-language sentence and one visual.
- **Use the tower's own vocabulary.** Colour = category, block = win. A bar
  chart made of stacked blocks is the app's own chart type and needs no legend.
- **No cards.** Sections separated by space and a hairline, like everywhere
  else.
- Delete anything that is a number for its own sake. The tower already shows
  how much you have done; Insights should say something the tower cannot.

## Photos

**Recommendation: not a tab.** A photo is always a photo *of* a win or *of* a
day, so it belongs on those:

- **Hold the `+` slot → camera.** The drag already sizes the block; a long
  press opens the camera and the photo becomes that win's block face. The
  schema already supports it (`HabitLog.imageFileName`, and blocks already
  render a photo face).
- Photos appear in the Calendar day sheet with that day's wins.

**OPEN:** if you want the camera to be a permanent tab anyway, say so — it is a
small change to the tab bar, but it costs a fifth of the bottom edge forever.

## Onboarding

Not yet, by the owner's decision. But the target is stated: *a kid should be
able to work out how to place, edit and do everything without being told.*
That is a design constraint on every screen above, not a screen of its own.
The test to apply to each: **can a first-time user do the main action without
reading anything?**

## Customisation / brand kit

Deferred to Settings, by the owner. Noted here so it is not lost: theme colours
and the block palette are the things worth making customisable, because they
are what the tower is made of.

## Build order (recommended)

1. **Today → checklist.** Highest value, deletes two screens, feeds the tower.
2. **Calendar month + day sheet.** The look-back half of the pivot.
3. **Week/spreadsheet view** inside Calendar.
4. **Insights redesign.**
5. **Photo capture on the slot.**

Each is independently shippable and none of them blocks the tower.
