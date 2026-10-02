# Where two screens answer the same question differently

Started 2026-10-01, at the owner's instruction: "make sure screens are
consistent like I see the colour on the plan isnt the same as the wins edit
sheet with the icons and stuff."

He found one. This is the pass that looks for the rest of the class, because an
instruction given as an example is an instruction about the class.

**This is check 3 of `docs/screen-audit.md` tested rather than asserted.** Check
3 reads "every surface, control, card, rim and shadow comes from the system. A
privately rebuilt one fails." Every screen passed it. The method was to read a
screen and ask whether what is on it came from a component; the method here is
to take each component, list its call sites, and then go looking for the places
that draw the same thing without it. The two methods do not agree.

**Read only from source and from captures already on disk.** Nothing was built,
run or tapped. Every pixel figure below names the PNG it was sampled from.
`/tmp/final3/` is dimmed by a camera permission alert over the whole set and
every colour in it reads about 20 levels light, so nothing is sampled from
there; `/tmp/room/` (16:26) and `/tmp/g3/` are the colour sources and
`/tmp/states/` (21:21) is the newest geometry.

**Every line number is as of 22:15 on 2026-10-01, on `9e4a50e` plus the working
tree.** Two other people were editing this tree while the pass ran and eleven of
the files below changed under it, some by thirty lines. Every finding was
re-resolved against the file as it stood at 22:15 and every one of them was
still live, but a number here is a pointer rather than an address: search for
the quoted code, not for the line.

---

## 1. The drift, worst first

### 1.1 The head maker's Save is white on a white page, 1.04:1

| | Retake | Save |
|---|---|---|
| file | `HeadMakerView.swift:791` | `HeadMakerView.swift:845` |
| ink | `AppColors.inkSecondary` | `AppColors.onDarkStrong` |
| what that is | adaptive, 0.62 black on light | FIXED white at 0.95 |
| ground | `WarmBackground` (`HeadMakerView.swift:719`) | the same ground, same row |
| measured | **6.11:1** | **1.04:1** |

Sampled from `/tmp/g3/after/18-head-maker.png`, which is the preview state of
the maker: the ground is rgb(243) and the darkest pixel anywhere inside the word
"Save" is rgb(239). Retake, eleven points to the left on the same row, is
rgb(91). A 15pt word is held to 4.5:1.

This is the one press that keeps a head somebody has just made, and in light
mode it is not there. It is the fault `CLAUDE.md` names under "An ink is not a
surface", for the fifth time: an `onDark*` token is for the camera, the review
and the viewfinder, which are dark whatever the phone is set to. The preview
page is not one of those. In dark mode the page is rgb(29) and the button reads
fine, which is why this survived.

The doc comment directly above the line argues at length for `accentPrimary` and
quotes 4.34:1 for it. **The code is neither that nor what the comment says it
replaced.** See §2.1.

**Which wins:** `inkPrimary`. It is what the confirm action on Profile and
Settings already is, it inverts with the scheme, and it is one step above the
`inkSecondary` that Retake wears, so the pair reads as a primary beside a
secondary. **Cost:** one token on one line.

### 1.2 The Memories tab never fills, and the function that fixes it is dead

| | the tab bar | the drawing of the tab bar |
|---|---|---|
| file | `MainAppView.swift:656` to `:690` | `MemoriesStill.swift:185` |
| Wins | `selectedTab == .tower ? "square.stack.fill" : "square.stack"`, typed inline | `tab.icon(selected: on)` |
| Camera | `selectedTab == .camera ? "camera.fill" : "camera"`, typed inline | `tab.icon(selected: on)` |
| Memories | `StrataTab.memories.icon`, which is `icon(selected: false)` | `tab.icon(selected: on)` |
| what arrives | every glyph filled, in every state | hollow, and filled on the one you are on |

`StrataTab.icon(selected:)` (`TabBarView.swift:25`) exists to be the one place
this is decided, and its own doc comment names the duplication: "`MainAppView`
then typed both strings inline for Wins and for Camera and passed the bare
`icon` for Memories. So `selectedIcon` was read by nothing at all, and Memories
is the one tab that never fills when you are on it."

**The function was written and the call sites were never changed.** Its only
caller in the app is `MemoriesStill`, which is a picture of the tab bar inside
the onboarding device frame.

Measured on `/tmp/states/s01-wins-empty.png` (Wins selected) against
`/tmp/states/s04-memories-one.png` (Memories selected), over the same 280x120px
box around each glyph: the Wins glyph is 3,778 dark pixels in one and 3,740 in
the other, a 1.0% difference, and the largest per-pixel delta anywhere in the
box is 21 of 255, which is the selection capsule's ground moving, not a glyph
changing. Zoomed, the Memories glyph is `photo.stack.fill` in both, although
line 689 asks for `photo.stack`. So the two strings in the source arrive on
screen as one, and the filled variant is being applied over the top of them.

So the app says "which tab" with the capsule alone, and the onboarding drawing
promises a second signal the app does not have.

**Which wins:** the three `Tab` labels read `icon(selected: selectedTab == …)`,
and if the filled variant still overrides them the drawing comes off it too, so
the mock and the bar agree. **Cost:** three lines, plus a look at the built bar
to see which way it resolves.

**What is not established here:** why the two strings resolve to one glyph. The
likeliest answer is that SwiftUI's `Tab` applies the `.fill` symbol variant to
every tab label, in which case nothing the source writes can change it and the
fix is to delete the branch and the drawing's rather than to wire it up. That
needs a build to settle, and this pass did not have one. What IS established is
that the app draws one glyph where the source asks for two, and that the
onboarding drawing draws two.

### 1.3 Switches are two colours, and the token's own doc says nothing reads it

| | Settings | Profile, and the plan line |
|---|---|---|
| file | `SettingsView.swift:224, 272, 312, 322, 359, 398` | `ProfileView.swift:897, 967, 978, 989`; `PlanItemDetailSheet.swift:72` |
| tint | `AppColors.inkPrimary` | `AppColors.switchOn`, #138BC2 |
| count | 6 switches | 5 switches |

