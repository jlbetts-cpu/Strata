# Screen control — a measured layout system for Strata

Research and build plan. Read-only pass over `/Users/jaydenbetts/StrataWork/owner-head`
at `1e446e3`. Nothing was edited, built or run.

The owner's words this answers:

> "make sure we are doing screen control in all the screens: optimizing the
> screen size, understanding where the bottom of the screen is and how many
> pixels off it for each component, keeping it consistent and clean. Making
> sure boxes are the largest they can be while suiting the margins and the
> grid we've established."

---

## 0. What is measured here, and what is not

**The screenshot set I was pointed at no longer exists** — the scratchpad was
cleared. Every number below marked **(code)** is derived from the source and is
exact. Every number marked **(derive)** is arithmetic over one device constant I
have not been able to read off a real frame: the bottom safe-area inset the
iOS 26 floating tab bar applies to a `TabView`'s scrolling content. I call that
`tabInset` and I take it as **83pt**, because `DayAlbumDetailView.swift:37`
records it as a measured fact:

> "It was 110, on the assumption that the tab bar's room had to be added by
> hand; the scroll view was already reserving it, so the day's tower floated
> 194pt above the bottom against the real tower's 91pt… At 0 the gap came out
> 83pt. 8 is the remainder, and the two towers now stand on the same line."

So `tabInset = 83`, the tower's base stands **91pt above the screen bottom**, and
those two are the only anchors in the app that were established by measurement
rather than by choice. **Everything in §2 is derived from them.** §6 lists the
exact shots needed to confirm them and to fill the "unused space" column.

Reference device throughout: **402 × 874 pt** (iPhone 16 Pro), safe top 62,
safe bottom 34 — chosen because `CLAUDE.md` already records "the camera's
wordmark landed at 71.7pt against the 81.0pt line every other header sits on",
and `62 + headerCapTop(18.8) = 80.8`. That agreement is what makes 62 the right
top inset to reason in.

Derived grid at that width: `hPad` 16 → content width 370 →
`cellSize = floor((370 − 12)/4) = 89` → `gridWidth = 4·89 + 3·4 = 368`.
**The grid is 2pt narrower than the content box.** That is already known
(`MainAppView.swift:797-800` pins the tower header to `towerGridWidth` for
exactly this reason) and it is the single most useful fact in this document: a
box that is "as large as it can be" is either **370 wide (prose, a photo, a
form)** or **368 wide (anything on the 4-column grid)**, never both.

---

## 1. The measured inventory

`hPad` = `GridConstants.horizontalPadding` = 16 (code).
`capTop` = `GridConstants.headerCapTop` = 18.8, measured from the top of the
content area, i.e. absolute y = 80.8 on the reference device (code).

### 1a. Bottom-most interactive element, by screen

| Screen / state | Bottom-most control | Written as (file:line) | Off the **screen** bottom | Off the **safe-area** bottom | Off the **tab-bar** inset |
|---|---|---|---|---|---|
| **Wins tower** (reference) | top row of blocks / next slot | `MainAppView.swift:2326` `.padding(.bottom, 8)` inside the TabView inset | **91** (derive; recorded as measured) | 57 | **8** (code) |
| Tower header replay pill / Plan | `GlassIconButton` 44pt | `MainAppView.swift:804` | n/a (top) | — | — |
| **Camera** (in tab) | shutter, 80×80 | `CameraView.swift:880` `.padding(.bottom, bottomInset + 40)`, `bottomInset = 0` in-tab | **137** (derive: 83 + 14 + 40) | 103 | 54 |
| Camera viewfinder bottom edge (r34) | — | `CameraView.swift:209` `h = … − tabGap(14)` | **97** (derive) | 63 | **14** (code) |
| **Camera, full-screen** (from add sheet) | shutter | same line, `bottomInset = 34` | **74** (code+derive) | **40** (code) | n/a |
| **Camera review** (in tab) | Retake / head / Use Photo | `CameraView.swift:454` `bottomInset + 40` | **137** | 103 | 54 |
| **Camera review** (full-screen) | same row | same line | **74** | **40** | n/a |
| **Memories map** (drawer hidden) | recentre button | `MemoriesMapView.swift:1157` `.padding(.bottom, tabBarClearance)` = 110 | **110** (code) | 76 | 27 |
| Memories map | Apple attribution | `MemoriesMapView.swift:283` `.safeAreaPadding(.bottom, 110 − 22)` | **88** (code) | 54 | 5 |
| Memories title row | Photographs + Profile buttons | `MemoriesView.swift:112` `.padding(.top, headerArtworkTopPadding)` | n/a (top) | — | — |
| **Drawer, `.hidden`** | — | `MemoriesDrawer.swift:151` `height + 24` | off screen | — | — |
| **Drawer, `.full`** | last gallery row | `MemoriesView.swift:239` `.padding(.bottom, 110)`; drawer `.ignoresSafeArea(edges:.bottom)` | **110** (code) | 76 | 27 |
| Drawer handle (top of panel) | 36×5 capsule, 28pt band | `MemoriesDrawer.swift:107-110` (8 + 5 + 15) | n/a | — | — |
| **Month tower** (inside drawer) | top block | inside the 110 | 110 | 76 | 27 |
| **Albums shelf** | cover card | `AlbumCarousel.swift:20` width from `UIScreen.main` | inside the 110 | — | — |
| **Day album** | top block of the day's tower | `DayAlbumDetailView.swift:97` `Color.clear.frame(height: 8)` + TabView inset | **91** (code, matches tower) | 57 | **8** |
| **Gallery / place collection** | last photo row | `PhotoCollectionView.swift:51` `.padding(.bottom, 110)` **on top of** the TabView inset | **193** (derive) | 159 | **110** |
| **Photo viewer** | filmstrip | `PhotoViewer.swift:138` `.padding(.bottom, 28)` over `.ignoresSafeArea()` | **28** (code) | −6 (inside the home indicator) | n/a |
| Photo viewer header (close, ⋯) | 44pt buttons | `PhotoViewer.swift:137` `.padding(.top, 58)`, `.statusBarHidden()` | n/a (top) | — | — |
| **Profile** | last `Form` row | `Form`, system insets | system (≈ tabInset) | — | system |
| **Settings** | last `Form` row | `Form`, system insets | system | — | system |
| **Add / edit win sheet** | Size control | `AddWinSheet.swift:141` `.padding(.bottom, gapLabel)` = 16 | 16 from the sheet's bottom safe area | 16 | n/a |
| **Plan sheet** | last row | `PlanSheet.swift` — no explicit bottom | system | — | n/a |
| **Head maker** (lining/capturing) | shutter | `HeadMakerView.swift:225` `.padding(.bottom, gapSection)` = 32 | **66** (code+derive) | **32** | n/a |
| **Head maker preview** | Retake / Save | `HeadMakerView.swift:468` `.padding(.bottom, 32)` | **66** | **32** | n/a |
| **Onboarding**, all 6 steps | Continue / Not now | `OnboardingView.swift:69` `.padding(.bottom, gapSection)` = 32 | **66** | **32** | n/a |
| **Replay**, close | share / close controls | `ReplayFrame.swift:293` hung from `baseY`, floor `bottomInset + gapTight(8)` | ≥ **42** (code+derive) | ≥ 8 | n/a |

