# Every screen, rated

Started 2026-10-01, at the owner's instruction: "go through every screen and
sheet and rate each one individually until you can confidently report a 10/10
for each page... if we posted it on Pinterest it should get tons of likes. The
illustrations will strengthen it further, but make the experience stunning on
its own so the illustrations will have a good place to enter."

**This file is the pass, not a summary of it.** A rating that lives in a reply
is a rating nobody can check tomorrow; this one has the criteria written down
above it, the evidence under it, and a date on every change.

---

## What a 10 means

A number I can argue for, so that "9" and "10" are different claims rather than
different moods. Each screen is scored against ten checks. Every check is
pass/fail, and every failure has to name the thing that fails it — not "feels
cramped" but "the fold cuts the primary action", not "too grey" but "thirty
cells at 0.035 ink".

**Nine of the ten are shared with every other screen. That is the point of
them:** a cohesive system is one where the same ten questions are askable
everywhere and get the same answers.

| # | Check | How it is decided |
|---|---|---|
| 1 | **One subject** | Name the screen's subject in one phrase. Everything on it either IS that subject or helps you act on it. Anything else fails. |
| 2 | **The primary action is above the fold** | Measure the content height against the usable height. The thing the screen is for cannot require a scroll to find. |
| 3 | **Shared components only** | Every surface, control, card, rim and shadow comes from the system: `BlockSurface`, `GlassIconButton`/`glassCapsule`, `SectionHeading`, `Elevation`, `BlockRim`, `EtherealFill`. A privately rebuilt one fails. |
| 4 | **Three type tiers, no more** | Screen title, section/object title, body. A fourth size or a second face on one screen fails. |
| 5 | **Colour is content** | Saturated colour means a win or a photograph. Chrome is ink and light. One accent is allowed, for the primary action. A decorative colour fails. |
| 6 | **Greyscale is earned** | Count the grey elements. A weight that is right for one of something, applied to thirty, fails — this has caught the lattice twice and the calendar once. |
| 7 | **The spacing is on the ladder** | 8 / 12 / 16 / 24 / 32, and a section break is the biggest gap on the page. A fifth value fails. |
| 8 | **Every target is 44pt, measured** | Not declared. Measured off the built screen. |
| 9 | **Contrast is measured** | Text clears 4.5:1, a shape 3:1, against the ground it is actually on — sampled, not assumed. |
| 10 | **Motion answers a person** | Everything that moves does so because somebody did something, on the ladder's durations. Anything that animates because it appeared fails. |

**Ten of ten, or the screen is not done.** A 9 is a screen with one named
failure, and this file names it.

---

## The inventory

Twenty-two places a person can be. Grouped by how they are reached, because a
sheet and a tab are judged the same but arrived at differently.

### Tabs
1. Wins — the tower
2. Wins — empty
3. Camera — viewfinder
4. Camera — permission refused
5. Camera — review (after a shot)
6. Memories — the month
7. Memories — empty
8. Memories — the map

### Sheets off Wins
9. Add a win
10. Plan
11. Block card (editing a win)

### Sheets off Memories
12. Profile
13. Settings
14. Day album
15. Place / curated collection
16. Photo viewer
17. Replay (full screen)

### Head
18. Head maker
19. Head picker

### First run and edges
20. Onboarding (six pages)
21. Restore from backup
22. Store unavailable

---

## The ratings

Filled in as each screen is measured. Nothing here is a guess: a row without
evidence under it has not been done yet.

### 1. Wins — the tower · **9/10** (2026-10-01)

| | |
|---|---|
| Subject | Today, as a tower. |
| Fixed this pass | **The header had no left side.** The count came off at the owner's word and left a `Spacer` and two controls, so the row was one button alone in a corner — a control left behind rather than a header. The date fills it, and not as balance: the tower IS today's, the filter is today-only, the slot adds to today, and nothing on the screen said which day. Somebody opening the app after a few away could not tell from this page whether they were looking at yesterday. |

Checks 1, 3, 4, 5, 6, 7, 8, 9, 10 pass. **Check 2 is the open one**: the slot —
the screen's primary action — is at the top of the tower, so on a tall tower it
sits mid-screen and on a very tall one it is above the fold only because the
scroll rests at the bottom. It has never been measured against a 40-win day.
That measurement is the next thing on this screen.

### 2. Wins — empty · **7/10** (2026-10-01)

| Check | |
|---|---|
| 1 Subject | PASS — a tower not started. |
| 2 Fold | PASS — the slot is visible. |
| 3 Components | PASS. |
| 4 Type tiers | PASS — two. |
| 5 Colour | PASS — none. |
| 6 Greyscale | PASS — twelve whisper cells. |
| **7 Spacing** | **FAIL** — "Nothing yet today" is centred in the grid and lands ON the lattice rows, so the copy overlaps cells. It reads as debris on the surface rather than as a caption of it. |
| 8 Targets | PASS. |
| 9 Contrast | PASS. |
| 10 Motion | PASS. |
| | **and the composition**: the copy is centre, the slot bottom-left, the one control top-right. Three things in three places with nothing relating them. |

### Not yet audited

3–22. Every other screen. Each needs its own capture, its own ten checks and
its own measurements; the two above took a pass each and found one real failure
each, which is the rate to expect rather than a reason to go faster.

**The order they will be done in**, most-used first, because a screen somebody
sees ten times a day earns the attention before one they see at install:

Add a win · Camera · Memories (map) · Block card · Photo viewer · Day album ·
Replay · Profile · Plan · Settings · Head maker · Camera review · Camera
refused · Memories empty · Head picker · Place collection · Onboarding ·
Restore · Store unavailable.
