# The photo viewer, the way Photos does it

2026-10-14. Research and code audit, no Swift changed.

The owner, 2026-10-14: "the photo carousel isnt really styled accordingly
right now either look at what the photos app does it looks super clean and
proves that light and dark mode can exist when you zoom in then everything
disappears and it gets dark."

## 0. In five lines

1. Today both viewers are black in both appearances, always, and force the
   dark scheme on their chrome (`PhotoViewer.swift:134`, `:210`;
   `ChatPictureViewer.swift:46`, `:75`).
2. Photos is two states: at rest it follows light or dark; a tap, or zooming
   in, hides every control and the ground goes black.
3. The plan is one `chromeHidden` bool in `PhotoViewer`, a ground that is
   `WarmBackground` with a black layer faded over it, the chrome faded and
   made untouchable, and a single tap added beside the existing double tap.
4. Gestures that exist are kept as they are; the stage never changes size
   when the chrome toggles, so the picture does not move.
5. It changes the letter of one owner decision (caption "in the BLACK",
   CLAUDE.md:559) and the doc comment built to his reference
   (`PhotoViewer.swift:6-9`). Section 4 lists both for his yes.

## 1. What exists

### 1.1 `PhotoViewer` (Strata/Views/PhotoViewer.swift)

| What | Where | Today |
|---|---|---|
| Doc comment, "the picture is an object on a black field" | `:4-20` | Built to a reference the owner supplied |
| Ground | `:134` | `Color.black.ignoresSafeArea()` |
| Layout | `:147-185` | VStack of deck, date line, filmstrip; header overlaid on top; `topInset` 58, `bottomInset` `gapSection` |
| Crew reactions over the picture's foot | `:155-166` | `reactions(current)`, fixed to the bottom of the deck |
| Forced dark scheme on the whole ZStack | `:187-210` | `.environment(\.colorScheme, .dark)`; dialogs and share sheet sit outside it |
| Status bar | `:213` | `.statusBarHidden()`, always |
| VoiceOver escape | `:217` | `.accessibilityAction(.escape) { onClose() }` |
| Metrics | `:300-344` | `topInset` 58, `headerHeight` 44, `dateHeight` 56, `stripHeight`, `printInset` 16 |
| Deck | `:353-389` | Paging horizontal `ScrollView`, `scrollPosition(id:)`, live `onScrollGeometryChange` into `DeckPosition`, `scrollDisabled(isZoomed)` at `:387` |
| Zoom report | `:361` | `onZoomChanged: { isZoomed = $0 }` |
| Header | `:410-446` | Title `AppColors.onDarkStrong` at `:414`, close `GlassIconButton(systemName: "xmark", tint: .white)` at `:438` |
| Menu | `:448-520` | One `Menu` behind `GlassIconLabel(systemName: "ellipsis", tint: .white)` at `:517` |
| Date line | `:524-577` | Two lines in `AppColors.onDarkQuiet` at `:549` and `:564`, comment at `:546` says "The viewer is always dark" |

There is no single tap and no drag to dismiss in `PhotoViewer`. Closing is the
x, the escape action, or (only where the cover was presented with a zoom
transition) whatever the system zoom dismissal provides.

### 1.2 `PhotoPage` (same file, `:959-1163`)

- `Color.black` behind every page at `:982`; doc comment at `:945-949`
  ("The frame is black until the photograph is there").
- The print: fitted with `aspectRatio(_:contentMode:)`, corner
  `radiusSurface`, inset 16 (`:997-1009`).
- `.clipped()` at `:1032` keeps a zoomed picture inside its stage so it never
  runs under the chrome.
- `.gesture(magnify)` `:1037`, `.panWhenZoomed(zoomed ? pan : nil)` `:1053`,
  `.gesture(doubleTap)` `:1054`, `onChange(of: zoomed)` reporting up `:1055`.
- `magnify` `:1066-1080` reports only on commit: `zoomed` is
  `committedScale > 1.01`, so the viewer learns of a pinch when the fingers
  lift, not while they move.

