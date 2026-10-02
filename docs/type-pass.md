# The type pass, 2026-10-01

One face, one weight story, no tiny text. What the owner asked for, verbatim:

> "I want you to actually mark spots that I dont like the tiny text lets remove
> it focus on the bigger text making it more clear and thicker like a premium
> font instead of thin I dont like thin sf pro I like it with more assertiveness
> throughout the app on everypage the weight should be similar no tiny thin font
> anywhere but like the settings or other places just research but I like the
> thicker font with less font around it look."

> "I hate when there is like one type of font next to another and I dont like a
> lot of text I like the text that is there to feel like a medium weight and be
> consistent guiding the user no tiny text under or anythign like that I want it
> to be controlled"

> "I just want everything thats not like photos to have air to breathe"

---

## What it is now

**Three sizes. One weight. 34 / 17 / 15, all Medium.**

| tier | text style | pt at the default Dynamic Type size | weight |
|---|---|---|---|
| title | `.largeTitle` | 34 | Medium |
| body | `.body` | 17 | Medium |
| label | `.subheadline` | 15 | Medium |

`Strata/Models/Typography.swift` names one number per tier, in one function
(`tier(_:)`), and every token is that function or the owner's digits. **That
function is where a custom typeface drops in**: one `.custom(_, relativeTo:)`
there and one in `StrataFont.relative`, and the app has changed face. Nothing
else in the app has to be found.

### What moved

| token | was | is |
|---|---|---|
| `screenTitle` / `screenTitleDrawn` / `tally` | largeTitle 34 Medium | unchanged |
| `headerMedium` | headline 17 Medium | `.body` 17 Medium (same ramp, one style) |
| `sheetTitleDrawn` | headline 17 Medium | `.body` 17 Medium |
| `bodyLarge` | body 17 **Regular** | body 17 **Medium** |
| `headerSmall` | subheadline 15 Medium | unchanged |
| `screenSubtitle` | subheadline 15 **Regular** | subheadline 15 **Medium** |
| `sectionLabel` | footnote **13** Medium | subheadline **15** Medium |
| `bodySmall` | footnote 13 Regular | **DELETED** |
| `caption2` | caption2 11 Medium | **DELETED** |

`.body` and `.headline` share a Dynamic Type ramp (17 at Large, 19 / 21 / 23 up,
28 / 33 / 40 / 47 / 53 at the accessibility sizes) and differ only in default
weight, which the tokens override. So the 17 tier is one text style, not two
that happen to agree at one setting.

### The price, named

**17 and 15 are now one weight as well as one face**, so size is the only thing
separating a heading from the line under it. That is the look he asked for, and
what keeps it readable is INK: a heading takes `inkPrimary`, the line under it
`inkSecondary` or `inkTertiary`. Measured off SF's own `wght` axis at `opsz` 17,
upem 2048: a capital's stem goes 0.0879 em Regular to 0.1097 Medium — **1.50pt
to 1.87pt, 24.8% more stroke on every body line in the app**.

---

## 1. The inventory, as shipped before this pass

**144 `.font(` call sites** across `Strata/`, `Shared/` and `StrataWidget/`.
Of those:

- **40 set type below 15pt.**
- **64 set a weight lighter than `.medium`.** Seven of those are SF Symbols and
  one (`StrataMark.swift:170`) is a false positive, so **56 are text.** Symbols
  are a different axis — see the note at the end of §2.

The full 144-row table is at the bottom of this file. The two groups the owner
named are here.

### Every place the app sets type below 15pt — 40 sites