### 1b. Title line, by screen

| Screen | Title | Set by | Cap y (abs, derive) | On the shared line? |
|---|---|---|---|---|
| Wins tower | `34pt` tally + "wins" | `MainAppView.swift:804` `headerTopPadding(34)` = **10.94** | **80.8** | **yes — this is the line** |
| Memories | drawn `MemoriesTitle` | `MemoriesView.swift:112` `headerArtworkTopPadding` = 18.8 | 80.8 | yes |
| Camera | drawn wordmark, 32pt cap | `CameraView.swift:456` `topInset + Header.topPadding` | 80.8 | yes |
| Head maker | drawn wordmark, 32pt cap | `HeadMakerView.swift:206` | 80.8 | yes |
| Onboarding | drawn wordmark, 32pt | `OnboardingView.swift:62` | 80.8 | yes |
| Replay | `screenSubtitle` 15pt over `headerMedium` | `ReplayFrame.swift:81` `headerTopPadding(15)` = 15.33 | 80.8 | yes |
| Drawer page header | drawn `MemoriesTitle` + Done | `MemoriesView.swift:541` `.padding(.top, gapItem)` = 12 | 62 + 28 (handle) + 12 = **102** | **no — its own line** |
| **Day album** | `screenTitle` 34pt | `DayAlbumDetailView.swift:85` `.padding(.top, 28)` **under a system nav bar** | ≈ 62 + 44 + 28 + 7.9 = **142** | **no — 61pt low** |
| **Place / curated collection** | `screenTitle` 34pt | `PhotoCollectionView.swift` header, **no top padding**, under a *visible* bar | ≈ 62 + 44 + 7.9 = **114** | **no — 33pt low, and 28pt off the Day album it is a twin of** |
| Add / edit win | system inline 17pt | `AddWinSheet.swift:143` | sheet bar | n/a (sheet) |
| Plan | system inline 17pt | `PlanSheet.swift:49` | sheet bar | n/a |
| Profile | system inline 17pt | `ProfileView.swift:62` | sheet bar | n/a |
| Settings | system inline 17pt | `SettingsView.swift:413` | pushed bar | n/a |
| Photo viewer | 17pt `headerMedium`, centred | `PhotoViewer.swift:137` `.padding(.top, 58)` hard-coded | **58 + 22 = 80** | coincidentally yes, by a hard-coded number |

### 1c. Horizontal margin, by screen

