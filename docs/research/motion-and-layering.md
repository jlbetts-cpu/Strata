# Strata: a motion and layering system

Research and build plan, 2026-09-15. Read against
`/Users/jaydenbetts/StrataWork/owner-head` at `fad9c51` (clean worktree).

**Method, and its one limit.** Everything below is read out of the source. The
screenshots and films this was meant to be checked against were cleared from the
scratchpad before I could open them, and I was asked not to build or run a
simulator (three agents hold the three simulators). So nothing here is a claim
about what a frame looks like. Where a judgement needs a frame, it is listed in
§5.2 as a capture request with the flag, the device, the thing to watch and the
number that decides it — nothing in §4 is scheduled ahead of the capture it
depends on.

The owner's words this answers:

> "there should be elements of polish. Buttons should always feel one way.
> Animations should all be consistent and clean; there shouldn't be animations
> where I can still see the previous thing. Animations should flow in and out.
> I remember sending the apple.md, that should help. Layering: making sure
> elements are correctly layered, backed by research and results, such as the
> map, what to prioritise."

Three sentences, three sections. §1 is "buttons should always feel one way", §2
is "no animation where I can still see the previous thing", §3 is layering.

---

## 0. The headline

**The app has no `ButtonStyle`.** Not one, anywhere — `Strata`, `Shared` and
`StrataWidget`. What it has instead is 34 `.buttonStyle(.plain)` call sites,
which is the style that explicitly asks for *no* press treatment, and one
comment in `AddWinSheet.swift:539` that already noticed:

> "The whole app had 20 `.buttonStyle(.plain)` and not one native style"

So the press feedback in Strata today is: a haptic in the action closure (fired
on release), and, on iOS 26 only, whatever Liquid Glass does on its own inside
`GlassIconButton`. Three controls have a real press animation and each invented
its own: the tower slot, the camera shutter, the tower block. On the 18.0
deployment target, a `GlassIconButton` — the close button on the photo viewer,
the replay, the head maker, the camera, and the two buttons on the Memories
title row — has **no visual response to a press at all**.

That is the whole of "buttons should always feel one way": there is no one way.

By contrast the *transition* work is in much better shape than I expected.
`CachedImageView`, `MonthTowerView`'s slideshow, `PlaceBlock`'s photo handover
and `BlockSurface` have each already been fixed for exactly the symmetric-fade
bug CLAUDE.md names, and each carries the reasoning in a comment. The remaining
violations are the places that fix has not reached yet, and they are listed in
§2 with the working pattern to copy.

---

## 1. Button behaviour

### 1.1 What every tappable control does today

Columns: press (visual on pointer-down), release, haptic and when, disabled.

#### A. Plain buttons — no visual press response, haptic on release

These all read `Button { HapticsEngine.… ; action() } label: { … }` with
`.buttonStyle(.plain)` or nothing. Press: **nothing.** Release: nothing.
Haptic: on release, inside the action.

| File:line | Control | Haptic |
| --- | --- | --- |
| `Strata/Views/GlassIconButton.swift:33` | every `GlassIconButton` (11 call sites) | `lightTap` |
| `Strata/Views/ProfileAvatar.swift:75` | Profile button, Memories header | `lightTap` |
| `Strata/Views/AlbumCarousel.swift:36` | album card | `lightTap` |
| `Strata/Views/PhotoGalleryGrid.swift:99` | gallery thumbnail | `lightTap` |
| `Strata/Views/ReplayShelf.swift:50` | replay poster card | `lightTap` |
| `Strata/Views/MonthTowerView.swift:54` | a day's block on the month tower | `lightTap` |
| `Strata/Views/MonthTowerView.swift:276` | month `‹` / `›` chevrons | `lightTap` |
| `Strata/Views/HeadLookPicker.swift:38` | a face in the picker | `tick` |
| `Strata/Views/FilmLookStrip.swift:38` | a film look | `tick` |
| `Strata/Views/HeadSticker.swift:316` | the sticker toggle | `tick` |
| `Strata/Views/AddWinSheet.swift:305` | Cancel | `lightTap` |
| `Strata/Views/AddWinSheet.swift:315` | Save / Add | **none** |
| `Strata/Views/AddWinSheet.swift:339` | the photo well | `lightTap` |
| `Strata/Views/AddWinSheet.swift:464` | a category chip | `tick` |
| `Strata/Views/AddWinSheet.swift:544` | Delete | `tick` |
| `Strata/Views/AddWinSheet.swift:795` | Replace, on the review | `lightTap` |
| `Strata/Views/AddWinSheet.swift:803` | Remove, on the review | `warning` |
| `Strata/Views/MemoriesView.swift:515` | Done, drawer header | `lightTap` |
| `Strata/Views/MemoriesMapView.swift:533` | the map's empty-state button | `lightTap` |
| `Strata/Views/MainAppView.swift:858` | the Your Week / Your Month pill | `lightTap` |
| `Strata/Views/ProfileView.swift:194` | a background swatch | `tick` |
| `Strata/Views/ProfileView.swift:496` `:548` | Make / Remake my head | `lightTap` |
| `Strata/Views/ProfileView.swift:559` | Delete Head | **none** |
| `Strata/Views/ProfileView.swift:609` | Done | `lightTap` |
| `Strata/Views/SettingsView.swift:212` `:216` | Preview Your Week / Month | **none** |
| `Strata/Views/SettingsView.swift:264` `:287` | Replay tour, Back Up Everything | `lightTap` |
| `Strata/Views/SettingsView.swift:301` | Reset All Data | **none** |
| `Strata/Views/SettingsView.swift:356` | Rate Strata | **none** |
| `Strata/Views/SettingsView.swift:449` | Done | `lightTap` |
| `Strata/Views/PlanSheet.swift:91` | Tidy | `lightTap` |
| `Strata/Views/PlanSheet.swift:110` | add a line | **none** |
| `Strata/Views/PlanSheet.swift:201` | a plan row's bullet | **none** |
| `Strata/Views/PlanSheet.swift:259` | the focused row's `ⓘ` | `lightTap` |
| `Strata/Views/PlanItemDetailSheet.swift:80` `:119` `:178` `:189` | category, repeat day, Done, Delete | `lightTap` ×3, `warning` |
| `Strata/Views/CameraView.swift:398` | close the review | `tick` |
| `Strata/Views/CameraView.swift:439` | keep the shot | `success` |
| `Strata/Views/CameraView.swift:479` | a size option on the review | `tick` |
| `Strata/Views/CameraView.swift:921` | the zoom pill | `lightTap` |
| `Strata/Views/CameraView.swift:1001` | `glyphButton` — grid, flash, flip, timer | `tick` |
| `Strata/Views/HeadMakerView.swift:302` `:337` `:440` | back, flash, retake | `lightTap`, `tick`, `tick` |
| `Strata/Views/HeadMakerView.swift:452` | save the head | `success` |
| `Strata/Views/OnboardingView.swift:417` | the LinkedIn link | **none** |
| `Strata/Views/OnboardingView.swift:510` | the continue pill | `lightTap` |
| `Strata/Views/OnboardingView.swift:540` | Skip / Not now | `lightTap` |
| `Strata/Views/PhotoViewer.swift:314` `:320` | menu items, Save and Remove | none, `warning` |

