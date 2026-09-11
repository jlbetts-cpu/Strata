# Profile, and your head in the app — plan

**Status: built on 2026-09-11, uncommitted,** except the tower placement
(§5.6), which is still plan. Profile, Settings' move, the head maker, the
living head, the map marker, the photo sticker and the Reset All Data fix are
in. Capture itself (the camera and subject lifting) cannot run in the
simulator and is unverified until it is tried on a phone.

---

## 1. The owner's decisions

- **The head is 100% optional.** Every place it can appear is its own switch,
  and every switch starts OFF. Someone who never makes a head must never feel
  they are missing part of the app.
- **Profile is a button, not a tab.** Three tabs stay and the camera stays in
  the middle. A fifth tab would need a fifth real destination, and
  `product-direction.md` already records the cost: a tab "costs a fifth of the
  bottom edge forever".
- **The profile picture is a choice:** initials (the default), a photograph, or
  the moving head.
- **Profile shows a streak and a trend chart.** In the owner's words, for
  someone like his mum, who "loves seeing her progress and trends". Milestones
  are parked (they already exist in code — see §4.4).
- **The head can appear on the map, in the camera, and on the tower** — each
  optional, each off by default.
- **Settings lives only in Profile.** The gear leaves the Memories page.
- **Making a head has no eye step.** The website maker's eye placement "gave
  me a lot of trouble" and was not intuitive. The app's maker is built for
  the iPhone: it uses your real eyes and places nothing by hand (§5.2).
- **The look is Apple-native.** Apple Health is the reference for Profile. It
  still follows Strata's own system (§6) — native does not mean default.

## 2. Why each decision holds up

| Decision | Evidence |
|---|---|
| Head only where it stands for YOU and reacts to what you did | A likeness of yourself that changed with your own exercise increased exercise; an unchanging self-avatar or another person's avatar did not (Fox & Bailenson, 2009). |
| Profile behind your picture, top right | Apple Health: "tap your profile picture in the upper-right corner". Apple Music does the same. Apple's tab bar guidance covers navigation between sections, not accounts. |
| Picture is a choice | Apple's own My Card offers a photo, emoji, monogram or Memoji. |
| Settings only behind the picture | Apple Health puts Health Details behind the profile picture. One door to one room: two entry points are two things to keep in step. |
| Blink captured, not placed | Eye openness can be measured per frame from face landmarks — the eye aspect ratio (Soukupová & Čech, 2016) — so the maker can pick the open and shut frames itself. |
| Cut-out people already understand | `VNGenerateForegroundInstanceMaskRequest` (iOS 17) is the subject lifting behind touch-and-hold in Photos. |
| Streak shown, but a break never shouted | Intact streaks shown in a log increase engagement; broken ones shown reduce it, more so when people blame themselves, less when they can repair it (Silverman & Barasch, 2023). |
| A trend chart at all | Monitoring progress improves goal attainment, d = 0.40 across 138 studies, and more when it is recorded (Harkin et al., 2016). |
| One sentence above the chart | Apple HIG, Charts: "Summarize the main message of your chart." Apple Health's Highlights pair one sentence with one small chart. |
| A trend that one bad week cannot flip | Apple Fitness Trends compares the last 90 days with the last 365 so "a single day… won't ruin your trends". |
| Bars, not lines, for wins per week | Apple HIG, Charts: bars compare values across time "when sums are meaningful" — a week's wins is a sum. |

## 3. Where things live

```
Wins header       [12 wins ................... (Plan)]        ← unchanged
Memories header   [Memories ...... (Photographs) (Profile)]   ← the gear goes; Settings moves into Profile
Camera            no profile button — it is a viewfinder
```

