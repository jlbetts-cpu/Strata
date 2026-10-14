# Motion pass, 2026-10-14: the drawers

The owner: "a big emphasis pass improving the animations truely researching how
to get the app to the apple quality", "everything needs to be smooth going down
too", "opening chats ... jolt out", "the drawer is used a lot ... plan, journal,
edit, messages make sure they all work fairly similar", "the plan with crew and
the plan needs to feel the same".

Read-only audit against the tree at `ea5c9c8`. Nothing here was built or
filmed; every finding is from the source and is marked where it needs a
frame-by-frame look on a phone before it is believed. `docs/motion-audit.md`
(2026-10-02) is the token audit; this pass is the drawers and sheets, which
came after it.

---

## 1. How Apple gets fluid motion (sourced)

1. **One object follows the finger, 1:1, and moves; it is not resized.** Content
   stays attached to the touch and the gesture's history is kept so the hand-off
   is seamless. [WWDC18 Designing Fluid Interfaces][wwdc18]
2. **Release hands the finger's velocity to a spring.** "Continue from the
   gesture's current velocity rather than restarting." In SwiftUI the cheap way
   is: drive the value with `.interactiveSpring` while dragging, then a plain
   `.spring` on release; each new spring retargets the last and inherits its
   velocity, no maths needed. [WWDC24 Enhance your UI animations][wwdc24]
   Or pass `initialVelocity` normalised by the distance left (the app already
   does this in `GridConstants.slotRelease`). [WWDC23 Animate with springs][wwdc23s]
3. **Decide where it lands from the projection, not the position.** A flick
   should open or close even when it travelled 20pt; use
   `predictedEndTranslation` and pick the nearest rest. [WWDC18][wwdc18]
4. **Everything is interruptible and redirectable.** A drawer grabbed while it is
   still moving must stop under the finger, not finish first. Springs retarget
   with their velocity; timing curves (`easeInOut`, our `crossFade`) only add up
   and do not carry velocity. [WWDC23 Explore SwiftUI animation][wwdc23e]
5. **Springs by duration and bounce; bounce 0 for UI, a little only where a
   gesture carried momentum.** Damping 100% for a tap, about 80% when a swipe
   throws it. [WWDC23 Animate with springs][wwdc23s], [WWDC18][wwdc18]
6. **Rubber-band at the edges**, never a hard wall. [WWDC18][wwdc18]
7. **Do not wait on a sleep for "it has landed".** Settling time is
   unpredictable; use the animation's completion, which fires on the
   perceptual duration. [WWDC23 Animate with springs][wwdc23s]
8. **Things that move together move on one curve.** The keyboard is a spring
   (reverse-engineered as mass 3, stiffness 1000, damping 500, overdamped);
   anything riding on it should use the same curve or be driven by the
   keyboard safe area, which SwiftUI animates on the keyboard's own curve.
   [Apple Developer Forums 48088][kbd]
9. **iOS 26 sheets.** A partial detent floats inset with device-concentric
   corners and Liquid Glass; at `.large` it attaches edge to edge and goes
   opaque. A custom `presentationBackground` opts out of the glass. A sheet can
   morph out of the button that opened it with `matchedTransitionSource` +
   `.navigationTransition(.zoom)`. [WWDC25 Build a SwiftUI app with the new
   design][wwdc25], [Nil Coalescing][nilc]
10. **Reduce Motion swaps a slide for a dissolve**; it does not just run the
    slide faster. (`docs/apple-design.md` §14.)

---

## 2. Every drawer and sheet, side by side

