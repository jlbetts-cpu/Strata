# Head parity: the made head up to the creator's standard

Research only. Read from `/Users/jaydenbetts/StrataWork/owner-head` at `b252e01`. Nothing built, nothing run, no simulator touched.

Owner: "make sure the head is as expressive as the head we added of me with the black and white; make sure the custom head is up to the same standards, animations, movements and the way it moves."

## Summary (ten lines)

1. There are two engines. `CreatorHead` (618 lines) runs the owner's head on the thank-you page. `LivingHeadView` (1058 lines) runs every made head. They share only `HeadTake`, the springs and the 125ms blink clock.
2. **Gap 1, the head barely moves (code).** 45% of the creator's idle beats turn the head in 3D: a turn up to 16°, and a glance with 5° of yaw. On the made head only 4% do (the turn, at 12°), and its glance only tips.
3. **Gap 2, the eyes (code, plus a rule).** The creator rests looking at you and looks away on purpose. The made head never looks at you, and its eyes move every 0.65 to 1.8s plus micro-saccades. It reads as restless, not engaged.
4. **Gap 3, blinks and face changes (mostly assets).** The creator has a shut photo for every face and brows that are the same photo. It blinks with a two-stage squash of 7 to 9%, a smile or wink pops in, and calm faces arrive behind a blink. A made head only blinks on neutral, squashes 5 to 7% (0% in chrome), and crossfades. Its shut and brows photos are separate frames, so the whole face can jump.
5. Smaller code gaps: the creator looks at something on its page (`lookTarget`, a look down at the words). Its catchlight stays still while the iris moves, and its pupil is bigger (0.55 against 0.46). Its greeting is brows then a wink, while the made head's is brows then a smile.
6. **Nothing the creator does needs a face a full capture lacks.** A user can capture neutral, shut, smile, brows, surprised and wink. The difference is quality: pixel-identical lids and brows, and a shut picture for every face. Both can be derived at make time from what is captured (§2.3), and existing heads can be migrated from their saved PNGs.
7. **Recommendation: one engine.** `LivingHeadView` becomes the only player. Idle beats become data (`HeadBeat`, like `HeadTake`), played by the same interpreter as taps. Timing comes from a seeded `HeadDirector`, and liveliness is a `HeadLife` profile. `CreatorHead` becomes a 20-line wrapper over `HeadRig.creator()`.
8. `.calm` (header, sticker button, sticker, map) stays eyes-and-brows only. `.expressive` (Profile, maker preview, onboarding head page, thank-you page) gets the creator's movement mix. Every recent fix is kept: tap owns the head, generation checks, `finishTake` keyed on the take, the stare floor for takes, no iris on a shut eye, and the incoming face underneath.
9. **One decision needs the owner:** bounded eye contact (at most 3.0s, then away) on expressive heads. The creator does it, and the made head's "never looks at you" rule forbids it. See §4.
10. Verification is measured, not judged. The same seed and the same script play on both heads. Timelines are compared exactly in unit tests, then rendered motion is compared frame by frame on a DEBUG parity page against a baseline of today's `CreatorHead` recorded before anything changes. About 11 tasks: 3 S, 6 M, 2 L.

---

## 1. Behaviour inventory

Files: `CH` = `Strata/Views/CreatorHead.swift`, `LHV` = `Strata/Views/LivingHeadView.swift`, `GC` = `Strata/Models/GridConstants.swift`, `HT` = `Strata/Models/HeadTake.swift`. Sizes on screen: thank-you creator 92pt; onboarding head page 152pt; maker preview 200pt; Profile 67pt; header and sticker button 33pt; map 52pt.

Verdict key: **missing** (the made head does not do it), **weaker** (smaller, rarer or flatter), **different** (not better or worse), **same**, **made-only** (the made head has it, the creator does not).

