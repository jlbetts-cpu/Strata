# Every piece of motion, and whether it is one system

Started 2026-10-01, at the owner's instruction: "Make sure that animations are
clean and under one system as well like things efforlessly change."

Scored against check 10 of `docs/screen-audit.md` — *"Everything that moves does
so because somebody did something, on the ladder's durations. Anything that
animates because it appeared fails"* — and against the standing direction: one
system, minimal by default, premium is subtraction.

**This file is the pass, not a summary of it.** Every finding below carries a
file and a line. A finding with no file:line is not in here.

---

## What this audit measured, and what it did not

**Measured, off the source and the arithmetic:** every call site, every
duration, every curve, every damping fraction, and for each spring its settle
time to 1% and its peak overshoot, computed from the parameters SwiftUI
documents (`ω = 2π/response`, `t₁% = ln(100)/(ζω)`, `overshoot =
e^(−πζ/√(1−ζ²))`). Those are numbers, not adjectives.

**NOT measured:** what any of it looks like on a phone. Nothing in this file was
photographed, and the one judgement this audit cannot make from arithmetic — of
two springs 0.5pt apart in overshoot, does anybody feel the difference — is the
reason section "The system, if we collapse to one" ranks the work rather than
ordering it. The app was not built during this pass: another worker holds the
tree.

**Read `docs/design-system.md` §5 knowing its own header is right.** It is
superseded by the code and lists eleven tokens that no longer exist.

**Line numbers are as of this pass, and `MainAppView.swift` moved under it.**
Another worker was editing that file while this was written; its references were
re-read and corrected at the end, and they drifted by 2 to 4 lines in the
meantime. If one is off, grep the token name — the token names are the stable
handle, which is most of the argument for having them.

---

## The headline

| | |
|---|---|
| Animation call sites | **147**, in **27 files** |
| Named `GridConstants` tokens with ≥1 call site | **40** |
| Inline literals outside the tokens | **3** |
| **Distinct animations the app ships** | **40** |
| **Distinct curve families** | **6**, plus `nil` |
| Distinct fixed time values | **23**, plus one variable (the fall) |
| Share of call sites on the top three animations | **41%** (60 of 147) |
| Share of call sites on the top three time values | **50%** (74 of 147) |

**A system is a short list used often; a pile is a long list used once each.
This is both at once.** Three animations carry 41% of the app, and the
remaining 59% is spread across 37 more — **twenty of which have exactly one
call site.** The top is a ladder. The tail is a pile.

The three that carry it:

| Token | Value | Call sites |
|---|---|---|
| `motionSnappy` | spring, response 0.25, damping 0.82 | **27** |
| `crossFade` | `easeInOut(0.20)` | **18** |
| `gentleReveal` | spring, response 0.22, damping 0.85 | **15** |

**The good news first, because it is real and it is unusual.** Only **3 of 147**
call sites type an animation inline: `NextSlotButton.swift:384`,
`CameraView.swift:313`, `ReplayView.swift:130`. CLAUDE.md says the "no inline
`.spring(...)`" convention "is widely violated in older code
(`TowerAnimationCoordinator`, `TimelineHabitRow`, parts of `MainAppView`)". That
is no longer true: `TowerAnimationCoordinator` is 12 for 12 on tokens, and
`TimelineHabitRow` does not exist. **98% of the app's motion goes through a
named token.** The problem is not that call sites invent curves. It is that
there are too many tokens for them to invent from.

---

## 1. The ladder, as shipped

### Springs, response/damping (21 distinct values, 102 call sites)

Sorted by response. `settle` is time to 1% of the step; `over` is peak
overshoot.

| Token | R | ζ | settle | over | Sites |
|---|---|---|---|---|---|
| `eyeSaccade` | 0.09 | 1.00 | 66ms | 0% | 5 |
| `microBounceDownSpring` | 0.10 | 0.50 | 147ms | 16.3% | 1 |
| `rippleCompressSpring` | 0.12 | 0.55 | 160ms | 12.6% | 1 |
| `headNod` | 0.14 | 0.90 | 114ms | 0.15% | 1 |
| `microBounceUpSpring` | 0.15 | 0.70 | 157ms | 4.6% | 1 |
| `wobbleSpring` | 0.18 | 0.65 | 203ms | 6.8% | 1 |
| `dropStretchSpring` | 0.18 | 0.65 | 203ms | 6.8% | 1 |
| `motionSmooth` | 0.22 | 0.78 | 207ms | 1.99% | 5 |
| `gentleReveal` | 0.22 | 0.85 | 190ms | 0.63% | **15** |
| `elasticPop` | 0.25 | 0.50 | 367ms | 16.3% | 1 |
| `motionSnappy` | 0.25 | 0.82 | 224ms | 1.11% | **27** |
| `shutterRelease` | 0.28 | 0.60 | 342ms | 9.5% | 2 |
| `naturalSettle` | 0.28 | 0.78 | 263ms | 1.99% | **11** |
| `dropSettleSpring` | 0.28 | 0.78 | 263ms | 1.99% | 2 |
| `heavySettle` | 0.28 | 0.80 | 257ms | 1.52% | 2 |
| `danceRise` | 0.30 | 0.52 | 423ms | 14.8% | 1 |
| `slotSnap` | 0.30 | 1.00 | 220ms | 0% | 9 |
| `rippleReleaseSpring` | 0.35 | 0.60 | 428ms | 9.5% | 1 |
| `cardMorph` | 0.35 | 0.86 | 298ms | 0.50% | 3 |
| `danceSettle` | 0.40 | 0.78 | 376ms | 1.99% | 1 |
| `layoutReflow` | 0.55 | 0.90 | 448ms | 0.15% | 4 |
| `headTurn` | 0.55 | 1.00 | 403ms | 0% | 2 |
| `headTakeEaseBack` | 0.70 | 1.00 | 513ms | 0% | 2 |

**Two of those rows are the SAME NUMBER under two names**, which is the thing
CLAUDE.md names as how a ladder stops being one:

- `wobbleSpring` and `dropStretchSpring` are both **0.18 / 0.65**, byte for
  byte (`GridConstants.swift:283` and `:246`). Both are called exactly once,
  from the same function, four lines apart —
  `TowerAnimationCoordinator.swift:454` and `:475`. **No comment anywhere
  acknowledges they are the same value.** This is the pre-ladder spelling
  problem the audit already fixed for `cornerRadiusSmall`/`radiusControl`, and
  it is still live for motion.
- `naturalSettle` and `dropSettleSpring` are both **0.28 / 0.78**
  (`:322` and `:247`). This one is acknowledged — `naturalSettle`'s doc says
  "matches dropSettleSpring, reusable" — so it is a deliberate alias, which is
  a different fault: 13 call sites split across two names for one number.