| Surface | Where | Presented as | Height | Open / close curve | Grabber | Title row | Ground, corners | Keyboard |
|---|---|---|---|---|---|---|---|---|
| **Messages** (chat drawer) | `ChatRestBar.swift:165` `ChatDrawer`, hosted `CrewTowerView.swift:312` | Custom overlay panel, offset in from below | `min(560, room - 150)`; full = room | `.smooth(0.36)` open/close (`:235`), `.smooth(0.3)` part/full (`:236`), `motionSnappy` for the VoiceOver toggle (`:203`); release ignores velocity | Own capsule 36x5, 22pt strip; **the only drag handle** | Own `ChatDrawerTitle`: "Today" + Done (`CrewChatSheet.swift:1433`) | `WarmBackground.top`, **top corners 8pt** (`GridConstants.cornerRadius`), hairline | Fixed `Task.sleep(360ms)` (`CrewChatSheet.swift:240`) |
| Chat resting bar | `ChatRestBar.swift:16` | Bottom safe-area inset | Content | Lift follows at 0.5x, capped 30pt; back on `motionSnappy` (`:127`) | Own capsule, decorative | none | same 8pt top corners | n/a |
| **Plan** (Wins) | `MainAppView.swift:670`, `DaySheet` `.planOnly` | System sheet | `.large` (`DaySheet.swift:389`) | UIKit sheet spring, velocity-aware | System | Nav bar "Plan", ＋ left, Done right | `presentationBackground` WarmBackground, system corners | Fixed `Task.sleep(500ms)` (`DaySheet.swift:527`); bar at the **foot** (`DayComposer`) |
| **Journal** | `DaySheet.swift:90` (past day), same sheet on Wins | System sheet | `.large` | UIKit | System | Nav bar title or Plan/Journal words | same | Bar at the foot; Suggest row springs in on `motionSnappy` (`:830`) |
| **Edit** (a win) | `MainAppView.swift:784`, `AddWinSheet` | System sheet | `.large` (`AddWinSheet.swift:539`) | UIKit | System | "Edit" drawn title, Cancel / Save | same | n/a |
| **Plan with crew** | `ChatPlus.swift:108` `GroupPlanSheet`, from inside the chat drawer (`CrewChatSheet.swift:287`) | System sheet **over the custom drawer** | `.height(236 / 292)` (`:198`) | UIKit | System | "Plan with X", Cancel / Plan | same | Fixed `Task.sleep(380ms)` (`:204`); field at the **top**, `glassCapsule` |
| Plan line | `PlanItemDetailSheet.swift:262` | System sheet | `.medium, .large` | UIKit | System | "Line" | same | n/a |
| Chat stickers | `CrewChatSheet.swift:1327` | System sheet over the drawer | `.medium, .large` | UIKit | System | "Stickers", Cancel | same | n/a |

**What differs, in one line each**

- **Two physics.** Messages is a hand-built panel: grabber-only drag, the panel
  is resized not moved, release drops the finger's speed, no rubber band. Plan,
  Journal and Edit are UIKit sheets: drag anywhere at the top of the content,
  velocity carried, projected landing, rubber band. This is the root of "make
  sure they all work fairly similar".
- **Corners.** The drawer's top corners are 8pt; every sheet next to it uses
  the system's device-concentric radius (and on iOS 26 a part-height sheet is
  inset). A crew plan opened from the chat stacks a 38pt-ish sheet on an 8pt
  panel.
- **The plan twice.** Your plan: a tall sheet, writing at the foot in the
  chat's bar (`glassField`), Return sends, the days row on top, weekday chips
  just above the bar. Crew plan: a short sheet, the field at the top in a
  capsule (`glassCapsule`), Plan in the toolbar, chips under the days row.
- **Four "after it lands" sleeps:** 360, 380, 500 and 350ms
  (`CrewChatSheet.swift:240`, `ChatPlus.swift:204`, `DaySheet.swift:527`,
  `DaySheet.swift:986/994`) for the same job.

---

## 3. Fixes, ranked

Risk: **Low** = local, no layout model change, safe to ship after one look.
**Med** = changes how a gesture or layout behaves; film before and after.
**Owner** = a look he has to choose.

### 1. The drawer moves with the finger instead of being resized. Med

`ChatRestBar.swift:189-199` and `:210`

```swift
.onChanged { pull = $0.translation.height }
...
.frame(height: max(open - pull, 200), alignment: .top)
```

Every drag frame re-lays out the whole chat (the thread's `GeometryReader`
`minHeight` at `CrewChatSheet.swift:377, 393`, the bottom-anchored
`LazyVStack`, the inset composer), so the lines slide inside the panel while
the panel's edge moves: the jolt, on the way down. It also stops dead at 200pt
(`max(..., 200)`) and grows without resistance upward (pull negative).

Proposed: keep the height fixed at `open` while dragging and move the panel.

```swift
// drag down: 1:1; drag up: rubber band
let shown = pull > 0 ? pull : -rubber(-pull, limit: 60)
.frame(height: open, alignment: .top)
.offset(y: (isOpen ? 0 : open + 60) + shown)
```

Extend the ground ~80pt below the panel (`.padding(.bottom, -80)` on the
background) so an upward rubber band never shows a gap. Height changes only
on the part/full step, never per frame.

### 2. Release carries the finger's speed and lands where it was thrown. Med

`ChatRestBar.swift:191-197`