Both files carry the same paragraph, almost word for word, about why the row's
`Text` takes `inkPrimary` rather than the row taking the tint. One of them then
changed its switch tint and the other did not.

`ProfileView`'s own header says Profile is "built as a `Form` on
`WarmBackground` exactly like `SettingsView`, so pushing from one to the other
reads as one place". You push from Profile to Settings through
`ProfileView.swift:1069`, and the switches change colour on the way.

**And `switchOn` says this cannot be happening.** `CategoryColors.swift:406`:

> **NOTHING READS THIS ANY MORE, AND THAT IS THE DECISION. 2026-10-01.** The
> owner: "I think I prefer if the primary color was the black and white button
> for dark mode instead of this blue color we are going with right now lets just
> do the basic." So the app is monochrome: every action, every switch and every
> link is `inkPrimary`.

Five live readers. The decision is recorded and half-applied.

**Which wins:** `inkPrimary`, because the owner asked for it by name and the
token's own doc already says so. **Cost:** five lines.

### 1.4 "Done" is two inks, and three of the six sheets do not make it 44pt

Sampled from `/tmp/room/`, the darkest pixel of the confirm word against the
sheet's rgb(247) ground:

| sheet | word | file | ink | measured |
|---|---|---|---|---|
| Add a win | Add / Save | `AddWinSheet.swift:559` | `accentWarm` | rgb(28,26,24), **16.18:1** |
| Plan | Done | `PlanSheet.swift:200` | `accentWarm` | rgb(28,26,24), **16.18:1** |
| Line | Done | `PlanItemDetailSheet.swift:302` | `accentWarm` | not captured |
| Profile | Done | `ProfileView.swift:119` tint | `inkPrimary` | rgb(37,36,37), **14.42:1** |
| Restore | Cancel / Done | `RestoreBackupView.swift:409` | `inkPrimary` | not captured |
| Settings | Done | `SettingsView.swift:868` | never drawn, see below |

Two near-blacks, nine levels apart, for one word on six sheets. Cancel on the
add sheet is `inkSecondary` at rgb(94,93,94), 6.11:1, which is the step the
other five do not have.

**Settings' Done is never drawn.** `settingsToolbar` is behind `if !isPushed`
(`SettingsView.swift:844`) and both call sites in the app pass `isPushed: true`
(`ProfileView.swift:125` and `:1069`). So `isPushed` has one value everywhere,
which is the condition `SectionHeading.swift:133` writes down about a different
flag: "A flag with one value in the whole app is a decision nobody made."
`settingsDoneButton` and the twelve-line argument above it describe a control
nobody can reach.

**The 44pt frame is on three of six.** `AddWinSheet.swift:546` and
`PlanSheet.swift:197` each carry `.frame(minWidth: 44, minHeight: 44)` with the
measurement that earned it ("Done came out 68x36 and the plus 35x36"), and
`AddWinSheet`'s comment says `PlanSheet` "carries the same fix with the owner's
own words on it, 'really easy to miss click', and this sheet never got it."
`ProfileView.swift:1115`, `SettingsView.swift:868`, `PlanItemDetailSheet.swift:295`
and `RestoreBackupView.swift:409` are all bare `Text`, so all four are still the
68x36 the audit measured.

**Which wins:** one `sheetAction(_:role:)` modifier holding the font, the ink and
the 44pt box, called by all six. The ink should be `inkPrimary`, because that is
what the two sheets that argued it out landed on and `accentWarm` is a fixed
warm black that does not invert the way the ink does. **Cost:** a 15-line view,
six call sites.

### 1.5 The plan line deletes with one tap, from the slot every other sheet uses for Cancel

| | every other delete | the plan line |
|---|---|---|
| file | see table in §3.3 | `PlanItemDetailSheet.swift:302` |
| where | a Form row, a menu item, the sheet body | `ToolbarItem(placement: .topBarLeading)` |
| what is normally there | Cancel (`AddWinSheet`), ＋ (`PlanSheet`) | a trash glyph |
| confirmation | yes, on 4 of 6 | **none** |
| colour | `warmRed` or `destructiveTint` | the system's #FF3B30 |

It deletes the line, commits and dismisses in one press, from the position a
thumb has learned means "back out of this". `PlanSheet` right behind it has ＋
in the same slot. The app's other irreversible press, Reset All Data, has a
confirmation whose message runs to 23 words.

**Which wins:** keep the delete, move it out of the leading slot and give it the
confirmation every other destructive press in the app has. **Cost:** a
`confirmationDialog` and a placement.

### 1.6 The filled primary action is built twice

| | `PrimaryCapsule` | the map's "Turn On Places" |
|---|---|---|
| file | `PrimaryCapsule.swift:140-166` | `MemoriesMapView.swift:753-761` |
| fill | `AppColors.inkPrimary` | `AppColors.slotInk`, rgb(64,61,57) |
| height | 50 (`PrimaryCapsule.height`) | 46 |
| width | full | content plus 22 either side |
| label | `Typography.headerMedium`, 17 | `Typography.headerSmall`, 15 |
| rim | `BlockRim.gradient` at `blockRimWidth` | none |
| press | `.pressWord` | `.plain`, so no answer at all |
| haptic | `HapticsEngine.lightTap()` inside the type | `lightTap()` at the call site |

`PrimaryCapsule`'s whole reason for existing is on its first line: "Three screens
had three copies of it ... So the app said 'this is the thing to press' in two
colours depending on which screen you were standing on." It took three of them
and the fourth was in a file the sweep did not open.

The map's comment cites a precedent that no longer exists: "it takes the app's
own primary pill: `slotInk` filled with the page's ground for a label, which is
what `OnboardingView.pillFill` draws on a light ground". There is no `pillFill`
in the tree. Onboarding draws `PrimaryCapsule`.