### Springs, duration/bounce (3 distinct, 11 call sites)

| Token | duration | bounce | Sites |
|---|---|---|---|
| `tapSquashSpring` | 0.06 | 0.00 | 7 |
| `tapPopSpring` | 0.22 | 0.20 | 2 |
| `snapBack` | 0.22 | 0.20 | 2 |
| *(inline)* `NextSlotButton.swift:384` | 0.34 | 0.18 | 1 |

**`tapPopSpring` and `snapBack` are the same number under two names** — and
again the doc admits it (`snapBack`: "Pop-back — matches tapPopSpring"). Four
call sites, two names, one value.

**The app parameterises springs two ways.** `response/dampingFraction` for 21
of them and `duration/bounce` for 3. Those are not the same axis — SwiftUI's
`duration` is not `response` — so a reader comparing `tapPopSpring` (0.22
duration) against `gentleReveal` (0.22 response) is comparing two different
quantities that look identical in the source. That is a readability failure in
the token file, not a visual one, but it is why the 0.22 row below counts 25
sites that do not all move at 0.22.

### Eases (15 distinct, 32 call sites)

| Token | Curve | Sites |
|---|---|---|
| `shutterPress` | `easeOut(0.08)` | 2 |
| `slotBloomIn` | `easeOut(0.10)` | 1 |
| `photoTitleFade` | `easeOut(0.12)` | 1 |
| `headMorph` | `easeOut(0.14)` | 1 |
| `crossFade` | `easeInOut(0.20)` | **18** |
| `towerBlockFadeIn` | `easeOut(0.20)` | 1 |
| *(inline)* `ReplayView.swift:130` | `easeOut(0.24)` | 1 |
| `screenFlashOut` | `easeOut(0.22)` | 1 |
| `imageFadeIn` | `easeIn(0.25)` | 2 |
| `mapFade` | `easeOut(0.30)` | 1 |
| *(inline)* `CameraView.swift:313` | `easeOut(0.36)` | 1 |
| `slotBloomOut` | `easeOut(0.45)` | 1 |
| `monthPhotoFade` | `easeInOut(0.70)` | 1 |
| `headFloatY` | `easeInOut(2.9).repeatForever` | 1 |
| `headFloatX` | `easeInOut(3.7).repeatForever` | 1 |

**`crossFade` at 0.20 `easeInOut` and `towerBlockFadeIn` at 0.20 `easeOut` are
the same duration with a different curve and one call site between them.**
`towerBlockFadeIn`'s only caller is `MainAppView.swift:3154`.

### Timing curve (1, 2 call sites)

`dropFallCurve` — `timingCurve(1/3, 0, 2/3, 1/3, duration: 1)`, scaled by
`.speed(1/fallDuration)` at `TowerAnimationCoordinator.swift:436` and
`OnboardingView.swift:494`. The only animation in the app whose duration is
computed rather than chosen: `t = √(2d/g)` clamped to 0.34…0.72s. **Exempt, and
not negotiable** — see the exemptions list.

### Distinct time values, with their share

| Value | Sites | | Value | Sites |
|---|---|---|---|---|
| **0.25** | **30** | | 0.14 | 2 |
| **0.22** | **25** | | 0.18 | 2 |
| **0.20** | **19** | | 0.24 | 1 |
| 0.28 | 17 | | 0.15 | 1 |
| 0.30 | 11 | | 0.34 | 1 |
| 0.06 | 7 | | 0.36 | 1 |
| 0.55 | 6 | | 0.40 | 1 |
| 0.09 | 5 | | 0.45 | 1 |
| 0.35 | 4 | | 2.90 | 1 |
| 0.70 | 3 | | 3.70 | 1 |
| 0.08 | 2 | | *variable* | 2 |
| 0.10 | 2 | | | |
| 0.12 | 2 | | | |

**0.20, 0.22, 0.25, 0.28 and 0.30 carry 91 of 147 call sites — 62%.** The
entire perceptual range those five occupy is **80 milliseconds**. Everything
else in the app is either a fast local response (0.06–0.18, 23 sites) or a
deliberate slow one (0.35–0.70, 14 sites) or the heads' float (2.9/3.7).

---

## 2. The cluster — the real finding of this audit

**Five springs sit inside a box 60ms wide and 0.07 of damping tall, and they
carry 60 of 147 call sites.** They are not a ladder. They are one rung spelled
five ways.

| Token | R | ζ | settle | overshoot | Sites |
|---|---|---|---|---|---|
| `gentleReveal` | 0.22 | 0.85 | 190ms | 0.63% | 15 |
| `motionSmooth` | 0.22 | 0.78 | 207ms | 1.99% | 5 |
| `motionSnappy` | 0.25 | 0.82 | 224ms | 1.11% | 27 |
| `heavySettle` | 0.28 | 0.80 | 257ms | 1.52% | 2 |
| `naturalSettle` | 0.28 | 0.78 | 263ms | 1.99% | 11 |

**The whole cluster spans 73ms of settle and 1.36 percentage points of
overshoot.** On a 100pt element the overshoot difference between the two
extremes is **1.4 points**. Between `heavySettle` and `naturalSettle` —
identical response, 0.02 apart in damping — it is **0.5 of a point**, which is
1.5 device pixels at 3x, and the settle times differ by **6.5ms, under half a
frame at 60Hz.**

**GridConstants already made this argument and then stopped one token short.**
`GridConstants.swift:398`, deleting `motionSettle` (0.28 / 0.90): *"`motionSettle`
was a THIRD spring at response 0.28, beside `naturalSettle` (0.78) and
`heavySettle` (0.80), both live, and three dampings a fifth of a point apart is
not a ladder."* Two dampings a **fiftieth** of a point apart is not one either.
`heavySettle` has two call sites (`MainAppView.swift:2133`, `:2739`) and its own
doc says only "Large elements settling" — there is no measurement behind the
0.80.

---

## 3. Off-ladder values, named

### Typed inline, three of them

| Site | Value | Verdict |
|---|---|---|
| `NextSlotButton.swift:384` | `interpolatingSpring(duration: 0.34, bounce: 0.18, initialVelocity:)` | **Hand-tuned and load-bearing.** The comment at `:378` names it: velocity handoff per `docs/apple-design.md` §5, normalised by remaining distance — `initialVelocity` is the whole point and no `Animation.spring` token can carry a per-gesture velocity. **Keep it, but the 0.34/0.18 should be a token the call site feeds the velocity into.** |
| `CameraView.swift:313` | `easeOut(duration: 0.36)` | **Typed.** No measurement in its comment; the comment at `:309` is about the `Task.yield()` before it, not the 0.36. It is the camera tab's arrival cover fading away, and it is 0.36 against a ladder whose nearest rungs are 0.30 (`mapFade`) and 0.45 (`slotBloomOut`). |
| `ReplayView.swift:130` | `easeOut(duration: GridConstants.replayLoadingFade)` (0.24) | **Half a token.** The duration is named (`GridConstants.swift:609`) with a reason on it; the curve is typed at the site. It is the only place in the app that reassembles an `Animation` from a loose duration, and 0.24 exists nowhere else. |