| Value | Screens | Verdict |
|---|---|---|
| **16** (`hPad`) | tower, tower header, Memories title, drawer header, month tower, albums shelf, day album, place collection header, add sheet, camera close button, head-maker header, onboarding, replay, photo-viewer header, privacy | the page margin |
| **0** | photo gallery grid (`PhotoGalleryGrid.swift:47`, 2pt gutter) | **deliberate** — CLAUDE.md: "edge to edge… a photo grid with a margin is a set of cards". Leave. |
| **6** | month picker (`MemoriesView.swift:577`, `hPad − 10`) | **deliberate optical** — the menu label's own inset, so the *word* lines up on 16. Leave. |
| **5 / 16** | Plan rows (`PlanSheet.swift:187`, `hPad − 11`) | same optical trick. Leave. |
| **24** (`gapWide`) | camera review Retake/Use Photo, head-maker Retake/Save | a wider margin for a two-word action row. Consistent with itself; name it rather than leave it as `gapWide`. |
| **44** | camera shutter row (`CameraView.swift:879`) | it is a **centring** device, not a margin — the shutter is a centred sibling. Leave. |
| **44 + 16** | photo-viewer title (`PhotoViewer.swift:292`) | derived from the buttons. Correct, leave. |
| **≈20** (system) | **Profile**, **Settings** — SwiftUI `Form`, inset-grouped | **wrong.** `AddWinSheet.swift:135` fixed exactly this bug ("This was 20 while every other screen is `horizontalPadding` (16)"); the two `Form` screens are the survivors. |
| `UIScreen.main.bounds.width − 32` | month tower (`MemoriesView.swift:613`), day tower (`DayAlbumDetailView.swift:176`), album cover (`AlbumCarousel.swift:20`) | right number, **wrong source** — the device, not the container. |

### 1d. Unused space

This column needs the shots (§6). What the code already says:

- **Place / curated collection: ~110pt of dead space** under the last photo row
  (double-counted tab-bar clearance) — the exact bug `DayAlbumDetailView` was
  fixed for, still live in its sibling.
- **Camera review, in-tab vs full-screen: the same control row sits at 137pt and
  at 74pt off the bottom** depending on how it was reached. 63pt of difference in
  one row, one file, one `bottomInset`.