Nine of those fire no haptic at all, including three destructive ones
(`SettingsView.swift:301` Reset All Data, `ProfileView.swift:559` Delete Head)
and the app's primary confirm (`AddWinSheet.swift:315` Add).

#### B. The three that do have a press animation, each its own

| Control | Down | Up | Haptic |
| --- | --- | --- | --- |
| **The tower slot** `NextSlotButton.swift:174`, scale at `:52`, animation at `:146` | uniform `1 − 0.04 = 0.96`, `tapSquashSpring` (`spring(duration: 0.06, bounce: 0)`), on pointer-**down**; plus the recess doubles and the outline gains 0.10 alpha and the colour comes up to 0.60 | `elasticPop` to `charge = 1`, then `snapBack` after 90 ms | `tick` on **down**; `snap` on every size crossing |
| **The camera shutter** `CameraView.swift:1093`, scale at `:1248` | `HapticsEngine.tick()` on pointer-down — **but no visual change at all** | `0.86` on `shutterPress` (`easeOut 0.08`) then `shutterRelease` (`spring(0.28, 0.6)`) delayed 0.08 | `tick` on down, `snap` in `fire()` |
| **A tower block** `FlippableBlockView.swift:130`, animation at `:218` | nothing | on tap **completion**: `phaseAnimator` squash `x 1.02−, y 0.97+` scaled by mass tier, `tapSquashSpring` in, `tapPopSpring` (`spring(0.22, bounce 0.20)`) out | `lightTap` on completion |

The shutter's squash is the sharpest divergence and it is worth stating plainly:
`shutterScale` is written inside `fire()` (`CameraView.swift:1248`), not on
`shutterDown`. With the timer armed, `shutterPressed()` starts a countdown and
`fire()` runs **seconds** later — so the one control on the screen whose entire
job is to be pressed does not move when you press it, and then squashes on its
own a few seconds afterwards. `apple-design.md` §1: "Respond on pointer-down,
not on release. Waiting for click/touch-up to show feedback feels dead."

#### C. iOS 26 glass, which supplies its own press

`GlassIconButton.swift:103` and `:83` apply `.glassEffect(.regular.interactive(),
in:)`, which deforms under a finger. Below iOS 26 — and 18.0 is the deployment
target — the fallback at `:105` / `:85` is `.ultraThinMaterial` plus a hairline
and **nothing happens on press**. So the same button feels like two different
buttons depending on the phone.

There are also **three copies of the same glass helper**:
`GlassIconButton.swift:81` `glassCapsule()`, `MemoriesMapView.swift:1117`
`mapPrimeGlass()`, `CameraView.swift:1391` `zoomGlass()`. They are byte-identical
on iOS 26; on the fallback path the shared one adds a
`.strokeBorder(.white.opacity(0.18), lineWidth: 0.5)` and the other two do not.
Same class of drift `SectionHeading` and `GlassIconLabel` each already record.

#### D. Not buttons, and correctly so

- **Block taps on the map** — `MemoriesMapView.swift:555` is a `Button` with
  `.plain` wrapping `PlaceBlock`; it inherits everything in §A.
- **The month tower's blocks** — `MonthTowerView.swift:54`, §A.
- **The drawer handle** — `MemoriesDrawer.swift:115`, a `DragGesture`
  (`minimumDistance: 8`) with momentum projection and rubber-banding. Correct as
  built; see §2.
- **Sheet toolbar items** — there are none. Every sheet's Done/Cancel is a plain
  `Button` in the sheet's own header (`AddWinSheet.swift:305/315`,
  `ProfileView.swift:609`, `SettingsView.swift:449`, `MemoriesView.swift:515`).
  That is why they all fall under §A rather than inheriting a system style.
- **Alert and `confirmationDialog` buttons** — `AddWinSheet.swift:150/206/214`,
  `PhotoViewer.swift:169`, `ProfileView.swift:81`, `SettingsView.swift:320`,
  `MainAppView.swift:469/474`. System-drawn, leave them alone.
- **`Menu` labels** — `ProfileView.swift:139–159`, `PhotoViewer.swift:302`,
  `MonthTowerView`'s month menu. A `Menu` owns its own press handling and cannot
  hold a `Button`; `GlassIconLabel` already exists for exactly this
  (`GlassIconButton.swift:47`). A `ButtonStyle` will not reach them — see §1.3.

#### E. Disabled — four different answers

Six `.disabled(…)` sites, four treatments:

1. `HeadMakerView.swift:394` — SwiftUI's automatic environment dim. The comment
   at `:388` measured it: the white block "came out at 128 of 255", so the file
   works around it by keeping `lit` true during capture. **This is the evidence
   that `.plain` does dim on disable**, and that the dim is unmanaged.
2. `AddWinSheet.swift:318–319` — explicit `foregroundStyle(canSave ? accentWarm
   : inkQuiet)` *on top of* the automatic dim, so the disabled Add is dimmed
   twice.
3. `OnboardingView.swift:517–531` — a deliberately different pill: ink type on a
   12%-ink capsule, with a comment explaining that fading the whole control took
   the label to near-white. The right answer, arrived at once, privately.
4. `PhotoViewer.swift:318`, `SettingsView.swift:246/298` — menu and form rows,
   system dim.

### 1.2 The one press behaviour

One `ButtonStyle`, `StrataPress`, in a new `Strata/Views/StrataPress.swift`.
Every value in it already exists in `GridConstants`; nothing new is invented.

```
scale        0.96, uniform, from the centre
down curve   GridConstants.tapSquashSpring   spring(duration: 0.06, bounce: 0.0)
up curve     GridConstants.snapBack          spring(duration: 0.22, bounce: 0.20)
opacity      unchanged while pressed
disabled     label at 0.40 opacity, no press response
haptic       HapticsEngine.lightTap() on COMMIT (see below)
hit shape    .contentShape(Rectangle()) over the whole label
```