### Raw dwell times driving the drop sequence

`TowerAnimationCoordinator.swift:450–497` sequences the landing with nine
hard-coded `Task.sleep` values and no token among them:

| Phase | mass 1 | mass 2 | mass 3+ | Line |
|---|---|---|---|---|
| squash dwell | 40ms | 70ms | 100ms | `:450` |
| stretch dwell | 60ms | 80ms | 120ms | `:460` |
| micro-bounce hold | — | — | 60ms | `:471` |
| wobble dwell | 100ms | 160ms | 220ms | `:479` |
| tail | 120ms | 120ms | 120ms | `:493` |

**Typed, not measured.** The comments assert the intent ("heavier = lingers in
compression") and no comment gives a number behind any of the nine. They are
**nine durations invisible to every count in this file**, because they are
`sleep`s rather than `Animation`s — the drop's total length is 220 to 560ms of
dwell on top of a 340–720ms fall, and none of it is on the ladder or reachable
from `GridConstants`. Section 5 of the design language caps anything at 0.7s;
a mass-3 landing runs 0.72 + 0.50 = **1.22s** of sequenced motion.

### Durations living as private statics in view files

| Site | Value | What it is |
|---|---|---|
| `MemoriesMapView.swift:132` | `cycleSeconds = 7` | the map block's photograph cycle |
| `MemoriesMapView.swift:134` | `cycleSettle = 2.5` | how long after a pan before it cycles |
| `MonthTowerView.swift:201` | `dwell = 5s` | the month block's photograph cycle |
| `MainAppView.swift:1503` | `skeletonGrace = 100ms` | before the loading placeholder |
| `MainAppView.swift:1504` | `skeletonHold = 300ms` | and its minimum hold |
| `CameraView.swift:1645` | `.delay(0.08)` | duplicates `shutterPress`'s own duration |

The 7 is the owner's instruction and is a **sanctioned exemption** in
`screen-audit.md`. The 5 beside it is not, and the pair is finding 5.2 below.

---

## 4. Things that animate because they APPEARED — check 10

Six, ranked by how much a person would notice.

### 4.1 The tower fades in when the Wins tab arrives — `MainAppView.swift:3154`

```
.transition(isNewlyDropped ? .identity
            : .opacity.animation(GridConstants.towerBlockFadeIn.delay(stagger)))
```

`stagger` is `towerVM.staggerDelay(for:)`, which returns 0 for anything not in
`newlyDroppedIDs` (`TowerViewModel.swift:300`, cache built at `:240` only when
that set is non-empty). On the first build it is empty, so **every block on the
tower fades in together over 0.20s** — inside the animated transaction at
`MainAppView.swift:2055` (`withAnimation(layoutReflow) { refreshData() }`),
which runs from `setup()`'s `.task` after the first frame is on screen and after
the 100ms/300ms skeleton handover.

**This is the hard fail, and it contradicts three things already written down
in this repo:**
- `MainAppView.swift:2645`: *"Nothing animates here on arrival."*
- `GridConstants.swift:690`, deleting `skeletonPop`: *"nothing in this app
  animates because a screen appeared, and anything that moved there muddied the
  handover as the real blocks faded in over the top."* It deleted the
  skeleton's pop and left the tower's fade.
- `screen-audit.md` rates screen 1 at 10/10, and check 10 is one of the ten.

`towerBlockFadeIn` has this one call site. Deleting it is a one-line change that
takes a token and a check-10 failure off at once.

### 4.2 The camera's arrival cover — `CameraView.swift:308–315`

```
.task { await Task.yield()
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.36)) { hasArrived = true } }
```

A full-bleed `WarmBackground` fades out over 0.36s because the tab appeared.
The file argues it at `:290–300` (what is underneath is the dark ground rather
than a cut to it) and it honours Reduce Motion, so this is a **defensible
check-10 failure rather than an oversight** — but it is one, and it is also the
app's longest fade outside the heads' float, on a value that exists nowhere
else.

### 4.3 Every map block lands when the map opens — `MemoriesMapView.swift:1197–1204, 1251`

`.onAppear { … arrive() }` → `withAnimation(mapFade.delay(delay)) { arrived = true }`,
scaling 0.94 → 1 and 0 → 1 opacity. **Gated properly for the repeat case**: the
`arrives` flag (`:830`, `:950`, `:1151`) is false for a block that was already
settled, so panning does not re-animate. But the first fill does, with a
per-block stagger, purely because you navigated to the map. The comment at
`:1190` makes the argument ("twenty blocks landing is a map filling in"). Reduce
Motion short-circuits it at `:1203`.

### 4.4 The confetti — `AllClearCelebration.swift:78, 116`

A 2.0s `TimelineView(.animation)` + `Canvas`, started by `.onAppear`.
**The file already flags itself as this exact failure**, at `:32–41`:
*"Section 5 of the design language says nothing runs over 0.7s and nothing
animates because a state appeared; `GridConstants.confettiDuration` is 2.0s on a
state arriving… If the wave is the celebration, this file should go rather than
be tuned. That is his call."*

Two things to add to that note now they are measured: it is the **only** file
with motion and **zero** Reduce Motion handling that runs for two full seconds,
and its trigger path (`MainAppView.swift:2036–2046`) fires off
`animCoord.onAllDropsComplete`, so on a day that is already perfect the drop
cascade finishing is enough — **nobody has to log anything.**

### 4.5 The launch handoff — `LaunchHandoff.swift:42, 52–58`

`.onAppear { DispatchQueue.main.async { running = true } }` drives a 1.2s
`TimelineView`. **Sanctioned.** A launch animation is the one thing that by
definition animates because it appeared, it is Apple's own pattern, and
`:26–27` already gives it a Reduce Motion path (no roll, the S stands still,
shorter fades).

### 4.6 The two photograph slideshows, and the heads

- `MonthTowerView.swift:239–270` and `MemoriesMapView.swift:461–472` both cycle
  a block's photograph on a timer with nothing driving them. **Sanctioned** —
  `screen-audit.md` names the map's seven-second cycle as one of its two
  exemptions, "the owner's instruction and carries information no still frame
  can". Both are off under Reduce Motion (`MonthTowerView:252`,
  `MemoriesMapView:464`).