```swift
let dy = value.translation.height
withAnimation(reduceMotion ? GridConstants.crossFade : .smooth(duration: 0.3)) {
    pull = 0
    if dy < -60 { full = true }
    else if dy > 80 { if full { full = false } else { isOpen = false } }
}
```

Distance thresholds only, a curve that starts from rest. A quick flick of 40pt
does nothing; a slow 81pt drag closes.

Proposed: decide on `value.predictedEndTranslation.height` (nearest of closed,
part, full), and drive `pull` with `withAnimation(.interactiveSpring)` in
`onChanged` so the release spring inherits velocity (WWDC24 pattern), or pass
`initialVelocity: value.velocity.height / remaining` as
`GridConstants.slotRelease` already does. One token,
`GridConstants.drawerRelease(velocity:)`, `bounce` about 0.1 only when thrown.

### 3. Closing by drag no longer re-grows the panel while it leaves. Low

Same block, `:194-196`. `pull = 0` and `isOpen = false` change together: the
height animates back up to `open` (0.3s) while the offset slides it away
(0.36s, the implicit `.animation` at `:235` wins for `isOpen`). The panel and
its contents swell by the dragged distance on the way down. "Everything needs
to be smooth going down too."

Proposed: on a close, leave `pull` where the finger left it and zero it in the
animation's completion (or after `fix 1`, it is an offset and simply folds into
the slide).

### 4. One curve for one panel, as tokens. Low

`ChatRestBar.swift:193, 203, 235, 236` use `.smooth(0.3)`, `.smooth(0.36)`,
`motionSnappy` and `crossFade` for the same object; `:127` writes
`reduceMotion ? crossFade : motionSnappy` though `motionSnappy` already passes
through `calm()`. `docs/motion-audit.md` closed with "no animation is typed
inline".

Proposed in `GridConstants.swift` beside `layoutReflow` (`:424`):

```swift
/// The chat drawer opening, closing and stepping part/full. One curve.
static var drawerMove: Animation { calm(.smooth(duration: 0.36)) }
```

Use it at all four sites; the VoiceOver toggle at `:203` too.

### 5. Every message bar stops snapping 17pt when the keyboard comes. Med (film it)

`DayComposer.swift:190-201` `BarSink`

```swift
.padding(.bottom, keyboardUp ? GridConstants.gapTight : GridConstants.gapTight - GridConstants.barSink)
.onReceive(...keyboardWillShowNotification) { _ in keyboardUp = true }
```

The flag flips with no animation while the keyboard rises on its own spring,
so the field steps 17pt in one frame and then rides the keyboard. It is in
every bar: chat, drawer, rest bar, plan, journal. Likely part of "jolt out";
confirm on a recording.

Proposed: animate the flip on the keyboard's curve.

```swift
{ note in
    let d = (note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
    withAnimation(.spring(duration: d, bounce: 0)) { keyboardUp = true }
}
```

or `Spring(mass: 3, stiffness: 1000, damping: 500, allowOverDamping: true)`,
the community-measured keyboard spring; tune side by side with the keys.

### 6. Rows in the foot move with the keyboard, not against it. Low

- `CrewChatSheet.swift:265`: focusing the field folds the + row on
  `motionSnappy` while the keyboard rises on its own curve.
- `CrewChatSheet.swift:968-969`: + drops the keyboard and raises the row at
  once, two springs crossing.
- `DaySheet.swift:817` and `:830`: the Journal's Suggest row springs in on
  `motionSnappy` as the keyboard comes.

Proposed: use the keyboard curve token from fix 5 for these (they are
keyboard-driven changes), and make the inserted rows `.opacity` only, no
`.move(edge: .bottom)` (`CrewChatSheet.swift:959, 963`), so nothing travels
against the keys.

### 7. One "after it has landed", from the animation, not a guess. Low

`CrewChatSheet.swift:240` (360ms), `ChatPlus.swift:204` (380ms),
`DaySheet.swift:527` (500ms), `DaySheet.swift:986, 994` (350ms).

Proposed: for the drawer, open with
`withAnimation(GridConstants.drawerMove) { showsChat = true } completion: { ... }`
at `CrewTowerView.swift:140` and hand focus over there. For system sheets,
which give no completion, one token,
`GridConstants.afterSheetLands: Duration = .milliseconds(450)` (the value
`afterSheet` at `CrewChatSheet.swift:1119` already uses), at every site.

### 8. Reduce Motion fades the drawer instead of sliding it faster. Low