| Behaviour | CreatorHead | LivingHeadView (made head) | Verdict |
|---|---|---|---|
| Idle float / breathing | None, on purpose ("no breathing loop", CH:39-40). | Expressive only: roll ±0.6°, x ±1.2% of side, y ±1% of side, periods 3.7s / 2.9s repeatForever (LHV:140-151, GC:350-351). Calm: none. | made-only; continuous redraw cost (§5) |
| Resting gaze | `.zero`: **at you**. Every beat ends with `look(.zero)` (CH:65, 429, 439, 447, 457, 468, 475). | Never at you: a new rest point every 650-1800ms (expressive) or 1500-4000ms (calm), radius 0.45-0.9, y × 0.62 - 0.04 (LHV:210-226). | **different: the biggest perceptual gap in the eyes** |
| Micro-saccades | None. | Expressive: ±0.12 x, ±0.085 y every 340-1540ms (LHV:230-239). | made-only |
| Iris travel | `gaze × eye width × 0.16`, `gaze.y × eye height × 0.16` (CH:86, 105-106). | Along the eye `(w - d)/2 × 0.8`, across `h × 0.2` (LHV:936-937). For the creator rig this is also 0.16 of width. For a measured outline it is 0.15-0.20. | same |
| Iris drawing | Ellipse 0.6w × 1.05h, pupil 0.55, **catchlight fixed to the eye** ("belongs to the light", CH:570-617). | Circle `clamp(max(0.5w, 1.25h), ≤0.62w)`, pupil 0.46, **catchlight moves with the iris** (inside `IrisDisc`, LHV:949-968), despite the doc saying it "stays where the light is". Person's own iris colour. | **weaker** (catchlight is a bug; pupil smaller) |
| Blink cadence | 2.6-5.8s, calm faces only (neutral, rest), skipped while reacting (CH:317-325). | 2.6-5.8s, neutral only, needs `rig.shut` (LHV:243-270). | same |
| Blink shape | Shut + squash 0.905-0.935 → one step later squash +0.045 (a crunch and release) → 1-2 more steps. Every size (CH:329-365). | Shut + squash 0.93-0.95 **expressive only**, flat, 2-3 steps (LHV:272-281). Calm: no squash. | **weaker** |
| Double blink | 24%: open one step, shut again with squash 0.92 → 0.95 (CH:348-357). | 24%: one step, then a second full blink (LHV:264-268). | same |
| Slow blink | None. | Beat, lids down five steps, squash 0.9 → 0.93 (LHV:284-296, 479-486). | made-only |
| Lids on non-neutral faces | Every face has a closed photograph: `HeadNeutralClosed`, `HeadRestClosed`, `HeadSmileClosed`, `HeadWinkClosed` (CH:555-564). A take's `.lids` shuts any face (CH:279-281). | Only neutral has shut (`HeadRig.shut`, HeadRig.swift:67). `.lids` on another face is ignored (LHV:184, 193, 678). | **missing (asset)** |
| Blink with a gaze shift | Turn beat: 50% blink after the eyes land (CH:416-418). | Turn beat: 50% (LHV:519-521). | same, but the turn is 5x rarer on a made head |
| Beat cadence | Rest 3.5-8.0s after each beat (CH:379). First beat 1.5s, or 3.4s after a greeting (CH:376). | Expressive 3.0-7.5s, calm 7-14s (LHV:340-343). No first-beat delay beyond the rest. | same (expressive) |
| Beat mix | glance .26, turn .19, tilt .18, **smile .16**, down .12, brow .09; never twice running (CH:397-405). **Head moves in 91% of beats; yaw in 45%.** | Expressive: glance .13, smile .12, tilt .09, brow .09, sideEye .09, doubleTake .08, surprise .07, eyeRoll .07, peoplesEyebrow .07, slowBlink .07, browFlash .05, **turn .04**, wink .03 (LHV:361-364). **Head moves in ~64%; yaw in 4%.** Calm: glance .4, sideEye .3, browFlash .3, no head motion (LHV:359, 869). | **weaker: the biggest gap in movement** |
| Head turn | Eyes to `lookTarget` → 90ms → 50% blink → **yaw ±16°**, roll 3×x, lean 3pt×x, dip 1.5pt×y (at 92pt) → 380ms → eyes give back to 0.45 → hold 1.2-2.2s → eyes home → 90ms → head home → 650ms (CH:412-432). | Eyes to (dir, -0.1) → 90ms → 50% blink → **yaw ±12°**, roll 2, lean 0.03×side, **no dip** → 350ms → eyes to 0.4 → hold 1.0-1.6s → release → 90ms → head → 450ms (LHV:515-529). Random direction, no target. | **weaker** |
| Glance | Eyes (±0.5, -0.05) → 80ms → **yaw 5°**, roll 1.1°, lean 1pt → 900ms → home → 400ms (CH:433-441). | Eyes (±0.75, -0.1) and roll 1.1° together, **no yaw, no eyes-first lead** → 800ms → home → 350ms (LHV:397-404). | **weaker** |
| Tilt | Eyes ±0.1 + roll 3° → 1300ms → home → 500ms (CH:442-449). | Roll 3°, eyes keep resting → 1100 → home → 400 (LHV:405-410). | same (slightly shorter) |
| Look down / at the page | `down`: eyes (-0.2, 1) → 80ms → roll 1.2°, dip 1.5pt → 900-1500ms → home (CH:469-477). `lookTarget` points turns at the photograph (OnboardingView:396-397). | None. | **missing** |
| Brow raise | Eyes y -0.04, brows 480ms, home 460ms (CH:450-458). Brows photo = neutral with brows (IoU 0.999, owner-head-report). | Eyes y -0.15 keeping rest → 230ms → brows 480ms → 230ms (LHV:411-419). Brows photo is a separate capture aligned by eyes (HeadMakerModel:289-291). | different (asset quality) |
| Brow flash | Greeting only: 240ms up, 160ms down (CH:150-155). | Beat and greeting: 220ms (LHV:420-424). | same |
| People's Eyebrow, side-eye, eye roll, double take, surprise, idle wink | None as idle beats (they exist as taps). | All idle beats (LHV:425-514). | made-only |
| Smile (idle) | Weight .16. Eyes y -0.05, **pops in** (hard swap), hold 1.3-2.0s, back **through a blink** reopening on neutral (CH:459-468, 160-184). No head move. | Weight .12. **Crossfade** 140ms + squash 0.975, roll 2°, hold 1.3-2.0s, `settleThroughBlink` (LHV:487-494, 775-844). | different (pop vs dissolve) |
| Expression change | smile and wink pop in; calm faces are reached behind a blink (CH:172-184). Takes hard-swap every face (`wear`, CH:212-215). | Brows hard swap; everything else crossfades out on top of the incoming face with a squash (LHV:762-819). Back to neutral through a blink (LHV:823-844). | different |
| Squash on a face change | None (pop), or the blink's crunch. | Expressive 0.975 via `tapSquashSpring`, settles on `naturalSettle` (LHV:807-818). | made-only |
| Greeting | 700ms → brows 240ms → 160ms → **wink 1.6s**. Reduce Motion: wink as a face swap only (CH:139-158). Beats wait 3.4s (CH:376). | 700ms → browFlash 220ms → 250ms → **smile beat** (LHV:315-337). Reduce Motion: nothing. | different |
| Tap | 12 takes via its own interpreter (CH:193-290). Haptic `lightTap`. Yaw clamp 16°. Faces hard swap. `.lids` works on any face. `.bounce` has no generation check (CH:282-288). | Same catalogue via `play` (LHV:542-690). Tappable only through `TappableHead` (maker, onboarding head page, LHV:893-914) and the sticker (`HeadSticker.swift:250-269`, haptic `tick`). **Profile's head is not tappable**: it sits in the "Change profile picture" `Menu` label (ProfileView:161-166). Yaw clamp 12°. | different (clamp); Profile no tap by design |
| Scroll / device motion | None. | None. | same |
| Sound | None. | None. | same |
| Haptics | `lightTap` on a tap. | `lightTap` (TappableHead), `tick` (sticker). | same |
| Watchdog / leftovers | Relies on generation checks. | Blink loop watchdog restores neutral (LHV:255-261); `settleImmediately` on loop start (LHV:313). | made-only (keep) |
| Kept take / held face | None. | `held`, `keepsTake`, `gazeHeld`, `stillGaze` for the sticker (LHV:49-61, 610-632). | made-only (keep) |
| Reduce Motion | No blinks or beats. Greeting wink as a swap. **Gaze stays at `.zero`, looking straight at you for as long as the page is open.** Takes are a face swap (CH:228-234). | No blinks, beats, wander or float. Eyes rest at (0.5, 0.1). Takes are a face swap (LHV:211-213, 562-571). | different; creator breaks the no-stare rule |

### What the numbers say about "the way it moves"

At a 5.75s mean beat period (creator: 3.5-8s of rest plus about 2s of beat), the creator turns its head in 3D about **4.7 times a minute** (glance and turn, 45% of beats). The made head, at 5.25s of rest plus about 1.6s of beat, turns about **0.35 times a minute** (turn, 4%, and only if nothing is filtered out). Roughly 13x less yaw. In between, its eyes move about **80 times a minute** (wander plus micro) against the creator's roughly 12 (beats only). That is the whole shape of the complaint: the creator is a still head that looks at you and moves with intent, and the made head is a head that stays put while its eyes fidget.

---

## 2. Why they differ

### 2.1 From CODE (two engines)

| Difference | Where |
|---|---|
| Beat weights: yaw beats at 45% vs 4%; smile .16 vs .12 | CH:397-398 vs LHV:361-364 |
| `maxYaw` 16 vs 12 | CH:89 vs LHV:116 |
| Glance has no yaw and no eyes-first lead | LHV:397-404 |
| No `down` beat, no `lookTarget` parameter | LHV has neither |
| Resting gaze is always off-centre and restless | LHV:210-239 |
| Blink has no crunch, and no squash in chrome | LHV:272-281 |
| Faces crossfade instead of popping in | LHV:775-811 |
| Greeting ends on a smile, not a wink | LHV:336 |
| Catchlight rides the iris; pupil 0.46 | LHV:958-965 |
| Turn has no dip, shorter hold (1.0-1.6 vs 1.2-2.2s) and shorter return (450 vs 650ms) | LHV:522-529 |
| Float exists only on the made head | LHV:140-151 |

### 2.2 From ASSETS