- `LivingHeadView.swift:189–190` starts `headFloatX`/`headFloatY`
  (`repeatForever`) off `.onChange(of: awake && floats, initial: true)`, and the
  idle beat loops run on their own clock. **Sanctioned and the product** — a
  living head that only moves when touched is a photograph. The sleep rule
  (CLAUDE.md: a head sleeps when it cannot be seen) is what keeps this honest,
  and `HeadLife.calm` holds still in chrome.

**Everything else in the app passes check 10.** `TowerLattice.swift:364` and
`TouchRipple.swift:197` mount their `TimelineView` only while `touches` is
non-empty; `TowerCompanionLayer.swift:486`, `LaunchHandoff.swift:42` and
`ReplayView.swift:218` all pass `paused:`. `SkeletonBlockView` arrives as one
object without moving. That is a good record and it should be said.

---

## 5. Inconsistencies a person would feel

Ranked. Each is two file:lines and two numbers.

### 5.1 A press gets four different answers, and most buttons get none

**`PressResponse` — the app's one press, "every button acknowledges the press,
in one place" (`PressResponse.swift:3`) — has FOUR call sites, and its primary
variant `.press` has ZERO.**

| Answer | Where | In | Out | Scale | Dim |
|---|---|---|---|---|---|
| `.pressWord` | `CameraView:485`, `PrimaryCapsule:166`, `OnboardingView:820`, `:1010` | `easeOut(0.08)` | spring 0.28/0.60 | 0.96 | 0.62 |
| `.press` | **nowhere** | `easeOut(0.08)` | spring 0.28/0.60 | 0.92 | 0.72 |
| `PosterPress` | `MemoriesShelf:147` | spring 0.06/0.0 | spring 0.06/0.0 | 0.97 | none |
| `.animation(tapSquashSpring)` | `NextSlotButton:254`, `MemoriesShelf:360` | 0.06 | 0.06 | — | — |
| `.phaseAnimator` | `FlippableBlockView:233` | `tapSquashSpring` | `tapPopSpring` | — | — |
| iOS's own | `.glassCircle`/`.glassCapsule` `.interactive()` | — | — | — | — |
| **nothing at all** | **31 × `.buttonStyle(.plain)`** | | | | |

`PosterPress` (`MemoriesShelf.swift:353–362`) is a private rebuild of
`PressResponse` — **check 3 of the screen audit failing**, and the one the
dead-code sweep half-caught: CLAUDE.md records deleting `CardPress` because its
own note "apologised for being `MemoriesShelf`'s `PosterPress` 'to the point'".
The duplicate it apologised for is still here, and the comment above it
(`:134–139`) argues for press feedback in the app's own words — *"`.plain` left
the shelf inert under a finger, and section 5 asks for reaction rather than
decoration"* — then supplies it privately instead of reaching for
`PressResponse`.

**This is felt on one screen, in one scroll.** The Memories tab stacks three
rows of pressable cards:

| Row | File:line | Press response |
|---|---|---|
| The month's replay row | `MonthReplayRow.swift:81` | **none** (`.plain`) |
| Collections shelf | `MemoriesShelf.swift:147` | `PosterPress`, 0.97, no dim, 60ms |
| Camera roll grid | `PhotoGalleryGrid.swift:178` | **none** (`.plain`) |

Press the poster and it answers. Press the picture 40 points below it and
nothing happens. Both are a rectangle with a photograph in it that opens
something.

### 5.2 The same photograph handover, at 0.20s and at 0.70s

| | Map block | Month block |
|---|---|---|
| The animation | `GridConstants.crossFade` — `easeInOut(0.20)` | `GridConstants.monthPhotoFade` — `easeInOut(0.70)` |
| Call site | `MemoriesMapView.swift:1049` | `MonthTowerView.swift:265` |
| Cycle | 7s (`MemoriesMapView.swift:132`) | 5s (`MonthTowerView.swift:201`) |