`ChatRestBar.swift:231, 235`: under Reduce Motion the offset still travels,
on `crossFade` (0.2s). That is a fast slide.

Proposed: `.offset(y: isOpen || reduceMotion ? 0 : open + 60)` and
`.opacity(isOpen ? 1 : 0)` under Reduce Motion only.

### 9. The rest bar hands off to the drawer instead of fighting it. Med

`ChatRestBar.swift:121-130` with `:231`. Dragging the bar lifts it 30pt at
most; on release it springs DOWN on `motionSnappy` while the drawer rises UP
from below the screen. Two objects, opposite ways, and the drawer appears from
under the bar rather than out of it ("opening chats ... jolt out").

Proposed, smallest version: no spring back when it opens (`lift` stays until
the drawer covers it, reset in completion), and decide with
`predictedEndTranslation` so a flick opens. Full version: the drag sets
`showsChat` at once and feeds the drawer's `pull`, so one panel follows the
finger from the bar to wherever it is let go (fixes 1 and 2 make this
possible).

### 10. The whole top of the drawer is a handle, as a sheet's is. Low

`ChatRestBar.swift:183-199`: only the 22pt grabber strip drags. Plan, Journal
and Edit can be pulled from their title rows and from content scrolled to the
top. Proposed: move the `DragGesture` to wrap the grabber and
`ChatDrawerTitle` together (about 70pt); leave the thread's own scroll alone
for now (scroll-to-drag hand-off is a later, Med step).

### 11. The crew plan is the plan. Owner + Med

`ChatPlus.swift:150-206` against `DaySheet.swift:549-570`. Proposed, to make
"the plan with crew and the plan feel the same":

- Same field: `DayComposer` with `glassField` at the foot, not a
  `glassCapsule` at the top (`ChatPlus.swift:156-163`).
- Same order: days row on top, weekday chips just above the bar
  (`ChatPlus.swift:168-172` sits them under the row today).
- Same title shape: "Plan" in the two-tone title with the crew
  ("Plan / Roommates", `TwoToneTitle`), as the plan's own sheet names itself.
- Height: keep a short sheet (his "opens too high", 2026-10-14) but as a
  `.height` that fits the bar plus the keyboard, measured once.
- Question for him: the crew plan confirms with Plan in the toolbar
  (`docs/ten.md` rule 3); your plan sends with the arrow. Same gesture, or keep
  the confirm?

### 12. Drawer corners. Owner

`ChatRestBar.swift:111, 212, 217, 224`: 8pt top corners against the
system's device-concentric sheets that open on top of it (crew plan,
stickers). Options: keep 8 (his "rounded only where it meets the tower"), or
`radiusSurface` 20, or iOS 26 `ConcentricRectangle`. A look call, not a fix.

### 13. Optional: Plan, Journal and Edit grow out of their button. Med

iOS 26's sheet morph: `matchedTransitionSource` on the `DayIcon` /
`JournalButton` glass, `.navigationTransition(.zoom(sourceID:in:))` on
`DaySheet`. The app already uses the zoom for photos
(`PhotoCollectionView.swift:124`). Reported glitchy in early betas; try on one
sheet first.

### Not changed, on purpose

- `presentationBackground { WarmBackground() }` on every sheet opts out of iOS
  26's part-height glass. Deliberate (dark on dark; the tower's colours bled
  through glass, `AddWinSheet.swift:548`). Leave it.
- `CrewChatSheet.swift:215-220` (detents, background interaction) and the
  `NavigationStack` branch at `:171` are unused now: the only caller
  (`CrewTowerView.swift:313`) passes `close`. Harmless; delete in a tidy pass
  so nobody tunes the wrong height.

---

## Order to do it in

3, 4, 7, 8, 10 (all Low, one sitting). Then 1 + 2 together, then 9 on top of
them. 5 and 6 together, filmed against the keyboard. 11 and 12 after he
answers.

[wwdc18]: https://developer.apple.com/videos/play/wwdc2018/803/
[wwdc23s]: https://developer.apple.com/videos/play/wwdc2023/10158/
[wwdc23e]: https://developer.apple.com/videos/play/wwdc2023/10156/
[wwdc24]: https://developer.apple.com/videos/play/wwdc2024/10145/
[wwdc25]: https://developer.apple.com/videos/play/wwdc2025/323/
[nilc]: https://nilcoalescing.com/blog/PresentingLiquidGlassSheetsInSwiftUI
[kbd]: https://developer.apple.com/forums/thread/48088