**Profile lives on Memories only** (owner, 2026-09-11, while building it: "maybe
the profile should just be in memories"). It was on both headers for one build.
The tower is today's record and its corner belongs to the plan; who you are and
how your weeks have gone is the Memories tab's subject — and it is where the
gear, and so Settings, already lived.

- **Profile** — a sheet from the profile button, like Settings is today.
- **Settings** — ONLY inside Profile, as a row that pushes the existing
  `SettingsView` unchanged (§4.6). Not inlined: it is 627 lines and it already
  works. Always reachable, because the profile button is always there —
  initials by default, head or no head.
- **Make / edit your head** — a row inside Profile.
- **Head switches** — inside Profile. There is no second place to turn the head
  on or off.

## 4. The Profile screen

**As built.** A `Form` on `WarmBackground` with `.scrollContentBackground(.hidden)`,
in a `NavigationStack` with a Done button — the same construction as
`SettingsView`, so the two read as one place. Opened from the profile button
on the Memories header only.

### 4.1 Identity

- The picture, 88pt, and it is the control: **no "Edit" under it** (owner's
  call). With nothing to choose between, one press opens the library;
  otherwise a menu — use my head / use photo or initials, choose photo,
  remove photo.
- Order of preference: your head (when switched on), a photo, initials from
  your name, a person glyph.
- Your name underneath, an inline text field, stored on this phone only.
- **A colour behind the picture** (owner's call): none, or one of the
  categories' own colours, under initials or your head. Initials switch
  between ink and white by the colour's computed luminance. **Not on screen
  all the time** (owner): "Background Colour" in the picture's menu shows the
  swatches, and picking one puts them away after 650ms, long enough to see
  the ring land. Not offered while a photo is the picture, because a photo
  covers it. The picture is therefore always a menu.

### 4.2 Streak

Current and best, side by side, in the owner's numerals. **Best is always
shown**, so a break never erases the record; no red, no "streak lost". A zero
reads "Log a win to start one."

### 4.3 Wins per day, week or month

- **Day / Week / Month**, a segmented control, remembered. Bars are days (14),
  weeks (12) or months (12), in ink, the unfinished one at 0.45 (3.3:1 light,
  4.4:1 dark — computed).
- **The sentence quotes the numbers** (owner: "more fleshed out"): "You're
  keeping a steady pace. About 18 wins a week over the last 4 weeks, close to
  your usual 17." Recent stretch vs the one before — 7 days vs 21, 4 weeks vs
  8, 3 months vs 9 — with a 20% band before anything is called a change.
- **Tap a bar** and the sentence becomes that day, week or month: "5 wins —
  Thursday, Sep 10". Tap it again for the trend back.
- Familiar ticks (0/10/20/30); Audio Graphs via `AXChartDescriptor`.

### 4.4 Milestones (parked)

About 30 exist in code, named after landmarks, so no badge art is needed. If
they come back it is one row, "Next: Eiffel Tower — 42 more". Delete the
habits-era types first.

### 4.5 Your head

No head: one row, **Make your head**, and a footer that says what it is.
A head: **Use as profile picture**, **Show my head on the map**, **Add my head
to photos**, **Make it again**, **Delete head** (confirmed). A first head turns
on the picture and the photo sticker (the sticker still takes a press each
time); the map stays off. Only switches for placements that exist —
a switch that cannot fire is worse than none.

### 4.6 Settings

A row that pushes `SettingsView` (no Done of its own when pushed). The gear is
gone from Memories; `-strataOpenSheet settings` opens Profile and pushes it.

## 5. The head system

### 5.1 One head, and what it is made of

**As built (2026-09-11).** A head is a `HeadRig`: up to five faces — neutral,
brows up, surprised, smile and (for the bundled creator head) wink — an
eyes-shut neutral for blinking, and where the eyes are on each face. Every face shares
one square canvas, lined up BY THE EYES, so changing face never moves the head.

- **Storage:** `Application Support/Head/` — `neutral.png`, `surprised.png`,
  `smile.png`, `shut.png` and `head.json` (each face's eyes, the canvas's
  content height and chin). Not SwiftData, not synced, not shared with the
  widget (both entitlement files are empty on purpose).
- **The eyes are drawn, like the portfolio's.** On every open-eyed face the
  maker finds each eye's outline, paints the photograph's eye over with an
  eye-white sampled from the inner 80% of the opening (the whitest, least
  saturated quarter, pulled 65% toward a neutral grey so skin at the lid line
  can never tint it), a soft edge and a little shade from the upper lid, and
  records the opening's outline, tilt and the iris colour (the 15th to 45th
  percentile of darkness, so lashes and highlights do not decide it). Tried
  on the Mac against 13 cut-outs: natural on 12 of 12 people (beards,
  glasses, older, darker skin); a cat and a dog are rejected, correctly. `LivingHeadView` draws an iris tinted with that colour, clipped to
  those lids. Nothing is placed by hand — the website maker's eye step, which
  the owner found hard, does not exist here. The smile keeps its own eyes: a
  grin narrows them past where an iris sits right.
- **The creator's head is a rig too** (`HeadRig.creator()`), with the eye
  positions measured in the portfolio's calibration mode. It stands in for a
  made head on the simulator (`-strataSeedHead`).
- **One view:** `LivingHeadView(rig:side:liveliness:)` everywhere a head is
  drawn. It centres a head by its face (crown to chin), not its file, so the
  bundled head — which has more margin — and a made head sit the same way.
  `CreatorHead` on the thank-you page is untouched.

### 5.2 Making it

**Strata's camera, not the iOS one.** "Make your head" opens `HeadMakerView`
as a full-screen cover on `CameraService` and `CameraPreview` — the same
viewfinder, wordmark, shutter block and warm ring light (`WarmRingLight`,
shared with `CameraView`) — on the front lens. Never `CameraPickerView`.

1. **Move your head into the outline.** A head-shaped outline — crown, cheeks,
   a jaw that narrows to the chin, not a pill — draws itself centred between
   the wordmark and the prompt, with the viewfinder dimmed around it. No
   rule-of-thirds lines (owner's call). The engine's "lined up" test is
   derived from where the outline is drawn, through the preview's aspect
   fill, so on-screen and in-code can never disagree. One short caption says
   what to change; one tick when you are in.
2. **Press the shutter.** `CameraView`'s own block, dim until you are lined up,
   solid when it will take. The flash sits in `CameraView`'s flash slot — the
   row is the camera's five slots with only the flash filled.
3. **"Blink slowly"** (2.2s), **"Now a big smile"** (1.6s), **"Raise your
   eyebrows"** (1.6s), **"Now look surprised"** (1.6s, the jaw dropped, kept
   only if the inner lips open by 0.12 of the eye distance more than the
   neutral face). The shutter's block fills from the bottom across all four. **No Skip** (owner's call). Each window keeps its
   best frame — most open eyes, most shut, widest smile, highest brows — and
   only keeps a smile or a raise that really happened (`HeadFraming`
   thresholds); anything that did not come through is left out and the
   preview says so, with Retake.