- **Add/edit sheet**: `.presentationDetents([.large])` with a form that is often
  short. The comment at `AddWinSheet.swift:156` already argues this is acceptable
  ("Empty space under a form is ordinary; a control cut off by the edge of a
  sheet is a bug") — I agree, do not reopen.
- **Onboarding** gives the stage `Spacer(minLength: 0)` above the words and
  nothing below, so all of the slack pools between the wordmark and the headline.
  On a Pro Max that is ~90pt more slack than on an SE, in one place.

---

## 2. The system

Six tokens, three rules. Every value is what the majority of screens already do.
Nothing here introduces a look the app does not have.

### 2.1 The tokens

Add to `GridConstants`, in a new `MARK: - Screen control` section.

```swift
// MARK: - Screen control
//
// Where a screen sits against the device. Four anchors: the page margin, the
// title line, the bottom band, and the grid. Everything else is derived.

/// The page margin. Every screen, both edges.
///
/// Alias of `horizontalPadding`, named for what it is rather than for the
/// modifier it goes into. Exceptions are listed in the doc and each is
/// argued: the gallery is edge to edge, and three controls sit at
/// `pageMargin` minus their own label inset so the WORD lands on the margin.
static let pageMargin: CGFloat = horizontalPadding            // 16

/// Distance from the top of the content area to a title's CAP.
/// Already here as `headerCapTop`. Unchanged.                 // 18.8

/// Between a title's layout box and the top of the content under it.
///
/// The tower's own number, written as a literal at MainAppView.swift:808 and
/// nowhere else. Named because four other screens need it and are currently
/// each picking their own.
static let titleToContent: CGFloat = 20

/// **The bottom band.** How far a bottom-anchored control row sits above the
/// space the system has already reserved.
///
/// 8, from the tower — the reference screen, and the only bottom anchor in
/// the app established by measurement. Its base stands 91pt off the screen
/// on a 402x874, and `DayAlbumDetailView` was corrected until its tower
/// stood on the same line.
///
/// It goes on TOP of whatever the container already reserves:
///  - inside a Tab's scroll view, the TabView's own inset (~83pt) is
///    already applied; add `bottomBand` and nothing else.
///  - a view that `.ignoresSafeArea(edges: .bottom)` reserves nothing, so it
///    needs `tabBarClearance` instead.
static let bottomBand: CGFloat = 8

/// The bottom band for a full-screen cover, which has no tab bar.
///
/// 32 (`gapSection`), from onboarding and the head maker — the two covers
/// that already agree with each other. Measured above the SAFE AREA, not
/// the screen: 66pt off a 402x874.
static let coverBottomBand: CGFloat = gapSection              // 32

/// Air between a full-bleed rounded surface and the tab bar.
/// The camera's `tabGap`, which is the only place this shape occurs.
static let surfaceTabGap: CGFloat = 14

/// The margin for a two-word action row in a cover — Retake / Use Photo,
/// Retake / Save. Wider than the page margin on purpose: the words are
/// pushed to the corners of a picture, not set in a column of content.
static let actionRowMargin: CGFloat = gapWide                 // 24
```

And two functions, because "as large as it can be" is arithmetic and should
not be retyped:

```swift
/// The widest a box may be on a screen of this width. Prose, a photograph,
/// a form, a card.
static func contentWidth(in width: CGFloat) -> CGFloat {
    width - pageMargin * 2
}

/// The widest a box may be if it sits on the 4-column grid. Always 0–3pt
/// narrower than `contentWidth`, because the cell is floored.
///
/// A tower, a month, a packed set of blocks takes THIS. Taking
/// `contentWidth` instead is how the tower header's share button ended up
/// 2.3pt past the tower's right edge (MainAppView.swift:790).
static func gridContentWidth(in width: CGFloat) -> CGFloat {
    gridWidth(cellSize: cellSize(forGridWidth: contentWidth(in: width)))
}
```

### 2.2 The three rules

**Rule 1 — the title line.** Every screen that names itself puts its title's cap
on `headerCapTop` (18.8) below the top of its own content area. Type asks for
`headerTopPadding(forTitleSize:)`; a drawing asks for `headerArtworkTopPadding`.
**A screen with a system navigation bar is a screen with a second title line,
and the app does not have two.** A pushed page either hides the bar and draws its
own title on the line (Day album, Place collection), or it has no drawn title at
all (Settings, inside Profile).

**Rule 2 — the bottom band.** There are exactly three bottoms, and which one you
are on is decided by what reserves space for you, never by what the screen is:

| Container | What it reserves | What you add | Result on 402×874 |
|---|---|---|---|
| a scroll view inside a `Tab` | the TabView's inset (~83) | `bottomBand` **8** | 91 off the screen |
| a view that ignores the bottom safe area, over the tab bar | nothing | `tabBarClearance` **110** | 110 off the screen |
| a full-screen cover or a sheet | the safe area (34) | `coverBottomBand` **32** | 66 off the screen |

`tabBarClearance` keeps its value and gains the sentence that makes it safe:
**it is the clearance for content that has opted out of the safe area, and
adding it to content that has not is a 110pt hole.** That is the Place
collection's bug and it is written down in `DayAlbumDetailView.swift:29-37` as
the thing that was already caught once.

**Rule 3 — boxes as large as they can be.** A box fills
`contentWidth(in:)` horizontally, or `gridContentWidth(in:)` if it is on the
grid, and it fills vertically from `title bottom + titleToContent` down to the
bottom band. Width comes from the **container's** `GeometryReader` or layout,
never from `UIScreen.main`. Height is a `minHeight` with an alignment, never a
fixed frame — the tower already does exactly this
(`MainAppView.swift:2330-2333`: `minHeight: viewportHeight, alignment: .bottom`)
and it is the pattern to copy, because it is what lets a short day and a busy
day both stand on the same line.

**The one exception, stated so it is not re-litigated:** the gallery is edge to
edge and takes the full container width with a 2pt gutter. It is not a box.

### 2.3 What each surface type gets

- **Tabs** (Wins, Camera, Memories): title on the line, `pageMargin`,
  `bottomBand` over the TabView's inset. The camera is the one full-bleed tab and
  gets `surfaceTabGap` instead, because a rounded surface has to show that it
  stops.
- **Pushed pages inside a tab** (Day album, Place collection): identical to a
  tab. The nav bar is hidden and the title is drawn on the line. They keep the
  tab bar's inset, so `bottomBand`.
- **Sheets** (Add/edit win, Plan): the system bar and its inline title are the
  header — do not draw a second one. `pageMargin` for content,
  `gapLabel` (16) at the bottom of the scroll. `.large` detent where the content
  can be tall.
- **Full-screen covers** (Camera modal, Head maker, Onboarding, Photo viewer,
  Replay): title on the line, `coverBottomBand` above the safe area,
  `actionRowMargin` for a two-word action row.
- **The drawer**: `.full` only. It ignores the bottom safe area, so its scroll
  takes `tabBarClearance`. Its header is its own line (102) because the handle is
  above it — that is correct and is the one place a second title line is earned.

---

## 3. Per-screen deltas, ranked by how visible they are

Ranked most visible first. Each is the smallest edit that brings the screen onto
the system.

### 1. Place / curated collection has ~110pt of dead space under it

`Strata/Views/PhotoCollectionView.swift:51`

```swift
- .padding(.bottom, GridConstants.tabBarClearance)
+ // The TabView already reserves the bar's room for this scroll view;
+ // adding it again floated the last row 193pt off the bottom. Same
+ // correction DayAlbumDetailView.swift:29 records.
+ .padding(.bottom, GridConstants.bottomBand)
```

Visible because it is the twin of the Day album, reached from the same shelf,
and the two now end 102pt apart.

### 2. Place collection and Day album put their titles 28pt apart

`PhotoCollectionView.swift:58-66` and `DayAlbumDetailView.swift:86`.
`PhotoCollectionView` shows a nav bar with a ground and draws its title below it
with no top padding; `DayAlbumDetailView` hides nothing and pads 28.

```swift
// PhotoCollectionView.swift, header:
  .padding(.horizontal, GridConstants.horizontalPadding)
+ .padding(.top, GridConstants.headerTopPadding(forTitleSize: Typography.screenTitleSize))
```

and both hide the bar, drawing their own back control:

```swift
- .navigationTitle("")
- .navigationBarTitleDisplayMode(.inline)
- .toolbarBackground(.visible, for: .navigationBar)
+ .toolbar(.hidden, for: .navigationBar)
```

**Caution, and this is the one that needs the owner:** the visible bar on
`PhotoCollectionView` is there for a stated reason — "The grid is edge to edge,
so without one the photographs slide under the title and the back chevron"
(`PhotoCollectionView.swift:60-66`), and the owner photographed that bug. Hiding
the bar re-opens it. **Two options, and I would ask before picking:** (a) keep
the bar on both screens and give both the same top padding under it, which costs
the shared title line but keeps the ground; or (b) hide it on both and give the
grid `titleToContent` of clearance below the drawn header, which restores the
line. The Day album already does (b) and looks right — but it has a tower under
its header, not photographs.

### 3. The camera review's action row jumps 63pt between two ways of reaching it

`Strata/Views/CameraView.swift:454` and `:880` both read
`.padding(.bottom, bottomInset + shutterBottomGap)`, where `bottomInset` is 0
in-tab and 34 full-screen. The full-screen camera therefore puts its shutter 74pt
off the screen and the in-tab one 137pt.

This is correct for the **shutter**, because in-tab the shutter sits inside the
rounded viewfinder and full-screen it sits on the screen edge. It is not correct
that both bottoms are called the same number. Make the intent explicit:

```swift
- private let shutterBottomGap: CGFloat = 40
+ /// Air between the shutter and the bottom edge of the VIEWFINDER.
+ /// Full screen the viewfinder's edge is the screen's, so the shutter also
+ /// has to clear the home indicator — which is what `bottomInset` adds.
+ private let shutterBottomGap: CGFloat = 40
```

and then check against the shot: if the in-tab shutter reads as floating, the
lever is `shutterBottomGap`, not `tabGap`. **Flagged as measure-first, not as a
change** — the camera's composition is tuned against its guides
(`CameraView.swift:150-170`) and I will not move it off a derivation.

### 4. Profile and Settings sit 4pt further in than every other screen

`ProfileView.swift:52` and `SettingsView.swift` both use `Form`, whose
inset-grouped rows are ~20pt from the edge.

```swift
  Form { … }
      .scrollContentBackground(.hidden)
+     // The app's page margin, not the list style's. Same correction
+     // AddWinSheet.swift:135 records: 20 against every other screen's 16.
+     .environment(\.defaultMinListRowHeight, 0)
+     .contentMargins(.horizontal, GridConstants.pageMargin - 20, for: .scrollContent)
```

`contentMargins` with a negative delta is fragile. The honest version is
`.listRowInsets(EdgeInsets(top: …, leading: 0, …))` per section plus
`.listSectionSpacing`, or leaving the two `Form` screens alone and writing the
exception down. **My recommendation: write it down and leave it.** A system
`Form` is the system's chrome, the way the nav bar is, and 4pt on the two
screens that are least often seen is the cheapest thing on this list. But it
should be a decision, not drift.

### 5. Three towers measure themselves against the device, not their container

`MemoriesView.swift:613`, `DayAlbumDetailView.swift:176`, `AlbumCarousel.swift:20`:

```swift
- width: UIScreen.main.bounds.width - GridConstants.horizontalPadding * 2,
+ width: GridConstants.contentWidth(in: containerWidth),
```

`containerWidth` from the enclosing `GeometryReader` (`DayAlbumDetailView`
already has one at line 64; `MemoriesView`'s drawer has one; `AlbumCarousel`
needs one or a passed width). Invisible today on a phone in portrait — visible
the moment anything is presented at a non-screen width, and it is three copies
of one number.

Note the second half of the fix: these draw **towers**, so they should take
`gridContentWidth(in:)`, not `contentWidth(in:)`. As written they hand a 370 to
`cellSize`, get 89 back, and draw 368 — the 2pt already falls out correctly
inside `MonthTowerView`. Passing `gridContentWidth` makes the frame agree with
the drawing instead of being 2pt wider than it.

### 6. The tower's `titleToContent` is a literal

`MainAppView.swift:808`:

```swift
- .padding(.bottom, 20)
+ .padding(.bottom, GridConstants.titleToContent)
```

No visual change. It is the token's definition, and naming it is what lets the
day album, the place collection and the drawer header use the same number.

### 7. The photo viewer's chrome is placed by four hard-coded numbers

`PhotoViewer.swift:206-212`: `topInset 58`, `bottomInset 28`, `headerHeight 44`,
`stripHeight 74`, over a `.ignoresSafeArea()` + `.statusBarHidden()`.

58 happens to land the title on 80 — the shared line — on this device. It does
so by coincidence. On an SE (top inset 20, no island) it is 38pt of black above
the title; on a Pro Max (62) it is 4pt under the physical island.

```swift
- private static let topInset: CGFloat = 58
+ /// Derived, not typed. The status bar is hidden here, so the safe area is
+ /// the island's own room — and the title still belongs on the app's line.
+ private static func topInset(_ safeTop: CGFloat) -> CGFloat {
+     safeTop + GridConstants.headerTopPadding(forTitleSize: 17)
+ }
```

and `bottomInset` from `safeBottom + gapTight` rather than 28. **28 is currently
6pt inside the home indicator** on a 34pt bottom inset — the filmstrip's last
6pt is under the bar.

### 8. Onboarding pools all its slack above the headline

`OnboardingView.swift:64`: one `Spacer(minLength: 0)` between the wordmark and
`words`. On a Pro Max that is ~90pt more than on an SE, all in one gap, so the
words sit lower on a bigger phone rather than the layout breathing evenly.

```swift
  StrataWordmark(…)
  Spacer(minLength: 0)
  words
+ Spacer(minLength: 0).frame(maxHeight: GridConstants.gapSection)
  actions
```

Low confidence without the shots — this may be exactly what the owner wants, since
the stage behind it is a photograph. **Do not ship this one without a before/after
pair at both sizes.**

### Deliberate — do not touch

| Thing | Where | Why it stays |
|---|---|---|
| Camera wordmark at 32, bigger than a page title | `CameraView.swift:161` | CLAUDE.md, settled: "deliberately bigger than a page title (32 against 23.96) and that is not drift", bounded by the composition guides. |
| Gallery edge to edge, 2pt gutter, no margin | `PhotoGalleryGrid.swift:44-47` | CLAUDE.md, owner's call from a phone 2026-09-09. |
| Map attribution at `tabBarClearance − 22` | `MemoriesMapView.swift:283` | Apple's licence requires it displayed and there is no API to place it; the `safeAreaPadding` is the only lever. |
| Drawer has two detents, not three | `MemoriesDrawer.swift:30-50` | Owner's call: "should open to full screen pop up with a done button". The brief asks for "each detent"; there are two, and `.hidden` is off screen. |
| Month picker at `hPad − 10`, Plan rows at `hPad − 11` | `MemoriesView.swift:577`, `PlanSheet.swift:187` | Optical alignment of the WORD to the margin. Correct as written. |
| Add sheet's `.large` detent over a short form | `AddWinSheet.swift:156` | Argued in place: a medium detent clipped the size control. |
| The tower's own 8 | `MainAppView.swift:2326` | This is the reference. Everything else moves to meet it. |
| Tower header bound to `towerGridWidth`, not the page | `MainAppView.swift:797` | Measured (tower right 383.7, button right 386). It is `gridContentWidth` in everything but name. |

---

## 4. Device sweep

### iPhone SE — 375 × 667, top 20, bottom 0 (no home indicator)

Grid: content 343 → `cellSize = floor(331/4) = 82` → `gridWidth = 340`.

| Risk | Where | What happens |
|---|---|---|
| **`coverBottomBand` over a 0pt bottom inset** | Onboarding `:69`, head maker `:225`/`:468` | 32pt off the **screen**, not 66. The action row hugs the bezel. The band should have a floor: `max(safeBottom, gapItem) + coverBottomBand` or similar. **The highest-value SE fix on this list.** |
| **`PhotoViewer.bottomInset = 28`** | `:207` | 28pt off the screen with no indicator — acceptable — but `topInset 58` against a 20pt safe top is 38pt of black. |
| **Head maker's outline collapses** | `HeadMakerView.swift:116-126` | `available = screenH − insets − 32 − 80 − 24 − 24 − 24`; at 667 that is ~420, and the outline takes `min(available·0.92, width·0.72/0.76 = 355)` → 355, so it is width-bound and fine. At **accessibility sizes** `promptHeight` is a fixed 24 with `lineLimit(2)` — a two-line prompt at AX3 is ~60pt and will overlap the pips. |
| **Replay's `baseY = 0.75·H`** | `ReplayScript.swift:44` | 500 on an SE against 655 on a Pro. The close is hung from `baseY` with a floor of `bottomInset + 8`, so it survives, but the tower has 25% less room. Already capped to xxLarge (`ReplayFrame.swift:65`). Watch, do not change. |
| **Camera review's three size words** | `CameraView.swift:478-497` | Three `Text`s at `headerSmall` with `gapItem` padding each, in one `glassCapsule`, **no `lineLimit`, no `ViewThatFits`**. "Quick / Regular / Deep" at AX1 on a 375pt screen overflows. The tower header solved the same problem with `ViewThatFits` (`MainAppView.swift:774`); this row has not. |
| **Camera review's action row** | `CameraView.swift:397-450` | `minWidth: 88` ×2 plus an optional head button plus `gapWide` ×2 = 224 minimum; fine at 375, but the labels grow with Dynamic Type and there is no wrap. |
| **`OnboardingView.cell = 74`** | `:43` | The opening tower is drawn at a fixed cell on every device. On an SE the 4-column tower is 340 wide at cell 82, but onboarding draws at 74 → 308, so it is 16pt narrower than the tower it is teaching. Visible as "the app's tower is wider than the one in onboarding". |
| **`ReplayCard` posters 132 / 96** | `ReplayCard.swift:77-79` | Fixed. Fine (a horizontal shelf), but they will not grow with Dynamic Type — the titles under them will. |

### iPhone Pro Max — 440 × 956, top 62, bottom 34

Grid: content 408 → `cellSize = floor(396/4) = 99` → `gridWidth = 408`. (Exactly, for once.)

| Risk | Where | What happens |
|---|---|---|
| **`PhotoViewer.topInset = 58` < safe top 62** | `:206` | The close button and the ⋯ menu sit **4pt inside the Dynamic Island's own region**. Status bar hidden does not move the island. This is a real, reachable defect. |
| **Onboarding's single spacer** | `:64` | ~82pt more slack than the SE, all above the headline. |
| **Everything else scales** | — | The `hPad`/`capTop`/`bottomBand` triple is device-independent by construction. |

### Accessibility text sizes

| Risk | Where | Status |
|---|---|---|
| Tower header | `MainAppView.swift:774` | **Solved** — `ViewThatFits`, argued in place. The pattern to copy. |
| Drawer Done button | `MemoriesView.swift:524` | **Solved** — `lineLimit(1) + fixedSize`, argued in place. |
| Camera review size words | `CameraView.swift:478` | **Not solved.** Needs `ViewThatFits` or a two-row fallback. |
| Head maker prompt | `HeadMakerView.swift:215` | `frame(minHeight: 24)` with `lineLimit(2)`; the reserved height does not grow, so at AX the prompt pushes the pips and controls down into `coverBottomBand`. |
| Day album / place collection titles | `:133`, `:91` | `lineLimit(1) + minimumScaleFactor(0.7)`. Deliberate and argued (a wrapping date pushed the tower down). Fine. |
| Drawn titles (wordmark, `MemoriesTitle`) | everywhere | **Do not scale with Dynamic Type at all** — they are artwork at a fixed cap. Body text around them does. At AX5 the page's type is 2× and its title is not. This is a consequence of the owner's settled decision that the titles are his letterforms, so it is a **note, not a delta** — but it should be seen once at AX5 before anyone calls it a bug. |
| Replay | `ReplayFrame.swift:65` | Capped at xxLarge, argued. Correct. |

---

## 5. How to verify each change

Every check is: launch with the flag, take one `simctl io screenshot`, and
measure in pixels / 3. **Tolerance ±2pt** unless stated — that is one screen
pixel at 3× plus rounding, and every number in §2 is a multiple of 4 or a
measured constant.

| # | Change | Launch | Measure | Pass |
|---|---|---|---|---|
| 1 | Place collection bottom | `-strataStartTab memories -strataSeedHistory 30 -strataSeedPlaces -strataOpenDrawer full` then tap a place, or `-strataOpenCurated 0` | last photo row's bottom edge → screen bottom | 91 ± 2, and **equal to the Day album's tower base in the same run** |
| 2 | Place / Day album title line | `-strataOpenDay 1` and `-strataOpenCurated 0` | first ink of the title → screen top | 80.8 ± 2 on both, and equal to the Wins tally in the same run |
| 3 | Camera bottoms | `-strataStartTab camera` and `-strataOpenSheet add` → camera | shutter's bottom edge → screen bottom | in-tab 137 ± 2, full-screen 74 ± 2 — **record both, change neither until the owner has seen the pair** |
| 4 | Profile / Settings margin | `-strataOpenSheet profile`, `-strataOpenSheet settings` | first row's leading text → screen left | 16 ± 2 if changed; 20 if the exception is written down instead |
| 5 | Three towers off the container | `-strataStartTab memories -strataOpenDrawer full -strataSeedHistory 60` | month tower's left and right block edges | left 16 ± 1, right 384 ± 1 (= 16 + 368) on a 402 |
| 6 | `titleToContent` | `-strataStartTab tower -strataSeedWins 12` | tally's layout bottom → first block's top | unchanged from before the edit, ±0 |
| 7 | Photo viewer chrome | `-strataStartTab memories -strataOpenPhoto 0`, on **both** an SE and a Pro Max | close button's top edge → screen top; filmstrip's bottom → screen bottom | title cap 80.8 ± 2 on the Pro Max; close button fully clear of the island; filmstrip bottom ≥ safe bottom |
| 8 | Onboarding slack | `-strataShowOnboarding -strataOnboardingStep 0..5`, SE and Pro Max | headline's cap → screen top | the **difference** between the two devices ≤ 24pt |
| 9 | SE cover bottom floor | `-strataShowOnboarding` and `-strataOpenHeadMaker preview` on an SE | action row's bottom → screen bottom | ≥ 32; today it is exactly 32 with no indicator, which is what to look at |
| 10 | AX overflow | any of the above with `-AppleTextSizeOverride` / the simulator's accessibility inspector at AX3 | nothing clipped, nothing overlapping | look, do not count |

**The counting rule from CLAUDE.md applies to all ten.** A row that measures 91.0
and looks wrong is wrong. Open every screenshot.

**Gate:** none of these are covered by a test today. The cheapest durable guard is
a unit test over the tokens themselves — `bottomBand + tabInset == 91`,
`headerTopPadding(34) + roundedCapInset * 34 == headerCapTop`,
`gridContentWidth(in: 402) == 368` — plus one XCUITest that dumps
`app.debugDescription` on the Wins tab and the Day album and asserts the two
towers' bottom frames are equal. That last one is the only assertion here that
can catch a regression the arithmetic cannot, and `CLAUDE.md` already records
`XCTFail(app.debugDescription)` as the way to read frames.

---

## 6. Shots needed to finish the inventory

I could not measure the "unused space" column or confirm `tabInset`. The
following set closes both. **Device: iPhone 16 Pro (402×874) unless the row says
otherwise. Light and dark for every row** (the app is light-dominant but the
drawer, the map chrome and the viewer all switch).

Allow 16s after launch before each shot, per CLAUDE.md.

| # | Screen / state | Flags |
|---|---|---|
| 1 | Wins tower, 12 wins | `-strataStartTab tower -strataSeedWins 12` |
| 2 | Wins tower, empty | `-strataStartTab tower` |
| 3 | Wins tower, tall (scrolled to bottom) | `-strataStartTab tower -strataSeedWins 44` |
| 4 | Add sheet | `-strataStartTab tower -strataOpenSheet add` |
| 5 | Edit sheet (a block with a photo) | `-strataSeedWins 12 -strataSeedTodayPhotos 1 -strataOpenSheet block` |
| 6 | Camera, in tab | `-strataStartTab camera` |
| 7 | Camera review, in tab | `-strataStartTab camera -strataOpenReview small 1` |
| 8 | Camera review, small / medium / hard | `-strataOpenReview medium 1`, `-strataOpenReview hard 1` |
| 9 | Camera, full screen from the add sheet | `-strataOpenSheet add` **then a tap on the photo well** — no flag reaches it. Either an XCUITest tap or report it unmeasured. This is the one that settles delta #3, so it is worth the test. |
| 10 | Memories map, drawer hidden, pale | `-strataStartTab memories -strataSeedHistory 30 -strataSeedPlaces -strataMapStyle quiet` |
| 11 | Memories map, satellite | same with `-strataMapStyle satellite` |
| 12 | Drawer `.full` | `… -strataOpenDrawer full` |
| 13 | Drawer `.full`, scrolled to the gallery | `… -strataOpenDrawer full -strataScrollMemories` |
| 14 | Drawer `.full`, scrolled to the shelf | `… -strataScrollMemories shelf` |
| 15 | Month tower, busy month | `-strataSeedHistoryPerDay 4 -strataOpenDrawer full` |
| 16 | Day album | `-strataOpenDay 1` |
| 17 | Place collection | `-strataSeedPlaces -strataOpenCurated 0` |
| 18 | Photo viewer | `-strataStartTab memories -strataSeedTodayPhotos 1 -strataOpenPhoto 0` |
| 19 | Profile | `-strataOpenSheet profile -strataSeedHead` |
| 20 | Settings | `-strataOpenSheet settings` |
| 21 | Head maker — each state | `-strataOpenHeadMaker outline`, `blink`, `smile`, `brows`, `failed`, `preview` |
| 22 | Onboarding — each step | `-strataShowOnboarding -strataOnboardingStep 0` … `5` |
| 23 | Replay, close frame | `-strataOpenReplay sampleWeek -strataReplayAt 17` |
| 24 | Replay, mid-build | `-strataOpenReplay sampleWeek -strataReplayAt 6` |
| 25 | **Plan sheet — NOT REACHABLE by flag.** `-strataOpenSheet` takes only `settings\|profile\|add\|block` (`MainAppView.swift:1691`). The sheet opens from the checklist button in the tower header and nothing can tap. | `-strataSeedPlan 6 -strataStartTab tower` gets the data in; the sheet needs an XCUITest tap (`StrataUITests`) or a one-line `case "plan"` added to that switch. **Say it is unmeasured rather than implying otherwise.** |

**Repeat 1, 6, 12, 16, 17, 18, 21(preview), 22(0 and 5) on:**

- **iPhone SE (3rd gen), 375×667**, light only
- **iPhone 16 Pro Max, 440×956**, light only
- **iPhone 16 Pro at AX3** (`Accessibility → Larger Text`, or the launch
  argument the harness supports), light only

That is 25 states × 2 schemes + 9 × 3 devices = **77 shots**. If that is too
many, the eight that decide everything are: **1, 6, 12, 16, 17, 18** on the
reference device, plus **1 and 18 on a Pro Max** (the photo viewer's island
collision and the tower's base line are the two findings that change a
recommendation).

**What I will do with them:** fill the "unused space" column in §1, confirm
`tabInset = 83` from shot 1 (tower base → screen bottom, minus 8), confirm
`safeTop = 62` from shot 1 (tally's first ink → screen top, minus 18.8), settle
delta #2 (which of the two title treatments the Day album / Place collection pair
should take) and delta #3 (whether the in-tab shutter reads as floating), and
re-rank §3 by what is actually visible rather than by what the arithmetic says.

---

## Sources

- `/Users/jaydenbetts/StrataWork/owner-head/CLAUDE.md` — "The tower screen is the
  reference", "Settled", "Deliberate pairs", "An ink is not a surface", "Where the
  design is written down", the drawn-header rules, the camera wordmark decisions.
- `docs/apple-design.md` §9 (rubber-banding), §6 (momentum) — the drawer already
  implements both; nothing here touches motion.
- `docs/design-system.md` §3 is marked superseded. The only value taken from it is
  `Horizontal padding 16pt`, and only because the code agrees
  (`GridConstants.swift:108`). Its "Grid spacing 10pt" and "Standard radius 16pt"
  contradict the code (4 and 12) and are ignored.