| file:line | token | pt | weight | what it says |
|---|---|---|---|---|
| `TowerWidgetView.swift:144` | `inline .system` | 13 | medium | Text(snapshot.today == 1 ? "win" : "wins") |
| `TowerWidgetView.swift:162` | `inline .system` | 13 | medium | Text(snapshot.total == 0 ? "Your first win goes here" : "Nothing yet today") |
| `TowerWidgetView.swift:183` | `inline .system` | 13 | medium | Text(secondLine) |
| `SiriSnippetViews.swift:47` | `Typography.bodySmall` | 13 | regular | Text("and \(wins.count - 5) more") |
| `AddWinSheet.swift:510` | `Typography.bodySmall` | 13 | regular | Text("Add a photo") |
| `AlbumCarousel.swift:87` | `StrataFont.relative(.footnote)` | 13 | medium | Text(verbatim: number) |
| `AlbumCarousel.swift:97` | `Typography.bodySmall` | 13 | regular | Text(parts.words.lowercased()) |
| `BlockContent.swift:128` | `Typography.bodySmall.weight(.medium)` | 13 | medium | Text(title) |
| `CameraView.swift:1289` | `Typography.bodySmall.weight(.medium)` | 13 | medium | Text(label) |
| `CameraView.swift:1341` | `numeral()` | 10 | medium | Text("\(camera.timerSeconds)") |
| `DayAlbumDetailView.swift:93` | `Typography.bodySmall` | 13 | regular | Text("Nothing logged this day.") |
| `FilmLookStrip.swift:94` | `Typography.bodySmall` | 13 | regular | Text(look.kind.name) |
| `HeadLookPicker.swift:98` | `Typography.bodySmall` | 13 | regular | Text(look.kind.name) |
| `HeadMakerView.swift:741` | `Typography.bodySmall` | 13 | regular | Text(model.saveFailure.isEmpty ? previewCaption(rig) : model.saveFailure) |
| `HeadPickerRow.swift:99` | `Typography.bodySmall` | 13 | regular | Text(entry.name) |
| `MainAppView.swift:3072` | `Typography.bodySmall` | 13 | regular | Text("Tap the slot to log your first win.") |
| `MemoriesMapView.swift:1465` | `numeral()` | 13 | medium | Text(verbatim: StrataFont.digits(count)) |
| `MemoriesShelf.swift:303` | `StrataFont.relative(.footnote)` | 13 | medium | Text(verbatim: StrataFont.digits(count)) |
| `MemoriesShelf.swift:319` | `Typography.bodySmall` | 13 | regular | Text(count == 1 ? "win" : "wins") |
| `MemoriesView.swift:713` | `Typography.bodySmall` | 13 | regular | Text("Every win you log becomes a block, and they collect here by month.") |
| `MonthReplayRow.swift:68` | `Typography.bodySmall` | 13 | regular | Text("\(replay.count) \(replay.count == 1 ? "win" : "wins")") |
| `OnboardingView.swift:764` | `Typography.bodySmall` | 13 | regular | Text("Founder, developer and product designer") |
| `OnboardingView.swift:1004` | `Typography.bodySmall` | 13 | regular | Text("Not now") |
| `PhotoCollectionView.swift:123` | `Typography.bodySmall` | 13 | regular | Text("No photographs here.") |
| `PhotoViewer.swift:447` | `Typography.bodySmall` | 13 | regular | Label(place, systemImage: "mappin.and.ellipse") |
| `PlanItemDetailSheet.swift:143` | `Typography.sectionLabel` | 13 | medium | Text(letter(for: day)) |
| `PlanSheet.swift:411` | `Typography.bodySmall` | 13 | regular | Text(summary) |
| `PrivacyPolicyView.swift:31` | `Typography.bodySmall` | 13 | regular | Text(section.body) |
| `PrivacyPolicyView.swift:37` | `Typography.bodySmall` | 13 | regular | Text("Last updated 14 September 2026") |
| `ProfileView.swift:431` | `Typography.bodySmall` | 13 | regular | Text(label) |
| `ProfileView.swift:464` | `Typography.bodySmall` | 13 | regular | Text(shownDetail(summary: summary, bars: bars)) |
| `ProfileView.swift:628` | `Typography.bodySmall` | 13 | regular | Label() |
| `ProfileView.swift:636` | `Typography.bodySmall` | 13 | regular | Label(format: labelFormat) |
| `ProfileView.swift:777` | `Typography.bodySmall` | 13 | regular | Text(heads.look.name) |
| `RestoreBackupView.swift:148` | `Typography.bodySmall` | 13 | regular | Text(plan.winsAlreadyHere == 1 |
| `RestoreBackupView.swift:155` | `Typography.bodySmall` | 13 | regular | Text(plan.photographsForExistingWins.count == 1 |
| `RestoreBackupView.swift:161` | `Typography.bodySmall` | 13 | regular | Text("Restoring only adds. Nothing already on this phone is deleted or changed.") |
| `RestoreBackupView.swift:296` | `Typography.bodySmall` | 13 | regular | Text(text) |
| `SettingsView.swift:157` | `Typography.sectionLabel` | 13 | medium | Text(verbatim: appVersion) |
| `SettingsView.swift:917` | `Typography.sectionLabel` | 13 | medium | Text(text) |

### Every place the app sets a weight lighter than .medium — 64 sites

| file:line | token | pt | weight | what it says |
|---|---|---|---|---|
| `SiriSnippetViews.swift:20` | `Typography.screenSubtitle` | 15 | regular | Text(today == 1 ? "The first on today's tower" : "\(today) on today's tower") |
| `SiriSnippetViews.swift:41` | `Typography.screenSubtitle` | 15 | regular | Text(win.title ?? "A win") |
| `SiriSnippetViews.swift:47` | `Typography.bodySmall` | 13 | regular | Text("and \(wins.count - 5) more") |
| `SiriSnippetViews.swift:59` | `Typography.screenSubtitle` | 15 | regular |  |
| `AddWinSheet.swift:510` | `Typography.bodySmall` | 13 | regular | Text("Add a photo") |
| `AlbumCarousel.swift:97` | `Typography.bodySmall` | 13 | regular | Text(parts.words.lowercased()) |
| `CachedImageView.swift:117` | `inline .system` | min(width | regular | (SF Symbol) Image(systemName: "photo") |
| `CameraView.swift:459` | `Typography.bodyLarge` | 17 | regular | Text("A win can be a photograph. Turn the camera on for Strata in Settings and this beco |
| `CameraView.swift:1381` | `inline .system` | 21 | regular | (SF Symbol) Image(systemName: symbol) |
| `DayAlbumDetailView.swift:93` | `Typography.bodySmall` | 13 | regular | Text("Nothing logged this day.") |
| `DayAlbumDetailView.swift:190` | `Typography.screenSubtitle` | 15 | regular | Text(logs.count == 1 ? "win" : "wins") |
| `FilmLookStrip.swift:94` | `Typography.bodySmall` | 13 | regular | Text(look.kind.name) |
| `HeadLookPicker.swift:98` | `Typography.bodySmall` | 13 | regular | Text(look.kind.name) |
| `HeadMakerView.swift:634` | `inline .system` | 21 | regular | (SF Symbol) Image(systemName: flashIsOn ? "bolt.fill" : "bolt.slash.fill |
| `HeadMakerView.swift:741` | `Typography.bodySmall` | 13 | regular | Text(model.saveFailure.isEmpty ? previewCaption(rig) : model.saveFailure) |
| `HeadPickerRow.swift:99` | `Typography.bodySmall` | 13 | regular | Text(entry.name) |
| `IconStyle.swift:27` | `inline .system` | size | regular |  |
| `MainAppView.swift:844` | `Typography.bodyLarge` | 17 | regular | Text(Self.headerDate.string(from: Date())) |
| `MainAppView.swift:917` | `Typography.screenSubtitle` | 15 | regular | Text(towerVM.placedBlocks.count == 1 ? "win" : "wins") |
| `MainAppView.swift:3072` | `Typography.bodySmall` | 13 | regular | Text("Tap the slot to log your first win.") |
| `MemoriesMapView.swift:719` | `Typography.screenSubtitle` | 15 | regular | Text(denied |
| `MemoriesShelf.swift:319` | `Typography.bodySmall` | 13 | regular | Text(count == 1 ? "win" : "wins") |
| `MemoriesStill.swift:138` | `inline .system` | 20 * s | regular | (SF Symbol) Image(systemName: tab.icon(selected: on)) |
| `MemoriesView.swift:713` | `Typography.bodySmall` | 13 | regular | Text("Every win you log becomes a block, and they collect here by month.") |
| `MonthReplayRow.swift:68` | `Typography.bodySmall` | 13 | regular | Text("\(replay.count) \(replay.count == 1 ? "win" : "wins")") |
| `MonthReplayRow.swift:75` | `inline .system` | 30 | regular | (SF Symbol) Image(systemName: "play.circle.fill") |
| `OnboardingView.swift:764` | `Typography.bodySmall` | 13 | regular | Text("Founder, developer and product designer") |
| `OnboardingView.swift:879` | `Typography.bodyLarge` | 17 | regular | Text(subtitle) |
| `OnboardingView.swift:1004` | `Typography.bodySmall` | 13 | regular | Text("Not now") |
| `PhotoCollectionView.swift:123` | `Typography.bodySmall` | 13 | regular | Text("No photographs here.") |
| `PhotoCollectionView.swift:155` | `Typography.screenSubtitle` | 15 | regular | Text(photoCount == 1 ? "photo" : "photos") |
| `PhotoViewer.swift:432` | `Typography.screenSubtitle` | 15 | regular | Text(caption) |
| `PhotoViewer.swift:447` | `Typography.bodySmall` | 13 | regular | Label(place, systemImage: "mappin.and.ellipse") |
| `PlanItemDetailSheet.swift:29` | `Typography.bodyLarge` | 17 | regular | TextField("What do you mean to do?", text: $item.text, axis: .vertical) |
| `PlanSheet.swift:336` | `Typography.bodyLarge` | 17 | regular | Text("Write what you mean to do, then press its block when you have.") |
| `PlanSheet.swift:411` | `Typography.bodySmall` | 13 | regular | Text(summary) |
| `PrivacyPolicyView.swift:31` | `Typography.bodySmall` | 13 | regular | Text(section.body) |
| `PrivacyPolicyView.swift:37` | `Typography.bodySmall` | 13 | regular | Text("Last updated 14 September 2026") |
| `ProfileAvatar.swift:158` | `Typography.bodyLarge` | 17 | regular | (SF Symbol) let glyph = Image(systemName: "person.fill") |
| `ProfileView.swift:427` | `Typography.bodyLarge` | 17 | regular | Text(value == 1 ? "day" : "days") |
| `ProfileView.swift:431` | `Typography.bodySmall` | 13 | regular | Text(label) |
| `ProfileView.swift:464` | `Typography.bodySmall` | 13 | regular | Text(shownDetail(summary: summary, bars: bars)) |
| `ProfileView.swift:628` | `Typography.bodySmall` | 13 | regular | Label() |
| `ProfileView.swift:636` | `Typography.bodySmall` | 13 | regular | Label(format: labelFormat) |
| `ProfileView.swift:777` | `Typography.bodySmall` | 13 | regular | Text(heads.look.name) |
| `ReplayFrame.swift:169` | `Typography.screenSubtitle` | 15 | regular | Text(roll.count == 1 ? "win" : "wins") |
| `ReplayFrame.swift:277` | `Typography.screenSubtitle` | 15 | regular | Text(rangeText) |
| `ReplayFrame.swift:283` | `Typography.screenSubtitle` | 15 | regular | Text("Sample") |
| `RestoreBackupView.swift:114` | `Typography.bodyLarge` | 17 | regular | Text(summary.wins == 1 ? "win in this backup" : "wins in this backup") |
| `RestoreBackupView.swift:142` | `Typography.bodyLarge` | 17 | regular | Text(plan.winsToAdd == 1 |
| `RestoreBackupView.swift:148` | `Typography.bodySmall` | 13 | regular | Text(plan.winsAlreadyHere == 1 |
| `RestoreBackupView.swift:155` | `Typography.bodySmall` | 13 | regular | Text(plan.photographsForExistingWins.count == 1 |
| `RestoreBackupView.swift:161` | `Typography.bodySmall` | 13 | regular | Text("Restoring only adds. Nothing already on this phone is deleted or changed.") |
| `RestoreBackupView.swift:171` | `Typography.bodyLarge` | 17 | regular | Text("Everything in this backup is already on this phone.") |
| `RestoreBackupView.swift:199` | `Typography.bodyLarge` | 17 | regular | Text(failure) |
| `RestoreBackupView.swift:210` | `Typography.bodyLarge` | 17 | regular | Text(report.winsAdded == 1 ? "win restored" : "wins restored") |
| `RestoreBackupView.swift:241` | `Typography.bodyLarge` | 17 | regular | Text(message) |
| `RestoreBackupView.swift:252` | `Typography.bodyLarge` | 17 | regular | Text(text) |
| `RestoreBackupView.swift:268` | `Typography.bodyLarge` | 17 | regular | Text(label) |
| `RestoreBackupView.swift:272` | `Typography.bodyLarge` | 17 | regular | Text(value) |
| `RestoreBackupView.swift:296` | `Typography.bodySmall` | 13 | regular | Text(text) |
| `StoreUnavailableView.swift:53` | `Typography.bodyLarge` | 17 | regular | Text(StoreUnavailableCopy.body) |
| `StoreUnavailableView.swift:59` | `Typography.bodyLarge` | 17 | regular | Text(StoreUnavailableCopy.stillFailing) |
| `StrataMark.swift:170` | `inline .system` | points | regular | Text(text) |


**One row in the second table is wrong and worth saying so**: `StrataMark.swift:170`
reads `weight: Typography.titleWeight`, which is Medium. The generator matched on
a literal `weight: .x` and recorded "regular" by default.

---

## 2. Every site below 15pt, and what happened to it

Default was **delete**. 29 sites carried `bodySmall`; one was deleted outright,
four went to 17 because they are consequences rather than captions, and the
other 24 went to 15. One more — the chart's second line — was deleted in two of
its five states.

### Deleted

| site | what it said | why |
|---|---|---|
| `AddWinSheet.swift:510` | "Add a photo" | A camera glyph in a dark disc in the middle of an **empty** photo well. The caption said what the thing beside it already showed, and it was conditional on `size != .small`, so the well captioned itself on two of the three block sizes and not on the third. Nothing lost to VoiceOver: the well's own `accessibilityLabel` is already "Add a photo". |
| `ProfileView.detail(_:)`, the `.notEnough` and `.empty` cases | "It appears once you have about 6 weeks of wins." under "Keep logging to see your trend."; "Log a win and it's counted here." under "Your weeks will show up here." | The same sentence twice. **It surfaced as a measurement, not as taste**: at 13 Regular that line fitted one row, and at 15 Medium it wrapped to **three**, with "of wins." alone on the last. The three states that remain all carry numbers the chart has no other legend for, so the method stayed. |
| `CameraView.swift:1341` | the timer delay, `numeral(10)` stacked under the glyph | Replaced rather than removed — see "Rebuilt" below. |

### Promoted to 17 (body) — a consequence, not a caption

All four are on `RestoreBackupView`, which is the screen that asks you to press
a button that changes your data. The two sub-facts under the merge plan, the
"Restoring only adds. Nothing already on this phone is deleted or changed."
promise, and the warning note. **The promise in particular is the sentence that
makes the press safe, and it was the smallest text on the screen.** The screen
is now two sizes, 34 and 17.

Also promoted to 17: `PrivacyPolicyView.swift:31`, the policy body. Prose you
sit and read is body.

### Promoted to 15 (label) — 24 sites

`SiriSnippetViews:47` · `AlbumCarousel:87, 97` (and `captionSize` 13 to 15) ·
`HeadLookPicker:98` · `FilmLookStrip:94` · `ProfileView:431, 464, 628, 636, 777` ·
`PhotoViewer:447` · `CameraView:1289` · `DayAlbumDetailView:93` ·
`HeadPickerRow:99` · `MonthReplayRow:68` · `PhotoCollectionView:123` ·
`MemoriesShelf:303, 319` (and `countSize` 13 to 15) · `OnboardingView:764, 1004` ·
`PlanSheet:411` · `PrivacyPolicyView:37` · `HeadMakerView:741` · `MemoriesView:713`

Plus the `sectionLabel` token itself (`SettingsView:157, 917`,
`PlanItemDetailSheet:143`, `PrivacyPolicyView` through `FormSectionLabel`), which
moved from footnote 13 to subheadline 15 and took every uppercase heading in the
app with it.

And the widget, which is a separate target and cannot see `Typography`, so its
three 13pt literals are now 15pt literals: `TowerWidgetView:144, 162, 183`.

### Rebuilt

**The camera's timer delay.** It was `Typography.numeral(10)` — a 10pt digit
hung under a 44pt control over a live viewfinder, which is the clearest case in
the app of "no tiny text under". It is **beside** the glyph now, at a fixed 15.

It is not deleted, because the glyph does not carry what it says: dimmed against
lit tells you the timer is on, and nothing tells you whether it is 3 or 10.

Measured, because the control is 44pt and cannot grow: the `timer` glyph is
**25.0pt** wide at 21pt; "10" is **18.9pt** in SF Medium monospaced digits,
**26.7pt** as "10s", and **27.2pt** in the owner's face (tabular at 0.906 em).
So the pair is **43.9pt inside a 44pt box** in SF with no spacing, 51.7 with the
"s", and 52.2 in `StrataFont`. Hence: SF digits, no "s", no gap — the glyph's own
side bearing is the gap. Fixed rather than a tier for the reason the 21 beside it
is fixed: this row is solved against a 44pt control, and anything in it that grew
with Dynamic Type would run into its neighbour.

Verified on the simulator with `cameraTimerSeconds` forced to 10: the pair
renders at x 317.0 to 355.0pt on a 402pt page, with 46.7pt of clear ground to the
flip-camera glyph on its left.

### Kept, with the reason

**Three things are still under 15. Each is a measurement arguing against the
instruction, and each is written at the site as well as here.**

| site | pt | why |
|---|---|---|
| `BlockContent.swift:128` — a block's title | 13 Medium | It is sized to the **block**, not to the page — the same family as the month block's `cell * 0.16` numeral. The live cell is 86.5pt less the 12/8 padding, so a 1x1 block offers **66.5pt** on its one line. Measured with Core Text over fourteen ordinary titles: **4 truncate at 13 and 8 at 15.** "Inbox zero" is 64.4pt at 13 and 72.8 at 15; "Groceries" 60.1 and 68.0; "Deep work" 66.2 and 75.0. Raising this rung **doubles the truncation rate on the one string the person typed**. It is Medium, which is what the instruction was really about, and already was. If this is reopened the lever is the CELL, not the type. |
| `MemoriesMapView.swift:1465` — the map's cluster badge | 13 Medium | A **digit on an 18pt capsule**, solved against the 44pt block it sits on. At 15, SF Medium's digit advance goes 8.27 to 9.54pt, so the capsule goes 18.0 / 24.3 / 32.6 to 18.0 / **27.1** / 36.6 for one, two and three digits: a two-digit badge from 55% of the cell's width to 62%, re-inflating a badge that was deliberately measured DOWN to 16.7% of the block on 2026-10-01. |
| `MemoriesStill.swift:138, 140` — the drawn tab bar | 20 and 11, times `s` ≈ 0.5 | It is a **picture of a phone** inside the onboarding device frame. Those are UIKit's tab-bar metrics, not this app's type. Raising them makes the drawing stop matching the thing it is a drawing of, which is the whole argument for composing the view rather than screenshotting one. |

**SF Symbols are not counted, here or anywhere.** `IconStyle.iconSize` and the
`GridConstants.icon*` tokens size glyphs, which are a separate axis on a separate
kind of object. `Typography`'s own comment already records that a previous pass
counted the symbols into the weight ladder, concluded the app had five cuts, and
was wrong. The one symbol that did change is `CachedImageView:117`, from
`.regular` to `.medium`, to agree with `GlassIconButton`, `PlanBullet` and
`ProfileAvatar`.

---

## 3. Air

`tools/page-room.py`, share of the usable band with nothing drawn on it, all 24
seeded captures at 402 x 874pt. **Twenty-two of the twenty-four moved by less
than one point**, which is the result to want: the type got heavier and bigger
without the pages getting fuller.

| screen | before | after |
|---|---|---|
| Wins, tower | 77.6% | 77.6% |
| Wins, empty | 77.6% | 77.6% |
| Camera, refused | 79.8% | 79.7% |
| Memories, month | 55.9% | 55.7% |
| Add a win | 57.8% | 57.5% |
| Plan | 90.2% | 90.2% |
| Block card | 52.5% | 52.2% |
| **Profile** | **44.3%** | **45.1%** |
| Settings | 43.6% | 44.0% |
| Day album | 71.4% | 71.4% |
| Photo viewer | 21.2% | 21.2% |
| Head maker | 68.3% | 67.9% |
| Onboarding 1-4 | 49.1 / 52.9 / 38.6 / 37.9% | 49.0 / 52.8 / 38.6 / 39.0% |
| Store unavailable | 78.4% | 77.9% |

(Three of the twenty-four fixtures do not reach the screen they name and never
did: `07-memories-empty` and `08-memories-map` both land on the month, and
`21-restore` lands on Settings. Pre-existing, and not this pass's doing — the
restore screen was captured separately with
`-strataSeedBackup 40 -strataOpenSheet settings -strataRestoreFrom strata-debug-backup.zip`,
and the camera review with `-strataStartTab camera -strataOpenReview medium`.)

**Profile is the one that moved, and it moved the right way.** Raising the
chart's second line to 15 Medium took it to **39.9%** — 4.4 points of air gone to
a sentence that repeated the one above it. Deleting that sentence in the two
states where it had nothing of its own to say put the page at **45.1%, above
where it started.** That is the whole pass in one number: subtraction bought the
weight.

---

## 4. Contrast

**No ink changed anywhere in this pass** — only size and weight — so no ratio
could fall. Spot-checked on the built app anyway, same box before and after:

| what | ground | before | after |
|---|---|---|---|
| Settings section label (`NOTIFICATIONS`, `inkSecondary`) | rgb(246) | 6.09:1 | 6.09:1 |
| Profile streak label (`Current`, `inkSecondary`) | rgb(255) | 6.19:1 | 6.19:1 |
| Profile chart axis (`inkSecondary`) | rgb(255) | — | 6.19:1 |
| Restore, the promise line (`inkSecondary`) | rgb(243) | — | 6.03:1 |

All clear 4.5:1. Measured as the 0.5th-percentile luminance in the text's box
against the box's modal colour, because the mean of an anti-aliased glyph is a
lie.

---

## 5. Tests

`StrataTests/TypographyTests.swift`, 7 tests in 3 groups. **Full suite: 559
tests in 66 suites, all passing** (552 in 65 before this).

1. **The tiers.** `noTierIsBelowFifteenPoints` reads the point size off
   `UIFont.preferredFont(forTextStyle:)` rather than asserting it.
   `thereAreExactlyThreeTiers` pins 34 / 17 / 15 and that no two collide.
   `theOneWeightIsMedium` pins the lever.
2. **The tokens.** `SwiftUI.Font` is `Hashable`, so `everyTokenResolvesToATier`
   is a real identity check: every token `==` one of the three tiers, and the
   nine of them resolve to exactly 3 distinct fonts.
   `headingAndBodyAreOneFont` pins `headerMedium == bodyLarge` and
   `headerSmall == screenSubtitle == sectionLabel`.
3. **The call sites.** `noSourceSetsTypeBelowTheFloor` sweeps the Swift sources
   for `.footnote` / `.caption` / `.caption2`, a deleted token, a `weight:` of
   `.regular` / `.light` / `.thin`, and a literal `.system(size:)` or
   `numeral()` under 15. **A token system proves nothing about a view that
   writes `.font(.system(size: 11))`**, and this is the test that would have
   caught the state the app was in before the pass.

   Its exemptions are listed by file and by the exact line, each with its
   reason, so moving one of them fails the test rather than widening it
   silently. `theSweepCatchesWhatItIsFor` re-injects six bugs — one of them is
   exactly what `BlockContent` used to say — and asserts the sweep flags all
   six and none of four legitimate lines.

   **The injection has already earned its keep.** The first version extracted
   the digits from the regex match with a `filter`, which picked up the dot in
   `.system`, so `size: 15` parsed as 0.15 and failed every legitimate 15 while
   `size: 14.5` parsed as nothing and passed. The injection caught both.

---

## 6. Left for the other worker

`Strata/Views/MainAppView.swift` and `Strata/Views/ReplayFrame.swift` were not
edited. **Both were re-read after their in-flight changes landed and neither now
sets anything below the floor or lighter than Medium**, so there is nothing to
apply. What is worth knowing:

| file:line | token | now resolves to | note |
|---|---|---|---|
| `MainAppView.swift:3045` | `headerMedium` | 17 Medium | "Tap the slot to log your first win." The worker had already moved this off `bodySmall` and deleted the title above it. Nothing to do. |
| `ReplayFrame.swift:169` | `screenSubtitle` | 15 **Medium**, was 15 Regular | "win"/"wins" beside the replay's count. |
| `ReplayFrame.swift:247` | `tally` | 34 Medium | unchanged. |
| `ReplayFrame.swift:277` | `screenSubtitle` | 15 **Medium**, was 15 Regular | the date range. |
| `ReplayFrame.swift:283` | `screenSubtitle` | 15 **Medium**, was 15 Regular | the "Sample" badge. |

**Flag for them:** those three `ReplayFrame` lines changed weight without their
file being touched, because `screenSubtitle` changed underneath. The replay is
the one screen that becomes a VIDEO, so it is worth one look at an exported
frame — the type is 24.8% more stroke in `inkQuiet` on the warm ground, and
`ReplayFrame`'s own comment at line 143 says the date line is a subheadline,
which is still true.

`Typography.bodySmall` was going to be kept as a transitional alias for those two
files. It turned out to have **zero** call sites once their edits landed, so it
is deleted. If a `bodySmall` reappears in a merge, the right replacement is
`screenSubtitle` for a line under a heading and `bodyLarge` for a sentence
somebody reads.

---

## 7. The full inventory, 144 sites as shipped before the pass

| file:line | token / inline | style | pt | weight |
|---|---|---|---|---|
| `Shared/TowerWidgetView.swift:141` | `StrataFont.size` | fixed | 30 | medium |
| `Shared/TowerWidgetView.swift:144` | `inline .system` | fixed | 13 | medium |
| `Shared/TowerWidgetView.swift:162` | `inline .system` | fixed | 13 | medium |
| `Shared/TowerWidgetView.swift:178` | `StrataFont.size` | fixed | 16 | medium |
| `Shared/TowerWidgetView.swift:180` | `inline .system` | fixed | 15 | medium |
| `Shared/TowerWidgetView.swift:183` | `inline .system` | fixed | 13 | medium |
| `Strata/Intents/SiriSnippetViews.swift:18` | `Typography.headerMedium` | headline | 17 | medium |
| `Strata/Intents/SiriSnippetViews.swift:20` | `Typography.screenSubtitle` | subheadline | 15 | REGULAR |
| `Strata/Intents/SiriSnippetViews.swift:41` | `Typography.screenSubtitle` | subheadline | 15 | REGULAR |
| `Strata/Intents/SiriSnippetViews.swift:47` | `Typography.bodySmall` | footnote | 13 | REGULAR |
| `Strata/Intents/SiriSnippetViews.swift:59` | `Typography.screenSubtitle` | subheadline | 15 | REGULAR |
| `Strata/Views/AddWinSheet.swift:116` | `Typography.headerMedium` | headline | 17 | medium |
| `Strata/Views/AddWinSheet.swift:361` | `Typography.headerSmall` | subheadline | 15 | medium |
| `Strata/Views/AddWinSheet.swift:370` | `Typography.headerSmall` | subheadline | 15 | medium |
| `Strata/Views/AddWinSheet.swift:510` | `Typography.bodySmall` | footnote | 13 | REGULAR |
| `Strata/Views/AlbumCarousel.swift:48` | `Typography.headerMedium` | headline | 17 | medium |
| `Strata/Views/AlbumCarousel.swift:87` | `StrataFont.relative(_, .footnote)` | footnote | 13 | medium |
| `Strata/Views/AlbumCarousel.swift:97` | `Typography.bodySmall` | footnote | 13 | REGULAR |
| `Strata/Views/BlockContent.swift:128` | `Typography.bodySmall.weight(.medium)` | footnote | 13 | medium |
| `Strata/Views/CachedImageView.swift:117` | `inline .system` | fixed | min(width | regular |
| `Strata/Views/CameraView.swift:231` | `Typography.numeral` | fixed | 96 | medium |
| `Strata/Views/CameraView.swift:456` | `Typography.screenTitle` | largeTitle | 34 | medium |
| `Strata/Views/CameraView.swift:459` | `Typography.bodyLarge` | body | 17 | REGULAR |
| `Strata/Views/CameraView.swift:475` | `Typography.headerSmall` | subheadline | 15 | medium |
| `Strata/Views/CameraView.swift:617` | `Typography.headerSmall` | subheadline | 15 | medium |
| `Strata/Views/CameraView.swift:644` | `Typography.headerSmall` | subheadline | 15 | medium |
| `Strata/Views/CameraView.swift:696` | `Typography.headerSmall` | subheadline | 15 | medium |
| `Strata/Views/CameraView.swift:1289` | `Typography.bodySmall.weight(.medium)` | footnote | 13 | medium |
| `Strata/Views/CameraView.swift:1341` | `Typography.numeral` | fixed | 10 | medium |
| `Strata/Views/CameraView.swift:1381` | `inline .system` | fixed | 21 | regular |
| `Strata/Views/CameraView.swift:1767` | `Typography.headerSmall` | subheadline | 15 | medium |
| `Strata/Views/DayAlbumDetailView.swift:93` | `Typography.bodySmall` | footnote | 13 | REGULAR |
| `Strata/Views/DayAlbumDetailView.swift:187` | `StrataFont.relative(_, .subheadline)` | subheadline | 15 | medium |
| `Strata/Views/DayAlbumDetailView.swift:190` | `Typography.screenSubtitle` | subheadline | 15 | REGULAR |
| `Strata/Views/FilmLookStrip.swift:94` | `Typography.bodySmall` | footnote | 13 | REGULAR |
| `Strata/Views/GlassIconButton.swift:92` | `inline .system` | fixed | glyphSize | medium |
| `Strata/Views/HeadLookPicker.swift:98` | `Typography.bodySmall` | footnote | 13 | REGULAR |
| `Strata/Views/HeadMakerView.swift:420` | `Typography.headerMedium` | headline | 17 | medium |
| `Strata/Views/HeadMakerView.swift:594` | `Typography.headerSmall` | subheadline | 15 | medium |
| `Strata/Views/HeadMakerView.swift:634` | `inline .system` | fixed | 21 | regular |
| `Strata/Views/HeadMakerView.swift:741` | `Typography.bodySmall` | footnote | 13 | REGULAR |
| `Strata/Views/HeadMakerView.swift:755` | `Typography.headerSmall` | subheadline | 15 | medium |
| `Strata/Views/HeadMakerView.swift:784` | `Typography.headerSmall` | subheadline | 15 | medium |
| `Strata/Views/HeadMakerView.swift:863` | `Typography.headerMedium` | headline | 17 | medium |
| `Strata/Views/HeadMakerView.swift:869` | `Typography.headerMedium` | headline | 17 | medium |
| `Strata/Views/HeadPickerRow.swift:99` | `Typography.bodySmall` | footnote | 13 | REGULAR |
| `Strata/Views/IconStyle.swift:27` | `inline .system` | fixed | size | regular |
| `Strata/Views/MainAppView.swift:844` | `Typography.bodyLarge` | body | 17 | REGULAR |
| `Strata/Views/MainAppView.swift:890` | `Typography.tally` | largeTitle | 34 | medium (digits) |
| `Strata/Views/MainAppView.swift:917` | `Typography.screenSubtitle` | subheadline | 15 | REGULAR |
| `Strata/Views/MainAppView.swift:943` | `Typography.headerMedium` | headline | 17 | medium |
| `Strata/Views/MainAppView.swift:3065` | `Typography.headerMedium` | headline | 17 | medium |
| `Strata/Views/MainAppView.swift:3072` | `Typography.bodySmall` | footnote | 13 | REGULAR |
| `Strata/Views/MemoriesMapView.swift:709` | `Typography.headerMedium` | headline | 17 | medium |
| `Strata/Views/MemoriesMapView.swift:719` | `Typography.screenSubtitle` | subheadline | 15 | REGULAR |
| `Strata/Views/MemoriesMapView.swift:754` | `Typography.headerSmall` | subheadline | 15 | medium |
| `Strata/Views/MemoriesMapView.swift:1465` | `Typography.numeral` | fixed | 13 | medium |
| `Strata/Views/MemoriesShelf.swift:249` | `Typography.sheetTitleDrawn` | headline | 17 | medium |
| `Strata/Views/MemoriesShelf.swift:278` | `Typography.headerMedium` | headline | 17 | medium |
| `Strata/Views/MemoriesShelf.swift:285` | `Typography.headerMedium` | headline | 17 | medium |
| `Strata/Views/MemoriesShelf.swift:303` | `StrataFont.relative(_, .footnote)` | footnote | 13 | medium |
| `Strata/Views/MemoriesShelf.swift:319` | `Typography.bodySmall` | footnote | 13 | REGULAR |
| `Strata/Views/MemoriesStill.swift:138` | `inline .system` | fixed | 20 * s | regular |
| `Strata/Views/MemoriesStill.swift:140` | `inline .system` | fixed | 11 * s | medium |
| `Strata/Views/MemoriesView.swift:710` | `Typography.headerMedium` | headline | 17 | medium |
| `Strata/Views/MemoriesView.swift:713` | `Typography.bodySmall` | footnote | 13 | REGULAR |
| `Strata/Views/MonthCalendarView.swift:364` | `Typography.numeral` | fixed | numberSize | medium |
| `Strata/Views/MonthReplayRow.swift:64` | `Typography.headerMedium` | headline | 17 | medium |
| `Strata/Views/MonthReplayRow.swift:68` | `Typography.bodySmall` | footnote | 13 | REGULAR |
| `Strata/Views/MonthReplayRow.swift:75` | `inline .system` | fixed | 30 | regular |
| `Strata/Views/MonthTowerView.swift:135` | `Typography.numeral` | fixed | cell * 0.16 | medium |
| `Strata/Views/MonthTowerView.swift:347` | `Typography.headerMedium` | headline | 17 | medium |
| `Strata/Views/OnboardingView.swift:761` | `Typography.headerMedium` | headline | 17 | medium |
| `Strata/Views/OnboardingView.swift:764` | `Typography.bodySmall` | footnote | 13 | REGULAR |
| `Strata/Views/OnboardingView.swift:807` | `Typography.headerMedium` | headline | 17 | medium |
| `Strata/Views/OnboardingView.swift:873` | `Typography.screenTitle` | largeTitle | 34 | medium |
| `Strata/Views/OnboardingView.swift:879` | `Typography.bodyLarge` | body | 17 | REGULAR |
| `Strata/Views/OnboardingView.swift:1004` | `Typography.bodySmall` | footnote | 13 | REGULAR |
| `Strata/Views/PhotoCollectionView.swift:123` | `Typography.bodySmall` | footnote | 13 | REGULAR |
| `Strata/Views/PhotoCollectionView.swift:153` | `StrataFont.relative(_, .subheadline)` | subheadline | 15 | medium |
| `Strata/Views/PhotoCollectionView.swift:155` | `Typography.screenSubtitle` | subheadline | 15 | REGULAR |
| `Strata/Views/PhotoViewer.swift:351` | `Typography.headerMedium` | headline | 17 | medium |
| `Strata/Views/PhotoViewer.swift:432` | `Typography.screenSubtitle` | subheadline | 15 | REGULAR |
| `Strata/Views/PhotoViewer.swift:447` | `Typography.bodySmall` | footnote | 13 | REGULAR |
| `Strata/Views/PlanBullet.swift:93` | `inline .system` | fixed | side * 0.52 | medium |
| `Strata/Views/PlanItemDetailSheet.swift:29` | `Typography.bodyLarge` | body | 17 | REGULAR |
| `Strata/Views/PlanItemDetailSheet.swift:104` | `Typography.headerSmall` | subheadline | 15 | medium |
| `Strata/Views/PlanItemDetailSheet.swift:143` | `Typography.sectionLabel` | footnote | 13 | medium |
| `Strata/Views/PlanItemDetailSheet.swift:217` | `Typography.headerSmall` | subheadline | 15 | medium |
| `Strata/Views/PlanSheet.swift:144` | `Typography.headerSmall` | subheadline | 15 | medium |
| `Strata/Views/PlanSheet.swift:336` | `Typography.bodyLarge` | body | 17 | REGULAR |
| `Strata/Views/PlanSheet.swift:411` | `Typography.bodySmall` | footnote | 13 | REGULAR |
| `Strata/Views/PrimaryCapsule.swift:195` | `Typography.headerMedium` | headline | 17 | medium |
| `Strata/Views/PrivacyPolicyView.swift:31` | `Typography.bodySmall` | footnote | 13 | REGULAR |
| `Strata/Views/PrivacyPolicyView.swift:37` | `Typography.bodySmall` | footnote | 13 | REGULAR |
| `Strata/Views/ProfileAvatar.swift:111` | `inline .system` | fixed | side * 0.42 | medium |
| `Strata/Views/ProfileAvatar.swift:115` | `Typography.screenTitle` | largeTitle | 34 | medium |
| `Strata/Views/ProfileAvatar.swift:158` | `Typography.bodyLarge` | body | 17 | REGULAR |
| `Strata/Views/ProfileAvatar.swift:201` | `Typography.headerSmall` | subheadline | 15 | medium |
| `Strata/Views/ProfileView.swift:218` | `Typography.headerMedium` | headline | 17 | medium |
| `Strata/Views/ProfileView.swift:224` | `Typography.headerMedium` | headline | 17 | medium |
| `Strata/Views/ProfileView.swift:423` | `Typography.tally` | largeTitle | 34 | medium (digits) |
| `Strata/Views/ProfileView.swift:427` | `Typography.bodyLarge` | body | 17 | REGULAR |
| `Strata/Views/ProfileView.swift:431` | `Typography.bodySmall` | footnote | 13 | REGULAR |
| `Strata/Views/ProfileView.swift:460` | `Typography.headerMedium` | headline | 17 | medium |
| `Strata/Views/ProfileView.swift:464` | `Typography.bodySmall` | footnote | 13 | REGULAR |
| `Strata/Views/ProfileView.swift:628` | `Typography.bodySmall` | footnote | 13 | REGULAR |
| `Strata/Views/ProfileView.swift:636` | `Typography.bodySmall` | footnote | 13 | REGULAR |
| `Strata/Views/ProfileView.swift:777` | `Typography.bodySmall` | footnote | 13 | REGULAR |
| `Strata/Views/ProfileView.swift:932` | `Typography.headerSmall` | subheadline | 15 | medium |
| `Strata/Views/ReplayFrame.swift:169` | `Typography.screenSubtitle` | subheadline | 15 | REGULAR |
| `Strata/Views/ReplayFrame.swift:247` | `Typography.tally` | largeTitle | 34 | medium (digits) |
| `Strata/Views/ReplayFrame.swift:277` | `Typography.screenSubtitle` | subheadline | 15 | REGULAR |
| `Strata/Views/ReplayFrame.swift:283` | `Typography.screenSubtitle` | subheadline | 15 | REGULAR |
| `Strata/Views/ReplayView.swift:741` | `Typography.headerMedium` | headline | 17 | medium |
| `Strata/Views/RestoreBackupView.swift:111` | `Typography.tally` | largeTitle | 34 | medium (digits) |
| `Strata/Views/RestoreBackupView.swift:114` | `Typography.bodyLarge` | body | 17 | REGULAR |
| `Strata/Views/RestoreBackupView.swift:142` | `Typography.bodyLarge` | body | 17 | REGULAR |
| `Strata/Views/RestoreBackupView.swift:148` | `Typography.bodySmall` | footnote | 13 | REGULAR |
| `Strata/Views/RestoreBackupView.swift:155` | `Typography.bodySmall` | footnote | 13 | REGULAR |
| `Strata/Views/RestoreBackupView.swift:161` | `Typography.bodySmall` | footnote | 13 | REGULAR |
| `Strata/Views/RestoreBackupView.swift:171` | `Typography.bodyLarge` | body | 17 | REGULAR |
| `Strata/Views/RestoreBackupView.swift:196` | `Typography.screenTitle` | largeTitle | 34 | medium |
| `Strata/Views/RestoreBackupView.swift:199` | `Typography.bodyLarge` | body | 17 | REGULAR |
| `Strata/Views/RestoreBackupView.swift:204` | `Typography.tally` | largeTitle | 34 | medium (digits) |
| `Strata/Views/RestoreBackupView.swift:210` | `Typography.bodyLarge` | body | 17 | REGULAR |
| `Strata/Views/RestoreBackupView.swift:238` | `Typography.screenTitle` | largeTitle | 34 | medium |
| `Strata/Views/RestoreBackupView.swift:241` | `Typography.bodyLarge` | body | 17 | REGULAR |
| `Strata/Views/RestoreBackupView.swift:252` | `Typography.bodyLarge` | body | 17 | REGULAR |
| `Strata/Views/RestoreBackupView.swift:268` | `Typography.bodyLarge` | body | 17 | REGULAR |
| `Strata/Views/RestoreBackupView.swift:272` | `Typography.bodyLarge` | body | 17 | REGULAR |
| `Strata/Views/RestoreBackupView.swift:296` | `Typography.bodySmall` | footnote | 13 | REGULAR |
| `Strata/Views/RestoreBackupView.swift:355` | `Typography.headerSmall` | subheadline | 15 | medium |
| `Strata/Views/SectionHeading.swift:50` | `Typography.headerMedium` | headline | 17 | medium |
| `Strata/Views/SettingsView.swift:157` | `Typography.sectionLabel` | footnote | 13 | medium |
| `Strata/Views/SettingsView.swift:720` | `Typography.headerSmall` | subheadline | 15 | medium |
| `Strata/Views/SettingsView.swift:917` | `Typography.sectionLabel` | footnote | 13 | medium |
| `Strata/Views/StoreUnavailableView.swift:48` | `Typography.screenTitle` | largeTitle | 34 | medium |
| `Strata/Views/StoreUnavailableView.swift:53` | `Typography.bodyLarge` | body | 17 | REGULAR |
| `Strata/Views/StoreUnavailableView.swift:59` | `Typography.bodyLarge` | body | 17 | REGULAR |
| `Strata/Views/StrataMark.swift:170` | `inline .system` | fixed | points | regular |
| `Strata/Views/StrataTitle.swift:24` | `Typography.screenTitleDrawn` | largeTitle | 34 | medium |
| `Strata/Views/StrataTitle.swift:37` | `Typography.screenTitle` | largeTitle | 34 | medium |
| `Strata/Views/StrataTitle.swift:90` | `.font(drawn && StrataFont.covers(title)` | ? | ? | ? |