**Which wins:** `PrimaryCapsule`. **Cost:** one call, minus eight lines.

### 1.7 The outlined capsule is built twice, on the same six pages

| | `PrimaryCapsule.waiting` | the walkthrough's LinkedIn button |
|---|---|---|
| file | `PrimaryCapsule.swift:168-183` | `OnboardingView.swift:886-899` |
| shape | `Capsule(style: .continuous)` | `Capsule()` |
| ring | `AppColors.inkTertiary` at `strokeThin` | `AppColors.inkQuiet` at `strokeThin` |
| label | `inkSecondary` | `inkPrimary` |
| height | `PrimaryCapsule.height` | `PrimaryCapsule.height` |

The corner is the part that is already written down as a bug.
`PrimaryCapsule.swift:171`: "`Capsule(style: .continuous)`, where the
walkthrough's waiting pill was a plain `Capsule()`. Its own filled state was
already `.continuous`, so the two states had different corner profiles on the
one page that shows both, which is this file's whole subject in miniature."

The fix went into the extracted type. The file it was extracted from still draws
the plain `Capsule()`, forty lines above the call to the type that fixed it.

**Which wins:** `PrimaryCapsule` grows a third initialiser, or the LinkedIn
button uses `waiting:` with no reason string. **Cost:** one initialiser.

### 1.8 `PressResponse.press` has no call sites, and the controls it names are still `.plain`

Counted across `Strata/Views`: **25 `.buttonStyle(.plain)`, 4 `.pressSurface`,
4 `.pressWord`, 1 `.bordered`.** `PressResponse.press`, the base variant, is
used nowhere. Three of the 25 wrap a Liquid Glass label and are correct
(`GlassIconButton.swift:71`, `ProfileAvatar.swift:150`, `PhotoViewer.swift:379`);
two more wrap `glassCapsule` labels (`ReplayView.swift:767, 796`).

`PressResponse.swift:20` names its targets by name: "What was left with nothing
was the plain-glyph row: the grid, the flash, the flip and the timer, and the
size chips beside the shutter." Both are still `.plain`:
`CameraView.swift:1452` (the glyph helper the grid, flash, flip and timer all
go through) and `CameraView.swift:756` (the size chips).

The twenty with no press answer, by file:line:
`AddWinSheet.swift:741` (the photo well), `:830` (the colour row),
`CameraView.swift:680` (Retake and Use Photo), `:756`, `:1340`, `:1452`,
`FilmLookStrip.swift:99`, `HeadLookPicker.swift:107`,
`HeadMakerView.swift:599, 640, 675, 851`, `HeadPickerRow.swift:203`,
`HeadSticker.swift:333`, `MemoriesMapView.swift:761`,
`MonthCalendarView.swift:317`, `PlanItemDetailSheet.swift:209, 258`,
`PlanSheet.swift:519, 580`, `ProfileView.swift:319, 403`.

The camera's own refused screen uses `.pressWord` at `CameraView.swift:522` and
its review's Retake and Use Photo, two screens later, use `.plain`. The head
maker's Retake and Save do too. So the two most-pressed words in the capture
flow are the ones with no answer.

**Which wins:** `.press` on the glyphs, `.pressWord` on the words,
`.pressSurface` on the cards. **Cost:** about twenty lines, no new code.

### 1.9 The two picture pickers disagree, and one of them carries the measurement

| | `FilmLookStrip` (the camera review) | `HeadLookPicker` and `HeadPickerRow` (Profile) |
|---|---|---|
| file | `FilmLookStrip.swift:36-102` | `HeadLookPicker.swift:35-110`, `HeadPickerRow.swift:111-211` |
| tile | 58pt, `blockCornerRadius(forCell:)` | 60pt, `blockCornerRadius(forCell:)` |
| chosen rim | `onDarkStrong` at 2pt | `inkPrimary` at 0.55, `strokeMedium` |
| unchosen rim | `onDarkFaint` at 1pt | nothing |
| unchosen scale | **1.0** | **0.94** |
| caption | `onDarkStrong` / `onDarkQuiet` | `inkPrimary` / `inkSecondary` |

The inks differ because the grounds differ, which is correct. The scale does
not have that excuse, and `FilmLookStrip.swift:75` is the measurement that
removed it:

> `scaleEffect` does not change a layout box, so all four boxes stayed 58pt and
> the DRAWN squares did not: an unchosen one lost 1.74pt a side. Measured on the
> built review, the declared 8pt gutter rendered as **9.7 / 11.4 / 11.4**: one
> number on the ladder arriving on screen as two that are not, and the pattern
> moves every time you pick a different look.

`HeadPickerRow` was edited at 22:00 while this pass ran, and its ring now hides
when there is only one head (`ringInk(isChosen:entries:)`, `:48`). The scale did
not move. With one head there is nothing to compare the tile against, so the
0.94 never shows; with two or more it does, and `HeadPickerRow` lays its tiles
out in an `HStack(spacing: gapItem)` with fixed 60pt frames, so the same
arithmetic applies: a 0.94 scale takes 3.6pt off each
unchosen tile and the declared 12pt gutter renders 12.0 beside the chosen one
and 15.6 between two unchosen ones. `HeadPickerRow`'s own doc says it is
"deliberately the same shape as `HeadLookPicker`", and the two of them do agree.
The one they both disagree with is the one with the numbers on it.

**Which wins:** drop the scale, as the review did, and keep the ring plus the
caption ink step, which is the two signals `FilmLookStrip` kept. **Cost:** two
lines. **Note the second claim that goes with it:** both pickers' rings justify
themselves by saying the swatch "says chosen three times over: the ring, the step
up from 0.94 to full size, and the name under it". On `HeadPickerRow` the name is
now drawn only when somebody typed one (`:179`), so for a default roster it says
it twice, and dropping the scale takes it to once. The ring is then doing the
whole job at 0.55 ink, which should be re-measured before it ships.