| Creator asset | Made head | Effect |
|---|---|---|
| A closed photo for **every** face (9 imagesets) | One `shut.png`, the neutral blink frame (HeadStore.swift:161-162, 223) | Lids only on neutral. `sleepy`/`sideEye` lids and blinks during brows or surprise are skipped. |
| Closed = the same photo with lids painted (IoU 0.999) | Shut = a **different video frame** seconds later, aligned only by eye centres (HeadMakerModel:273-275, 305-308) | The 250-375ms blink swap can move hair, jaw, light or expression. A blink can read as a flicker, not a blink. **Not measured yet.** Task T2 measures it. |
| BrowsUp = neutral with only brows changed (IoU 0.999) | A separate capture with its own eye paint (HeadMakerModel:289-291) | The 220ms hard-swap brow flash can move the whole face and resample the iris colour. |
| Every face normalised to neutral's size (IoU 0.947-0.999, fix rounds 1-2) | Aligned by eyes only; silhouette overlap unknown | Decides whether pop-in is safe per face (§3.4). |
| "surprised" slot is the relaxed **rest** face (HeadRig.swift:52-53, 139-141) | A real surprised face, mouth open | Semantics only; no idle beat on the creator uses rest. |
| Wink: one drawn iris beside a painted shut eye (CH:560-561) | `eyes: []`, the photo's own eyes (HeadMakerModel:297-304) | The creator's wink can glance; a made wink cannot. The maker's rule (no drawn iris beside a shut eye on a real capture) stays. No action. |
| Near-black iris | The person's own iris colour | Keep. |

### 2.3 Faces a user head has, and what the creator's behaviours need

Captured by `HeadMakerModel.sequence` (HeadMakerModel:181-187) and kept only if `HeadCaptureEngine.caught` judges the expression real (HeadCaptureEngine:144-172):

| Face | Required? | Drawn irises? |
|---|---|---|
| neutral | yes (make fails without it) | yes, measured outline and iris colour |
| shut (blink) | stage required, **kept only if `isRealBlink`** | no |
| smile | optional | no (photo eyes) |
| browsUp | optional | yes |
| surprised | optional | yes |
| wink | optional | no (photo eyes) |

**Every creator behaviour maps to a face a fully captured user has.** None needs `rest` (the creator never idles on it). The gaps are per-face shut, pixel-stable lids and brows, and heads with missing captures. How to get the same feel from what is captured:

1. **Derived lids ("lid patch"), made at make time and by migration.** Composite only the eye regions of `shut.png` onto `neutral.png`. Use a feathered mask: each eye's measured outline (`HeadRig.Eye.outline`, already stored) dilated 60% and feathered over 0.012 of the canvas. Save it as the neutral face's shut. The rest of the face is then the neutral pixels, exactly as the creator's closed faces are. Apply the same patch to `browsUp` and `surprised`, which have drawn irises and measured outlines. That gives them a shut too, so blinks and `.lids` work on those faces. Smile and wink get none, the same as the creator's idle behaviour (it never blinks on a smile). All faces share one eye-aligned canvas, so existing heads can be migrated from their saved PNGs without the frames. Write new files, never overwrite originals (`neutral-shut.png`, `browsUp-shut.png`, `surprised-shut.png`) and bump the manifest to `version = 3`.
2. **Derived brows.** Composite the forehead band of `browsUp.png` onto `neutral.png`: from the crown down to the top of the upper-lid outline, minus 0.01 of the canvas, feathered over 0.02. Use neutral's eyes for the result, which is what the creator does (HeadRig.swift:134-138). The brow flash then changes brows and nothing else. Keep the raw capture as `browsUp-raw.png` in case the seam fails its measurement (§6), and fall back to it per head.
3. **A head without shut** (the blink was not judged real). No drawn or procedural lids: a painted-over eye without an iris is a blank eye, and a skin-coloured drawn lid is an uncanny partial lid (§4). It does not blink. It gets the extra head movement instead (turn and glance weights rise by the slow-blink and sleepy share). The maker should re-ask for the blink once. That is a product call for the owner, not part of this plan.
4. **A head without browsUp.** `brow`, `browFlash`, `peoplesEyebrow` and `doubleTake` are filtered out today (LHV:376-385). Substitute a **lift**: dip -0.015 of the side and eyes y -0.2 over 480ms. Posture carries the "oh, hello" of a brow raise without a face that is not there.
5. **A head without smile.** Substitute the smile beat's weight with a **nod** (the take's first three nods, no face). Warmth through motion.
6. **Neutral-only heads** still get all yaw, tilt, down, glance and contact beats. Those need no faces, so movement parity holds for every head.

---

## 3. The plan: one engine

### 3.1 Shape

```
HeadRig (faces, per-face shut, popsIn, contentHeight, chin)   <- creator is one of these
   |
HeadDirector (seeded RNG + HeadLife + rig capabilities)       <- WHAT happens WHEN (pure, testable)
   |  produces [HeadBeat.Moment] using HeadTake.Step vocabulary
LivingHeadView.run(_ moments:, kind: .beat | .take)            <- ONE interpreter, the existing play()
   |
State (expression, outgoing, shut, squash, rest, micro, beatGaze, yaw, roll, lean, dip)
```

- **`HeadLife`** (new, `Strata/Models/HeadLife.swift`): everything that differs between `.calm` and `.expressive` as data. It replaces `enum Liveliness` (LHV:40). Values are GridConstants tokens.
- **`HeadBeat`** (new, `Strata/Models/HeadBeat.swift`): the idle beats as cue lists, like `HeadTake.catalogue`. Every branch (`perform`, LHV:387-532, and CH:408-479) becomes data.
- **`HeadDirector`** (same file): a seeded generator (`SystemRandomNumberGenerator` in release, `SplitMix64` under `-strataHeadSeed`). It picks beats, rests, wander points, blink gaps, double blinks and the turn's 50% blink, and resolves each beat into concrete moments. The randomness then lives in one place, the same seed gives the same life on any rig, and the tests can read it.
- **`LivingHeadView`** keeps all state, the take machinery and every fix. Its idle loops shrink to "ask the director, run the moments". `perform` is deleted.
- **`CreatorHead`** becomes a wrapper. `HeadFace`, `HeadEye`, and its blink, beat, greet and take code are deleted.

### 3.2 Types

```swift
// Strata/Models/HeadLife.swift
nonisolated struct HeadLife: Equatable, Sendable {
    var beatWeights: [HeadBeat.ID: Double]
    var beatRest: ClosedRange<Double>            // seconds
    var firstBeatDelay: Double                   // after appear, or after the greeting ends
    var wanderEvery: ClosedRange<Double>         // seconds between fixations
    var contactShare: Double                     // 0 = never looks at you (calm)
    var contactHold: ClosedRange<Double>         // capped by GridConstants.headContactMax
    var microSaccades: Bool
    var blinkSquash: ClosedRange<CGFloat>?       // nil = no squash (calm)
    var morphSquash: Bool
    var floats: Bool
    var movesHead: Bool                          // false: pose only when `invited` (a tap)
    var maxYaw: Double

    static let calm: HeadLife
    static let expressive: HeadLife
}
```