**Why 0.96 and not something new.** It is what the tower slot already does
(`NextSlotButton.swift:52`, `1 - abs(charge) * 0.04`), it is the value the site's
own reference lands on (`apple-design.md` §1, `scale(0.97)`), and it is the only
press scale in the app that is uniform — the slot's comment at `:44` records that
a non-uniform squash was tried on the slot and removed because the element
stopped lining up with its cell. The block's mass-scaled squash is not a
counter-example; it is the exception in §1.4.

**Why `tapSquashSpring` down.** `bounce: 0.0` is critically damped, which is
`apple-design.md` §4's stated default: "Start most UI at damping 1.0." 0.06 s
response is below the perception threshold, so the control is already down by
the time the finger registers it — which is the whole of §1.

**Why `snapBack` up, and why bounce is earned there.** §4 again: "Add bounce only
when the gesture itself carried momentum." A lift is a release of the stored
compression, which is momentum the user supplied. `snapBack` is
`spring(duration: 0.22, bounce: 0.20)` and it is **numerically identical** to
`tapPopSpring`, which the tower block already uses for exactly this moment
(`FlippableBlockView.swift:227`). Two names for one curve; collapse them and keep
`snapBack`, noting the merge in `GridConstants`.

**Why the haptic stays on commit.** This is the one place I am not following
`apple-design.md` §1 literally, and the reason is §13's causality rule, which is
in the same document. A haptic says *it happened*. A press the user slides off
and cancels did not happen, and buzzing it would be a lie the visual does not
tell. So: **the visual responds on pointer-down; the haptic fires on commit.**
The style owns both, so the call sites stop carrying `HapticsEngine.lightTap()`
in their action closures and the nine buttons that currently fire nothing start
agreeing with the other thirty-eight.

The exception inside the exception: the slot and the shutter fire `tick()` on
pointer-down and keep it. There the press is not a button press, it is the start
of a continuous gesture that draws a size — the down IS a causal event, because
something began.

**Interruptibility.** A `ButtonStyle` driving `.scaleEffect` off
`configuration.isPressed` with `.animation(_:value:)` is interruptible by
construction: SwiftUI re-targets from the presentation value, so a press during
the release spring picks the scale up wherever it is. That is `apple-design.md`
§3 satisfied for free, and it is the reason to do this as a style rather than as
a `phaseAnimator` (which the block uses, and which cannot be interrupted —
`FlippableBlockView.swift:219`).

**Reduced motion.** `@Environment(\.accessibilityReduceMotion)`: drop the scale,
keep a 0.90 opacity dip on `GridConstants.motionReduced`
(`easeOut(duration: 0.05)`). `apple-design.md` §14 — reduced motion means a
gentler equivalent, not no feedback.

Sketch:

```swift
struct StrataPress: ButtonStyle {
    /// Off for controls that paint their own disabled state
    /// (the onboarding pill, the head maker's shutter).
    var dimsWhenDisabled = true
    /// Off where Liquid Glass already deforms — see §5.2 capture C1.
    var scales = true
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(scales && !reduceMotion && configuration.isPressed
                         ? GridConstants.pressScale : 1)
            .opacity(pressOpacity(configuration))
            .contentShape(Rectangle())
            .animation(configuration.isPressed
                       ? GridConstants.tapSquashSpring
                       : GridConstants.snapBack,
                       value: configuration.isPressed)
    }
}

extension View {
    /// The app's press. Replaces `.buttonStyle(.plain)` everywhere.
    func strataPress(scales: Bool = true, dimsWhenDisabled: Bool = true) -> some View
}
```

Two new `GridConstants` entries, in the tap section beside `tapSquashSpring`
(`GridConstants.swift:214`):

```swift
/// The app's one press scale. Uniform and never above 1 — see NextSlotButton.
static let pressScale: CGFloat = 0.96
/// What a disabled control's label drops to.
static let disabledOpacity: Double = 0.40
```

And delete `tapPopSpring` (`:215`) in favour of `snapBack` (`:255`), or keep the
name as an alias with a comment saying they are one curve.

### 1.3 Call sites to convert

Mechanical: replace `.buttonStyle(.plain)` with `.strataPress()` and delete the
`HapticsEngine.*()` line from the action closure. Where no `.buttonStyle` is
present, add `.strataPress()`.

Straight swap — `.buttonStyle(.plain)` → `.strataPress()`:

`AlbumCarousel.swift:42` · `PhotoGalleryGrid.swift:120` ·
`AddWinSheet.swift:438` `:487` · `MemoriesMapView.swift:555` ·
`PlanItemDetailSheet.swift:105` `:144` · `ProfileAvatar.swift:81` ·
`GlassIconButton.swift:40` (see C1) · `HeadLookPicker.swift:66` ·
`PhotoViewer.swift:302` · `HeadSticker.swift:329` · `MonthTowerView.swift:111` ·
`CameraView.swift:450` `:496` `:932` `:1018` · `HeadMakerView.swift:312` `:349`
`:466` · `ReplayView.swift:306` `:502` · `MemoriesView.swift:534` ·
`OnboardingView.swift:428` · `ReplayShelf.swift:56` · `FilmLookStrip.swift:78` ·
`ProfileView.swift:165` `:217` · `PlanSheet.swift:224` `:268`

Add where absent: `AddWinSheet.swift:305` `:315` · `SettingsView.swift:212`
`:216` `:264` `:287` `:301` `:356` `:394` `:449` · `PlanSheet.swift:91` `:110`
`:201` · `ProfileView.swift:496` `:548` `:559` `:609` · `MainAppView.swift:858`
· `MemoriesView.swift:515` · `MemoriesMapView.swift:533` ·
`CameraView.swift:398` `:439` `:479` `:921` `:1001` · `HeadMakerView.swift:302`
`:337` `:440` `:452` · `OnboardingView.swift:417`.

With the special forms:

- `HeadMakerView.swift:387` — `.strataPress(dimsWhenDisabled: false)`. The
  measured problem at `:388` (128 of 255) is exactly this, and the fill at `:381`
  already paints its own disabled state.
- `OnboardingView.swift:534` — `.strataPress(dimsWhenDisabled: false)`. Same
  reason, written out at `:515`.
- `AddWinSheet.swift:318` — drop the double treatment: keep the explicit
  `foregroundStyle` or the style's dim, not both.
- `MonthTowerView.swift:111` and `MemoriesMapView.swift:555` — these wrap a
  `BlockSurface`. Verify the 0.96 does not fight the photo handover; capture C4.