4. **Lift out.** Subject lifting, cropped by the eyes, faded out under the
   chin, eyes painted.
5. **"That's you."** The page comes up over the viewfinder (opaque, never a
   two-way crossfade) and the new head greets you — a brow flash, a smile —
   with Retake and Save.

### 5.2.1 Offered in onboarding

A page between the map and the thank you (owner: visible, "instead of just
hidden in the settings"). The creator's head in a circle on a colour, the way
a picture would show it, "Make your own head", **Make my head** and **Not
now**. Not now declines the head, not the tour. A made head moves you on;
closing the maker without one leaves you on the page.

### 5.3 Behaviour

- **Faces morph.** The incoming face fades in over the outgoing one, which is
  held opaque underneath; a slight squash sells it as the same head moving.
  Irises are drawn once and glide from one face's eyes to the next.
- **A smile returns through a blink**, which hides the change.
- **`.calm`** (the Memories button, the map marker): blinks and glances.
- **`.expressive`** (Profile's picture, the maker's preview): glances, tilts,
  brow raises, brow flashes, the People's Eyebrow, side-eye, eye roll, double
  take, slow blink, smile, surprise, wink and turn, weighted, never the same
  beat twice running, and only beats the head has faces for.
- **It never looks straight at you.** Resting points are 45 to 90% of the way
  out; micro-saccades keep the eyes from locking.
- **Brows are a hard swap**, as in the portfolio: a 220ms flash never arrives
  through a fade.
- **Irises cannot go missing.** The portfolio's bug was a face left in a
  non-neutral or shut state when a beat was interrupted. Here every beat loop
  starts by settling to neutral, and the blink loop checks on every tick: not
  busy but not neutral, not open, or still mid-morph means it settles at once.
- Not creepy on purpose: it looks away every few seconds, its eyes move before
  its head, it blinks as it turns. Reduce Motion holds it still.
- No shadow unless standing on something (the map).

### 5.4 The map (switch: off)

- Swap `UserAnnotation()` (`MemoriesMapView.swift:220`) for
  `UserAnnotation { HeadMarker() }` when the switch is on. When off, the
  native marker is untouched.
- One fixed size at every zoom — the same reasoning as one thumbnail width.
- It is standing on the ground, so it gets the contact shadow.
- Known limit: custom `UserAnnotation` content is reported to lose tap
  interaction. The recentre button already exists, so nothing needs the tap.

### 5.5 The photo sticker (switch: on with a first head)

**As built.** On the photo review, after the shutter, not the viewfinder: the
viewfinder's single gesture layer already owns pinch (zoom) and drag
(exposure), and a still is where you decide what the picture is.

- Your head, small and calm, sits between Retake and Use Photo. Press it and
  your head appears on the photo, low and right inside the block's crop;
  press again to take it off. No frame, no badge, no shadow (it is not
  standing on anything).
- **Like a real sticker** (owner: "super easy"): one finger on the head moves
  it (an 88pt target however small it is drawn); two fingers anywhere on the
  photo pinch and turn it; it snaps upright within 4° with a tick. The move is
  measured in the photo's space, since the head's own space moves with the
  finger and reported half the distance (measured: 81pt for a 158pt swipe,
  157pt after).
- **The block's crop is outlined**, a light hairline inside a dark one,
  nothing dimmed (owner: "subtle, just to see"). Square for Quick and Deep,
  wide for Regular, from `BlockSize.cropAspectRatio`.
- **Use Photo** draws it into the picture at the photo's own resolution
  (`HeadSticker.composite`), before the camera roll and the block see it, so
  both get the photograph you approved. The drawn head is `HeadStill`: neutral,
  eyes open and resting to one side, because a still caught mid-blink or
  mid-grin is not a face anybody chose.
- Screenshot it: `-strataOpenReview small -strataSeedHead -strataHeadOn camera
  -strataReviewSticker`.

### 5.6 The tower (switch: off)

- The head stands on the topmost block, with a contact shadow, and smiles when
  a win drops.
- Read the driving value in the grid's own body, never in the `Equatable`
  `AnimatedBlockView` (the trap has struck four times).
- `.zIndex` above the tower; never cover the empty slot or its drag; hidden
  while rearranging.

## 6. Consistency — the rules Profile and every placement must follow

**No literal numbers.** If a layout wants a value that is not a token, use the
nearest token.

| Thing | Use | Value |
|---|---|---|
| Page side padding | `GridConstants.horizontalPadding` | 16 |
| Glyph ↔ its label | `gapTight` | 8 |
| Items in a set | `gapItem` | 12 |
| Heading ↔ what it heads | `gapLabel` | 16 |
| Header ↔ content under it | `gapWide` | 24 |
| Section ↔ section | `gapSection` | 32 |
| Title position (type) | `headerTopPadding(forTitleSize:)` | computed |
| Title position (drawn) | `headerArtworkTopPadding` | computed |
| Header buttons | `GlassIconButton`, `defaultSide` | 44 |
| Button vertical placement | `(Typography.screenTitleCap - GlassIconButton.defaultSide) / 2`, as `MemoriesView.titleRow` | computed |
| Between header buttons | `gapTight` | 8 |
| Radii | `radiusSurface` / `radiusField` / `radiusControl` / `radiusMark` | 20 / 12 / 8 / 4 |
| Dividers | `headerDividerHeight`, `headerDividerOpacity` | 0.5pt, 6% |
| Scrolling page above the tab bar | `tabBarClearance` | 110 |

- **Type:** SF Pro Rounded, two weights. Numbers in `Typography.numeral` /
  `tally`. Section labels `Typography.sectionLabel`. Body `bodyMedium`.
  Captions `caption`. Semibold only in the wordmark.
- **Colour:** ink `.primary.opacity(0.85)`; `inkSecondary` / `inkQuiet` for
  labels; `accentWarm` for tint; `AppColors.switchOn` for switches. Category
  colours only on things that have a category.
- **Surfaces:** no white rims, frosted bands or card shadows — those say
  "block". Sections are separated by space and a hairline.
- **Motion:** `GridConstants` tokens only (`headTurn`, `eyeSaccade`,
  `gentleReveal`, `naturalSettle`, …). Critically damped by default.
- **Haptics:** `HapticsEngine` only.
- **Appearance:** light and dark, both screenshotted, both measured.

## 7. Privacy — part of the change, not after it

- Faces are processed on device and never transmitted, so they are not
  "collected": `NSPrivacyCollectedDataTypes` stays empty.
- `PrivacyPolicyView` gains a short section: the head is made from your camera,
  stays on this phone, is never sent, and Delete removes it.
- Re-read `NSCameraUsageDescription` in BOTH built Info.plists; if it only
  mentions win photographs, it must also cover making a head.

## 8. Build order

Each step is useful on its own and ships with its switch off.

1. **Profile** — the button (initials or photo), streak, trend chart, Settings
   row, gear removed from Memories. No head.
2. **The head** — maker, storage, `HeadView(source:)`, "Head" as a picture
   choice.
3. **Map marker** switch.
4. **Camera sticker** switch.
5. **Tower** switch.

## 9. Verification (rule zero)

- Build and run every step. Screenshots in light and dark.
- Suggested `DebugHarness` flags: `-strataOpenSheet profile`,
  `-strataSeedHead` (the bundled creator faces as a stand-in head),
  `-strataHeadOn map,camera,tower`.
- The profile button must land at the same y as the Memories gear it replaces.
  Measure before and after.
- The trend sentence: `-strataSeedHistory 120`, then check each of the three
  sentences and the not-enough-data case.
- Everything behind a tap is unverified until a UI test presses it. Say so.
- **The maker runs on a device only** — subject lifting does not run in the
  simulator. Test it with glasses, in low light, and with a face turned away,
  and confirm each gives an instruction rather than a broken head.
- **Head mode's chrome can still be photographed in the simulator** with a
  forced flag (`-strataOpenHeadMaker [outline|blink|lift]`), the same way the
  zoom pill is — the simulator has no capture device, so the viewfinder is
  empty but the outline, captions, ring and lift can be checked.

## 10. Coordination

- New files (Profile view, its view model, the maker, `HeadView`, `HeadStore`)
  conflict with nothing.
- Four touch points sit in files the other session is active in: the Wins
  header and gear (`MainAppView`), the Memories title row (`MemoriesView`), the
  map annotation (`MemoriesMapView`), the camera controls (`CameraView`). Do
  those with that session or after it.
- Moving Settings also touches `MainAppView` (`settingsButton`, the
  `-strataOpenSheet settings` route) — same rule.
- Head mode touches `CameraView` (1,200+ lines, one gesture layer) and
  `CameraService` (additive video output). Neither was in the other session's
  last three hours, but check `git log` for both before starting.
- `GridConstants`: additive only.

## 11. Open questions for the owner

- A name field in Profile, or only the picture?
- 12 weeks only, or a Weeks / Months switch? (One view is easier for a first
  look; a switch is one more decision.)
- Bring milestones back as a single "next" row?

## Sources

- Fox & Bailenson (2009), *Virtual Self-Modeling*, Media Psychology — https://www.tandfonline.com/doi/abs/10.1080/15213260802669474
- Silverman & Barasch (2023), *On or Off Track*, Journal of Consumer Research — https://academic.oup.com/jcr/article-abstract/49/6/1095/6623414
- Harkin et al. (2016), *Does Monitoring Goal Progress Promote Goal Attainment?*, Psychological Bulletin — https://pubmed.ncbi.nlm.nih.gov/26479070/
- Apple HIG, Charts — https://developer.apple.com/design/human-interface-guidelines/charts
- Apple HIG, Tab bars — https://developer.apple.com/design/human-interface-guidelines/tab-bars
- Apple Support, View your data in Health — https://support.apple.com/guide/iphone/view-your-health-data-iphe3d379c32/ios
- Apple Support, Add or edit your contact info and photo — https://support.apple.com/guide/iphone/add-your-contact-info-iph18b749db1/ios
- Apple Fitness Trends — https://www.macstories.net/stories/activity-trends-in-ios-13/
- Genmoji and stickers in third-party text (WWDC24) — https://developer.apple.com/videos/play/wwdc2024/10220/
- Custom user-location annotation limits — https://developer.apple.com/forums/thread/776494
- Soukupová & Čech (2016), *Real-Time Eye Blink Detection using Facial Landmarks* — https://cmp.felk.cvut.cz/ftp/articles/cech/Soukupova-TR-2016-05.pdf
- `VNGenerateForegroundInstanceMaskRequest` — https://developer.apple.com/documentation/vision/vngenerateforegroundinstancemaskrequest