### 1.10 The plan line's form glyph is the only one not drawn by `SettingsIcon`

| | every Settings and Profile row | the plan line's Repeats row |
|---|---|---|
| file | `SettingsView.swift:1004-1035` | `PlanItemDetailSheet.swift:94-96` |
| component | `SettingsIcon` | a bare `Image(systemName:)` |
| size | `GridConstants.iconCategory` (13), scaled with Dynamic Type | the `Label`'s own, fixed |
| ink | `AppColors.inkSecondary` | `AppColors.accentWarm`, a near-black |
| box | 32x32, which is what sets the 44.65pt row | none |

Three `Form`s in the app. Two of them draw their row glyphs through one
component whose doc explains that the 32pt box is what lifts the row over 44,
and the third has one glyph and draws it by hand, at a different size, in an ink
three steps darker than every other glyph in the app.

This is the "icons and stuff" half of the owner's sentence, on the same sheet he
was looking at.

**Which wins:** `SettingsIcon`. It is already internal for exactly this reason:
"Internal so Profile's Settings row wears the same glyph at the same size."
**Cost:** one line.

### 1.11 Two consecutive Profile rows carry the same glyph for two different things

`ProfileView.swift:986` draws `SettingsIcon(systemName: "camera")` for "Add My
Head to Photos". `ProfileView.swift:1001` draws `SettingsIcon(systemName:
"camera")` for "Add Another Head". They are fifteen points apart.

Visible in `/tmp/g3/after/19-head-picker.png`: the two rows under the switches
are the same camera outline, and the second one is the only row on the page that
opens a whole screen.

**Which wins:** the second one is an add, and `plus` is already the app's add
glyph (`PlanSheet.swift:206`). **Cost:** one string.

### 1.12 The falling block's socket is a private glass slot with the forbidden rim

| | `SlotGlass` | `MainAppView.ghostSlot` |
|---|---|---|
| file | `SlotGlass.swift:108-117` | `MainAppView.swift:3536-3543`, called at `:3396` |
| material | `GlassRecipe.slot`, `.ultraThinMaterial` pre-26 | `.ultraThinMaterial` only |
| rim | **none, deliberately** | `Color.white.opacity(0.2)` at 1pt |
| ink | the caller draws `slotInk` | none |

`SlotGlass.swift:95` is the argument it breaks: "The fallback deliberately draws
no white rim ... CLAUDE.md forbids giving a surface a white rim or a frosted edge
because that is a block's own claim to be a lit object you built, and this
surface is already block-shaped and block-sized."

`ghostSlot` is block-shaped, block-sized, and has the white rim. It is on screen
only while a block is in the air above it, which is why nobody has caught it.

**Which wins:** `glassSlot(cornerRadius:)` plus the slot's own recess, so the
socket a block falls into is the socket it is pressed out of. **Cost:** eight
lines deleted.

### 1.13 The count readout is hand-built four times, and two of them argue the opposite case at the same size

| | under a screen title | in a card's caption |
|---|---|---|
| files | `DayAlbumDetailView.swift:186-190`, `PhotoCollectionView.swift:152-156` | `AlbumCarousel.swift:84-100`, `MemoriesShelf.swift:328-351` |
| digits | `StrataFont.relative(15, to: .subheadline)` | `StrataFont.relative(15, to: .subheadline)` |
| word | `Typography.screenSubtitle` | `Typography.screenSubtitle` |
| ink | `inkTertiary` | `inkTertiary` |
| optical inset | **none** | **`-StrataFont.opticalInset * 15`** |
| number transition | `.numericText()` on the day album only | none |

Four copies of six lines. The only thing left that separates the two pairs is
the optical inset, and each pair has a written argument for its answer at the
same 15pt size: the day album says "at 15pt the face's mean left bearing works
out near 1pt, under the size worth correcting", and the shelf says the inset is
what "stand[s] the two lines of the caption on one edge".

Both can be true, because they are different jobs: a count under a title stands
alone, and a count in a caption stands under a name. But the record of the
decision says otherwise, and it is stale. See §2.4.

**One of the four is dead.** `MemoriesShelf.countLine` is reachable only from
`MemoriesShelf.card(_:width:)` at `:186`, and `card` has no caller: the body
calls `row(width:)` at `:143`, which draws `AlbumCard`. The replay cards moved to
`ReplayRow`. Lines 186 to 355 of that file, including `poster`, `periodName`,
`nameLine`, `systemName` and `countLine`, are unreachable, and with them the
`model`, `now`, `excluding`, `transitionNamespace` and `onPlay` properties the
call site at `MemoriesView.swift:203` still fills in.

**Which wins:** one `CountReadout(_:unit:inset:)` with the inset as the
parameter, which is what `SectionHeading.swift:118` says the shared one would
need. The dead half goes first.

### 1.14 Two hairline widths on one page, and the thinner one is the rule

`MemoriesShelf.swift:246` strokes an album card's edge at `1 / displayScale`.
`ReplayRow.swift:135` strokes a replay thumbnail's edge at a flat `0.5`, and its
comment says "The same ink hairline the shelf's posters wear ... See
`MemoriesShelf`." On a 3x phone those are 0.333pt and 0.5pt, 50% apart, on two
cards one band apart on the Memories page.

`RestoreBackupView.swift:334` states the rule: "One hairline, one token:
`1 / displayScale`, not a flat 0.5, which is 50% too heavy on a 3x phone."

**Which wins:** `1 / displayScale`. **Cost:** one line, and `ReplayRow` gains a
`@Environment(\.displayScale)`.

### 1.15 `IconStyle` exists to stop fixed icon sizes and five sites still use them

`IconStyle.swift:7`: "`.font(.system(size:))` is a fixed size, it does not
respond to the user's text size at all, so icons stayed put while the labels
beside them grew. brand.md requires Dynamic Type across every screen (WCAG
1.4.4)."

Thirteen call sites use `.iconSize`. Five do not:

| file:line | glyph | size |
|---|---|---|
| `ReplayRow.swift:102` | `play.circle.fill` | `.system(size: 30)`, and 30 is on no icon ladder |
| `GlassIconButton.swift:92` | every glass button in the app | `.system(size: glyphSize)`, default 17 |
| `CameraView.swift:1441` | the chrome glyph helper | `.system(size: 21, weight: .regular)` |
| `PlanBullet.swift:92` | the checkmark | `.system(size: side * 0.52)`, geometry-solved |
| `CachedImageView.swift:116` | the missing-picture glyph | geometry-solved |

The last two are a fraction of an object and are the exception `Typography`
already declares for geometry-solved numerals. The first three are not. The
second is the worst of them, because it is the shared component: every
`GlassIconButton` and `GlassIconLabel` in the app has an icon that does not grow
with Dynamic Type, and `17` is typed twice there as a literal rather than read
from `GridConstants.iconToolbar`, which is the same 17.

**Which wins:** `.iconSize(GridConstants.iconToolbar, relativeTo: .body, weight:
.medium)` inside `GlassIconLabel`, and a token for the play glyph.

### 1.16 Two blocks are drawn without the app's inside light

`BlockSurface` takes its fill from the caller. Eight call sites hand it
`EtherealFill.fill(...)`: `BlockFace.swift:75`, `MonthCalendarView.swift:339`,
`MonthTowerView.swift:109`, `PlanBullet.swift:89`, `MergedGroupView.swift:122`,
`AddWinSheet.swift:658`, and the two swatch drawings.

Two hand it a flat colour:

- `PlanItemDetailSheet.swift:163`, the plan line's colour swatches, which is the
  screen the owner was looking at.
- `OnboardingView.swift:1291`, the walkthrough's demo block, which is the first
  block anybody ever sees.

`EtherealFill` is `coreBoost` 0.035 over `rimSaturation` 0.94 with `rimLift`
0.03, so the difference on a 34pt swatch is small and on the walkthrough's cell
is not. It is still two objects in the app that are a block everywhere except in
the one property the owner asked for by name ("I want the blocks to have this
kinda glass transparency as well in them, for the inner colour instead of just
flat").

**Which wins:** `EtherealFill.fill`. **Cost:** two lines.

### 1.17 Two tokens still spell a colour the way `CLAUDE.md` forbids

`GridConstants.swift:165` and `:167`:

    static let fillWell = Color.primary.opacity(0.04)
    static let fillHairline = Color.primary.opacity(0.08)

`CategoryColors.swift:199` carries the rule these break: "`.primary.opacity(x)`
is not a colour, it is a colour in light mode." Eight hand-written instances
were converted to adaptive tokens in that pass. Two survived as tokens, which
is worse than surviving as literals, because a token reads as sanctioned. Ten
call sites between them, including every card hairline on the Memories page and
the plan line's seven day chips.

They may well be right by accident: 4% and 8% of black on a 253 page and of
white on a 29 page are not far apart. **Nobody has measured it**, and the rule
exists because the four cases that were measured were all wrong.

### 1.18 `radiusField` has no call sites

The radius ladder in `GridConstants.swift:150-158` is four rungs.
`radiusSurface` has 2 call sites, `radiusControl` 1, `radiusMark` 2, and
**`radiusField` 0**. The only mention of it left in the app is
`MemoriesShelf.swift:189` saying "the block ladder at this card's size, not the
flat `radiusField`." Everything that was a field now derives its corner from
`blockCornerRadius(forCell:)`, which has 18 call sites.

This is the condition the 2026-10-01 sweep deleted `cornerRadiusSmall` and
`cornerRadiusMicro` for, in its own words: "Two names for one number is how a
ladder stops being one." `docs/design-audit.md` already had it open under "Still
open".

---

## 2. The decisions that were written down, and whether they still hold

### 2.1 Three files name a colour they do not use

This fault was found once, written up, and has recurred twice since.

`ReplayRow.swift:51` is the write-up: "The comment that stood here said this row
'carries the page's only accent' and named `accentPrimary`; the code has drawn
`inkPrimary` the whole time, so the file was claiming a colour it did not use."

Two more are live now:

- `RestoreBackupView.swift:395` is headed "**`accentPrimary`, and it was
  `accentWarm`.** (2026-10-01)" and runs eight lines on why Cancel is blue. The
  code at `:410` is `.foregroundStyle(AppColors.inkPrimary)`.
- `HeadMakerView.swift:820` is headed "**`accentPrimary`, measured.**" and gives
  4.34:1 for it. The code at `:845` is `AppColors.onDarkStrong`, which measures
  1.04:1 on that page (§1.1).
- `ProfileView.swift:105` says "The primary, on the platform's own controls. The
  owner: 'make sure you are changing the primary to the blue.'" The tint at
  `:119` is `AppColors.inkPrimary`.

**Verdict: the arguments are dead and the colour they argue for is dead with
them.** `AppColors.accentPrimary` has **zero call sites**. The owner's later
instruction ("lets just do the basic") retired it, which is correct, and the
comments were never caught up. All four should be rewritten to say what the code
does; `accentPrimary` should go the way `accentPurple` and `healthGreen` went in
the same file, with its measurement kept in the comment that replaces it.

### 2.2 "There is exactly one Semibold in the app"

`CLAUDE.md`, under Settled: "**SF Pro Rounded, two weights** ... There is
exactly one Semibold in the app and it is no longer the wordmark's ... the
exception moved to `MemoriesTitle`."

**Verdict: superseded twice over and the file does not say so.** The face is SF
Pro, not Rounded, since 2026-09-23, and `Typography.swift:4` records that and
says `CLAUDE.md` is stale on it. Then on 2026-10-01 `Typography.titleWeight`
became `.semibold` (`Typography.swift:114`), and it is the DEFAULT argument of
`tier(_:)`, so **`screenTitle`, `headerMedium`, `headerSmall` and `sectionLabel`
are all Semibold.** Semibold is not an exception, it is the title weight of the
whole scale.

Three doc comments did not follow it and now state the wrong weight for the
token under them:

- `Typography.swift:230`: "15 Medium. Buttons, a row's value, a look's name."
  `headerSmall` is `tier(.subheadline)`, which is Semibold.
- `Typography.swift:242` on `sectionLabel`, same.
- `SettingsView.swift:664`, arguing to the owner that Settings' labels are not
  thin: "`Typography.sectionLabel` is `tier(.subheadline)` at `titleWeight`:
  **15pt Medium**, which is exactly the floor." It is `titleWeight` and
  `titleWeight` is Semibold.

The argument put to the owner is sound and the number in it is wrong. Nothing on
screen needs to change; three comments and one `CLAUDE.md` entry do.

### 2.3 "The dash exists nowhere else in this app"

Two files say the app has no dashed outline, and three files draw one.

- `AddWinSheet.swift:608`: "The dash exists nowhere else in this app. The
  comment above it claimed it matched 'the tower's empty slot', and the tower's
  slot is a solid stroke."
- `MemoriesView.swift:755`: "The dash is a vocabulary this app does not have."

Live dashes: `ReplayView.swift:895` (the replay's loading slot),
`PlanSheet.swift:447` (the empty plan's ghost bullet),
`HeadMakerView.swift:279` (the head outline over the viewfinder).

**Verdict: the vocabulary is coherent and the two claims are false.**
`ReplayView.swift:880` states the rule the other two should have cited: "the
real slot is a thing you press and a continuous hairline is a boundary you can
aim at, while this is a thing you wait for, and a dash is how this app says not
yet." The plan's ghost bullet is a thing you wait for. The head outline is a
thing you line up with, which is a third job and is over a live camera where
nothing else in the app lives.

Keep all three. Fix the two sentences, because the next pass that reads
`AddWinSheet`'s will delete a dash that is carrying a meaning.

### 2.4 "Two rungs, differing for reasons each one measured off a build"

`SectionHeading.swift:98` records why the count readout is not shared:

> **The page-level count IS built, twice, and neither is `CountReadout`'s
> shape.** Two rungs, differing for reasons each one measured off a build:
> a count under a screen title: 15pt ... NO optical inset ... a count in a
> card's caption: **13pt** relative to `.footnote`, WITH `-StrataFont.opticalInset * 13`.

**Verdict: the argument is about a size that no longer exists.** The caption rung
went to 15 in the same day's type pass: `AlbumCarousel.swift:107` ("It was 13 and
is 15") and `MemoriesShelf.swift:357` ("It was 13 and moved with everything else
off that rung"). The record still says 13.

So the two rungs are now one size, one face, one ink and one word tier, and the
only thing left between them is the inset. The reason not to share has shrunk to
a boolean. See §1.13.

### 2.5 "Only three callers, all of them shelves on this page"

`SectionHeading.swift:44`. **Verdict: one caller.**
`PhotoGalleryGrid.swift:148` is the only one left; the ALBUMS heading was
deleted (`MemoriesShelf.swift:95`) and so was the replays heading.

Nothing is broken by that, but the component's own argument for `gapSection * 2`
rests on being "the biggest gap on the page" across the shelves it headed, and
it is now one heading over the photo grid. Worth re-reading before the next
Memories pass, not worth changing now.

### 2.6 Settings' title is SF because of the wordmark

`StrataTitle.swift:55`: "Settings stays SF: its header is already the mark and
the wordmark, and a screen gets one drawn word."

**Verdict: half the reason is gone.** The wordmark came off everywhere on
2026-09-30 and the `StrataWordmark` view is deleted. The mark is still there
(`CLAUDE.md`: the `S` "is the app icon and the Settings header"), so the
conclusion survives on one leg. `docs/research/font.md` records the outcome
("Settings, Line and Privacy are SF Rounded Medium"), so the decision is safe;
the sentence is not.

### 2.7 The blue that was removed to stop two near-blacks competing

Both `ProfileView.swift:1096` and `SettingsView.swift:855` carry the same
argument, in nearly the same words:

> This carried `.foregroundStyle(AppColors.accentWarm)` and measured
> (28, 26, 24) on the built sheet, 16.2:1, beside a title measuring (37, 37, 37)
> at 14.3:1. Two words in the bar, the same weight of black, and nothing on the
> screen said which one was the button.

**Verdict: the fault is unfixed, and the fix moved it rather than removing it.**
Taking the override off leaves the `Form`'s tint, and that tint is now
`inkPrimary`. The title is also `inkPrimary` (`StrataTitle.swift:92`). Measured
off `/tmp/room/12-profile.png`, Profile's Done is rgb(37,36,37) and its title is
rgb(37,36,37): the two words in the bar are not "the same weight of black" any
more, they are the same colour exactly.

The argument was written when the tint was `accentPrimary`. When the owner asked
for black again, the fix became the fault. Something has to say which word is
the button: a weight, a size, or the ink step `AddWinSheet` already uses between
its Cancel and its Add.

---

## 3. The count

The number of distinct answers the app has to each of the nine questions.

### 3.1 Shared component against private re-implementation

| component | call sites | drawn without it |
|---|---|---|
| `ColourSwatch` | 1 (`AddWinSheet.swift:791`) | 2 (`ProfileView.swift:369`, `PlanItemDetailSheet.swift:160`) |
| `BlockSurface` | 10 | 0, but 2 pass a flat fill (§1.16) |
| `GlassIconButton` / `GlassIconLabel` | 7 / 3 | 0 |
| `glassCapsule` | 4 | 0 |
| `PrimaryCapsule` | 4 | 2 (`MemoriesMapView.swift:753`, `OnboardingView.swift:891`) |
| `PressResponse` | 8, and `.press` is 0 | 20 `.plain` on non-glass controls |
| `SectionHeading` | 1 | 0 |
| `FormSectionLabel` | 13 | 0 |
| `ShutterBlock` | 2 | 0 |
| `TowerLattice` | 5 | 0 |
| `BlockRim` | 6 | 1 (`MainAppView.swift:3541`) |
| `EtherealFill` | 10 | 2 |
| `Elevation` / `Legibility` | 6 | 1, in the widget target, which cannot see the file |
| `SlotGlass.glassSlot` | 1 | 1 (`MainAppView.swift:3536`) |
| `StrataTab.icon(selected:)` | 1, and it is a drawing | 3, the real tab bar |
| `IconStyle.iconSize` | 13 | 3 fixed sizes that are not geometry-solved |
| `SettingsIcon` | 14 | 1 (`PlanItemDetailSheet.swift:94`) |

**Eight components have a live copy of themselves somewhere.** Three of them
(`StrataTab.icon`, `SlotGlass.glassSlot`, `SectionHeading`) are used less in the
app than in the thing they were extracted from.

### 3.2 Selection

**Ten answers**, and the four that are the same idea differ in three ways.

| what it does | file:line |
|---|---|
| a 0.55 ink ring 2pt OUTSIDE the shape, no scale | `AddWinSheet.swift:821` |
| a 0.55 ink ring 2pt ON the shape, plus a 0.94 scale step, plus a caption ink step | `HeadPickerRow.swift:152`, `HeadLookPicker.swift:91` |
| a 0.55 ink ring on a circle, no scale, no caption | `ProfileView.swift:397` |
| a rim going 1pt `onDarkFaint` to 2pt `onDarkStrong`, plus a caption ink step | `FilmLookStrip.swift:70` |
| a 2pt `onDarkStrong` ring on a circle | `HeadSticker.swift:329` |
| a white checkmark inside, plus a 0.86 scale step | `PlanItemDetailSheet.swift:168` |
| the shape fills with the category colour and the letter goes white | `PlanItemDetailSheet.swift:220` |
| a system `Menu` checkmark | `MonthTowerView.swift:323` |
| a capsule slides under the glyph | `MainAppView.swift:631` |
| the unpicked bars drop to `unpickedBarShare` opacity | `ProfileView.swift:680` |

Three scale steps for one idea: **1.0, 0.94 and 0.86.**

### 3.3 Destructive actions

**Six shapes, three reds, two with no confirmation.**

| what | file:line | shape | red | confirms |
|---|---|---|---|---|
| delete a win | `AddWinSheet.swift:984` | `.bordered`, `.controlSize(.large)`, left-aligned in the body | `AddWinSheet.destructiveTint` (#B3000F light, rgb(255,92,84) dark) | yes |
| reset all data | `SettingsView.swift:500` | Form row, word and glyph | `AppColors.warmRed` #E85D4A | yes |
| delete a head | `ProfileView.swift:1005` | Form row, word and glyph | `AppColors.warmRed` | yes |
| remove a photo | `PhotoViewer.swift:397`, `AddWinSheet.swift:1260` | menu item | the system's #FF3B30 | yes |
| delete a plan line | `PlanItemDetailSheet.swift:302` | toolbar glyph, leading slot | #FF3B30 | **no** |
| delete a plan line | `PlanSheet.swift:608` | swipe action | #FF3B30 | no, and a swipe is its own confirmation |

Two rows carry a comment about "two reds four points apart on one line, and the
app's palette losing to the platform's". Both fixed their own row. The platform's
red is still the answer in four other places.

### 3.4 A sheet's title row

**Eight sheets, six shapes.**

| sheet | left | title | right | 44pt |
|---|---|---|---|---|
| Add a win | "Cancel", 15, `inkSecondary` | drawn 17 | "Add"/"Save", 15, `accentWarm` | both |
| Plan | ＋, 17 glyph, `accentWarm` | drawn 17 | "Done", 15, `accentWarm` | both |
| Line | trash, 17 glyph, #FF3B30 | SF 17 | "Done", 15, `accentWarm` | neither |
| Profile | nothing | drawn 17 | "Done", 15, `inkPrimary` | no |
| Settings | system back chevron | SF 17 | nothing (dead code) | n/a |
| Restore | "Cancel"/"Done", 15, `inkPrimary` | SF 17 | nothing | no |
| Privacy | system back chevron | SF 17 | nothing | n/a |
| Head maker | nothing | **no title row at all** | ✕ `GlassIconButton`, 44 | yes |

Four sheets put their title in the owner's face and four in SF, which is a rule
(`docs/research/font.md`: a drawn title names the sheet). One sheet has no title
row. "Done" is in two inks. Three of six word buttons are under 44pt.

### 3.5 Empty states

**Five answers, three type tiers, three inks, two alignments.**

| what | file:line | type | ink | where |
|---|---|---|---|---|
| one line | `MainAppView.swift:3104` (Wins), `MemoriesView.swift:781` (Memories) | `headerMedium`, 17 | `inkPrimary` | leading, page margin |
| one line | `PhotoCollectionView.swift:122`, `DayAlbumDetailView.swift:93` | `screenSubtitle`, 15 | `inkTertiary` | leading, page margin, `gapWide` under the count |
| a heading, a sentence and a pill | `MemoriesMapView.swift:705` | `headerMedium` + `screenSubtitle` | `inkPrimary` + `inkSecondary` | **centred**, in a panel |
| a dashed ghost bullet and a line | `PlanSheet.swift:447-471` | `bodyLarge`, 17 | `inkSecondary` | leading, two thirds down the field |
| a dashed square and a line | `TowerWidgetView.swift:168` | `.system(15)` | `.tertiary` / `.secondary`, the system's | leading |
| nothing, at opacity 0 | `DayAlbumDetailView.swift:217`, `PhotoCollectionView.swift:188` | the count is hidden rather than reading "0" | | |

The map's is the only centred composition on a page whose own title, picker and
calendar start at 16, which is the fault `MemoriesView.swift:757` removed from
the Memories empty state ("Centred copy on a left aligned page is two alignment
systems on one screen, and the same fault the empty tower had"). It has an
excuse the others do not, because it is a panel over a map rather than a page,
but nothing says so.

### 3.6 Icons

**Four ways to size one**, listed in §1.15, of which two are legitimate.

**Three concepts with two glyphs each:**

| concept | glyph A | glyph B |
|---|---|---|
| the camera | `camera` for "Add My Head to Photos" (`ProfileView.swift:986`) | `camera` for "Add Another Head" (`ProfileView.swift:1001`) |
| the photo library | `photo.on.rectangle` (`AddWinSheet.swift:1256`, `ProfileView.swift:302`) | `photo.on.rectangle.angled` (`SettingsView.swift:356`, `MemoriesStill.swift:93`) |
| "there is more here" | `info.circle` on a restore note (`RestoreBackupView.swift:346`) | `info.circle` opening the plan line (`PlanSheet.swift:569`) |

The first is one glyph for two actions on consecutive rows and is a defect. The
second and third are two glyphs for one idea and one glyph for two ideas, and in
both cases the two sites are a tab apart rather than a row apart, so they are
worth one line each rather than a pass.

### 3.7 Rows and cards

| row or card | file:line | height | corner | press |
|---|---|---|---|---|
| Settings / Profile row | `SettingsView.swift:1004` | 44.65, set by the 32pt glyph box | the platform's card | the platform's |
| replay row | `ReplayRow.swift:78` | 84 (thumbnail), 116 wide | `blockCornerRadius(forCell: 116)` | `.pressSurface` |
| album card | `MemoriesShelf.swift:61` | 108 wide | `blockCornerRadius(forCell: 108)` | `.pressSurface` |
| head tile | `HeadPickerRow.swift:40` | 60 | `blockCornerRadius(forCell: 60)` | `.plain` |
| film look swatch | `FilmLookStrip.swift:22` | 58 | `blockCornerRadius(forCell: 58)` | `.plain` |
| day chip | `PlanItemDetailSheet.swift:236` | 44 | `blockCornerRadius(forCell: 44)` | `.plain` |
| gallery cell | `PhotoGalleryGrid.swift:182` | the grid's | none, a 2pt hairline | `.pressSurface` |

**The corners are one system and that is a real result**: everything derives
from `blockCornerRadius(forCell:)`, and the only exceptions are
`radiusSurface` at two sites and `radiusMark` at two. **The press is not**:
three of seven answer a finger.

### 3.8 Counts

**Five live readouts and one dead one.**

| where | file:line | digits | word | inset | rolls |
|---|---|---|---|---|---|
| day album | `DayAlbumDetailView.swift:186` | `StrataFont` 15 | `screenSubtitle` | no | yes |
| place collection | `PhotoCollectionView.swift:152` | `StrataFont` 15 | `screenSubtitle` | no | no |
| album card caption | `AlbumCarousel.swift:86` | `StrataFont` 15 | `screenSubtitle` | yes | no |
| the replay | `ReplayFrame.swift:168` | the script's odometer | `screenSubtitle` | its own | yes, hand-drawn |
| the widget | `TowerWidgetView.swift:153` | `StrataFont.size(30)` | `.system(15, .medium)` | no | no |
| (dead) shelf card | `MemoriesShelf.swift:328` | | | yes | no |

The word and the ink are the same everywhere, which is the part that works. The
inset is on two of five at one size, and `.numericText()` is on one of five.

The Wins tab prints no count at all any more (`MainAppView.swift:942`,
`headerCount` deleted), so `CLAUDE.md`'s "The tower header carries the win count
and a share button" is stale in both halves.

### 3.9 The two colour schemes

**One fixed colour doing an adaptive job, and two tokens spelling the forbidden
pattern.**

- `AppColors.onDarkStrong`, a fixed `white.opacity(0.95)`, on the light head
  maker preview: `HeadMakerView.swift:845`. **1.04:1**, measured. §1.1.
- `GridConstants.fillWell` and `fillHairline` are `Color.primary.opacity(…)`,
  which is the one spelling `CLAUDE.md` and `CategoryColors.swift:199` both
  forbid, at ten call sites. §1.17.
- Everything else sampled checks out: `inkPrimary`, `inkSecondary`,
  `inkTertiary`, `inkQuiet`, `slotInk`, `quietFill`, `switchOn`, `accentWarm`
  and `destructiveTint` all carry a `userInterfaceStyle` branch, and
  `Elevation.opacity(in:)` multiplies rather than carrying a second constant.

The `onDark*` family is correctly fixed and correctly used on the camera, the
review, the viewfinder and the photo viewer. The head maker is the one screen
that is dark in four of its states and light in the fifth, and it is the one
screen the family leaks out of.

---

## What this does not cover

- **Nothing was built or run.** Every geometric and colour figure is either read
  from source or sampled from a PNG named above. Three claims could not be
  checked against a build and say so: the mechanism behind §1.2 (why the tab
  bar's two strings resolve to one glyph), the dark-mode ratios in §1.17, and
  the head maker preview's exact ground, which is sampled at rgb(243) in a
  capture whose source says `WarmBackground.top` is rgb(253).
- **The owner's own instance is not in here.** `AddWinSheet` against
  `PlanItemDetailSheet`, the circle against the rounded square, is with another
  worker. The two findings that touch that pair from a different direction are
  §1.10 (the Repeats glyph) and §1.16 (the flat fill), and neither overlaps the
  swatch itself.
- **The replay, the tower's own chrome and the camera's gesture layer** were read
  for shared components and not measured screen by screen, because every capture
  of them on disk is either pre-change or dimmed.