### 1.3 `Filmstrip` (same file, `:783-934`)

Driven by `DeckPosition.live`; cards 46 x 60 with depth scaling; whole strip
is a scrub `DragGesture` (`:907`, `:918-933`); cards tap to select
(`:885`). Its cold slot is `quietFill` through `CachedImageView`, which is
why the scheme was forced dark (`:192-198`). `quietFill` is dynamic
(CategoryColors.swift:277), so on a light ground it is correct again.

### 1.4 `ChatPictureViewer` (Strata/Views/Crews/ChatPictureViewer.swift)

- Ground `Color.black` `:46`; one `PhotoPage` `:48-53`, offset and faded by
  the drag `:52-53`.
- Foot "Sam, 4:12 PM" in `onDarkQuiet` `:54-60`.
- Close and menu, `tint: .white`, forced dark `:62-75`.
- `.statusBarHidden()` `:78`; drag down to close, disabled while zoomed,
  `:79-87`; escape `:88`.

### 1.5 How each is presented

| Presenter | Line | Transition |
|---|---|---|
| `PhotoCollectionView` | `PhotoCollectionView.swift:118-124` | zoom from `PhotoGalleryGrid` cell |
| `MemoriesView` | `MemoriesView.swift:394-406` | zoom from `PhotoGalleryGrid` cell |
| `ReplayView` | `ReplayView.swift:163-173` | zoom from `"replayBlockPhoto"` |
| `DayAlbumDetailView` | `DayAlbumDetailView.swift:151-161` | none, slides up |
| `CrewDayView` | `Crews/CrewDayView.swift:53` | none, slides up |
| `CrewTowerView` | `Crews/CrewTowerView.swift:320`, `:458` | none, slides up |
| `CrewChatSheet` (chat viewer) | `Crews/CrewChatSheet.swift:329-338` | none, slides up |

Four of seven entries break CLAUDE.md:571-572 ("A photo opens out of its
thumbnail ... Not a sheet sliding up"). Not part of this pass, but it matters
for swipe-down (section 3.5).

## 2. What Photos does

Tags, as in the research notes: (a) Apple documentation, HIG or WWDC;
(b) shipping product, observed by the owner or a reviewer; (c) inference,
check on a device before relying on it.

1. **Hiding the chrome for the content is the sanctioned pattern.** HIG,
   Going full screen: "Prioritize content by temporarily hiding toolbars and
   navigation controls ... such as when viewing full-screen photos ... let
   people restore the hidden elements with a familiar gesture or action like
   tapping, swiping down". (a)
2. **At rest the viewer follows the system appearance.** HIG, Dark Mode:
   people "generally expect all apps and games to respect their preference",
   and "Avoid offering an app-specific appearance setting." The same page
   allows a dark-only interface "in rare cases" for immersive media, which is
   the reasoning the current viewer leans on; Photos itself does not take
   that exception at rest. (a for the guidance, b for Photos)
3. **A single tap toggles the chrome, and with it the ground goes black, in
   both appearances.** The owner's own description, and UIKit's
   `hidesBarsOnTap` is the system's version of the same toggle (Sarun W.,
   "How to Hide Navigation Bar on Tap in UIKit", which names Photos as the
   example). The black is Photos' choice, not a system default. (b)
4. **Zooming in enters the same immersive state.** The owner: "when you zoom
   in then everything disappears and it gets dark." (b) Whether zooming back
   out to fit restores the chrome by itself is not documented; this plan
   leaves it hidden until a tap. (c)