- The `Menu` labels (`ProfileView.swift:139–159`, `PhotoViewer.swift:302`,
  `MonthTowerView`'s month menu) cannot take a `ButtonStyle`. Give
  `GlassIconLabel` an optional `isPressed`-driven scale and drive it from a
  `.onLongPressGesture(minimumDuration: 0, pressing:)` — or accept that menus
  keep the system's own press, which is the cheaper and more defensible answer.
  Decide after C1.

### 1.4 The exceptions that earn a difference

Four, and no more.

1. **The tower block's squash** (`FlippableBlockView.swift:218–228`). Mass-scaled
   — a 2×2 squashes less than a 1×1 — because a block is an object with mass and
   that is the app's identity. Keep the values. **One change:** it fires on tap
   completion through a `phaseAnimator(trigger:)`, so it is neither on
   pointer-down nor interruptible. Convert to a `ButtonStyle` variant
   (`StrataPress(blockMass: massTier)`) or to `isPressed` state, so the squash is
   under the finger and the pop is the lift. Same curves, same numbers.
2. **The shutter** (`CameraView.swift:1248`). The 0.86 squash is tied to *the
   picture being taken*, which is the causal event, and it must stay there —
   including seconds later at the end of a countdown. But it must **also**
   respond on pointer-down: add the standard 0.96 on `shutterDown`
   (`CameraView.swift:1095`), which is already set. Two scales, two events, both
   honest.
3. **The next slot** (`NextSlotButton.swift`). Not a button — a continuous
   draw gesture with a size, a colour preview and a recess that deepen under the
   finger. It is the control the shared style is copied *from*; leave it.
4. **The drawer handle** (`MemoriesDrawer.swift:115`). A drag with projection and
   rubber-banding. Not a press.

Everything else — including the shutter *button* in the head maker, the album
cards, the gallery thumbnails, the map blocks, the month blocks and all 11
`GlassIconButton`s — is the one press.

---

## 2. Transitions

### 2.1 The test

For each: (a) is anything visible *through* the middle of the handover, (b) does
it have both an in and an out, (c) is it interruptible, (d) does its timing come
from a `GridConstants` token.

The app already knows the answer to (a) and has written it down four times:

> "A crossfade must never reveal what is under it. `.transition(.opacity)` on one
> slot fades both copies through partial alpha at once, the pair composites to
> less than opaque, and the substrate shows through the middle of the handover."
> — CLAUDE.md

The working pattern, three times in the tree, is **two slots**: hold the outgoing
layer at full opacity underneath, bring the incoming one up on top, then swap.
`CachedImageView.swift:78–97`, `MonthTowerView.swift:188–232`,
`MemoriesMapView.swift:889–900`. Copy it; do not re-derive it.

### 2.2 Violations, with the smallest fix

**V1 — the tower's loading skeleton crossfades into the real blocks.**
`MainAppView.swift:2277–2279` picks `skeletonGrid` or the blocks off
`towerVM.isLoading`. `TowerViewModel.swift:279` flips `isLoading = false` inside
`withAnimation(GridConstants.layoutReflow)` (`MainAppView.swift:1300`), a 0.55 s
spring. The skeleton leaves on `.transition(.opacity)`
(`MainAppView.swift:2396`); the real blocks arrive on
`.opacity.animation(towerBlockFadeIn)` — `easeOut(0.2)`, staggered
(`MainAppView.swift:2768`). Two partially transparent layers, in the same cells,
for most of half a second, and the skeleton is a shimmering 10 % ink rect
(`SkeletonBlockView.swift:11`) so it muddies every block's colour as it goes.
Both (a) and (b) fail; (d) passes on both halves separately, which is how it got
here.
*Fix:* hold the skeleton at full opacity under the blocks and remove it only
after the blocks are opaque — `.transition(.identity)` on the skeleton plus an
explicit removal a beat after `isLoading` clears, exactly as
`CachedImageView.swift:87` does with `holdsPlaceholder`. `stopSkeletonBuildUp()`
(`MainAppView.swift:1289`) already has the hook.
**S.**

**V2 — the camera's review layer crossfades with the controls over a live
viewfinder.** `CameraView.swift:1291` sets `review` inside
`withAnimation(GridConstants.gentleReveal)`. The review inserts on
`.transition(.opacity)` (`CameraView.swift:257`) while the controls fade out via
`.opacity(review == nil ? 1 : 0)` (`CameraView.swift:246`) on the same spring.
Through the middle: the photograph at ~50 %, the camera controls at ~50 %, and
the moving viewfinder behind both. This is the clearest case in the app of "an
animation where I can still see the previous thing", and it is on the path of
every photographed win.
*Fix:* make the review opaque from its first frame — no insertion transition on
the layer, a full-bleed opaque backing — and drop the controls under it rather
than fading them (`.opacity` → remove, or keep them at 1 and let the opaque
review cover them). Reverse on the way out.
**S.**

**V3 — the month tower crossfades one month through another, and the page below
jumps.** `MemoriesView.swift:620–622`: `.id(vm.monthTitle)` + `.transition(
.opacity)`, driven by `withAnimation(GridConstants.crossFade)` at
`MemoriesView.swift:573` (`easeInOut 0.2`). Two problems. (a) Both months' blocks
pass through partial alpha at once, so for 0.2 s you see September's arrangement
ghosting through October's — different blocks, different colours, different
packing. (b) An `.id()` swap is a remove plus an insert, and both views occupy
the `LazyVStack` during the overlap, so everything below (the replay shelf, the
albums, the whole gallery) is displaced by a tower height and snaps back.
*Fix:* two slots for the tower as well — keep the outgoing month opaque
underneath in a fixed-height container, bring the new one up on top, swap. The
container's height must be reserved so the page below cannot move. The comment
at `:621` is right that a cross-fade is the correct *idea* ("a spring would claim
the blocks travelled somewhere"); it is the symmetric implementation that is
wrong.
**M** — needs the container height solved. See capture C5 for whether the page
below actually jumps, which I cannot tell from source.

**V4 — the photo viewer's zoom lands on black, then fades the picture in.**
`MemoriesView.swift:290` presents `PhotoViewer` in a `.fullScreenCover` with
`.navigationTransition(.zoom(sourceID:in:))`. Inside, `PhotoViewer.swift:666–686`
is `ZStack { Color.black; if let image { … .transition(.opacity) } }` with
`.animation(GridConstants.gentleReveal, value: image != nil)`. So the zoom morph
carries the thumbnail out to full size and arrives at a **black rectangle**, and
the photograph then fades in over it. The thumbnail you tapped is visibly gone
before its replacement exists, which is the failure the owner described in a
different place ("it shows the colored block behind it") and which
`MemoriesMapView.swift:889` already fixed for the map.
*Fix:* open on something that is already there. `PlaceBlock.body`
(`MemoriesMapView.swift:936–943`) is the model: if the asked-for decode is not
ready, put up the one that is. Here the thumbnail is by definition already
decoded — seed the viewer with it and hand over to the full-size image on the two-
slot pattern. Same treatment for `ReplayView`'s zoom out of its card
(`MemoriesView.swift:303–311`).
**M.** Confirm with capture C2 — if the decode is always inside one frame this is
invisible and should drop down the list.

**V5 — the tab switch cross-dissolves a dark screen into a light one while the
window scheme has already snapped.** `MainAppView.swift:641–648` updates
`windowScheme` inside a transaction with `disablesAnimations = true` — correct,
and the reasoning at `:620–640` is sound. But `TabView` still cross-dissolves the
two tabs' content, so leaving the camera you get the near-black viewfinder
showing through the off-white tower for the duration of the dissolve, with the
status bar and the tab bar already in their new scheme. Compounded by the known,
documented, accepted cost at `:660–678`: the Liquid Glass tab bar keeps the
camera's dark sample (measured 0.341 against 0.956).
*Fix:* none that is cheap. The tab bar half is already ruled out in writing
(`.id` fixes the glass and breaks `selection`). The dissolve half could be
covered by an opaque ground under each tab's content so nothing composites
through, which is a one-line background and worth trying.
**S to try, L to solve.** Capture C3 decides whether it is visible enough to
spend on.

**V6 — `AddWinSheet.swift:126` and `SettingsView.swift:143`, rows that appear
with `.opacity.combined(with: .move(edge: .top))`.** They slide down out of the
row above and fade, over whatever the form is drawing. In and out are symmetric
(good, `apple-design.md` §7), timing inherits whatever the caller's
`withAnimation` supplies — so (d) depends on the call site and I could not trace
every one. Low severity: a form row over a flat ground, not over content.
*Fix:* none needed beyond pinning the driving animation to a token.
**S.**

**V7 — `MainAppView.swift:883`, the Your Week / Your Month pill's
`.transition(.opacity)`.** The pill appears and disappears as the period changes.
Symmetric fade over the header's ground; harmless in isolation, but it is a glass
capsule, and a glass surface fading its opacity reads as a sheet of plastic
rather than a material arriving. `apple-design.md` §12: "Materialize, don't just
fade — animate blur radius and scale together."
*Fix:* `.scale(0.92).combined(with: .opacity)` anchored on its own trailing edge,
so it grows out of the header rather than appearing on it.
**S.**

### 2.3 What is already right — do not "fix" these

Listed so a later pass does not undo work that was measured.

- `CachedImageView.swift:78–97` — placeholder held at full opacity, picture
  fades in on top, placeholder removed with `.transition(.identity)`. The
  reference implementation.
- `MonthTowerView.swift:188–232` — two slots for the per-day slideshow, with the
  reasoning written out.
- `MemoriesMapView.swift:889–900` and `:936–943` — two slots for the map block's
  photo cycle, plus "open on something that is already there".
- `MemoriesMapView.swift:395–430` — the block handover on zoom. Nothing is kept
  to leave; the old set is held *unmoved and opaque* for 110 ms while MapKit
  makes the new views, then removed with animations disabled. This is the
  hardest transition in the app and it is solved.
- `MainAppView.swift:2765–2770` — a newly dropped block gets `.identity`, not a
  fade, because the fall is its entrance. Correct, and the comment records the
  bug that fading it caused.
- `MemoriesDrawer.swift:115–136` — momentum projection (`§6`), rubber-banding
  (`§9`), `naturalSettle` on release, `nil` animation while dragging so the panel
  tracks 1:1 (`§2`), and a haptic only when the detent actually changed. This is
  the best-behaved gesture in the app; it is the model for anything new.
- `ReplayView` — the whole replay is a pure function of time
  (`ReplayScript`), drawn in a `TimelineView`, with no `withAnimation` anywhere.
  Nothing to audit; do not add a transition to it.
- `MainAppView.swift:1235–1295` — the skeleton's 100 ms grace and 300 ms hold,
  and the decision to bring it up as one object rather than eight popping blocks.
  Keep both; V1 is about its exit only.
- `CameraView.swift:658` (the focus reticle contracting onto the point) and
  `:939` (the zoom pill growing out of the shutter's line). Both are
  `apple-design.md` §7's anchored origin, done deliberately.

### 2.4 The five a person actually notices

In order:

1. **V1**, the tower skeleton. Every cold launch, on the home tab, on the app's
   signature object.
2. **V2**, the camera review. Every photographed win.
3. **V3**, the month swap. The Memories drawer's primary control.
4. **V4**, the photo viewer opening onto black. The most ceremonial transition in
   the app, and the one that most has to land.
5. **The absence of any press response on 34 controls** (§1). Not a transition,
   but it is the single thing most responsible for "buttons should feel one way",
   and it is felt on every tap rather than at four moments.

---

## 3. Layering

### 3.1 The z-order the app should have

Six bands. Everything in the app belongs to exactly one, and within a band,
declaration order decides.

| # | Band | What is in it | Rule |
| --- | --- | --- | --- |
| 0 | **Ground** | the map tiles, `WarmBackground`, the camera preview, `Color.black` in the viewer | never casts, never receives a shadow; always opaque |
| 1 | **Content** | tower blocks, map blocks, month blocks, gallery thumbnails, the photograph in the viewer | the only things that cast a shadow (see 3.3); ordered *within* the band by the tie rules below |
| 2 | **Scrim** | the map's `warmBlack` wash (`MemoriesMapView.swift:294`), the map title's legibility gradient (`MemoriesView.swift:116`), the Memories scroll-edge fade (`MemoriesView.swift:264`) | always `.allowsHitTesting(false)`; sits between content and chrome so chrome is never washed |
| 3 | **Floating chrome** | `GlassIconButton`s, the glass capsules, the recentre control, the map title, the camera's controls, the tab bar | translucent, never shadowed, always above every scrim |
| 4 | **Overlays** | the drawer, sheets, full-screen covers, the photo viewer, the replay | opaque or scrimmed; covers band 3 entirely rather than competing with it |
| 5 | **Alerts** | system alerts and confirmation dialogs | system-owned |

Two rules that fall out and are worth stating:

- **A scrim belongs to the thing it is darkening, not to the thing it is
  protecting.** The map's wash is applied to the map (`MemoriesMapView.swift:294`)
  and the title's gradient is a `.background` of the title row
  (`MemoriesView.swift:116`) — both correct. A scrim applied as an overlay of the
  *whole screen* would wash the chrome too.
- **Translucency does not stack.** `apple-design.md` §12: "Never stack a light
  translucent surface on another — legibility collapses." Audited: the only place
  two translucent layers meet is a `GlassIconButton` over the map's scrim, and
  the scrim is a solid-colour wash rather than a material, so it is fine. The
  drawer's panel is `WarmBackground`, opaque — also fine.

### 3.2 What the code does today

**Only four `zIndex` calls exist in the whole app.**

- `MainAppView.swift:2760` — `animState.dropPhase != nil ? 100 : Double(block.row + 1)`.
  A falling block goes above everything; otherwise higher rows draw over lower.
  Correct, and load-bearing twice over: the comment at `:2753` records that this
  `zIndex` read is the *only* reason the drop phases render at all, because it
  forces the grid to re-evaluate past the `Equatable` child.
- `PhotoViewer.swift:578` — `distance < 0.5 ? 1 : 0`, the current page above its
  neighbours in the deck. Correct.
- `MemoriesView.swift:594` — the month picker above the month tower, with the
  measured frames in the comment (`{17, 120, 182, 242}` swallowing
  `{18, 136.7, 44, 44}`). This is CLAUDE.md's recorded bug, fixed, and the
  comment correctly says it is kept as a belt even though the picker now sits
  outside the clipping scroll view.
- `MemoriesMapView.swift` — **none.** The map's ordering is entirely implicit in
  declaration order, which is documented at `:241–250` ("Last, so it is never
  underneath a block") but not enforced.

**Where zIndex is missing and the hazard is real:**

- Anything the app draws with `.offset` above a control. The month tower is the
  one that bit; the same shape exists in `MainAppView.swift:2760`'s grid (blocks
  offset over the header area) and it is currently held by the row-index zIndex
  rather than by an explicit band. If a new floating control is ever put over the
  tower, it will be swallowed the same way. **Give the six bands names in
  `GridConstants` and use them** rather than bare numbers:
  `zGround 0 · zContent 100 · zScrim 200 · zChrome 300 · zOverlay 400`.
  `MainAppView.swift:2760`'s `Double(block.row + 1)` then becomes
  `zContent + Double(block.row + 1)` and `100` becomes `zContent + 99`, which
  also removes the collision between a row-1000 tower and the magic `100`.
- `MemoriesView.swift:95–152` — the ZStack is map / title / drawer. The title is
  band 3 and the drawer is band 4, so declaration order is right, and the comment
  at `:101` reasons about it correctly. But it is three siblings with no z
  declared; one reordered line breaks it silently.

**Where a shadow implies the wrong depth.** CLAUDE.md is explicit: "The blocks
are the identity; chrome is not. Do not give cards, sheets or form wells a white
rim, a frosted band or a blurred edge." The shadow audit against the six bands:

| Site | Band | Verdict |
| --- | --- | --- |
| `FlippableBlockView.swift:115`, `MergedGroupView.swift:89`, `BlockChrome.swift:129`, `MainAppView.swift:3007`, `MonthTowerView.swift:105`, `TowerWidgetView.swift:136` | 1 | correct — content |
| `MainAppView.swift:3064` (drop-only), `:3265` (fly-away) | 1 | correct — motion |
| `BlockContent.swift:99` | 1 | a text shadow on a block's title over a photograph. Legibility, not depth. Fine. |
| `CameraView.swift:760` `:973` `:1014` `:1373`, `HeadMakerView.swift:198` `:217` `:284` `:345` | 3 | **eight chrome shadows at 0.35–0.40.** These are glyph/ink shadows over a viewfinder, so they are legibility, same argument as `BlockContent`. But `GlassIconButton` over the same viewfinder has none, so two controls on one screen separate from the ground two different ways. Unify: chrome over an image gets the glass, not a drop shadow. |
| `CameraView.swift:238` | 3 | the countdown numeral's shadow. Legibility. Keep. |
| `MemoriesDrawer.swift:90` | 4 | `shadowOpacity 0.10`, radius 12, y −2. An overlay separating from the ground it covers. The comment at `:22` pre-empts the objection ("a shadow is not a rim") and is right. Keep. |
| `OnboardingView.swift:384` | — | 0.10, radius 14, y 6. Check what it is under; likely band 1. |

### 3.3 The map

This is what the owner asked to be backed by research and results, so it is
argued from the code's own measurements and from `apple-design.md`, and the
ordering is stated as a rule rather than as a list.

**The principle.** A map has one job the app cannot do for it: say *where*. Every
layer is ranked by how badly its loss breaks that. The user's own position
outranks everything, because a map with no "you" is a picture. Then the user's
own data, because that is why this map exists and not Apple Maps. Then the
controls that move the map, because a map you cannot re-aim is a screenshot.
Then the map's own labels, which are context. Then the things the licence
requires.

**The order, bottom to top:**

| | Layer | Why here |
| --- | --- | --- |
| 1 | **Tiles** (`MemoriesMapView.swift:258`) | the ground. Imagery by the owner's 2026-09-10 call. |
| 2 | **MapKit's place names, road shields, POIs** | context. They are earned at zoom ≥ 13 (`:606`, `labelZoom`) and muted below it — already the right policy, and it is why they sit *under* the user's own content rather than competing with it. |
| 3 | **The scrim** (`:294`, 0.10 → 0.03 at `labelZoom`) | it darkens 1 and 2 and nothing above. The lift as labels arrive is correct: `apple-design.md` §12's "a wash over type is the one thing that makes a map feel cheap", and the code says so at `:296`. |
| 4 | **Photo blocks** (`:238`) | the user's own data; the only saturated objects on the screen, by the measured decision at CLAUDE.md ("the blocks are the saturated objects and the ground's job is to be quiet under them"). Above every label: a place name is replaceable context, a photograph of your own win is not. |
| 5 | **The count badge** (`:1049–1057`) | belongs to its block, drawn as its overlay, so it rides with it by construction. |
| 6 | **The head marker / user dot** (`:250–257`) | above every block. The comment at `:241` has the argument and it is correct: "stand where you have already photographed something and the marker for where you are went behind the picture of where you were. A player marker is the one thing on a map that is always on top." |
| 7 | **The map title** (`MemoriesView.swift:111–115`) and its legibility gradient (`:130`) | chrome. Above content because it names the screen; below the drawer because at `.full` you are looking at photographs. Already reasoned at `:101`. |
| 8 | **The recentre control** (`MemoriesMapView.swift:162`) | chrome, and the one control that fixes a lost user. Above everything on the map. |
| 9 | **Apple's attribution** (`:283`, inset by `tabBarClearance − 22`) | last, and non-negotiable — it cannot be removed or positioned, only inset. Nothing may cover it. |
| 10 | **The drawer** (`MemoriesView.swift:152`) | band 4; covers 7 and 8 entirely when raised. |

**The tie rule when blocks overlap each other.** The code already has two, and
they are different, and that is correct rather than a bug — but only one of them
is written down.

- **Merging (which blocks exist at all): busiest wins.** `PlaceMap.swift:325–330`,
  `busier(_:_:)` — more wins first, then newer, then id. A group that covers
  another by more than `maxOverlap` (`PlaceMap.swift:110`, one third) is absorbed
  into the busier one, which becomes the host. Right, and it is the same
  reasoning as "thinning a crowded map means going coarser".
- **Drawing (what is on top of the residual overlap): newest wins.**
  `PlaceMap.swift:378` returns `.sorted { ($0.newest, $0.id) < ($1.newest, $1.id) }`
  — oldest first, so newest is declared last and MapKit draws it on top. The
  doc comment at `:23` names this ("stacked newest on top") and it is the right
  answer: two places that survived the merge are genuinely two places, and the
  one you were at most recently is the one you are most likely to be looking for.

So: **busiest wins the merge, newest wins the draw, and the user's own position
wins everything.** That is the rule for ties, and it should be stated once in
`PlaceMap`'s header rather than discovered from a `sorted` at line 378.

**Blocks over a label.** The block always wins (layer 4 over layer 2). The reason
is not aesthetic: the map's label policy at `:673–700` already excludes every POI
below `labelZoom` and curates landmarks only above it, because "the map named
every sandwich shop in central London and buried the only thing on screen that
was the user's". Having paid for that, letting a place name occlude a photo block
would give it back.

**What is missing.** Nothing in the map's z-order is *declared*. It is ten layers
held up by the order of ten lines across two files. One reordered `ForEach`, one
moved `.overlay`, and the head marker goes back under the blocks — a bug the
comment at `:241` says has already happened once. **Add the band constants and
apply them**; the ordering does not change, but it stops being an accident.

---

## 4. The ten changes, in priority order

| # | Change | § | Effort | Risk |
| --- | --- | --- | --- | --- |
| 1 | `StrataPress` `ButtonStyle` + the two `GridConstants` tokens; convert the 34 `.plain` sites and add it to the ~30 with no style | 1.2, 1.3 | **M** | Low mechanically; **medium** on the four §1.4 exceptions and on the `Menu` labels, which cannot take a style. Convert in file-sized commits, not one sweep. |
| 2 | V1 — hold the skeleton opaque under the blocks | 2.2 | **S** | Low. `stopSkeletonBuildUp()` already has the hook; the pattern is `CachedImageView.swift:87`. Watch `MainAppView.body`'s type-checker ceiling — put it in a `ViewModifier`. |
| 3 | V2 — the camera review arrives opaque, controls drop under it | 2.2 | **S** | Low. Touches one ZStack. |
| 4 | Move the shutter's press response to pointer-down (keep the capture squash) | 1.4 | **S** | Low. `shutterDown` already exists at `CameraView.swift:1095`. |
| 5 | The block's squash on `isPressed` instead of `phaseAnimator(trigger:)` | 1.4 | **M** | **High.** `AnimatedBlockView` is `View, Equatable` and CLAUDE.md records the `Equatable` trap striking four times. Anything new the block view reacts to must be added to `==`, and press state is per-block. Do this last of the button work, with the film. |
| 6 | V3 — two slots for the month swap, with the height reserved | 2.2 | **M** | Medium. The container height is the whole problem; get C5 first. |
| 7 | Band constants (`zGround`…`zOverlay`) in `GridConstants`; apply to `MainAppView.swift:2760`, `MemoriesView.swift:95–152`, and the map's ten layers | 3.2, 3.3 | **S** | Low. No visual change intended — which is also the test: a before/after screenshot pair must be byte-identical. |
| 8 | V4 — the photo viewer opens on the thumbnail it came out of | 2.2 | **M** | Medium. Confirm with C2 first; if the decode is inside one frame, drop this to #11. |
| 9 | Collapse the three glass helpers into `glassCapsule()`; unify chrome-over-image separation (glass, not the eight 0.35 drop shadows) | 1.1C, 3.2 | **S** | Low, but it changes the camera and head maker's look. Owner's call, with a pair of frames. |
| 10 | Write the nine missing haptics (they arrive free with #1) and the one rule — visual on down, haptic on commit — into `docs/design-system.md` §5 | 1.2 | **S** | None. |

Deliberately **not** on the list: V5 (the tab dissolve) until C3 says it is
visible; V6 and V7, which are real but small; and anything in §2.3.

---

## 5. How to verify

### 5.1 The numeric bar

Each change gets a number that can fail, not an adjective.

- **A handover is clean when no frame has two layers both below full opacity.**
  Practically: extract frames, and for the pixel at the centre of the handing-over
  element, no frame may show a colour that is a blend of the outgoing and
  incoming layers *and* of the substrate. The cheap version, which is what the
  map's own bug was found with: sample the block's centre every frame and assert
  it is never within 10 % of the substrate's colour. For V1 the substrate is the
  page ground; for V2 the live viewfinder; for V3 the page ground; for V4 black.
- **A press is on time when the first frame after touch-down already shows
  movement.** At 60 fps, `tapSquashSpring` (0.06 s) is ~3.6 frames to settle, so
  frame 1 must be measurably below 1.0 scale and frame 4 must be at 0.96 ± 0.005.
- **A press is consistent when every control measures the same scale.** Film ten
  different controls' press frames and assert the ratio of pressed to unpressed
  bounding-box width is 0.96 ± 0.01 for all of them.
- **A move is smooth when no two consecutive frames step more than 8 pt.** The
  replay's corridor work already uses this bar (CLAUDE.md records a 21 pt step as
  the failure), so it is the house number. Apply it to V3's page-below jump: the
  content under the month tower must never move more than 0 pt.
- **Layer order is right when a probe pixel belongs to the layer it should.**
  For the map: place the head marker's coordinate inside a block's footprint
  (`-strataTestLocation`) and assert the pixel at the marker's centre is the
  marker's colour, not the photograph's.

### 5.2 The captures I need

I could not open a single frame. These are the ones that decide something I
cannot decide from source. Each says the flag, the device, what to watch, and the
number.

**C1 — does Liquid Glass's `.interactive()` press already read as a press, and
does a 0.96 scale on top of it read as one gesture or two?**
Flag: any screen with a `GlassIconButton` — `-strataOpenPhoto 0` is easiest
(the close button, white on black). Device: an **iOS 26** simulator *and* an
**iOS 18** one, because the fallback path has no press at all and that is half
the question. What to watch: the close button under a sustained press.
Test: on iOS 26, measure the glyph's bounding box pressed vs. unpressed. If the
glass already moves it by more than 2 %, `StrataPress` should pass
`scales: false` on iOS 26 and `scales: true` below; if it moves it by less than
1 %, scale on both. This decides `GlassIconButton.swift:40` and all 11 call
sites.

**C2 — does the photo viewer's zoom land on black?**
Flag: `-strataStartTab memories -strataSeedHistory 30 -strataOpenPhoto 0`, and
separately by tapping a thumbnail if a run can drive it. Device: whichever is
free, but the slowest one available — the whole question is decode latency.
What to watch: the 6–10 frames after the thumbnail starts to grow.
Test: count frames in which the centre pixel of the growing rectangle is black
(`< 8/255` in all channels). **Zero frames = V4 is invisible, drop it to #11.
One or more = build it.** Start the capture before the tap; CLAUDE.md records a
burst that returned 46 identical frames because it slept first.

**C3 — how visible is the camera→tower tab dissolve?**
Flag: `-strataStartTab camera -strataFlipTabs 4 -strataFlipTo tower
-strataFlipEvery 3`. Device: any.
What to watch: the frames between the camera going and the tower arriving.
Test: sample mean luminance of the full frame across the dissolve. The camera is
~9 and the tower page ~207 (CLAUDE.md's own measured numbers). If the curve is
monotonic, this is an ordinary cross-dissolve and V5 stays off the list. If any
frame shows the *tower's* geometry at a luminance below 100 — the dark
viewfinder showing through the light page — it is the artefact and V5 goes on.
Also read the tab bar's own luminance at the end of the run against the 0.341 /
0.956 pair already recorded.

**C4 — does a 0.96 press scale fight the map and month blocks' photo handover?**
Flag: `-strataOpenMap -strataSeedPlaces -strataMapStyle satellite`, and
`-strataStartTab memories -strataOpenDrawer full`. Device: **1512×850**, because
that is the size CLAUDE.md records as showing map defects that 1440×900 hides.
What to watch: press and hold a block while its picture is cycling.
Test: no frame may show the block's flat colour or `waitingFill` at its edges.
If the scale re-triggers a decode at a new width, `CachedImageView`'s cache key
is being missed — `[PERF]` with `-strataPerfProbe` will show the body count rise.
This decides whether `MonthTowerView.swift:111` and
`MemoriesMapView.swift:555` get `strataPress()` or `strataPress(scales: false)`.

**C5 — does the page below the month tower jump when the month changes?**
Flag: `-strataStartTab memories -strataSeedHistory 90 -strataOpenDrawer full`,
then step the month with `‹`. If nothing can tap, a flag that steps the month is
needed — none exists; add `-strataStepMonth n` to `DebugHarness` if the capture
agent can, or drive it from `StrataUITests` (the month picker is already
exercised by `testTheMonthPickerStepsAndStopsAtToday`).
What to watch: the vertical position of the ALBUMS heading, or of the first
gallery thumbnail, across the whole 0.2 s cross-fade.
Test: **it must not move by a single point.** If it moves, V3 is an M and the
height must be reserved; if it does not, V3 is an S and only the two-slot fade is
needed. Also count frames where both months' blocks are visible at partial alpha
— any such frame is the violation.

**C6 — the skeleton handover, before and after.**
Flag: `-strataStartTab tower -strataSeedWins 12`, capturing **from launch** with
no sleep. Device: any, but repeat on a cold launch (the skeleton has a 100 ms
grace and a 300 ms hold, so a warm launch may skip it entirely).
What to watch: the 0.5 s in which the shimmering grey rects become coloured
blocks.
Test: sample the centre of the block that lands in the bottom-left cell every
frame. Before the fix, expect frames whose colour is a blend of `slotInk` at 10 %
and the block's category colour. After, **zero such frames** — every frame is
either grey or the block's colour. This is the numeric bar for #2 and it is the
one I would most like to see both halves of.

**C7 — the camera review handover.**
Flag: the camera cannot capture on a simulator, but the review layer can be
forced: `DebugHarness.reviewPhoto` is read at `CameraView.swift:291`, so
`-strataOpenReview medium` puts it up. Device: any.
What to watch: the frames as the review arrives over the controls.
Test: sample a pixel that sits on a camera control (the flash glyph). It must go
from fully opaque glyph to fully covered with **no frame showing a blend**. Also
sample the review photograph's centre: no frame may show the viewfinder through
it.

**C8 — a press consistency sheet.**
Flags: one launch per screen — `-strataStartTab tower`,
`-strataOpenSheet add`, `-strataOpenSheet settings`, `-strataOpenSheet profile`,
`-strataOpenMap -strataSeedPlaces`, `-strataOpenPhoto 0`,
`-strataOpenHeadMaker preview`. Device: any, one is enough.
What to watch: nothing yet — this is the **before** set. Take one frame of each
screen at rest so the after-set has something to diff against.
Test: after #1 ships, drive a press on one control per screen with
`StrataUITests` (which can press for real — `TowerGestureTests` already does) and
assert the pressed bounding box is 0.96 ± 0.01 of the resting one, on every
screen. Ten screens, one number, and it is the direct answer to "buttons should
always feel one way".

### 5.3 Notes for whoever runs these

From CLAUDE.md, because each has cost this project time:

- **Start the capture before the thing you are capturing.** A burst aimed at the
  map's merge returned 46 byte-identical frames because the sweep finished during
  the `sleep` that preceded it. Every one-shot above (C2, C3, C6, C7) is exposed
  to this.
- **Allow ~16 s after launch before screenshotting anything that is not the
  launch itself** — a shorter delay catches the loading skeleton. C6 is the
  exception and wants the opposite.
- **`simctl io screenshot` samples at roughly 3 Hz.** It tells "never" from
  "sometimes"; it does not measure a duration. For C1, C6 and C7, which need
  per-frame evidence, record video and extract, or accept that a 3 Hz burst can
  only prove the artefact exists, never that it does not.
- **Classify every event and report the count, never an aggregate.** An aggregate
  frame count once looked healthy while 8 of 10 individual drops never animated.
- **`xcrun simctl launch` does not restart a running app** and silently ignores
  new arguments. Pass `--terminate-running-process`.
- **Haptics cannot be verified here at all.** Every haptic claim in §1 is a
  reading of the source, and the change in #1 — moving `lightTap` out of 38
  action closures and into the style — must be confirmed on the owner's phone
  before it is called done.