```swift
// Strata/Models/HeadBeat.swift
nonisolated struct HeadBeat: Equatable, Sendable {
    enum ID: String, CaseIterable, Sendable {
        case glance, turn, tilt, down, brow, browFlash, lift, smile, nod,
             peoplesEyebrow, sideEye, eyeRoll, doubleTake, slowBlink, surprise, wink, hello
    }
    let id: ID
    let needs: Set<HeadRig.Expression>
    let needsShut: Bool
    let movesHead: Bool              // filtered out when HeadLife.movesHead is false
    let cues: [HeadTake.Cue]         // authored for direction +1 and target (-1, -0.5)
    let tail: TimeInterval           // the last cue to the beat's end
}

nonisolated struct HeadDirector: Sendable {
    init(life: HeadLife, faces: Set<HeadRig.Expression>, shutFaces: Set<HeadRig.Expression>,
         lookTarget: CGPoint?, seed: UInt64?)
    mutating func nextRest() -> Duration
    mutating func nextBeat() -> (beat: HeadBeat, direction: Double)      // weighted, never twice running, only doable
    mutating func resolve(_ beat: HeadBeat, direction: Double) -> [HeadTake.Moment]  // randomness baked in
    mutating func nextFixation() -> (gaze: CGPoint, hold: Duration, contact: Bool)
    mutating func nextBlink() -> (gap: Duration, double: Bool, depth: CGFloat)
    func timeline(minutes: Double) -> [HeadTake.Moment]                   // tests and the parity page
}
```

`HeadTake.Step` (HT:46-60) gains three cases. The takes never use them, so `HeadTakeTests` still holds:

```swift
case blink(double: Bool)          // the crunch blink, on whichever face shows (needs that face's shut)
case settle                        // back to neutral: through a blink if the face has shut, else morph
case lookAtTarget(share: Double)   // the page's lookTarget × share; mirrored with x like .look
```

`HeadRig` (HeadRig.swift):

```swift
nonisolated struct Face { let image: UIImage; let eyes: [Eye]; var shut: UIImage? = nil }   // :58-63
var shut: UIImage? { faces[.neutral]?.shut }                        // :67, computed; call sites unchanged
func shut(on expression: Expression) -> UIImage? { faces[expression]?.shut }
let popsIn: Set<Expression>                                         // faces that hard swap (§3.4)
var shutFaces: Set<Expression> { Set(faces.compactMap { $1.shut == nil ? nil : $0 }) }
static let creatorRig: HeadRig? = creator()                         // cache; OnboardingView:358 builds one per body pass today
```

`HeadRig.creator()` (HeadRig.swift:126-152) attaches `HeadNeutralClosed` to neutral **and** browsUp (same photo), `HeadRestClosed` to surprised, `HeadSmileClosed` to smile and `HeadWinkClosed` to wink, with `popsIn: [.smile, .wink]`. The `init?` (HeadRig.swift:73-79) keeps a `shut:` argument that fills neutral's face, so `HeadStore.rig(from:)` (HeadStore.swift:194-203) and `load()` (:212-225) compile unchanged until T3 migrates them. `dressed(in:)` (:91-109) dresses each face's `shut` too.

### 3.3 Tokens (GridConstants, beside GC:335-364)

Rename the MARK "The owner's head (onboarding thank-you page)" to "Heads".

| Token | Value | Source |
|---|---|---|
| `headMaxYaw` | 16 | CH:89. Check that a made head at 16° does not read as a card (§6, shot 4). If it does, use 14 for both, never two values. |
| `headBeatRestExpressive` | 3.5...8.0 s | CH:379 |
| `headBeatRestCalm` | 7.0...14.0 s | LHV:342 |
| `headFirstBeat` / `headFirstBeatAfterHello` | 1.5 s / 3.4 s | CH:376 |
| `headBlinkGap` | 2.6...5.8 s | both |
| `headBlinkDepth` | 0.905...0.935 | CH:340 |
| `headBlinkRelease` | 0.045 | CH:344 |
| `headDoubleBlinkShare` | 0.24 | both |
| `headWanderExpressive` / `headWanderCalm` | 0.65...1.8 s / 1.5...4.0 s | LHV:216 |
| `headContactShare` | 0.35 expressive, 0 calm | new (§4, needs the owner) |
| `headContactHold` / `headContactMax` | 1.2...2.6 s / 3.0 s | Binetti et al. 2016, cited in CH:16-18 |
| `headStareFloor` | 0.45 | LHV:221, HeadTakeTests:111-121 |
| `headMicroX` / `headMicroY` | 0.12 / 0.085 | LHV:236 |
| `headEyesLead` | 90 ms (turn), 80 ms (glance, down) | CH:415, 436, 472 |
| `headPupilShare` | 0.55 calibrated (creator), 0.46 measured outline | keeps both heads pixel-identical to today except the catchlight |
| `headStep` | 125 ms | CH:83, LHV:114 (both private today) |
| `headMaxYaw` in `HeadTake` clamps | reads the token | CH:277, LHV:674 |

Existing tokens are unchanged: `headTurn`, `eyeSaccade`, `headMorph`, `headFloatX/Y`, `headTakeHold*`, `headTakeEaseBack`, `headNod`, `tapSquashSpring`, `tapPopSpring`, `naturalSettle`.

### 3.4 Behaviour decisions in the merged engine

1. **Beat mix (expressive).** The creator's six beats keep 80% of the weight in its proportions: glance .208, turn .152, tilt .144, smile .128, down .096, brow .072. The made head's extras share 20%: sideEye .04, doubleTake .03, peoplesEyebrow .03, eyeRoll .03, slowBlink .03, surprise .02, wink .02. `browFlash` becomes greeting-only on expressive heads. Yaw beats are 36% and head-moving beats about 85%. Weights of beats the head cannot do are dropped and the rest renormalised, after substitution (`lift` for brow, `nod` for smile). **Calm:** glance .4, sideEye .3, browFlash .3, unchanged, with `movesHead = false`.
   The thank-you creator therefore gains the extras at 20%. That is a visible change to the reference head. It is measured against its baseline in §6 and shown to the owner. If he wants his head exactly as it was, `HeadLife.expressive` takes a `extras: Bool` and the thank-you page passes false. That is one line, not a second engine.
