# The crew chat as a native sheet

Research, 2026-10-15 (written 2026-10-14). Nothing in the app was changed for
this. It is read against `main` at `92f64ba` (Build 144):
`Strata/Views/Crews/ChatRestBar.swift` (`ChatRestBar`, `ChatDrawer`,
`DrawerPanel`), `Strata/Views/Crews/CrewTowerView.swift` (hosts both, lines
161-178 and 348-364), `Strata/Views/Crews/CrewChatSheet.swift` (the thread),
`Strata/Views/MainAppView.swift:611-628` and
`Strata/Views/Crews/CrewsListView.swift:765-773` (the Crews stack).

**Tags.** (a) Apple documentation or a WWDC session. (b) Seen in a shipping
app, Apple's own unless named; re-check on a device running the current
iOS 26 point release before relying on it. (c) Inference from the code or from
how UIKit presentation works; each one says what would prove it.

---

## 0. Read this first: two things the owner has to hear before the build

1. **The "weird curve at the bottom" comes back, and there is no switch for
   it.** Commit `3851bfa` (2026-10-14) replaced a system sheet with the custom
   drawer because of exactly this: his words were "there is a weird curve at
   the bottom". On iOS 26 every partial-height sheet floats inset from the
   screen edges with corners concentric to the display, and only `.large`
   attaches edge to edge (a, WWDC25 "Build a SwiftUI app with the new design":
   "partial height sheets are inset by default", "At smaller heights, the
   bottom edges pull in, nesting in the curved edges of the display"). There is
   no public API to keep a small detent full width: the Developer Forums thread
   asking for one has no answer from Apple (b, thread 788849), and another
   project that tried found it insets "regardless of corner radius or
   background" and built its own tray (b, koan PR #988). A custom
   `presentationBackground` removes the glass, not the inset (b, Nil
   Coalescing; motion-pass item 9 in `docs/motion-pass-2026-10-14.md`).
   So the resting line becomes a floating rounded card, the way Maps' search
   card rests on iOS 26 (b). **If that look is still a no, a native sheet is
   the wrong tool**, and the fix for "not responsive and clean" is in the
   custom drawer instead.
2. **A persistent sheet owns the screen's presentations.** While any sheet is
   up, the crew screen underneath can no longer present anything: UIKit lets
   a view controller present one controller at a time (a, `UIViewController`
   `present(_:animated:completion:)`), and SwiftUI alerts and covers attached
   under an open sheet fail with "already presenting" (b, Swift Forums
   "UIKit error when attempting to present an alert while a fullscreen cover
   has not yet been dismissed"). The crew screen presents a lot today: the
   photo viewer cover, the week's Replay cover, Crew Info, the report dialog,
   Add a Win (from `MainAppView`), the tagged-win prompt. Every one of them has
   to move INTO the chat sheet (section 3.6). That is the real size of this
   job, more than the sheet itself.

Recommendation: build section 3 as a spike behind a debug flag
(`-strataNativeChat 1`), put it in his hands on a device, and only delete
`ChatDrawer` after he has seen the resting card.

---

## 1. Building a persistent bottom sheet (the Maps / Find My shape)

### 1.1 The modifiers, all on the sheet's CONTENT

```swift
.sheet(isPresented: $chatUp) {
    CrewChatSurface(...)                                   // section 3.3
        .presentationDetents([ChatDetent.rest, ChatDetent.reading, .large],
                             selection: $chat.detent)
        .presentationBackgroundInteraction(.enabled(upThrough: ChatDetent.reading))
        .interactiveDismissDisabled()
        .presentationDragIndicator(.visible)
        .presentationBackground { WarmBackground().ignoresSafeArea() }
        .presentationContentInteraction(.automatic)
}
```

- `presentationDetents(_:selection:)`: the heights it may rest at, and a
  binding that both reports where the person left it and moves it when you
  set it (a, Apple docs; introduced in WWDC22 "What's new in SwiftUI"). Set the
  binding inside `withAnimation` or bare; a change through the binding
  animates (b, FB19252983 write-up, SwiftUI Garden).
- `presentationBackgroundInteraction(.enabled(upThrough:))`: at or below that
  detent the content behind is not dimmed and takes touches; above it, it is
  dimmed and modal (a, Apple docs, iOS 16.4). This is what keeps the tower and
  the heads alive under the resting chat, as Maps keeps the map (b).
- `interactiveDismissDisabled()`: a drag down at the smallest detent can no
  longer close it. It blocks the GESTURE only; `isPresented = false` and
  `dismiss()` still close it (a, Apple docs). That second half is a trap:
  see 2.10.
- `presentationDragIndicator(.visible)`: the system grabber. Drop
  `ChatRestBar`'s own `Capsule` (lines 39-43) and `ChatDrawer`'s (299-308).
- `presentationCornerRadius(_:)`: available (a, iOS 16.4), but on iOS 26 it
  does not undo the inset (b, koan PR #988). Leave it unset so the corners
  stay concentric with the phone; `GridConstants.panelRadius` (38) was copied
  from the system sheet's corner in `01aecb1` and becomes unnecessary.
- `presentationBackground`: keep `WarmBackground`. It opts the sheet out of
  Liquid Glass (a, WWDC25 323 recommends removing it to GET the glass; we keep
  it to NOT get it). The app's dark-on-dark rule and the owner's "on dark mode
  the chat around it is too bright" (`3851bfa`) both want the chat's own
  ground; every other sheet in the app already does this.
- `presentationContentInteraction`: `.automatic` (default) lets a scroll view
  that is at its edge resize the sheet; `.scrolls` makes a drag on the content
  always scroll; `.resizes` makes it always resize (a, Apple docs, iOS 16.4).

### 1.2 What iOS 26 does with it

- At `rest` and `reading`: inset, concentric corners, and, with the default
  background, Liquid Glass. With ours: inset, concentric corners, opaque warm
  ground (a, WWDC25 323; b, Nil Coalescing).
- At `.large`: "the glass background gradually transitions, becoming opaque
  and anchoring to the edge of the screen" (a, WWDC25 323). With our opaque
  ground the visible change is the card widening to the edges as it rises (c).
- A sheet can morph out of the button that opened it with
  `matchedTransitionSource` and `.navigationTransition(.zoom)` (a, WWDC25
  323). Not for a sheet that is always up, and on 26.3 the zoom can ignore
  detents entirely (b, FB22262829, mberk.com). Do not use it here.

### 1.3 The resting detent, as its own type

Use a `CustomPresentationDetent`, not `.height(x)`:

```swift
/// The chat at rest: the newest line and the composer, nothing more.
struct ChatRestDetent: CustomPresentationDetent {
    static func height(in context: Context) -> CGFloat? {
        // Measured, section 3.2. Grows with Dynamic Type: the line and the
        // field are .body.
        let base: CGFloat = 112
        let metrics = UIFontMetrics(forTextStyle: .body)
        let traits = UITraitCollection(preferredContentSizeCategory:
                                       UIContentSizeCategory(context.dynamicTypeSize))
        return min(metrics.scaledValue(for: base, compatibleWith: traits),
                   context.maxDetentValue * 0.3)
    }
}

enum ChatDetent {
    static let rest = PresentationDetent.custom(ChatRestDetent.self)
    static let reading = PresentationDetent.fraction(0.62)   // CrewChatSheet.drawerHeight today
}
```

Why a type: its identity never changes while its height can (Dynamic Type,
rotation). A `.height(measured)` built from a measured `@State` is a new detent
every time the number moves, and when the selected detent drops out of the
set SwiftUI switches WITHOUT animation (b, FB19252983). `Context` reads
environment values by dynamic member lookup and gives `maxDetentValue` (a,
`PresentationDetent.Context` docs).

---

## 2. Pitfalls, each with its mitigation

### 2.1 The sheet looks different from what he approved (section 0.1)
Mitigation: show him first. Nothing in code fixes it (a, b).

### 2.2 Presenting anything else while the chat is up (section 0.2)
SwiftUI presents a `.sheet` from the nearest presenting controller; while the
chat sheet is up, a `.fullScreenCover`, `.sheet`, `.alert` or
`.confirmationDialog` attached to `CrewTowerView` (or to `MainAppView` above
it) has nothing to present from and is dropped with an "already presenting"
log (a, UIKit `present`; b, Swift Forums thread 58409, Developer Forums
discussions of alerts under sheets).

Mitigation: **every presentation the crew screen makes is hosted inside the
chat sheet's content** (section 3.6). Present FROM the sheet:
- `fullScreenCover` from the sheet covers the whole screen. It looks exactly
  as a cover from the tower does today. No sheet-on-sheet look. (c, verify on
  device that the cover's dismissal lands back on the sheet at the detent it
  left.)
- `.sheet` from the sheet stacks: the new sheet rises over the chat card. This
  is the look he rejected ("a sheet opening on top of a sheet I dont like
  that", `538f5eb`). Avoid it for the + choices (section 3.5).
- Alerts and confirmation dialogs from the sheet's content work (b, the
  Developer Forums advice is to attach the alert to the view that is actually
  presenting).

The dismiss-then-present alternative (what `alone(_:)`,
`CrewChatSheet.swift:1209-1218`, does today) still works with a native sheet,
but it now removes the resting line from the screen for the length of the
other presentation and slides it back after: the churn he dislikes, made more
visible. Keep it only as the fallback for Add a Win if 3.5 cannot host it.

Timing, wherever a dismiss must precede a present: a presentation asked for
while another is still dismissing is dropped, and a rapid re-present can
ignore its detents (b, FB17115890 on 18.4, FB22262829 on 26.3). Use the sheet's
`onDismiss` or the child's own completion rather than a sleep. Where a sleep is
unavoidable the app already settled on 450 ms (`afterSheet`,
`CrewChatSheet.swift:1241`), and the motion pass proposed naming it
`GridConstants.afterSheetLands` (`docs/motion-pass-2026-10-14.md`).

### 2.3 Back button while the sheet is up
The sheet's lifetime is tied to the view that presents it; when that view is
popped, SwiftUI tears the sheet down as part of the pop, and developers report
it "hangs for a second before disappearing" (b, Hacking with Swift forum
28459). Overlapping a sheet dismissal with a `NavigationPath` change has also
left the hierarchy with every button disabled (b, Developer Forums question
mirrored at spiceai), and a path bound to a stack changes only once the view
has finished returning (b, Fatbobman, "delayed state updates").

Mitigation: one exit, `leaveCrew()`, used by the back button
(`BackToCrews`, `CrewTowerView.swift:745`), the escape action (`:375`), "This
crew has ended" (`:205-210`) and Crew Info's Leave (`onLeft: onBack`, `:342`):

```swift
private func leaveCrew() {
    // 1. A still copy of the resting card joins the page, so it slides out
    //    with the page (section 3.7).
    // 2. The real sheet goes, with no animation of its own.
    var quiet = Transaction(); quiet.disablesAnimations = true
    withTransaction(quiet) { restReplica = true; chatUp = false }
    // 3. Pop on the next turn of the run loop, after UIKit has the dismissal.
    Task { @MainActor in await Task.yield(); onBack() }
}
```
(c) Measure: pop with the sheet at rest, at reading and at large with the
keyboard up; the sheet must be gone in the first frame of the pop.

### 2.4 Swipe back
The crew tower hides its navigation bar (`.toolbar(.hidden, for:
.navigationBar)`, `:190`) and, unlike pages with `.glassBackButton()`, does not
install `SwipeBackKeeper` (`Strata/Views/GlassBackButton.swift:56-90`), so the
edge swipe is probably off there today (c, verify on device; iOS 26 also adds a
content-area pop gesture to `UINavigationController`, check that too). If a
pop gesture can start while the chat is presented, the sheet stays over the
list for the whole interactive pop and is removed only when it commits (c).
Mitigation: keep the gestures off while the chat is presented, or adopt
`SwipeBackKeeper`'s delegate and run step 1-2 of `leaveCrew()` in
`gestureRecognizerShouldBegin`, restoring the sheet if the pop is cancelled.
Start with off; it is how the page behaves now.

### 2.5 Other ways the crew can stop being on screen
- A notification routes to another crew (`router.open`,
  `CrewsListView.swift:775-778`) and replaces the path under the sheet.
- The selected tab changes (a widget, a notification, Add Win's routing)
  while a crew is pushed. A sheet presented inside one tab stays on screen
  over the next tab, because the presentation sits above the tab controller
  (c, verify).

Mitigation: `chatUp` is derived, never stored alone:
`chatUp = isShown && pushLanded && !leaving`. `isShown` already reaches the
crew stack (`CrewDestinations(isShown: selectedTab == .crews)`,
`MainAppView.swift:617`); pass it to `CrewTowerView`. Route path changes made
while a crew is open through `leaveCrew()` first.

### 2.6 The sheet arriving with the push
Presenting while a push transition is running is at best deferred by UIKit
and at worst logged as an unbalanced transition (c). Even when it works, a
sheet rises from the bottom while the page slides in from the right: two
motions on two axes. Maps avoids the question because its sheet is there from
launch (b).
Mitigation, the same replica as 2.3 run forwards (section 3.7): the page
carries a still copy of the resting card in its own layout, so it slides in
with the push; when the push has landed (`onAppear` plus one run-loop turn,
or the navigation controller's transition coordinator) the real sheet is
presented with animations disabled exactly over it, and the copy is removed in
the same transaction. If the copy and the card are not pixel-identical the swap
shows as a one-frame jump; that is the check (c).

### 2.7 The keyboard with a small detent
At a partial detent the system moves the sheet for the keyboard; reports
include a sheet shoved to full height by focus at `.medium` (b, secondary,
citing Developer Forums), extra padding above and below a field in a
`.height` sheet (b, thread 744436), and focus problems inside custom-height
sheets (b, thread 804528). Maps sidesteps all of it: focusing its search field
takes the sheet to full height first (b). The owner asked for the same:
"its okay for the main chat to go full screen and then the name appear"
(`9ec0722`).
Mitigation: never focus the field below `.large`.

```swift
// Anything that wants to write: the resting field, Reply on a hold, Send.
func write() {
    withAnimation { chat.detent = .large }
    chat.wantsKeyboard = true            // the sheet focuses on landing
}
// In the sheet:
.onChange(of: chat.detent) { _, now in
    if now != .large { writing = false }        // dragged down: keys go
    else if chat.wantsKeyboard { chat.wantsKeyboard = false; writing = true }
}
```
(c) Measure both orders: focus in the same transaction as the detent change
(one motion if UIKit coordinates them) against focus on landing (two motions,
the "both rising at once was a jolt" note in `CrewChatSheet.swift:272`).
Pick by film.
What goes away: `ChatDrawer`'s keyboard notifications and `keysOver` lift
(`ChatRestBar.swift:241, 319-326`), `ChatDrawerWriting`, and `BarSink`'s
keyboard flip inside the chat. Inside a sheet the composer in a
`.safeAreaInset(edge: .bottom)` rides the keyboard on the keyboard's own curve
(a, SwiftUI keyboard safe area), which was the motion pass's rule 8.

### 2.8 Scroll views inside detents
A bottom-anchored thread at `reading`, with `.automatic`: a finger moving DOWN
scrolls to older lines; at the oldest line, continuing down lowers the sheet;
a finger moving UP at the newest line raises the sheet to `.large` (a, Apple
docs on `presentationContentInteraction`; c for the bottom-anchored case).
That is the M9 spec's "scroll the thread past its top: rest"
(`docs/qol-research-2026-10-13.md:124-125`). If reading old lines keeps
dragging the sheet, switch to `.scrolls` and let only the grabber, the title
row and the composer move it.
Performance: a sheet's content is re-laid out at each height during an
interactive drag (c, measure with `PerfProbe`): `3923369` measured a 148 ms
frame when the old drawer resized its chat. Keep `GeometryReader` out of the
thread, keep the `LazyVStack`, and at `rest` disable scrolling.

### 2.9 The tower behind the sheet
- Tappable and draggable at `rest` and `reading` via
  `presentationBackgroundInteraction(.enabled(upThrough: ChatDetent.reading))`
  (a). Dimmed and inert at `.large` (a).
- **Anything the page draws over its foot now draws UNDER the sheet** (c):
  the reaction bar and its Reply capsule on a low block, the head fan, a head
  dragged down, `reportAnchor`. Heads must treat the card's top edge as a
  floor: feed the measured card top into `parking.controls["chat"]` (today
  set from `ChatRestBar`'s frame, `CrewTowerView.swift:174-177`).
- The tower's base must stand above the resting card, not behind it: a
  constant bottom inset equal to the rest height (section 3.4).

### 2.10 `dismiss` inside the sheet closes the chat
`interactiveDismissDisabled` does not stop `@Environment(\.dismiss)` (a). Any
view swapped into the sheet that calls `dismiss()` (all of the + sheets do:
`GroupPlanSheet`, the sticker sheet, `CrewStripSendSheet`, `AddWinSheet`)
would close the persistent chat and leave the crew with no chat at all.
Mitigation: hosted inside the chat, they take a `done` closure that returns
the sheet to the chat page; grep each for `dismiss` before hosting it.

### 2.11 Reduce Motion
The system sheet slides and changes detent on UIKit's own spring; there is no
API to swap it for a dissolve (c: none found). The app's rule
(`docs/apple-design.md` section 14) is a dissolve under Reduce Motion, which
`ChatDrawer` honoured. Mitigation: set `chat.detent` without animation when
`accessibilityReduceMotion` is on (verify that a transaction with
`disablesAnimations` reaches the detent change, c), and accept the system's own
presentation for the person's drags, as every other system sheet in the app
already does.

### 2.12 VoiceOver
- The system grabber is an accessibility element that changes the detent (c,
  verify the label and that it cycles three detents).
- A sheet with background interaction is not modal at its low detents; check
  that VoiceOver can reach the tower at `rest` and cannot at `.large` (c).
- Escape: with dismissal disabled, the two-finger scrub should LOWER the sheet,
  not close it: `.accessibilityAction(.escape) { chat.detent = ChatDetent.rest }`
  on the sheet's content, replacing `ChatDrawer`'s.
- Keep `ChatRestBar`'s spoken label, value and "Open the chat" action on the
  resting line (M9 spec, `docs/qol-research-2026-10-13.md:134-136`).

### 2.13 The hidden tab bar
`.toolbar(crewTabBarHidden ? .hidden : .visible, for: .tabBar)` lives on the
Crews stack (`MainAppView.swift:623`) and animates back when the path empties.
The sheet is above the tab controller, so it neither moves with nor is moved by
the tab bar (c). The only collision is the pop: if the sheet is still
dismissing when the tab bar animates in, they overlap for a few frames. 2.3's
order (sheet gone first, then pop) removes it.

### 2.14 Backgrounding
A presented sheet survives backgrounding and comes back at its detent (c). The
keyboard does not: on return the field is unfocused at `.large`. Either lower
to `reading` on `scenePhase == .background` when nothing was typed, or leave it;
Messages leaves it. The live loop (`CrewTowerView.swift:304-333`) keeps
running under the sheet, as it does under the drawer.

### 2.15 iOS 26 detent bugs on record (2025-2026)
| Report | What | Status | Our exposure |
|---|---|---|---|
| FB19252983 (SwiftUI Garden) | When the selected detent leaves the set, the switch is not animated | Open as written | Never remove the selected detent; use the `CustomPresentationDetent` type (1.3); to add a temporary detent, add it, then select it; to remove it, select another, then remove it on the next turn |
| FB22262829 (mberk.com), iOS 26.3 | Zoom-transition sheets ignore detents and open full size, worst on a fast re-present | Open as written | Do not use the zoom transition on the chat |
| FB17115890 (Dev Forums 779671), iOS 18.4 | A rapid second presentation ignores detents | Not shown fixed | Do not dismiss and re-present the chat quickly (2.2) |
| Dev Forums 803092 | Selection binding not updated by the system for an inspector-as-sheet on iPhone; Apple engineer asked for a report | Open | We use `.sheet`, not `.inspector`; still log `chat.detent` on drag in the spike |
| Dev Forums 788849 | No full-width small detent on iOS 26 | No API | Section 0.1 |
| Dev Forums 804528 | Focus problems in a `.height` sheet | Unresolved | Never focus below `.large` (2.7) |

---

## 3. The recommended architecture for the crew

### 3.1 Where the sheet hangs
On `CrewTowerView`, not on the Crews `NavigationStack` root.
- On the tower, the sheet belongs to one crew: it cannot survive onto the
  list or into another crew, and the crew's state (`answeringWin`, the
  presentations in 3.6) is in reach (c).
- On the stack root it would outlive the crew and need its own rule for every
  path change, and it would sit above the list during the pop (c).
- The price is 2.3 to 2.6, all handled by one derived `chatUp` and one
  `leaveCrew()`.

A small `@Observable` object owned by the tower carries the state both sides
need, so the sheet does not rebuild the tower and the tower does not reach into
the chat:

```swift
@Observable final class CrewChatPresence {
    var detent: PresentationDetent = ChatDetent.rest
    var wantsKeyboard = false
    var answeringWin: UUID?
    var restTop: CGFloat = 0              // the card's top edge, for heads
    var cover: CrewCover?                 // 3.6
    var page: ChatPage = .thread          // 3.5
    var showsInfo = false
}
```

### 3.2 The resting height, measured from `ChatRestBar`
From `ChatRestBar.swift:38-104` and `GridConstants` (c, by arithmetic; confirm
with `onGeometryChange` in the spike):

| Part | Points |
|---|---|
| Top padding above our grabber (`gapTight`) | 8 |
| Our grabber | 5 |
| Gap (`gapTight`) | 8 |
| The newest line: `.body` text about 22 plus `(spacing + 2) * 2` = 12; floor 28 | 34 |
| Gap (`gapTight`) | 8 |
| The composer (`GlassIconButton.defaultSide`) | 44 |
| `BarSink`: `gapTight - barSink` = 8 - 17 | -9 |
| **Today, above the home indicator band** | **98** |

In the sheet our grabber goes (-13) and the system's needs its band at the top
(about 16-20, c), and `BarSink`'s 17-point sink into the home-indicator band
should not be carried into a card that already stands off the bottom edge.
Start at **112** (16 band + 34 line + 8 gap + 44 composer + 10 foot) and set the
final number from the spike's measurement, at default and at the largest
non-accessibility text size. Whether a custom detent's height includes the
bottom safe area on an inset iOS 26 sheet is exactly the thing to measure (c).

### 3.3 One object: the sheet IS the resting line and the composer
Replace both `ChatRestBar` and `ChatDrawer` with one view in the sheet,
`CrewChatSurface`, built from `CrewChatSheet`'s page:

```
CrewChatSurface
├── title row ("Today"; the crew's name at .large)  hidden at rest
├── thread (bottom-anchored LazyVStack)             crossfades with ↓ at rest
├── newest line (ChatRestBar.latest, one line)      shown at rest only
└── composer (+, field, Send)  .safeAreaInset(edge: .bottom)   never moves
```

- The composer is the same view at every detent, pinned to the bottom, so it
  stays under the thumb while the card grows above it. That is the "same exact
  drawer" he asked for in `3923369`, done by the system instead of
  `DrawerPanel`.
- At `rest` the thread is not the right thing to show: its newest item might
  be a photo or a strip, far taller than one line. Show `ChatRestBar.latest`
  (the friend's face and one-line bubble, `ChatRestBar.swift:150-178`) and
  crossfade to the thread as the detent leaves `rest`
  (`.opacity(chat.detent == ChatDetent.rest ? 1 : 0)` on one,
  the inverse on the other, `GridConstants.crossFade`).
- At rest the field is a button that calls `write()` (2.7), as it is today
  (`ChatRestBar.swift:73-88`); + calls `write()` with the + row out; Send with a
  draft calls `write()`. The line itself and a drag up go to `reading`.
- "Seen": `markChatSeen` when the detent LEAVES `rest`, not on presentation
  (M9: at rest you have read one line at most). `visible` in `CrewChatSheet`
  becomes `chat.detent != ChatDetent.rest`.
- Title: "Today" at `reading`, the crew's name at `.large`
  (`ChatDrawerTitle`, `CrewChatSheet.swift:1553-1582`; read `chat.detent`
  instead of `chatDrawerFull`). Done lowers to `rest`; it never dismisses.
- A light haptic on reaching a detent:
  `.sensoryFeedback(.selection, trigger: chat.detent)` (a), replacing
  `ChatDrawer`'s `HapticsEngine.lightTap()` on landing.
- Three detents or two: the brief says rest and full screen. `reading`
  (0.62) is his own earlier ask ("popping up enough to see the chat",
  `3851bfa`). Recommend keeping it; it is his call (question 2 below).

### 3.4 The tower's foot: covered, never pushed
His call (`3923369`): "The tower never moves; the open chat covers its foot."
A sheet does not change the presenting view's safe area, so the tower stays put
as the sheet rises (c). What the page needs is a CONSTANT inset equal to the
resting card, so that at rest the tower's base stands above the card exactly as
it stands above `ChatRestBar` now:

```swift
.safeAreaInset(edge: .bottom, spacing: 0) {
    // The resting card's room, never the live detent: the tower does not
    // move when the chat rises; the chat covers its foot.
    Color.clear.frame(height: chat.restRoom)      // restHeight + the card's
}                                                 // bottom margin on iOS 26
```

`chat.restRoom` comes from the sheet content's own
`onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }` read while the
detent is `rest` (and only then), which also gives `restTop` to the heads
(2.9). Never bind this inset to the live detent: that is the "pushed up"
version he did not choose.

### 3.5 The + choices without a sheet on a sheet
Maps and Find My change what their one sheet SHOWS instead of stacking sheets:
a place card replaces the search card inside the same sheet; a person replaces
the People list (b). Do the same:

```swift
enum ChatPage: Hashable { case thread, plan, stickers, strip, memory, win }
```

- The surface's root switches on `chat.page` (a `ZStack` with
  `.transition(.opacity)`, or a push-style `.move` when Reduce Motion is off).
  Choosing Plan sets `chat.page = .plan` and the detent the page wants;
  Cancel or Send sets `.thread` and returns the detent to where it was.
- Each + sheet today wraps its own `NavigationStack` and sets its own
  `.presentationDetents` (`ChatPlus.swift:163, 200, 591, 642, 671, 728`;
  `AddWinSheet.swift:288, 536`). Hosted in the surface, one stack at a time is
  fine (only the chat page's title row is not a stack), but **move every
  `.presentationDetents` out to the call sites** so the inner page's modifier
  cannot fight the chat's (c), and replace their `dismiss()` with `done`
  (2.10).
- Heights: Stickers, Strip, Memory and Win at `.large`. Plan is short by his
  ask ("opens too high", 2026-10-14). Either show it at `reading`, or add a
  fourth detent only while Plan is up (add it, then select it; select another,
  then remove it, per FB19252983), so the person cannot drag to it from the
  chat.
- Full-screen things stay full-screen covers, presented FROM the surface: the
  picture viewer (`CrewChatSheet.swift:386`) and the plan strip (`:396`). A
  cover is not a sheet on a sheet.
- `returnToChat`, `reopen`, `alone(_:)` and the 450 ms re-present
  (`CrewChatSheet.swift:170-180, 1206-1218`) all go.
- Add a Win is the hard one: it is presented by `MainAppView` (`winDraft`,
  `:716`) so that a win made in a crew is made the same way as on Wins. Host
  `AddWinSheet` as `.win` in the surface with the crew ticked, keeping its save
  path, or, if its `NavigationStack` and toolbar do not survive being hosted,
  fall back to dismiss-then-present for this one choice (2.2). Decide in the
  spike.

### 3.6 Everything else the crew screen presents moves into the sheet
Each of these is attached to `CrewTowerView` today and would fail while the
chat is up (2.2). The tower SETS state on `CrewChatPresence`; the surface
PRESENTS:

| Today on the tower | Line | In the surface |
|---|---|---|
| Photo viewer `.fullScreenCover(item: viewingBinding)` | 365 | `.fullScreenCover(item: $chat.cover)` case `.viewer` |
| Week Replay `.fullScreenCover(item: $playingWeek)` | 297 | same, case `.replay` |
| Crew Info `.sheet(isPresented: $showsInfo)` | 335 | a `ChatPage.info` at `.large`, or a cover; not a stacked sheet |
| Report dialog `reportAnchor` | 368 | `.confirmationDialog` on the surface |
| Add a Win via `onAddWin` -> `MainAppView` | 357, 619 | 3.5 |
| `keepTaggedWin(isBusy:)` prompt | 370 | on the surface; `isBusy` reads `chat.page` and `chat.cover` |

The hold's Reply (`CrewTowerView.swift:626-641`) becomes:

```swift
closeReactions()
chat.answeringWin = id
write()            // detent .large, keyboard on landing (2.7)
```

No presentation happens, so no timing: the sheet is already there.

### 3.7 The still copy for the push and the pop
`ChatRestReplica`: the resting card drawn as the page's own view (the same
`latest` line and composer, a `ConcentricRectangle` or the measured corner, the
same inset margins and `WarmBackground`), placed where `restTop` says the card
is, `allowsHitTesting(false)`. Shown only during a push in (2.6) and a pop out
(2.3), swapped with the real sheet in a transaction with animations disabled.
It costs a duplicated layout to keep in sync; build the card's look as one
shared view used by both so they cannot drift.

### 3.8 What is deleted
`ChatDrawer`, `DrawerPanel`, `ChatDrawerFullKey`, `ChatDrawerWriting`
(`ChatRestBar.swift:210-467`), `chatCovering`, `chatSettled`, `restTop` as
tower state, the drawer's keyboard plumbing, the `alone`/`reopen` dance, and
`ChatRestBar` as a separate view (its `latest` moves into the surface). The
`#if DEBUG` `-strataCrewSheet chat` launch path (`CrewTowerView.swift:219`)
becomes `chat.detent = ChatDetent.reading`. The UI tests that walk the drawer
(`testChatOpenFeel`, `testChatPlusChoices`, named in `538f5eb`) need new
queries: the sheet's elements live in the presented hierarchy.

### 3.9 The spike's checklist
Film each on a device, at 1x and with Reduce Motion on:
1. The resting card, light and dark, beside today's bar. **Show him.**
2. Push in and pop out (back button) with the chat at rest, reading, and large
   with the keyboard up: no sheet over the list, no jump at the replica swap.
3. Reply from a hold: one motion or two, keyboard on landing.
4. + Plan, + Stickers, + Win: never two sheets on screen.
5. Tap a block at rest: the viewer opens. Tap the header's middle: Crew Info
   opens.
6. Drag the thread at reading: older lines scroll, the sheet does not move
   until the oldest line.
7. `PerfProbe` during a slow drag from rest to large: no frame over 16 ms.
8. VoiceOver: open, lower by escape, reach the tower at rest.

---

## Questions for the owner (to go in the structured picker)

1. The resting chat as a floating rounded card above the bottom edge (iOS 26's
   own look, the one called "a weird curve at the bottom" on 2026-10-14), or
   keep the flush custom drawer and make it more responsive?
2. Three heights (rest, part way to read, full to write) or two (rest, full)?
3. Crew Info while the chat is up: a page inside the chat at full height, or a
   full-screen cover?

---

## Sources

- (a) WWDC25, "Build a SwiftUI app with the new design", session 323:
  https://developer.apple.com/videos/play/wwdc2025/323/ (sheets at 6:20, 6:53,
  7:10)
- (a) WWDC22, "What's new in SwiftUI", session 10052 (detents):
  https://developer.apple.com/videos/play/wwdc2022/10052/
- (a) `presentationDetents(_:selection:)`:
  https://developer.apple.com/documentation/swiftui/view/presentationdetents(_:selection:)
- (a) `presentationBackgroundInteraction(_:)`:
  https://developer.apple.com/documentation/swiftui/view/presentationbackgroundinteraction(_:)
- (a) `presentationContentInteraction(_:)`:
  https://developer.apple.com/documentation/swiftui/view/presentationcontentinteraction(_:)
- (a) `interactiveDismissDisabled(_:)`:
  https://developer.apple.com/documentation/swiftui/view/interactivedismissdisabled(_:)
- (a) `presentationCornerRadius(_:)`, `presentationBackground(_:)`,
  `presentationDragIndicator(_:)`: same documentation family.
- (a) `CustomPresentationDetent` and `PresentationDetent.Context`:
  https://developer.apple.com/documentation/swiftui/custompresentationdetent
- (a) `UIViewController.present(_:animated:completion:)`:
  https://developer.apple.com/documentation/uikit/uiviewcontroller/present(_:animated:completion:)
- (b) Nil Coalescing, "Presenting Liquid Glass sheets in SwiftUI on iOS 26":
  https://nilcoalescing.com/blog/PresentingLiquidGlassSheetsInSwiftUI
- (b) Developer Forums 788849, "How to do full width .sheet() on iOS 26+ with
  small presentation detents?": https://developer.apple.com/forums/thread/788849
- (b) koan PR #988, edge-to-edge trays replacing iOS 26 inset sheets:
  https://github.com/radiosilence/koan/pull/988
- (b) SwiftUI Garden, FB19252983:
  https://swiftui-garden.com/Misc/iOS-26/Animation-when-selected-presentationDetent-for-sheet-must-change
- (b) mberk.com, FB22262829 (iOS 26.3): https://mberk.com/posts/ZoomNavTransitionBug/
- (b) Developer Forums 779671, FB17115890: https://developer.apple.com/forums/thread/779671
- (b) Developer Forums 803092 (selection binding): https://developer.apple.com/forums/thread/803092
- (b) Developer Forums 804528 (focus in a `.height` sheet): https://developer.apple.com/forums/thread/804528
- (b) Developer Forums 744436 (padding with the keyboard): https://developer.apple.com/forums/thread/744436
- (b) Swift Forums, alert while a cover is dismissing:
  https://forums.swift.org/t/uikit-error-when-attempting-to-present-an-alert-while-a-fullscreen-cover-has-not-yet-been-dismissed/58409
- (b) Hacking with Swift forum 28459, sheet hangs when its parent goes:
  https://www.hackingwithswift.com/forums/swiftui/why-won-t-sheet-dismiss-with-parent-view/28459
- (b) Fatbobman, delayed state updates and `NavigationStack`:
  https://fatbobman.com/en/posts/serious-issues-caused-by-delayed-state-updates-in-swiftui/
- (b) Apple Maps, Find My, Stocks on iOS 26: persistent inset sheets, search
  focus goes to full height, detail replaces the list inside the one sheet.
  Observed behaviour; re-check on the current point release.