5. **Zoom gestures.** Apple's user guide: double tap or pinch out to zoom in,
   drag to see other parts, double tap or pinch closed to zoom back out; tap
   or drag the photo down to return. (a, iOS 14 to 16 editions of "View
   photos and videos on iPhone")
6. **The toolbar.** iOS 26 Photos puts share, favourite, info, edit and
   delete along the bottom, with copy, duplicate, add to album and metadata
   behind the top right. (b, AppleInsider, "Inside Photos in iOS 26")
   Strata keeps its single `⋯` by decision (`PhotoViewer.swift:405-409`,
   docs/ten.md:98-100); this pass does not change that.
7. **Open and close through the zoom transition.** WWDC24 session 10145:
   the zoom transition is "continuously interactive, allowing you to grab and
   drag it around, from the beginning or during the transition", and "these
   same APIs work with the fullScreenCover and sheet presentation APIs in both
   SwiftUI and UIKit". (a) UIKit's `UIViewController.Transition.ZoomOptions`
   has `interactiveDismissShouldBegin`, "A closure that determines whether an
   interactive dismissal can begin", which says the zoom carries its own
   interactive dismissal. (a) SwiftUI exposes no equivalent of that closure,
   so whether the system drag-to-dismiss fights the deck or a zoomed pan in
   `PhotoViewer` has to be tried on a phone. (c)
8. **A thumbnail strip.** Photos on iPhone has shown a scrubber of
   thumbnails at the foot of the one-up view across several releases; its
   exact presence and behaviour in iOS 26 on iPhone is not confirmed by any
   source found here. (c) Strata's `Filmstrip` is its own decision and stays.

## 3. The plan for this codebase

### 3.1 State

One bool in `PhotoViewer`, beside `isZoomed` (`:100`):

```swift
/// The Photos state: controls gone, the ground black. A tap toggles it,
/// zooming in enters it. Never set while VoiceOver is running.
@State private var chromeHidden = false
@Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

private var immersive: Bool { chromeHidden && voiceOver == false }

private func setChrome(hidden: Bool) {
    if hidden == chromeHidden { return }
    withAnimation(GridConstants.immersiveFade) { chromeHidden = hidden }
}
```

The ground, the chrome and the status bar all read `immersive`. One value, so
they cannot disagree, which is the same reasoning `DeckPosition` gives for the
strip.

New token, GridConstants.swift after `photoTitleFade` (`:572`):

```swift
/// The photo viewer going immersive and back: the ground darkening, the
/// chrome leaving, the status bar. One fade for all three. Opacity only,
/// nothing moves, so it is the same under Reduce Motion.
static let immersiveFade = Animation.smooth(duration: 0.25)
```

### 3.2 The ground and the inks

| Element | At rest | Immersive |
|---|---|---|
| Ground | `WarmBackground()` (light 0.992, dark 0.112 charcoal, WarmBackground.swift:90-94) | black |
| Title | `AppColors.inkPrimary` (14.9:1 light, 14.5:1 dark) | hidden |
| Date and place | `AppColors.inkSecondary` (6.9:1 light, 7.7:1 dark) | hidden |
| Close and `⋯` | `GlassIconButton` / `GlassIconLabel` with `tint: .primary, onPage: true` | hidden |
| Filmstrip | unchanged; `quietFill` is right on the page ground | hidden |
| Crew reactions | unchanged (they sit on the picture, `onDark: true` at CrewDayView.swift:79 is correct there) | hidden |
| Print | unchanged | unchanged |

The ratios are computed against `WarmBackground.top` with the WCAG formula.

**The crossfade rule (CLAUDE.md:574-580) decides the layering.** The page
ground is held underneath at full opacity and a black layer fades over it.
Animating one `Color` between two values would also work, but a stacked pair
can never composite to less than opaque, and it keeps `GroundField` intact:

```swift
/// The viewer's ground: the page at rest, black when immersive.
struct ViewerGround: View {
    let immersive: Bool
    var body: some View {
        ZStack {
            WarmBackground()
            Color.black.opacity(immersive ? 1 : 0)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
```

Put it next to `PhotoPage` so `ChatPictureViewer` uses the same one.

Changes, line by line:

- `PhotoViewer.swift:134`: `Color.black.ignoresSafeArea()` becomes
  `ViewerGround(immersive: immersive).onTapGesture { setChrome(hidden: chromeHidden == false) }`
  so a tap on the letterbox bands toggles too, as it does in Photos.
- `PhotoViewer.swift:187-210`: delete the `.environment(\.colorScheme, .dark)`
  and its comment. Its reason (light glass and a light `quietFill` on a black
  field) no longer exists: at rest the field is the page, and when the field
  is black nothing scheme-dependent is visible.
- `:414` `onDarkStrong` to `inkPrimary`; `:549`, `:564` `onDarkQuiet` to
  `inkSecondary`; rewrite the comment at `:546`.
- `:438` `GlassIconButton(systemName: "xmark", tint: .primary, onPage: true, ...)`;
  `:517` `GlassIconLabel(systemName: "ellipsis", tint: .primary, onPage: true)`.
  The `onPage` recipe exists for exactly this (GlassIconButton.swift:81-82,
  `GlassRecipe.onPage` near `:337`).
- `PhotoPage` `:982` `Color.black` becomes `Color.clear`. The page's
  `contentShape(Rectangle())` at `:1036` keeps the whole page touchable. Its
  doc comment at `:945-949` becomes "the frame is the ground until the
  photograph is there".

Dark mode at rest is charcoal 0.112, immersive is 0.0. That is a small step,
which is correct: it reads as the lights going down, not as a cut. If the
owner wants dark mode to be pure black at rest as Photos is, it is one line in
`ViewerGround` (question in section 4).

### 3.3 What fades

Everything except the print fades to 0 and stops taking touches. Nothing
slides and nothing resizes:

```swift
private extension View {
    /// Viewer chrome: gone, untouchable and unread while immersive.
    func viewerChrome(hidden: Bool) -> some View {
        self
            .opacity(hidden ? 0 : 1)
            .allowsHitTesting(hidden == false)
            .accessibilityHidden(hidden)
    }
}
```

Applied at:

- the reactions overlay content, `:162-165`
- `dateLine`, `:168-174`
- `Filmstrip`, `:176-178` (its scrub and card taps must not fire while
  invisible, so `allowsHitTesting` matters here most)
- `header`, `:181-182`

**The stage does not change size when the chrome goes.** The deck is sized
off fixed bands (`:149-154`), and the `dateHeight` note at `:310-325` already
records why a stage that resizes is worse than some empty ground: the picture
would jump on every tap. Photos overlays its bars rather than reflowing, so
holding the bands and fading what is in them is the same result.

The title's own `photoTitleFade` at `:415` keeps working; the chrome fade is
on the band, not the text.

### 3.4 Gestures

All existing gestures stay where they are. Two additions, both in
`PhotoPage`, both reported up through closures like `onZoomChanged` already
is:

```swift
// PhotoPage, beside onZoomChanged (:966)
var onTap: () -> Void = {}
/// Fired as soon as a pinch or a double tap starts going in, so the ground
/// darkens with the fingers rather than after them.
var onZoomIn: () -> Void = {}

private var singleTap: some Gesture {
    TapGesture(count: 1).onEnded { onTap() }
}
```

- `:1054` `.gesture(doubleTap)` becomes
  `.gesture(doubleTap.exclusively(before: singleTap))`. The single tap waits
  for the double tap to fail, which is the short delay Photos also has.
  No drag recogniser is added, so the deck's paging is not starved
  (CLAUDE.md's "an installed recogniser" rule, `:1038-1052`), but measure a
  swipe after the change anyway.
- `magnify.onChanged` (`:1068`): add
  `if value.magnification > 1.02 { onZoomIn() }`. `setChrome` ignores the
  repeats.
- `doubleTap`, the zoom-in branch (`:1110-1111`): call `onZoomIn()`.
- `PhotoViewer` deck (`:357-361`) passes
  `onTap: { setChrome(hidden: chromeHidden == false) }` and
  `onZoomIn: { setChrome(hidden: true) }`.
- Zooming back out leaves it immersive; a tap brings the chrome back, and
  the ground with it, even while zoomed.
- `.clipped()` at `:1032` stays for now. A later, separate step could clip
  only while the chrome is shown so a zoomed picture uses the whole black
  screen, as Photos does; that reverses a structural choice the comment at
  `:1012-1031` argues for, so it is not in this pass.

### 3.5 Swipe down to dismiss

`PhotoViewer` has none of its own. Do not add a SwiftUI `DragGesture` on the
viewer: it would sit on an ancestor of the paging deck and the zoomed pan,
which is the starvation case CLAUDE.md records.

1. Check on a phone whether the zoom presentations
   (`PhotoCollectionView.swift:124`, `MemoriesView.swift:405`,
   `ReplayView.swift:173`) already give a drag-down dismissal through the
   system zoom transition (section 2, item 7). If they do, the work is making
   the other four entries zoom too (section 1.5), which is CLAUDE.md:571
   being enforced, not a new idea.
2. If they do not, the dismissal goes in as a UIKit recogniser through
   `UIGestureRecognizerRepresentable` (iOS 18): a pan that only begins when
   the movement is downward, more vertical than horizontal, and `isZoomed`
   is false. While it tracks, the black layer in `ViewerGround` fades and the
   chrome is hidden, then either `onClose()` or a spring back.

### 3.6 Status bar and home indicator

- `:213` `.statusBarHidden()` becomes `.statusBarHidden(immersive)`.
- Add `.persistentSystemOverlays(immersive ? .hidden : .automatic)`.

At rest the clock shows, dark on light or light on dark, because the scheme is
no longer forced. `topInset` 58 (`:300`) already clears the status bar and the
Island, so the header does not move. Whether the status bar fades with
`immersiveFade` rather than snapping is a device check. (c)

### 3.7 VoiceOver, Reduce Motion, Reduce Transparency

- **VoiceOver:** `immersive` is false whenever VoiceOver runs, so the close,
  the menu, the caption and the strip are always reachable. A VoiceOver user
  has no use for a darker ground and every use for the controls. The escape
  action at `:217` stays.
- **Hidden chrome is hidden from everyone**, not only drawn at 0: the
  `viewerChrome` modifier sets `accessibilityHidden` and stops hit testing,
  so Voice Control and Switch Control cannot press an invisible button.
- **Reduce Motion:** the fade is opacity only, so it runs unchanged. Do not
  wrap it in `GridConstants.calm` (`:404`); nothing moves.
- **Reduce Transparency:** `WarmBackground` already drops `GroundField`
  (WarmBackground.swift:121-133); `GlassIconButton` handles its own glass.
  Nothing new to do.

### 3.8 `ChatPictureViewer`

Same model, same parts:

- `@State private var chromeHidden`, the same `immersive` and `setChrome`.
- `:46` `Color.black` becomes `ViewerGround(immersive: immersive)`.
- `:48-50` pass `onTap` and `onZoomIn` to its `PhotoPage`.
- Foot `:54-60` to `inkSecondary` and `.viewerChrome(hidden: immersive)`.
- Chrome `:62-75`: `tint: .primary, onPage: true`, `.viewerChrome(hidden:
  immersive)`, delete the forced scheme at `:75`.
- `:78` `.statusBarHidden(immersive)`.
- The drag down at `:79-87` stays. Its fade at `:53` fades the picture; on a
  light ground the better reading is to hide the chrome while dragging and
  let the picture stay opaque, as it travels back. Small, optional.

### 3.9 Whole sketch, `PhotoViewer.body` after the change

```swift
GeometryReader { geo in
    ZStack {
        ViewerGround(immersive: immersive)
            .onTapGesture { setChrome(hidden: chromeHidden == false) }

        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                deck(size: stageSize(geo), topPadding: Self.headerHeight)
                    .overlay(alignment: .bottom) {
                        if let reactions, let current {
                            reactions(current)
                                .padding(.bottom, 10)
                                .viewerChrome(hidden: immersive)
                        }
                    }
                dateLine
                    .frame(height: Self.dateHeight, alignment: .top)
                    .viewerChrome(hidden: immersive)
                Filmstrip(photos: photos, position: position,
                          currentID: currentID, select: select)
                    .frame(height: Self.stripHeight)
                    .viewerChrome(hidden: immersive)
            }
            header
                .frame(height: Self.headerHeight)
                .viewerChrome(hidden: immersive)
        }
        .padding(.top, Self.topInset)
        .padding(.bottom, Self.bottomInset)
    }
}
.ignoresSafeArea()
.statusBarHidden(immersive)
.persistentSystemOverlays(immersive ? .hidden : .automatic)
.accessibilityAction(.escape) { onClose() }
```

`stageSize(geo)` is the existing arithmetic at `:149-153`, unchanged.

## 4. Owner decisions this touches

**CHANGES AN OWNER DECISION.** CLAUDE.md:559, 2026-09-09: "A photo viewer
FITS, and its caption is in the BLACK, not on the picture." The plan keeps
the fit and keeps the caption off the picture, which was the point of the
rule (it was on the picture for one build). At rest it would sit on the page
ground instead of black. His words today ask for exactly that, but the rule
should be rewritten with his yes, not quietly.

**CHANGES AN OWNER REFERENCE.** `PhotoViewer.swift:6-9`: the viewer was
"Built to a reference the owner supplied ... the picture is an object on a
black field". Immersive keeps that look; at rest it becomes a print on the
page. The doc comment needs rewriting with the history kept.

**New, no prior decision:** the status bar showing at rest (it is hidden on
every state today, `:213`).

**Kept as decided:** close on the left and `⋯` on the right
(docs/ten.md:98-100), the `⋯` menu instead of a toolbar (`:405-409`), the
title as the win's name at the top (`:400-404`), the inset print with its
radius, the paging `ScrollView` deck (CLAUDE.md:566-570), the `Filmstrip`.

**Question for him:** dark mode at rest, charcoal (`WarmBackground`, the
app's ground, "dark on dark" in memory) or pure black like Photos.
Recommendation: charcoal, so the black of immersive still reads as a change.

## 5. Proving it

- Screenshots, light and dark, at rest and after a tap, and opened. Counting
  is not looking.
- Swipe the deck after the single tap lands: it must page (the starvation
  rule).
- Pinch: the ground darkens during the pinch, not on release.
- Tap on the strip area while immersive: nothing selects.
- VoiceOver on: a tap never hides anything; the escape scrub still closes.
- Each of the seven presenters in section 1.5 opens and closes.

## Sources

- Apple HIG, Going full screen:
  https://developer.apple.com/design/human-interface-guidelines/going-full-screen
- Apple HIG, Dark Mode:
  https://developer.apple.com/design/human-interface-guidelines/dark-mode
- WWDC24 session 10145, Enhance your UI animations and transitions:
  https://developer.apple.com/videos/play/wwdc2024/10145/
- `UIViewController.Transition.ZoomOptions.interactiveDismissShouldBegin`:
  https://developer.apple.com/documentation/uikit/uiviewcontroller/transition/zoomoptions/interactivedismissshouldbegin
- SwiftUI `NavigationTransition.zoom(sourceID:in:)`:
  https://developer.apple.com/documentation/swiftui/navigationtransition/zoom(sourceid:in:)
- SwiftUI `persistentSystemOverlays(_:)`:
  https://developer.apple.com/documentation/swiftui/view/persistentsystemoverlays(_:)
- Apple iPhone User Guide, View photos and videos (iOS 16 edition):
  https://support.apple.com/en-ge/guide/iphone/iph3d267610/16.0/ios
- Sarun W., How to Hide Navigation Bar on Tap in UIKit:
  https://sarunw.com/posts/hide-navigation-bar-on-tap-in-uikit/
- AppleInsider, Inside Photos in iOS 26:
  https://appleinsider.com/inside/ios-26/tips/inside-photos-in-ios-26-macos-26----refinements-in-apples-image-and-video-management-tool
- The owner, 2026-10-14 (quoted at the top).