2. **Beats are the creator's versions.** Glance with 5° yaw and eyes first. Turn with 16°, dip, 1.2-2.2s hold and 650ms return. Down looks at `lookTarget ?? (−0.2, 1)`. Tilt with eyes ±0.1. Smile with eyes y -0.05, no roll (the creator's), pop or morph per §3.4.4. The made-only beats keep their current numbers (LHV:425-514), translated to cues.
3. **Blink.** The creator's crunch (depth → +release → 1-2 steps, 24% double) on expressive heads. Calm heads keep lids only, no squash, because a 33pt header button that squashes reads as a pressed button. A blink runs on whichever face shows if that face has a shut (§2.3.1). Creator: neutral, browsUp, rest, smile, wink. Made: neutral, browsUp, surprised after migration. Idle blinks still only fire on calm faces, the creator's rule (CH:322): neutral, browsUp and the creator's rest. The generation check stays (LHV:273-280).
4. **Face change.** Pop in (a hard swap in one transaction, plus `tapSquashSpring` 0.975 on expressive) for faces in `rig.popsIn`. Everything else uses the existing morph (incoming underneath at full opacity, outgoing fades out on top and is removed on its own completion, LHV:784-811). Returns to calm go through a blink when the face being left has a shut, which is the creator's `blink(reopeningOn:)`, generalised from `settleThroughBlink` (LHV:823-844). A hard swap puts nothing translucent on screen, so it keeps the crossfade rule (CLAUDE.md:319-335). For made heads, `popsIn` is measured at make time or migration: a face pops only if its alpha silhouette's IoU with neutral is ≥ 0.94. The creator's smile is 0.947 and wink 0.962. Otherwise it morphs. It is stored in the manifest (`"popsIn": [...]`).
5. **Gaze (expressive).** Fixations alternate. With `headContactShare` 0.35 the eyes come home to near-centre, a point within 0.08 x / 0.04 y, never exactly zero, with micro-saccades on top so they are never locked. That lasts `headContactHold`, hard-capped at `headContactMax`, and the next fixation is always off-centre (0.45-0.9). Every beat ends on a contact or an off-centre fixation drawn by the director, not a fixed `.zero`. **Calm, takes, sticker holds and Reduce Motion never make contact** (the floor stays 0.45, HeadTakeTests:111-121). Under Reduce Motion the creator also rests at (0.5, 0.1), which fixes its permanent stare.
6. **`lookTarget: CGPoint?`** on `LivingHeadView` and `TappableHead`. The thank-you page passes (-0.8, -0.8), as today (OnboardingView:396-397). Other pages: nil, so the turn picks ±1 and `down` looks at (−0.2, 1), the words under every expressive head (maker caption, onboarding copy, Profile's name).
7. **Greeting (`hello` beat).** 700ms → brows 240ms → 160ms → wink 1.6s if the head has a wink, else smile 1.3-2.0s → beats wait `headFirstBeatAfterHello`. Under Reduce Motion: the face swap only, as the creator does today (CH:157). Every step keeps the "a tap wins over the hello" guards (LHV:317-336, CH:141-156).
8. **Iris.** The catchlight moves out of `IrisDisc` into `IrisLayer` and is positioned at the eye's centre offset (-0.08w, -0.14h), not at the iris. Pupil share comes from the token table. Calibrated eyes (outline nil) draw the portfolio's ellipse iris at 0.6w × 1.05h, so the creator renders as it does today.
9. **Float.** Expressive keeps it (made head today), and the creator gains it. The owner has never seen his head float. The parity page shows it, and it is the first thing to remove if he says his head feels busy. It is also the one continuous cost (§5).
10. **Tap.** Unchanged: `TappableHead` and the sticker. Profile stays untappable because its tap opens the photo menu (ProfileView:161-166). Taps use `rig.shutFaces` for `.lids`, so a made head with a migrated shut on browsUp gets the full `sleepy` take.

### 3.5 File by file

**`Strata/Views/LivingHeadView.swift`**

| Lines | Change |
|---|---|
| 40, 46 | `enum Liveliness` stays as the public API (call sites unchanged). Add a private `var life: HeadLife { liveliness == .calm ? .calm : .expressive }`. |
| 46-61 | Add `var lookTarget: CGPoint? = nil`. |
| 63-110 | Add `@State private var director: HeadDirector?` (built in `onAppear` from rig, life, target and `DebugHarness.headSeed`), `@State private var awake = true`, and `@Environment(\.scenePhase)`. |
| 114-116 | Delete `step` and `maxYaw`; use `GridConstants.headStep` and `headMaxYaw`. |
| 121-151 | Gate `floats` on `awake`. When sleeping, set `floatA/floatB` without animation so the repeatForever stops. |
| 145, 152-155 | The four idle `.task(id: reduceMotion)` become two: `.task(id: LoopKey(reduceMotion, awake)) { await liveWhileIdle() }` (beats plus greeting) and `.task(id: LoopKey(...)) { await eyesWhileIdle() }` (wander, contact, micro, blink). That leaves two tasks, not four. |
| 183-203 | `artwork`/`irises` use `rig.shut(on: face)` instead of `face == .neutral && rig.shut != nil`. Keep "a shut face has no iris" exactly. |
| 210-239 | Replace with `eyesWhileIdle()`, which sleeps to the earliest of next fixation, next micro and next blink. The `restShare > 0.5, !gazeHeld` guard (LHV:219) stays, and the watchdog (LHV:255-261) moves here unchanged. |
| 243-296 | `blink()` and `slowBlink()` become `apply(.blink)` / `.lids` in the interpreter, with the crunch from CH:340-357 and generation checks from LHV:273-293. |
| 300-385 | Delete `Beat`, `nextBeat` and `canPerform`; the director owns them. |
| 305-351 | `beatWhileIdle` becomes `liveWhileIdle()`: settle unless taking (keep LHV:313), greet via `run(director.resolve(.hello))`, then loop `sleep(director.nextRest())` → guard `!busy, !taking, heldFace == nil, !gazeHeld` (keep LHV:348) → `run(director.resolve(beat))`. |
| 387-532 | **Delete `perform`.** |
| 542-605 | `play` keeps its body but walks moments through a shared `run(_ moments:, start:, onCancel:)`, extracted from LHV:586-603. Beats call `run` with `generation` captured and `busy` set. Takes keep `taking`, `lastPlayed` and `finishTake` keyed on the take (LHV:638-642). |
| 645-690 | `apply` gains `.blink`, `.settle` and `.lookAtTarget`. `.lids` guards on `rig.shut(on: expression)`. `.face` uses pop when `rig.popsIn.contains(next)`. |
| 784-811 | `beginMorph` unchanged. Add `pop(to:)` next to `swap` (LHV:762-771): the same transaction, plus the squash when `life.morphSquash`. |
| 823-844 | `settleThroughBlink` uses the shut of the face being left, which is the creator's order (close on the old face, open on the new). |
| 867-876 | `pose` guards on `life.movesHead || invited`. |
| 893-914 | `TappableHead` passes `lookTarget`. |
| 949-968 | Catchlight out of `IrisDisc`, into `IrisLayer` (LHV:919-946), at the eye centre. |

New in the same file: `.onChange(of: scenePhase)` and `.onGeometryChange(for: Bool.self) { onScreen($0) }` set `awake` (§5).

**`Strata/Views/CreatorHead.swift`**: replace the whole file.

```swift
struct CreatorHead: View {
    var side: CGFloat = 44
    var greets = false
    var lookTarget = CGPoint(x: -1, y: -0.5)
    var body: some View {
        if let rig = HeadRig.creatorRig {
            TappableHead(rig: rig, side: side, greets: greets, lookTarget: lookTarget)
        }
    }
}
```

Delete `HeadFace` (CH:532-568), `HeadEye` (CH:577-618) and all of CH:58-523. Keep the research notes (CH:12-42) by moving them into `HeadBeat.swift`'s header. Positioning: `LivingHeadView` centres by chin, and for the creator rig that moves the head 0.74pt up at 92pt ((0.5 − (0.8988 − 0.3925)) × 117.2). Leave `OnboardingView:398`'s `.offset(x: 22, y: -14)` alone unless the stamp check in §6 shows more than 1pt of shift.

**`Strata/Models/HeadRig.swift`**: §3.2.

**`Strata/Models/HeadTake.swift`**: three `Step` cases (§3.2). `cues(direction:)` (HT:89-101) mirrors `.lookAtTarget`'s x. `stillGaze` (HT:127-140) treats `.lookAtTarget` as unknown, which gives nil.

**`Strata/Models/HeadStore.swift`**:
- `Face` (:16) and `Payload` (:22-25) carry per-face `shut: Data?` and `popsIn`.
- `Manifest` (:27-32) goes to `version = 3` with `popsIn: [String]` and `shutFaces: [String]`.
- `save` (:149-170) writes `<face>-shut.png`.
- `load` (:212-225) reads them. If `version == 2`, it runs `HeadDerivation.migrate(directory:)` once, off the main actor, keeping every original file.

**New `Strata/Services/HeadDerivation.swift`**: `lidPatch(open:shut:eyes:)`, `browBand(neutral:brows:neutralEyes:)`, `silhouetteIoU(_:_:)`, `migrate(directory:)`. It works on the 600px PNGs in canvas space with Core Image masks, the same toolkit as `HeadCaptureEngine.masked` (HeadCaptureEngine:440).

**`Strata/ViewModels/HeadMakerModel.swift` :284-309**: after the cut-outs, derive `neutral.shut`, `browsUp` (banded), `browsUp.shut`, `surprised.shut` and `popsIn`.

**`Strata/Services/DebugHarness.swift` (:213-248)**:
- `-strataHeadSeed <UInt64>`
- `-strataHeadBeat <id>` (moved from CH:515-519, now for every head)
- `-strataHeadScript parity|idle|beats|blinks`
- `-strataHeadParity` (opens the parity page)
- `-strataHeadTrace` (logs every state target)

**New DEBUG `Strata/Views/HeadParityView.swift`**: §6.

**Tests**: new `StrataTests/HeadDirectorTests.swift` and `StrataTests/HeadDerivationTests.swift`. `HeadTakeTests` is unchanged, plus one test that no take uses the new steps.

**CLAUDE.md "Profile and your head" (:942-966)**: "`CreatorHead` (thank-you page) is separate and untouched" becomes "`CreatorHead` is `TappableHead` on `HeadRig.creatorRig`; one engine". Add the lid-patch rule and the contact cap.

### 3.6 What stays exactly as it is

- A tap owns the head: `guard !taking` in beats and the greeting (LHV:318, 330, 391), throwing sleeps in takes (LHV:587), `finishTake` keyed on `lastPlayed` (LHV:638).
- Generation checks on every pause, blink, slow blink, settle and bounce (LHV:273-293, 686, 841, 880-883). The new interpreter gives the creator's `.bounce` the check it lacks (CH:284-288).
- Stare floor 0.45 for takes and calm wander, and its test.
- No iris on a shut face (LHV:190-194), and no iris on smile/wink photos (`eyes: []`).
- Crossfade order for heads: incoming underneath at full opacity, outgoing removed on completion (LHV:784-806, CLAUDE.md:326-335).
- `heldFace` read by loops, never `held` (LHV:94-99). `lastPlayed` replay guard (LHV:100-103). `gazeHeld` cleared in `settleImmediately` (LHV:745). The watchdog.
- `HeadStill` and the sticker's saved face and gaze.

---

## 4. Nothing creepy

The head is a real person's face. Guard rails, each tied to a mechanism and a test:

| # | Guard rail | Mechanism | Test |
|---|---|---|---|
| G1 | **No stare.** Eyes never rest at the viewer for more than `headContactMax` 3.0s, and never at all in chrome, on the map, on a sticker, during a take or under Reduce Motion. | Director caps contact holds, and the next fixation after contact is off-centre. `contactShare = 0` for calm. | `HeadDirectorTests.contactIsBounded`: 60 simulated minutes per life profile; longest run with \|gaze\| < 0.3 ≤ 3.0s (expressive), 0 (calm). The existing `nobodyStares`. |
| G2 | **No blank eyes.** A face with painted sclera always has irises unless its lids are shut. | Irises drawn per face layer; shut only swaps to a real shut photo. No procedural "hide the iris" blink. | `shutOnlyWithAPhoto`: no `.blink`/`.lids` moment on a face without `shut(on:)`. Frame check in §6: iris blob present on every open-eye frame. |
| G3 | **No uncanny partial lids.** Lids are never drawn, only photographed. | Lid patch copies real shut pixels. No skin-coloured shapes, no scaled lids, no mid-blink interpolation (the 8fps snap stays). | Seam check in §6 (ΔE at the mask edge). |
| G4 | **No iris beside a real shut eye, no iris on a shut lid.** | Kept: wink and smile photos have `eyes: []`. Irises are per face layer. | Existing frame counts (0 of 13 wink frames). |
| G5 | **No distress.** Nothing that reads as fear, pain, sadness, anger or illness: no trembling, no eyes rolled up held, no drooping face that does not recover, no rapid repeated blinking. | Blinks ≥ 2.6s apart plus at most one double. `sleepy` always wakes (HT:217-227). Eye roll finishes within 1.3s. Surprise ≤ 1.0s idle. No beat repeats back to back. Yaw ≤ 16°, roll ≤ 6°. | `noDistress`: blinks per minute ≤ 25, no two blinks within 250ms except the double, every beat ends on neutral or calm within `beat.tail + 1s`, pose limits. |
| G6 | **No watching.** It never follows the finger, the camera or device motion, and nothing is keyed to the viewer. | No motion or scroll input (kept). `lookTarget` points at page content only. Copy must never say it sees you (memory: no creepy copy). | Code review item. |
| G7 | **Chrome stays quiet.** A calm head never moves the head on its own and never changes to a non-brow face on its own. | `movesHead = false`; calm weights. | `calmHasNoPose`: zero `.pose` moments and zero `.face` other than browsUp/neutral in 60 simulated calm minutes. |
| G8 | **No flicker of the whole face.** A blink or brow flash changes only lids or brows. | Lid patch, brow band, pop only when IoU ≥ 0.94. | §6: pixel change outside eye and brow masks < 1% of head pixels during blink and flash frames. |

**Every proposed behaviour checked:**

| Behaviour | G1 | G2 | G3 | G5 | G7 | G8 | Note |
|---|---|---|---|---|---|---|---|
| Creator beat mix on made heads | ok | ok | ok | ok | ok (expressive only) | ok | More yaw is the point. Capped at 16°. |
| Bounded eye contact | **risk, bounded** | ok | ok | ok | ok | ok | The one behaviour that relaxes a written rule (plan §5.3 "It never looks straight at you"). The creator already does it, unbounded. **Owner decision**; default-off fallback is `contactShare = 0` everywhere. |
| Crunch blink | ok | ok | ok | ok at ≥ 2.6s gaps | squash off in calm | ok | |
| Lid patch | ok | ok | ok (real pixels) | ok | ok | fixes it | Seam measured. |
| Brow band | ok | ok | ok | ok | ok | fixes it | Falls back to the raw capture per head if the seam fails. |
| Pop-in faces | ok | ok | ok | ok | ok | gated by IoU | |
| `lookTarget` / look down | ok | ok | ok | ok | ok | ok | Looks at the page, not the viewer. |
| Wink greeting on made heads | ok | ok (photo eyes) | ok | ok | expressive only | IoU-gated | A made head winking at its maker is playful, not predatory. It is only on pages where the head is the subject. |
| Lift instead of brows | ok | ok | ok | ok | ok | ok | |
| Nod instead of smile | ok | ok | ok | ok | ok | ok | |
| Creator gains float | ok | ok | ok | ok | ok | ok | Taste call, see §3.4.9. |
| Creator Reduce Motion rests off-centre | fixes a stare | ok | ok | ok | ok | ok | |

---

## 5. Performance

### Today, per head

| | Tasks | Wake-ups per second (mean) | Continuous animation |
|---|---|---|---|
| CreatorHead | 2 loops + greet + reaction | blink 0.24, beat about 0.17, plus in-beat pauses about 0.8 | none |
| LivingHeadView expressive | 4 loops + held + play (+ debug) | blink 0.24, wander 0.82, micro 1.07, beat about 0.19, plus in-beat about 0.8 = **about 3.1** | float: two repeatForever transforms, every frame |
| LivingHeadView calm | same 6 tasks (micro exits at once) | blink 0.24, wander 0.36, beat 0.09 = **about 0.7** | none |

Each wake-up that changes `@State` re-evaluates `body` once. The spring then re-renders the head's display list for its settling time: saccade about 0.15s, turn about 0.8s, morph 0.14s. The float re-renders two transforms at the display rate for as long as the view exists. `body` is not re-run for that, but the layer tree with two to four radial and elliptical gradient irises is re-composited.

### Merged engine budget

- **Tasks:** two idle loops (`liveWhileIdle`, `eyesWhileIdle`) plus the take task, down from four plus two. Each sleeps until its next scheduled moment. No polling, no `TimelineView`, no per-frame work.
- **Wake-ups:** expressive about 2.4/s (contact fixations hold longer than wander fixations). Calm about 0.7/s, unchanged.
- **Redraw:** expressive is animating about 35-45% of the time from springs, plus the float at 100%. Calm is about 8%.
- **Target,** checked with the Instruments SwiftUI template and Time Profiler on device, not in the simulator:
  - An expressive head at rest adds ≤ 1.0% main-thread CPU and ≤ 1 hitch per minute on an A15-class phone. A calm head adds ≤ 0.3%.
  - If the float breaks the budget, rasterise the face and irises once per state change with `.drawingGroup()` placed **inside** the transforms (LHV:122-136, before `.frame` at :136). The float and turn then move a cached texture. Measure before adding it; it is not free for gradient re-rasterisation on every gaze change.
- **Map marker:** one calm head. The annotation must not rebuild the rig per region change (check `HeadMarker` is not re-created by `Map` content updates; `HeadStore.shared.headForMap` returns the same instance).

### The pause rule

A head is **awake** only when all of these are true:

1. `scenePhase == .active` (backgrounding and the app switcher put it to sleep).
2. Its frame intersects the window's bounds by at least 20% of its area. Use `onGeometryChange(for: Bool.self)` in `.global` against the window bounds. That covers `ScrollView` offscreen, a `List` row scrolled away and a map annotation panned out. Map annotations are the case to verify.
3. It is not covered by a full-screen presentation. A `NavigationStack` push fires `onDisappear`, and `.task` cancels. A sheet over Profile does not, so `ProfileView` passes `.environment(\.headsAwake, !isPresentingChild)`. Only needed where a sheet covers a head: Profile → Settings, maker → confirm.

When asleep:

- The idle task ids change, so the loops cancel.
- The float stops (non-animated set).
- If not `taking` and `heldFace == nil`, `settleImmediately()` runs. A take in flight is left to finish, and its throwing sleeps cancel only if the view goes away.

On waking, the loops restart, the first beat waits a full `nextRest()` (no burst of beats), and the director keeps its RNG state, so a seeded run stays deterministic across a pause.

---

## 6. Verification

The rule from both CLAUDE.md files: counting is not looking. Every number below is paired with a sheet that has been opened.

### 6.1 Baseline first (before any engine change)

Task T0 adds only the DEBUG parity page and `-strataHeadTrace` **on top of today's code** and records the reference:

- the old `CreatorHead`
- today's `LivingHeadView` on the seeded creator rig (`-strataSeedHead`)
- today's `LivingHeadView` on a real made head, if the owner's device export is available; otherwise the seeded rig

Those baseline trace files and videos are the fixed reference. Nothing is compared against memory.

### 6.2 The DEBUG parity page (`-strataHeadParity`)

Three columns on flat key-green (#00B140) squares, each head 152pt (the onboarding head page size): **A** creator rig, **B** made head (or seeded), **C** the same made head with the capture reduced to neutral + shut (shows the fallbacks). Every column has the same `HeadLife.expressive`, the same `-strataHeadSeed`, and the same `lookTarget` (0, 1). A fourth row repeats the three at 33pt calm.

`-strataHeadScript` modes:

- `parity`: a fixed list, each beat forced once in order with 1.5s rests: hello, glance, turn, tilt, down, brow, smile, sideEye, doubleTake, eyeRoll, slowBlink, surprise, wink, then blink ×5, double blink ×2, then all 12 takes with direction +1.
- `idle`: 10 minutes of free life on the seed.
- `blinks`: 60 blinks, 1s apart.

### 6.3 Exact comparison (unit tests, no rendering)

`HeadDirectorTests`, run serially in the one simulator:

1. **Same seed, same life.** Creator capabilities vs a full-capture made head: `timeline(minutes: 10)` is identical moment for moment, after dropping faces neither has. This is the structural proof that the heads cannot drift apart again.
2. **Fallback heads still move.** Neutral + shut only: yaw-bearing beats per minute ≥ 90% of the full head's, and total head-moving beats per minute ≥ the full head's.
3. **Against the old creator.** Expressive yaw beats per minute ≥ 80% of the old creator's 4.7. Mean turn yaw 16. Glance yaw 5. Blink rate within ±10% of `2 / (2.6 + 5.8)` per second. Double share 0.24 ± 0.03 over 5,000 blinks.
4. Guard-rail tests from §4: `contactIsBounded`, `shutOnlyWithAPhoto`, `noDistress`, `calmHasNoPose`.
5. `HeadTakeTests` unchanged and green.

### 6.4 Rendered motion (frame-sampled, off device)

Record: `xcrun simctl io <udid> recordVideo --codec h264` at the simulator's 60fps. The analysis runs off device in Swift or Python and needs no human judgement. Per column, per frame:

| Signal | How |
|---|---|
| Head mask | Chroma key on #00B140 |
| Centroid (lean/dip, float) | Mask moments |
| Roll | Principal axis of the mask, relative to frame 0 |
| Yaw | Mask width / rest width, inverted through the 0.45 perspective model (calibrated with `-strataHeadBeat turn` at known 0, ±8, ±16) |
| Squash | Mask height / rest height |
| Eyes open | Dark iris blob present inside each eye ellipse (rig eye coords, transformed by the frame's pose) |
| Gaze | Blob centroid minus eye centre, divided by travel |
| Face | Nearest of the rig's face PNGs by masked SSIM in the head's own frame |
| Whole-face change (G8) | % of head pixels outside the eye and brow masks that change more than ΔE 6 between consecutive frames |

Align runs on the `[strata-head-trace]` start line of each scripted beat. The trace time plus the video's first-frame timestamp, calibrated by a DEBUG 1-frame white flash at script start, keys each beat.

**Pass thresholds:**

| Metric | New A vs baseline creator | B vs A (same run) |
|---|---|---|
| Per-beat yaw/roll/squash curves, RMS difference | ≤ 10% of the beat's peak | ≤ 10% |
| Onset of each cue | ±2 frames (the machine runs loaded; the report measured up to 2.4s lag on start, so timing is relative to the logged start) | ±2 frames |
| Peak yaw on turn / glance | 16 ± 1.5° / 5 ± 1° | same |
| Blink closed duration | 250-375ms | same |
| Blink squash minimum | 0.905-0.935 | same |
| Idle 10 min: yaw events/min, blinks/min, face changes/min, saccades/min | ±15% | ±15% |
| Longest contact run | ≤ 3.0s | ≤ 3.0s |
| Frames with open eyes but no iris blob | 0 | 0 |
| G8 whole-face change during blink/brow frames | n/a | < 1% |
| Calm row: frames with yaw > 1° or roll > 1° | 0 | 0 |
| Empty-head frames (mask area < 90% of rest) | 0 | 0 |

**Derivation checks** (`HeadDerivationTests` plus a sheet):

- Lid patch: mean ΔE along the feathered seam < 3, and max < 8.
- Brow band: seam ΔE < 3 across the band edge.
- IoU gate reproduces the creator: smile 0.947 and wink 0.962 pop; rest 0.957 pops.
- Migration leaves every v2 file byte-identical.
- The creator's own `HeadNeutralClosed` against a lid patch built from `HeadNeutral` + `HeadNeutralClosed` is < 1% pixel difference outside the eyes. The patch is a no-op on already perfect assets.

**Position stamp:** on the thank-you page, the creator head's mask bounding box before and after within 1pt. This follows the portfolio trap "prove fidelity by stamping a rect at independently-measured coordinates".

### 6.5 Shots and films (one simulator, strictly one at a time, sim deleted after)

1. Baseline: parity page, `parity` script, light (T0, old code).
2. Baseline: parity page, `idle` 10 min, seed 7.
3. After: the same two, same seed, light, then dark.
4. After: `-strataHeadBeat turn` on the made head column at 16°, frame sheet at peak. **Look:** does a made head read as a card? If yes, use 14 for both (§3.3).
5. After: thank-you page, `-strataOnboardingStep` for the thanks page, 60-frame burst of the hello, and a 5-minute film. Contact sheet looked at next to baseline 1.
6. After: onboarding head page and maker preview (`-strataOpenHeadMaker preview`) on the seeded head, 5 minutes each.
7. After: Profile (`-strataOpenSheet profile -strataHeadOn picture`), 5 minutes. Scroll Profile until the head is off screen: the trace shows 0 events while off, and a full rest before the first beat after.
8. After: map marker (`-strataHeadOn map`) and header button, 5 minutes each. Calm row metrics.
9. After: Reduce Motion on, parity page, 2 minutes. Longest contact run 0; creator rests off-centre.
10. After: `-strataHeadTake cycle` on the parity page, all three columns. Sheet at each hold.
11. After: background the app for 30s mid-idle. Trace: zero events while inactive.
12. Contact episodes: a 90-frame burst on column B at a contact moment. **Look:** does it read as glancing at you, or staring? This goes to the owner with the sheet, not a verdict.

Deliver to the owner: one side-by-side film (baseline creator | new creator | his made head), 60 seconds, from shot 3, plus the table of §6.4 numbers.

---

## 7. Build tasks

| # | Task | Size | Depends on |
|---|---|---|---|
| T0 | DEBUG parity page, `-strataHeadTrace`, `-strataHeadSeed`, `-strataHeadScript` **on today's code**. Record baselines 6.5.1-2. | M | - |
| T1 | `HeadRig`: per-face `shut`, `popsIn`, `shutFaces`, `creatorRig` cache; `creator()` attaches all closed variants; `dressed(in:)` dresses shuts. Call sites compile unchanged. | S | - |
| T2 | `HeadDerivation`: lid patch, brow band, silhouette IoU, with `HeadDerivationTests`. Measure the whole-face jump on the seeded rig and at least one real made head **before** deciding the brow band is needed (G8). | M | T1 |
| T3 | `HeadStore` manifest v3 + migration (originals untouched) + `HeadMakerModel` derivation at make time. | M | T2 |
| T4 | GridConstants head tokens (§3.3); `HeadLife` calm/expressive. | S | - |
| T5 | `HeadBeat` catalogue (all 17 beats as cues, creator numbers for the six core beats, made-head numbers for the rest, `hello`, `lift`, `nod`) and `HeadDirector` (seeded, weights, substitutions, contact cap, blink scheduling) with `HeadDirectorTests` (§6.3). The three new `HeadTake.Step` cases. | L | T4 |
| T6 | `LivingHeadView` merge: shared `run` interpreter, two idle loops, crunch blink, per-face shut, pop vs morph, `lookTarget`, contact gaze, generalised settle-through-blink; delete `perform`/`Beat`/`nextBeat`/`canPerform`. Every §3.6 fix kept; the existing `-strataHeadTake` bursts rerun (0 empty frames, 0 iris on shut, watchdog 0). | L | T1, T5 |
| T7 | Iris: catchlight fixed to the eye, pupil tokens, calibrated ellipse iris for `outline == nil`. | S | T6 |
| T8 | Awake/pause: scenePhase, on-screen geometry, `headsAwake` environment for Profile's sheets; float stop; rest-on-wake. | M | T6 |
| T9 | `CreatorHead` → wrapper; delete `HeadFace`, `HeadEye` and the old loops; move `-strataHeadBeat`; stamp check on the thank-you page. | S | T6, T7 |
| T10 | Verification runs 6.4-6.5 (serial, one simulator), analysis script, contact sheets looked at, owner film. | M | T0, T6-T9 |
| T11 | Instruments pass on device for the §5 budget; `.drawingGroup()` only if measured over budget. CLAUDE.md "Profile and your head" updated (one engine, lid patch, contact cap, pause rule). | M | T10 |

Sizes: S under half a day, M one to two days, L three days or more. T6 is the risky one: every fix in §3.6 was found by a simulator burst, so the old bursts are re-run in T6 itself, not saved for T10.

### Questions for the owner before T5

1. **Eye contact:** may an expressive head look at you for up to 3 seconds at a time, the way his own head does now, or do made heads keep "never looks straight at you"?
2. **His head gaining the extras** (side-eye, double take, eye roll, slow blink, surprise and wink as idle beats, 20% of beats) and **the float**: yes, or keep his head exactly as it is?
3. **A head whose blink was not caught:** should the maker ask for the blink once more? Without it a head can never blink.

## Owner's answers (2026-09-16)
1. Eye contact: YES for expressive heads (profile, maker preview): rest eyes on the viewer up to 3s, then look away on purpose. Calm contexts (map marker, small chrome) still never stare.
2. His black-and-white head is only a reference example and never really in the app for users: treat its behaviour as the STANDARD made heads must match. A shared engine is still preferred; whether his head gains extras does not matter.
3. Missed blink: the maker asks for one quick blink again before finishing, only when the blink was not caught.