**These are the same mechanism, drawn on the same object, one tap apart.** Both
are a block cycling a day's photographs. Both files carry the *identical*
reasoning — hold the outgoing layer opaque underneath, bring the incoming one up
on top, swap after (`MonthTowerView:228–235`, `MemoriesMapView:1038–1043`) —
which is how you can tell neither was written in ignorance of the other. And
the fades are **3.5× apart**: 0.70s is named with a reason ("slow enough to read
as a dissolve rather than a cut", `GridConstants.swift:371`) and 0.20s is the
app's generic non-spatial crossfade. One of the two is wrong and the argument is
already written on the 0.70.

### 5.3 The photo viewer opens two different ways

| From | File:line | How it opens |
|---|---|---|
| The camera roll | `MemoriesView.swift:277, 288` | `.fullScreenCover` + `.navigationTransition(.zoom(sourceID:))` — out of the thumbnail |
| A place collection | `PhotoCollectionView.swift:93, 98` | the same zoom |
| Inside a replay | `ReplayView.swift:153, 163` | the same zoom |
| **A day album** | **`DayAlbumDetailView.swift:139`** | **`.fullScreenCover` with no transition — slides up from the bottom** |

`DayAlbumDetailView` has no `matchedTransitionSource` anywhere in the file, so
the block you tapped at `:273–286` has no source to open out of. CLAUDE.md is
explicit about which of these is right: *"A photo opens out of its thumbnail,
via `matchedTransitionSource` + `.navigationTransition(.zoom(sourceID:in:))`.
Not a sheet sliding up."* Three screens do it and the fourth does not, and the
fourth is reached from the same shelf as one that does.

### 5.4 A count changes: one rolls, one cuts

| | Day album | Place collection |
|---|---|---|
| | `DayAlbumDetailView.swift:185–189` | `PhotoCollectionView.swift:151–155` |
| Font | `StrataFont.relative(countSize, to: .subheadline)` | identical |
| Word beside it | `Typography.screenSubtitle` | identical |
| Spacing, alignment, ink | `GridConstants.spacing`, `.firstTextBaseline`, `inkTertiary` | identical |
| On change | **`.contentTransition(.numericText())`** | **nothing** |

`PhotoCollectionView` copied this line from `DayAlbumDetailView` — its comment
at `:140` says so by name, and reproduces the other file's three-paragraph
argument about `StrataFont.digits` verbatim — and dropped the one modifier that
moves. Both counts change for the same reason: you delete a photograph from
inside the viewer and come back. One rolls its digits, one cuts.

The same split runs wider: `.contentTransition(.numericText())` at
`ProfileView:425, 462` and `DayAlbumDetailView:188`;
`.contentTransition(.opacity)` at `MonthTowerView:351` and `HeadMakerView:431`;
and **nothing** at `MemoriesShelf:302`, `PhotoCollectionView:152`,
`MemoriesMapView:1464`, `RestoreBackupView:110, 203`. Three answers for one
event.

### 5.5 A form row appears: `gentleReveal`, gated — or no animation at all

| | Settings' reminder time | Add a win's Colour field |
|---|---|---|
| Transition | `.opacity.combined(with: .move(edge: .top))` — `SettingsView.swift:249` | the same, verbatim — `AddWinSheet.swift:152` |
| Animation | `.animation(reduceMotion ? .none : gentleReveal, value:)` — `:281` | **none** |
| Reduce Motion | honoured | not considered |

**The Add sheet's transition cannot play.** The four writes to `photo` that
insert and remove that field (`AddWinSheet.swift:222, 257, 267, 288, 299`) are
all bare assignments with no `withAnimation`, and there is no `.animation(…)`
anywhere in the file. A transition in an unanimated transaction is a cut, so the
Colour field hard-cuts in and out while the identical construction in Settings
springs. **A declared transition that no transaction can reach is the motion
equivalent of a probe with no call sites** — it reads as a feature you cannot
find.

### 5.6 `cardMorph` is named for a thing that no longer exists

Three call sites (`MainAppView:768, 2824, 3469`), all of the shape
`withAnimation(reduceMotion ? crossFade : cardMorph) { expandedBlockID = … }`.
Its doc (`GridConstants.swift:700`) says *"Card open/close morph"* and *"it is
the sheet's open and close now, in `MainAppView`"*. **It is not.** UIKit owns a
`.sheet`'s presentation curve; `withAnimation` cannot reach it. What the spring
actually animates is one line — `.opacity(isExpanded ? 0 : …)` at
`MainAppView.swift:3344` — the tapped block fading out to 0 under its sheet.

So a **spring with 0.50% overshoot is driving a pure opacity**, which is what
`crossFade` is for, and the Reduce Motion branch of these three sites already
substitutes `crossFade` — i.e. the accessible path and the default path differ
only in using the right token.

---

## 6. Liquid Glass

### What is there

Six helpers, in three files, all `@available`-gated to iOS 26 with an
`.ultraThinMaterial` fallback (deployment target is 18.0):

| Helper | File:line | Recipe |
|---|---|---|
| `glassCircle(onPage:)` | `GlassIconButton.swift:188` | `onPage ? GlassRecipe.onPage : .regular.interactive()`, in `.circle` |
| `glassCapsule(onPage:carriesType:)` | `GlassIconButton.swift:138` | `typePanel` / `onPage` / `.regular.interactive()`, in `.capsule` |
| `glassRoundedRect(cornerRadius:carriesType:)` | `GlassIconButton.swift:163` | `typePanel` / `photoOverlay` |
| `glassSlot(cornerRadius:thickness:)` | `SlotGlass.swift:109` | `GlassRecipe.slot(thickness:)`, `.clear`, no tint |
| `mapPanel(hairline:)` | `MemoriesMapView.swift:1520` | `.regular` + an ink hairline overlay |
| `zoomGlass()` | `CameraView.swift:1789` | `.regular.interactive()`, in `.capsule` |

**Layout order is correct everywhere.** Every one of the six documents "layout
first, glass after", and the two call sites worth checking confirm it:
`CameraView.swift:1294` sets `.frame(width: 56, height: 34)` before
`.zoomGlass()`, and `MemoriesMapView.swift:765–769` sets `.frame` and `.padding`
before `.mapPanel`. **No `.glassEffect()` in this app is applied before its
layout modifiers.**

### What is not there

**Zero `GlassEffectContainer`. Zero `glassEffectID`. Zero
`glassEffectTransition`. Zero `glassEffectUnion`.** Verified across `Strata/`,
`Shared/`, `StrataWidget/` and `WidgetSupport/`.

So the nesting question has a vacuous answer — **no `GlassEffectContainer` is
nested inside another, because there are none** — and the morph system is not
partly adopted, it is entirely unadopted.

### Where a morph would replace a hand-built transition

Two, and both are glass capsules that currently scale-and-fade:

| Site | Current | What a morph would do |
|---|---|---|
| `CameraView.swift:1311` | `.transition(.scale(scale: 0.7).combined(with: .opacity))` on the zoom pill | The comment at `:1308` states the intent exactly — *"It grows out of the shutter's line rather than fading in on the spot, which is what makes it read as belonging to the gesture that produced it."* That is a description of a `glassEffectID` morph out of the shutter, built by hand out of a scale and an opacity because the morph system is not in use. |
| `MemoriesMapView.swift:1302` | `.transition(.scale(scale: 0.4, anchor: .topTrailing).combined(with: .opacity))` on the count badge | Same shape: *"It belongs to the block, so it arrives out of the block's own corner."* |

### The duplicate

**`zoomGlass()` (`CameraView.swift:1789`) is `glassCapsule()` spelled again.**
Both resolve to `.glassEffect(.regular.interactive(), in: .capsule)` with
`.ultraThinMaterial` in a `Capsule()` as the fallback — identical on both paths,
except that `glassCapsule`'s fallback also draws `GlassFallback.rim`
(white 0.18 at 0.5pt) and `zoomGlass`'s does not. `GlassIconButton.swift:104`
names this exact fault: *"It was typed out three times, once in each shape
below, which is the drift this file exists to stop."* It is typed out a fourth
time, in another file, 480 lines from the shape it duplicates.

`mapPanel` is **not** a duplicate: `.regular` without `.interactive()` plus an
ink hairline, and its doc argues both choices (`:1500–1518`).

### The budget

`GlassIconButton.swift:17` sets it: *"at most three glass elements on a
screen"* (`docs/research/visual-cohesion.md` §4.2). `GlassIconButton.swift:21`
already lists three callers it calls "the audit's open question rather than the
precedent to copy", and two of the three it names are gone — the tower header's
replay pill and the Memories drawer's Done were both deleted on 2026-10-01
(CLAUDE.md records both). **That comment is stale and overstates the problem;
the open question is now one call site, the tower header's Plan button.**

---

## 7. Reduce Motion

**19 files read `\.accessibilityReduceMotion`. 12 files with motion do not.**
There is no global gate — no `.transaction { $0.disablesAnimations = … }` keyed
on the setting, and the two `transaction.disablesAnimations` sites
(`MainAppView:694, 3731`) are about something else.

### The convention, where it is followed

`GridConstants.swift:393` writes it down, in the note deleting `motionReduced`:
*"the app's reduce-motion convention is already written out across about twenty
call sites and it is `nil` / `.none` for anything that should not move, and
`crossFade` where the change still has to be seen."* Sixteen sites spell it,
and they spell it **three ways** — `nil` (10), `.none` (1,
`SettingsView:281`), and a substituted token (5). Only the `nil`/`.none` split
is noise; the substitution is the convention working.

### The ones that do not honour it

| File | Animating sites with no Reduce Motion path | Worst of them |
|---|---|---|
| `FlippableBlockView.swift` | `:134` `.animation(slotSnap, value: isLifted)`; `:233` `.phaseAnimator` tap bounce on `tapSquashSpring`/`tapPopSpring` | **This is the file the tower actually renders** (CLAUDE.md: "The tower renders `FlippableBlockView`, not `HabitBlockView`"). Every block in the app squashes and pops back with a 0.20 bounce on every tap, under Reduce Motion. The most-touched object in the app. |
| `PhotoViewer.swift` | `:332, 353, 455, 456, 854, 895, 918, 926, 977` — nine | Pinch-zoom clamping and page turns, all on `motionSnappy`. A zoom that springs back is exactly what Reduce Motion asks not to happen. |
| `ProfileView.swift` | `:262, 303, 311` (`motionSnappy`), `:425, 462` (`numericText`), `:468, 474` | The swatch tray opening and the chart's bar selection |
| `AllClearCelebration.swift` | `:78` `TimelineView(.animation)`, `:116` `.onAppear` | **2.0 seconds of tumbling particles**, the longest unguarded motion in the app |
| `AddWinSheet.swift` | `:593` (`motionSmooth`), `:694` (`slotSnap`) | the colour change and the size change |
| `PlanSheet.swift` | `:442` `.transition(.opacity)`, `:455` `.animation(motionSnappy, value: focused)` | |
| `PlanItemDetailSheet.swift` | `:109, :165` (`motionSnappy`) | |
| `PlanBullet.swift` | `:102` (`motionSnappy`) | the tick |
| `StoreUnavailableView.swift` | `:62` `.transition(.opacity)`, `:114` (`crossFade`) | `crossFade` is the app's own Reduce Motion answer, so this one is effectively fine already |
| `MemoriesView.swift` | `:569` (`crossFade`), `:674` `.transition(.opacity)` | as above |
| `DayAlbumDetailView.swift` | `:188` `.contentTransition(.numericText())` | whether `numericText` self-disables under Reduce Motion is **unverified** — this audit did not build |
| `PressResponse.swift` | `:44` | **The app's shared press style has no Reduce Motion path**, while the private `PosterPress` that duplicates it takes `reduceMotion` as a stored property and honours it (`MemoriesShelf.swift:354, 357`). The copy is more accessible than the original. |

**The best record in the app is the heads and the replay.** `ReplayScript`
carries `reduceMotionSpan` and `reduceMotionFade` in its own `Pacing`
(`ReplayScript.swift:84`, 12 references in the file); `LivingHeadView` has 14;
`HeadTake` has a documented face-swap-only mode; `TowerCompanionLayer:331`
parks the head and stops its clock for good. Those are the parts somebody
designed the accessible version of, rather than switching the default off.

---

## 8. The second ladder, and why it is right

**The replay is a separate motion system, deliberately, and it should stay
separate.** `ReplayScript.Pacing` (`ReplayScript.swift:78–120`) holds its own
sixteen time constants — `open` 0.9, `holdAfterLast` 0.5, `minGap` 0.14,
`maxGap` 0.55, `floorGap` 0.04, `cameraLead` 0.25, `cameraEarliestRise` 0.75,
`arrive` 0.45, `danceWave` 0.6, and the rest — and its own easing, a hand-rolled
smoothstep at `:573` (`q*q*(3-2q)`).

CLAUDE.md gives the reason and it is not negotiable: *"The whole replay is a
function of time. No `withAnimation` anywhere in it… `ReplayVideoExporter` draws
the same `ReplayFrame` to frames."* An implicit animation cannot be drawn into a
video frame. `LaunchRoll` is the same pattern for the same reason (an offline
preview renders from it).

**Do not fold these into the app's ladder.** They are the one place in this
codebase where "one system" means a second system, and both files say so.

---

## The system, if we collapse to one

### The proposed ladder

**Five durations and four curve shapes.** Nothing new is invented: every value
below is already in the app and already carries ≥4 call sites or a written
measurement.

| Rung | Value | For |
|---|---|---|
| **`press`** | spring, duration 0.06, bounce 0.0 (`tapSquashSpring`) | a finger going down |
| **`respond`** | spring, R 0.25, ζ 0.82 (`motionSnappy`) | anything a tap or a drag changes in place |
| **`settle`** | spring, R 0.30, ζ 1.00 (`slotSnap`) | anything that repositions — critically damped, per `apple-design.md` |
| **`reflow`** | spring, R 0.55, ζ 0.90 (`layoutReflow`) | the page's own layout changing |
| **`fade`** | `easeInOut(0.20)` (`crossFade`) | anything non-spatial, and the Reduce Motion substitute |

Plus **four bounce rungs**, kept because overshoot is earned by momentum
(`apple-design.md`, and CLAUDE.md's reading of it) and these four are the only
places momentum caused the motion:

| Rung | Value | For | Sites today |
|---|---|---|---|
| `impact` | R 0.18, ζ 0.65 | a block landing and the ripple | `wobbleSpring` + `dropStretchSpring` |
| `celebrate` | R 0.25, ζ 0.50 | the slot's release bloom | `elasticPop` |
| `dance` | R 0.30/0.52 and R 0.40/0.78 | the tenth-win wave | `danceRise`/`danceSettle` |
| `release` | R 0.28, ζ 0.60 | the shutter and the ripple's recovery | `shutterRelease` + `rippleReleaseSpring` |

**That is 9 animations against 40.** It takes the top of the ladder from three
tokens carrying 41% to five carrying 85%.

### The exact call sites that change

**Group A — delete the token, retarget its callers to `respond` (R 0.25 / ζ 0.82).**
The cluster argument in §2: all four are inside 73ms of settle and 1.4pt of
overshoot from it.

| Token | Sites to retarget |
|---|---|
| `gentleReveal` (15) | `MainAppView:1519` · `MemoriesMapView:1306, 1654` · `SettingsView:281` · `PhotoViewer:456, 854` · `CameraView:600, 899, 1024` · `HeadMakerView:123` · `OnboardingView:495` (RM branch), `:971` · `ReplayView:352, 353` |
| `motionSmooth` (5) | `AddWinSheet:593` · `CameraView:839, 1153, 1331` · `ProfileView:474` |
| `naturalSettle` (11) | `MemoriesMapView:246` · `LivingHeadView:585, 624, 653, 756, 805` · `OnboardingView:160, 281, 1001, 1106` · `HeadMakerView:908` |
| `heavySettle` (2) | `MainAppView:2133, 2739` |
| `dropSettleSpring` (2) | `TowerAnimationCoordinator:484` · `OnboardingView:669` |

**Group B — collapse an acknowledged alias.** Two names, one number, zero
visual change.

| Delete | Keep | Sites to repoint |
|---|---|---|
| `snapBack` (0.22/0.20) | `tapPopSpring` | `NextSlotButton:325, 338` |
| `wobbleSpring` (0.18/0.65) | one `impact` token | `TowerAnimationCoordinator:454, 475` |
| `towerBlockFadeIn` (easeOut 0.20) | **delete outright** — see §4.1 | `MainAppView:3154` |
| `cardMorph` (0.35/0.86) | `crossFade` — §5.6; it drives an opacity | `MainAppView:768, 2824, 3469` |

**Group C — bring the three inline literals onto the ladder.**

| Site | From | To |
|---|---|---|
| `CameraView:313` | `easeOut(0.36)` | `crossFade` at 0.20, or a named `tabArrive` if 0.36 is wanted — it is currently a number with no argument behind it |
| `ReplayView:130` | `easeOut(replayLoadingFade)` | one token holding both the curve and the 0.24 |
| `NextSlotButton:384` | `interpolatingSpring(0.34, 0.18, initialVelocity:)` | **keep the behaviour**, move 0.34/0.18 into a token the site feeds velocity into |

**Group D — the press, which is the biggest felt win and is not a token change.**

1. Delete `PosterPress` (`MemoriesShelf.swift:353–362`); point
   `MemoriesShelf:147` at `.buttonStyle(.press)`.
2. Give `PressResponse` a Reduce Motion path (`PressResponse.swift:44`) — the
   copy being deleted already has one.
3. Move the three card rows on the Memories tab onto it:
   `MonthReplayRow:81`, `PhotoGalleryGrid:178`, and `MonthTowerView`'s block
   button. Then audit the other 28 `.buttonStyle(.plain)` sites, which is a
   separate pass and should be one.

**Group E — the pairs.**

| Fix | Sites |
|---|---|
| One photograph-handover fade | pick 0.70 or 0.20 for `MemoriesMapView:1049` and `MonthTowerView:265`, and one cycle length for `:132` (7) and `:201` (5) |
| The day album's photo viewer opens out of its block | `DayAlbumDetailView:139`, which needs a `matchedTransitionSource` on the block at `:273` |
| The place collection's count rolls | add `.contentTransition(.numericText())` at `PhotoCollectionView:155` |
| The Add sheet's Colour field has a transaction to animate in | `AddWinSheet:222, 257, 267, 288, 299` |
| Spell Reduce Motion one way | `SettingsView:281` is the only `.none`; 10 others are `nil` |

**Group F — name the nine drop dwells.** `TowerAnimationCoordinator:450, 460,
471, 479, 493`. They are not `Animation`s, so no count in this file sees them,
and they are 220–560ms of the drop's length.

### What must be EXEMPTED, with the reason and the measurement

**Nine exemptions. Each is a value this collapse would otherwise flatten, and
each has a number behind it.**

1. **`dropFallCurve`** — `timingCurve(1/3, 0, 2/3, 1/3)`, `TowerAnimationCoordinator:436`,
   `OnboardingView:494`. Not a rung: `y = t²` exactly at the midpoint, scaled by
   `1/√(2d/g)` at `dropGravity` 4200, clamped 0.34…0.72. CLAUDE.md: *"All masses
   fall the same, because they do… Do not add easing-out at the end."* A spring
   here eases a falling object into the ground. **Measured**: the version that
   derived the start offset live fell on 2 of 10 drops.

2. **`eyeSaccade`** — 0.09 / 1.00, 66ms settle, `LivingHeadView:335, 350, 577,
   623, 870`. **Measured against the body**: a human saccade is tens of
   milliseconds, and the token's doc says why it must beat `headTurn` — "the
   eyes land before the head has started". 66ms against `headTurn`'s 403ms is
   that gap. Collapsing it to `press` (60ms) would be within a frame but the
   damping must stay 1.00: an eye that overshoots reads as a twitch.

3. **`headTurn` 0.55/1.00 and `headTakeEaseBack` 0.70/1.00** — `LivingHeadView:636,
   879` and the take ease-back. **Critically damped on purpose**, per
   `apple-design.md` as read in GridConstants:496 — *"a head arrives at what it
   is looking at, it does not overshoot and correct."* `layoutReflow` is the
   same 0.55 response at ζ 0.90, which overshoots 0.15%; on a photographed face
   that is visible and wrong. Two tokens, one response, different damping, and
   the damping is the point.

4. **`headMorph`** — `easeOut(0.14)`, `LivingHeadView:788`. Doc: *"longer and it
   reads as a slideshow dissolve, not a face."* And `headStep` 0.125 is the
   blink's posterised clock, which this has to sit inside.

5. **`headFloatX` 3.7s / `headFloatY` 2.9s** — `LivingHeadView:189, 190`. **The
   two periods are coprime on purpose** so the drift never reads as a metronome.
   Rounding either to a ladder rung puts them in phase.

6. **`monthPhotoFadeDuration` 0.70** — `GridConstants:371`, `MonthTowerView:204,
   265`. The only one of §5.2's pair with an argument on it. Whichever way that
   pair resolves, **one** of 0.70 and 0.20 is exempt and the other is drift;
   this audit cannot say which without looking at a phone, which is the open
   check below.

7. **The map's 7-second cycle** — `MemoriesMapView:132`. Already a sanctioned
   exemption in `screen-audit.md`: the owner's instruction, carrying information
   no still frame can.

8. **`ReplayScript.Pacing` and `LaunchRoll`, in full** — §8. They must be a pure
   function of time or the video cannot be exported. Sixteen constants, one
   hand-rolled smoothstep, and both files document the constraint.

9. **`slotSnap` 0.30 / 1.00** — kept as `settle` rather than folded into
   `respond`. Its doc (`GridConstants:528`) is the longest argument for a number
   in the file and it is a real one: it fires *while a finger is still dragging*
   and has to land before the finger asks for the next size, against
   `slotStep` 46 and `slotStepHysteresis` 12. **ζ must stay 1.00**: "Crossing a
   size threshold mid-drag is a reposition, not a throw, and a bounce there
   reads as the slot being unsure."

### Ranked: what a person feels first

1. **The press.** Four answers, 31 buttons with none, and three card rows on one
   Memories screen where the middle one answers and its neighbours do not
   (§5.1). This is the owner's sentence — *"every button with a clean
   animation… everything needs to feel easy to touch"* — and it is the only
   finding in this file where the app currently does nothing at all.
2. **The two photograph fades, 3.5× apart, one tap from each other** (§5.2).
   The month tower and the map are the two halves of the Memories tab.
3. **The day album's photo viewer slides up while every other photograph in the
   app zooms** (§5.3). One missing modifier, and CLAUDE.md already rules on it.
4. **The tower fading in because the Wins tab appeared** (§4.1). A one-line
   deletion that fixes check 10 on the app's home screen and takes a token with
   it.
5. **Reduce Motion on `FlippableBlockView`** (§7). Every block in the app bounces
   on tap with the setting on, in the one file the tower actually draws.
6. **The cluster collapse** — Group A, 35 call sites (§2). **Ranked fifth on
   purpose**: arithmetically it is the biggest number in this audit and
   perceptually it is the smallest thing in it. The whole cluster is 73ms and
   1.4pt wide. Nobody will see this change; what they get is a motion
   vocabulary a person can hold in their head, which is what makes the next
   change consistent for free.
7. **The dead transition in the Add sheet, and `cardMorph`'s name** (§5.5, §5.6).
   Two things that read as features and are not.
8. **`zoomGlass`, and the two hand-built glass transitions** (§6). Real, and the
   least felt: the duplicate renders identically and the two transitions already
   do roughly what a morph would.

### The open check

**None of this was looked at.** `screen-audit.md`'s own method — capture from a
seeded fixture, measure in points off the PNG — has not been applied to a single
animation here, because `simctl io screenshot` samples at ~3Hz and CLAUDE.md is
explicit that a burst *"is a coarse instrument: use it to tell 'never' from
'sometimes', not to measure a duration."*

So the one judgement that decides Group A and exemption 6 — whether 73ms and
1.4pt of overshoot is a difference anybody feels — is not in this file. It needs
the two versions built, filmed, and put side by side, which is exactly how the
white label and the 8pt corner were settled on 2026-10-01. **Until that
happens, every number above is an argument and not a verdict.**

---

## Filmed, 2026-10-02: every motion graded out of ten

The open check above is closed. Each motion below was **filmed** on Strata-E
(402x874) with `xcrun simctl io recordVideo` at the simulator's own frame
rate, driven by real taps through the simulator, and read frame by frame
with `tools/frames.swift` (time, change from the frame before, and the gap
between frames). Main-thread stalls were measured with `-strataPerfProbe`
on a build compiled `-O` (the debug harness, optimised), and the two worst
were sampled with macOS `sample` to find what the time was spent on.

**What the simulator cannot say.** It renders on the Mac's GPU, so a motion
that is GPU-bound here (the replay's last zoom-out drew 16fps in the film
while the main thread had 8 gaps over 50ms in 30 seconds) says nothing about
a phone. Those are marked "phone". Launch time is the same: a debug build
seeding photographs is not a launch.

**A 10 means:** on the ladder (`tools/motion-inventory.py`), caused by a
person (check 10) or a sanctioned exemption, calm under Reduce Motion, the
platform's own idiom where one exists, and no main-thread stall a person
would feel in the optimised build.

| Motion | Filmed | Grade | Note |
|---|---|---|---|
| Tab switch, any tab | glass pill ~220ms (system), page swap ~100ms | **10** | iOS 26's own |
| Camera arriving | 300ms dissolve over the page | **10** | the owner's request; Reduce Motion gated |
| Press, every control | glass answers itself; `.press`, `.pressWord`, `.pressSurface` elsewhere | **10** | the profile picture was silent as a photograph or colour; fixed |
| Block to Edit sheet | system sheet, 460ms | **10** | a 535ms cold freeze before it was Spotlight drawing a thumbnail per win; gone |
| Size Quick / Regular / Deep | 420 to 476ms, one 100ms frame gap (debug build) | **10** | `motionSnappy`; the probe saw no main-thread gap over 50ms on that tap, so the film's one gap was rendering, not the app |
| Colour change | 184ms crossfade | **10** | |
| Sheet dismiss (Cancel, swipe) | 465 to 533ms | **10** | system |
| Plan open | 521ms | **10** | system sheet |
| Wins to Memories, first visit | page in ~100ms, then the shelf and posters ~330ms later | **9** | phone: the late shelf is SwiftUI building the page once plus the fixture's photographs being processed; a second visit costs ~20ms of main thread |
| Calendar day open / back | zoom, 260 / 285ms | **10** | the platform's zoom, out of the cell |
| Album card open / back | push, ~460ms | **10** | the platform's push |
| Map push | 883ms, MapKit cold start (795ms main thread) | **9** | phone: no app code in the stall; pre-warming MapKit would cost memory and network for people who never open the map |
| Replay open | zoom out of its card, 503ms | **10** | |
| Replay play and rest | function of time (exemption 8) | **10** on motion, **phone** on frame rate | GPU-bound in the simulator |
| Replay close | 315ms zoom; the clock now pauses first | **9** | phone: 8 frames in 315ms here, GPU-side |
| Win drop and landing | ~450ms fall, landing, slot back ~300ms later | **10** | `dropFallCurve`, exemption 1 |
| Keyboard | system | **10** | |

**Seventeen motions: fourteen at 10, three at 9, and all three 9s wait on a
phone, not on code.** Nothing in this table is a 9 because of something the
app does wrong that the simulator can see.

### What changed to get here

- **One vocabulary.** `gentleReveal`, `naturalSettle`, `motionSmooth` and
  `dropSettleSpring` (Group A above) are `motionSnappy` now: 36 animations
  to 33, and one spring carries 63 of 148 call sites. The slot's release is
  a token that takes the finger's velocity; no animation is typed inline.
- **Reduce Motion decided once** (`GridConstants.calm`). Every UI spring is
  the 0.2s fade with the setting on, so the eight files that animated
  without reading it are covered by construction, in sheets and covers too.
- **Nothing silent under a finger.** `.plain` is left only on glass, which
  presses itself.
- **The first sheet stopped freezing.** The cold launch spent ~2,500 samples
  in the Spotlight reindex drawing one SF Symbol thumbnail per win; it now
  draws seven, at background priority, two seconds after launch.

### Disproved, so nobody tries it again

- **Pausing the replay clock does not fix the close's frame rate here.**
  Filmed before and after: 9 frames in 500ms, then 8 in 315ms. At the close
  the clock was already paused (finished and settled); the cost is the zoom
  compositing a page of photographs, which is the GPU and the simulator's.
  The pause stays because it is right for a replay closed mid-play.
