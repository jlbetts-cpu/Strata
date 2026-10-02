# Every word, and whether it earns its place

Written 2026-10-01, at the owner's instruction: "Make sure to understand when to
add text and when its truely not necessary... the areas are very self
explanitory and I think over explaining components loses the charm of what we
are building here... I dont like a lot of text I like the text that is there to
feel like a medium weight and be consistent guiding the user no tiny text under
or anythign like that."

**This file is the pass, not a summary of it.** Every finding carries a
`file:line` and the exact string, so it can be checked tomorrow and worked
through one screen at a time. Read-only: nothing in `Strata/` was changed to
produce it.

**Line numbers are as of 2026-10-01 and six files were being edited by other
workers while this was written.** `MainAppView.swift`, `ReplayFrame.swift`,
`RestoreBackupView.swift`, `Typography.swift`, `GridConstants.swift` and
`DebugHarness.swift` all have uncommitted changes in this tree, so a citation into one of them may drift by a
few lines. Every finding in those files also names the property or function it
lives in, which is the durable anchor. All 140 citations were resolved against
the source as the last step, and `MainAppView` and `RestoreBackupView` were
re-checked after their most recent edit.

**What was counted.** Every string literal that reaches a person's eyes:
`Text`, `Label`, button titles, `sheetTitle`, `FormSectionLabel`,
`SectionHeading`, `TextField` prompts, `Toggle` and `Picker` labels, alert and
`confirmationDialog` titles, bodies and buttons, `Form` footers, notification
titles and bodies, widget copy, App Intent titles, dialogs and descriptions, and
the error strings in `BackupArchive` / `BackupRestore` / `SharedModelContainer`
that surface in alerts. Accessibility labels, hints, values and announcements
are **excluded** and listed separately in Appendix A, so the owner can see that
removing a caption does not remove the spoken one.

A string with alternates (`isEditing ? "Save" : "Add"`) counts once. "Words" are
authored words, not words on screen at one moment: a `switch` with five arms is
counted in full, because all five are copy somebody wrote and has to maintain.

---

## The number

| | Strings | Words |
|---|---|---|
| **Now** | **399** | **2,197** |
| Cut list applied | −30 | −248 |
| **After** | **369** | **1,949** |

That is **7.5% of the strings and 11.3% of the words**, and it lands almost
entirely in one class. By class now: Fact 130, Guidance 129, Action 114,
**Explanation 26**. Of the 30 cuts, **24 are Explanation** and 6 are Guidance
that is said twice. After the pass the Explanation class is down to 2 strings.

**The honest read of that number is that it is small, and that is the finding.**
This app is not verbose. Three earlier passes already took out the greeting, the
gesture manual, the second empty-state button, the "Your week" title over the
replay, the busiest-day sentence, the skip on five of six onboarding pages, the
"More" shelf and the per-card count readout. What is left is 2,197 words of
which **1,057 — 48% — is two legal and recovery screens** (Privacy 402, Restore
398, Store unavailable 49, Settings' data and backup footers) that nobody sees
in normal use. The app a person actually lives in is the other half, and it is
already thin.

So the win here is not volume. It is that **26 strings are the app narrating
components that are sitting right there**, and those are the ones that make the
screens feel like they are explaining themselves instead of being a place.

Per screen, worst-offending first by words removed:

| Screen | Strings | Words | Cut | Words cut |
|---|---|---|---|---|
| Privacy | 19 | 402 | 0 | 0 |
| Restore | 49 | 398 | 2 | 16 |
| Profile | 56 | 257 | 6 | 30 |
| Settings | 50 | 255 | 3 | 41 |
| Onboarding | 31 | 195 | 6 | 28 |
| Siri / Shortcuts / Spotlight | 42 | 145 | 1 | 4 |
| Head maker | 19 | 86 | 1 | 13 |
| Add a win | 26 | 50 | 2 | 6 |
| Store unavailable | 4 | 49 | 1 | 28 |
| Wins, the tower | 9 | 42 | 1 | 3 |
| Camera | 14 | 38 | 0 | 0 |
| Photo viewer | 11 | 37 | 0 | 0 |
| Plan line | 7 | 36 | 3 | 32 |
| Memories, the map | 7 | 35 | 0 | 0 |
| Notifications | 6 | 32 | 2 | 16 |
| Memories, the month | 15 | 30 | 1 | 1 |
| Widget | 10 | 29 | 0 | 0 |
| Memories, empty | 2 | 18 | 1 | 13 |
| Plan | 5 | 17 | 0 | 0 |
| Replay | 10 | 17 | 0 | 0 |
| Day album | 3 | 13 | 0 | 0 |
| Place collection | 3 | 9 | 0 | 0 |
| Head look | 1 | 7 | 0 | 0 |

---

## The cut list

Ranked by how certain the cut is. Each entry names what is lost and what on the
screen already says it.

### Tier 1 — the thing it was there for is gone, or the screen says it twice

**1. `Strata/Views/MainAppView.swift:3023` — "Nothing yet today"**
Lost: nothing. **Its own code comment names the reason it existed and that
reason has been deleted.** `MainAppView.swift:2693`: *"'Nothing yet today' is a
statement about the day and the day is named directly above it."* There is no
date above it any more — `headerCount`, the date and the replay pill all came
off the Wins header, which is now a `Spacer` and one `checklist` button
(`towerHeader`, `MainAppView.swift:854–892`; `grep headerDate` returns nothing). So a sentence
justified by its neighbour is standing on its own over an empty tower, saying
that the empty tower is empty. What is left, `"Tap the slot to log your first
win."` at :3030, is the line that does work, and it should take
`Typography.headerMedium` and `inkPrimary` when the line above it goes — one
medium-weight line, which is exactly what he asked for.

**2. `Strata/Views/MemoriesShelf.swift:101` — "Collections"**
Lost: nothing. This is the heading-over-named-things case verbatim. The row
under it is `AlbumCard`s, and each card draws `album.title` at
`Typography.headerMedium` — "Gym session", "A year ago today", "Last month" —
with its own count caption under that (`AlbumCarousel.swift:47`, `:81`). The
heading's own doc comment (`MemoriesShelf.swift:94`) says *"the heading says what
they are"*, and the cards say what they are. The page already has a title
(`Memories`), a month picker, a replay row and a photo grid; "Collections" is a
fifth label on a page whose subject is the month above it.

**3. `Strata/Views/PlanItemDetailSheet.swift:60` and `:61` — "Comes back on these days. Ticking it off keeps it until the day turns." / "A one-off. It clears once the day it was finished is over."**
Lost: nothing a person needs at that moment. These are the footer under a
`Repeats` toggle (`:49`), and they are 25 words explaining the two states of one
switch, on a sheet whose entire content is a text field, a colour row and that
switch. The switch's own label is the fact. If anything here is worth keeping it
is the second half of :60 ("it stays until the day turns"), which is the one
non-obvious behaviour, and it is cheaper to make the row read `Repeats` /
`Repeats daily` than to carry two sentences.

**4. `Strata/Views/ProfileView.swift:485`, `:486`, `:487` — "You're logging more wins lately." / "You're keeping a steady pace." / "A quieter stretch lately."**
Lost: a mood. The line directly under each of them (`detail`, `:501` `:506`
`:508`) carries the same claim with the numbers in it: *"3 a week over the last
8 weeks, up from 2 before that."* That is a title and a subtitle where the
subtitle is strictly more informative, which is the pattern upside down. The fix
is not to delete a line, it is to **promote `shownDetail` into the
`headerMedium` slot and delete `headline`** — one medium-weight sentence over
the chart, no small grey line under it. `:488` ("Keep logging to see your
trend.") and `:489` stay: at those two states there is no number to promote.

**5. `Strata/Views/ProfileView.swift:512` — "Log a win and it's counted here."**
Lost: nothing. It is the detail line for `summary.kind == .empty`, whose
headline at `:489` already reads *"Your weeks will show up here."* Two sentences,
the second restating the first, under a section heading that already says
`Wins per week`.

**6. `Strata/Views/ProfileView.swift:878` — "It only appears where you switch it on."**
Lost: nothing. It is the head section's footer in the one-head case, directly
under the four switches it describes, each of which names its own surface: `Let
My Head Onto the Tower`, `Show My Head on the Map`, `Add My Head to Photos`,
`Use as Profile Picture`. Four labelled switches do not need a sentence saying
switches work. `:876` (the multi-head case, *"The head you pick above is the one
that appears where you switch it on."*) **stays** — it resolves a real ambiguity
the switches cannot, which face the switches belong to, and its own comment says
so. `:870` (the no-head case) stays: it is a promise before the thing exists.

**7. `Strata/Views/HeadMakerView.swift:895` — "Your head is ready. It only shows up where you turn it on."**
Lost: nothing. The head is on screen, blinking, above a name field and a `Save`
button. "Your head is ready" describes a head that is visibly ready; the second
sentence is the same sentence as ProfileView `:878`, which is where somebody will
be when they need it. `:897`, the honest version that names what the head
*cannot* do, **stays** — it carries a fact no picture shows.

**8. `Strata/Views/MemoriesStill.swift:139` — the tab bar labels "Wins" / "Camera" / "Memories"**
Lost: nothing, and it corrects an inaccuracy. This is inside the device mock-up
on onboarding page 3. It draws a tab bar with an 11pt medium word under each
glyph — *"no tiny text under or anythign like that"*, in a drawing whose stated
job (`MemoriesStill.swift:6`) is to "look like the real Memories screen". The
real tab bar is icon-only: `MainAppView.swift:605–644` builds each `Tab` with a
bare `Image(systemName:)` and the words exist only as `accessibilityLabel`. So
the mock-up is teaching a chrome the app does not have.

**9. `Strata/Views/RestoreBackupView.swift:160` — "Restoring only adds. Nothing already on this phone is deleted or changed."**
Lost: nothing. It is the **third** statement of that fact on one flow. The rows
immediately above it already say it per-category (`:145` *"N are already on this
phone and will be left as they are."*), and `SettingsView.swift:485`, the footer
on the button that opens this sheet, says *"Restoring only adds what the file
holds; nothing already on this phone is deleted."* Keep the Settings footer,
which is read before the decision; drop the restatement inside it.

**10. `Strata/Views/SettingsView.swift:377` — "Photographs you take in Strata keep the place they were taken, and appear on your map."**
Lost: nothing. `MemoriesMapView.swift:718` says the same sentence on the empty
map, which is where somebody is when they want to know
(*"Photos you take in Strata keep the place they were taken, and land here."*).
The Settings line sits under a toggle labelled `Remember Places` in a section
headed `Camera`, under a storage readout. The **denied** branch at `:376` stays:
that one is a fact the screen cannot otherwise show, and its comment correctly
says it "should not be discovered".

### Tier 2 — the component says it, but there is a judgement in it

**11. `Strata/Views/MemoriesView.swift:712` — "Every win you log becomes a block, and they collect here by month."**
Lost: a restatement of onboarding page 1 ("Finish something and it becomes a
block"). The line above it, *"Your first month starts here"* (`:709`), and the
real empty month calendar drawn directly under it, already make the promise —
and the file's own comment argues exactly that: *"the real calendar sits under
this copy and shows a real empty month, which is a better promise of the thing
than a drawing of a different thing."* Thirteen words. The judgement: this is
first-run copy and nobody sees it twice.

**12. `Strata/Views/AddWinSheet.swift:509` — "Add a photo"**
Lost: very little. It sits under a white `camera.fill` glyph on a 0.35 black
disc, in the middle of the largest object on the sheet, which is already drawn
as the block it will become. The glyph is the label. Note it is already
suppressed on a Quick block (`if size != .small`), so the sheet already accepts
that the well reads without it at one size.

**13. `Strata/Views/AddWinSheet.swift:262` — "Add a photo" (confirmationDialog title)**
Lost: nothing. It is presented with `titleVisibility: .hidden`, so **it is not
drawn at all** — the string is in the source and on screen are only `Take
Photo`, `Choose from Library`, `Remove Photo`, `Cancel`, which say it. One word
of real copy, zero visible. Cut it for tidiness, not for the screen.

**14. `Strata/Views/HeadPickerRow.swift:98` — the head's name under its face**
Lost: the name, when somebody typed one. The default for the first head is
`"Me"` (`HeadStore.swift:266`) and after that `"Head 2"`, `"Head 3"`
(`HeadStore.swift:471`). So out of the box this is a 13pt word under a picture
of the owner's own face reading "Me", and a numbered caption under each
subsequent face. The row's own comment admits the redundancy: *"this swatch says
'chosen' three times over: the ring, the step up from 0.94 to full size, and the
name under it going from secondary ink to primary."* Recommendation: draw the
name only when it differs from the generated default. A name somebody chose is a
Fact; a name the app made up is a caption repeating the thing.

**15. `Strata/Views/SettingsView.swift:400` — "The short walkthrough you saw when you first opened the app."**
Lost: nothing. It is the footer under a row reading `How Strata Works` with a
`questionmark.circle` glyph. The row names itself.

**16. `Strata/Services/SharedModelContainer.swift:353` — trim, do not delete**
Current: *"Nothing has been deleted. Your wins are on this phone and Strata
cannot read them right now, so it is showing you this instead of an empty
tower."* The first six words are the only thing a frightened person needs. The
rest is the app explaining its own implementation choice to the one person who
cannot act on it. Trim to **"Nothing has been deleted. Your wins are on this
phone."** 17 words out, the reassurance intact, `:354` (what to actually do)
untouched.

**17. `Strata/Services/ReplayReminder.swift:57` and `:58` — "Seven days of wins, stacked into one tower." / "A month of wins, stacked into one tower."**
Lost: a description of the thing that is one tap away. The titles — *"Your week
is ready"*, *"September is ready"* — carry the news. A notification body that
describes the feature is the push-notification equivalent of a caption under a
picture. The judgement: iOS gives the body space whether you use it or not, and
some people decide on the body. Low risk either way; 16 words.

**18. `Strata/Intents/HabitEntity.swift:32` — contentDescription "A win in Strata"**
Lost: nothing. It is the Spotlight subtitle under a result whose title is the
win's own name and whose `subtitle` is already the category
(`HabitEntity.swift:23`). Three facts, one of which says only that the app is
this app.

### Tier 3 — flagged, the owner's call, I would not cut without him

**19. `Strata/Views/SettingsView.swift:553` — "Everything you log stays on this device. Strata has no account and no server."**
This is the footer under the `Privacy` row, and `PrivacyPolicyView.swift:54`
says it at length one tap away. By the rule it is Explanation and it goes. I am
not cutting it, because it is the one sentence in the app that *sells* the thing
the brand doc calls the product's spine, and it is sitting where somebody who
cares will look. 13 words. His call.

**20. `Strata/Views/PlanItemDetailSheet.swift:28` — placeholder "What do you mean to do?"**
Only visible when the line is empty, which on a *detail* sheet is rare — you
arrive from a line you already typed. It also diverges from the add sheet's
`"What did you do?"` by one word, which is correct (plan is future, win is past)
and is the kind of near-duplicate worth knowing about rather than fixing.

**21. `Strata/Views/OnboardingView.swift:924` and `:925`**
`:924` *"Take it here and the picture becomes the block."* under the title *"A
win can be a photograph"*; `:925` *"Your wins land on the map where you took
them."* under *"Every photo keeps its place."* Both are a title and a subtitle
saying one thing. On every other screen I would cut the subtitle. Here the page
is a live demo with nothing else to read and the whole screen is six sentences
long, so the trade is between a bare title over a mock-up and a sentence that
earns the demo. Flagged, 20 words, his call. `:904` *"That's how every win is
made"* is a weaker case: it replaces *"Quick, regular or deep"* **after** the
person has drawn a block, which is the moment they have just proven they know,
so it is the app congratulating itself; cutting it leaves the title stable
across the page's two states.

### Not cut, and why — the pattern search came up empty here

Three patterns I went looking for and did not find, which is worth recording so
nobody re-runs the search:

- **A count stated twice.** `PhotoCollectionView` opens on `"12 here"` as its
  title when a place has no geocoded name, with a `"12 photos"` readout under
  it. That is the same number 2pt apart — and it is **already solved**: the
  readout carries `.opacity(sections.isEmpty || titleIsCount ? 0 : 1)`
  (`PhotoCollectionView.swift:193`). Leave it.
- **A hint under a field whose placeholder says it.** There is not one. Every
  text field in the app (`AddWinSheet:111`, `ProfileView:217`,
  `HeadMakerView:862`, `PlanSheet`, `PlanItemDetailSheet:28`) carries a
  placeholder and nothing underneath.
- **A caption under a block.** The tower draws `BlockContent.swift:127`, the
  win's own title, on the block, and nothing below it. `CLAUDE.md`'s "Nothing
  sits under the tower" is holding.

---

## Where the text is doing real work

Named so the pass reads as a judgement and not a sweep.

**Destructive confirmations — all of these stay, every word.** They are the only
place in the app where a sentence prevents a loss.
- `AddWinSheet.swift:198` + `:202` — "Delete this?" / "The block leaves the
  tower."
- `PhotoViewer.swift:198` + `:206` — "Remove this photo?" / "The win stays on
  your tower. Only the photograph is deleted." This one is load-bearing by
  `CLAUDE.md`'s own instruction: *"A delete button inside a photo viewer that
  silently shortened your tower would be the worst thing this app could do, so
  the confirmation says so out loud."*
- `SettingsView.swift:469` + `:478` — "Reset All Data?" / "This permanently
  deletes every win and photo, your name and profile photo, and your head. It
  cannot be undone."
- `ProfileView.swift:126` + `:132` — "Delete Me?" / "...A head can't be brought
  back, only made again."

**Permission explanations — stay.** Each one is the only thing on a screen
somebody is stuck on, and each names the switch to throw.
- `CameraView.swift:455` + `:458` — the refused viewfinder.
- `MemoriesMapView.swift:708`, `:717`, `:718` — the empty and denied map.
- `SettingsView.swift:272` — "Notifications are disabled in system settings."
- `SettingsView.swift:376` — the denied-location branch.
- `HeadMakerView.swift:460` — "Turn the camera on for Strata in Settings."

**Legal — stays, untouched.** `PrivacyPolicyView.swift:48–90`, nine sections,
402 words. It is 18% of the app's whole word count and it is also the document
`CLAUDE.md` records as having once described a product that did not exist. It
does not get edited for brevity.

**Recovery copy — stays.** `RestoreBackupView`, `BackupArchive`,
`BackupRestore`, `StoreUnavailableCopy`: 398 + 49 words across errors nobody
sees unless something has gone wrong, and every one of them ends by saying what
was *not* changed. That is the right instinct and it should not be shortened
into ambiguity. The one trim is item 16.

**The first-run promise — stays.** `OnboardingView.swift:903`/`:920` (page 1)
and `:929` (the thank-you). The thank-you is the owner's own voice, in the first
person, and is not copy an audit touches.

**The head maker's coaching — stays, all nine lines.**
`HeadMakerView.swift:466`–`:483`: "Press when you're ready", "Blink slowly",
"Now a big smile", "Raise your eyebrows", "Now look surprised", "Now a wink",
"Last one, a wink", "One more quick blink", "Got it". These are not captions
under components; they are the instruction, in sequence, for the one interaction
in the app a person cannot work out by looking.

**Every screen whose cut count is zero, on purpose.** Camera, Photo viewer,
Replay, Plan, Day album, Place collection, Widget, Head look picker, Memories
map. The Camera's review screen is four words of chrome (`Retake`, `Use Photo`)
plus a size picker and four look names. The Replay carries one count, one date
and three button labels. **The Wins tab's header has no text at all** — the
count, the date, the filter and the replay pill are all gone, leaving a
`Spacer` and one icon button. That is the standard the rest of the app is being
measured against, and it is already met.

---

## Voice

### One em dash, in user-facing copy

`Strata/Services/BackupArchive.swift:251`

```
"This backup is incomplete — it may not have finished downloading or copying. \(detail)"
```

Shown in the alert on `SettingsView.swift:626` and in
`RestoreBackupView`'s failure state. It breaks the rule recorded in `CLAUDE.md`
("Words the app says", 2026-09-11): *no long dash in anything a person reads*.
A colon is the fix: `"This backup is incomplete: it may not have finished
downloading or copying."` Note `docs/screen-audit.md` already logged "an em dash
in the copy" as what the Restore screen cost — this is the one that survived
that pass, because it lives in a service file and not in the view.

The only other em dash in a string literal in the whole app is
`DebugHarness.swift:615`, a `[strata-bench]` log line. Not user-facing, no
action. Swept over all of `Strata/`, `Shared/`, `StrataWidget/`,
`WidgetSupport/` for U+2014 and U+2013; those are the only two hits.

### One phrase that reads as the app keeping track of a person

`Strata/Views/SettingsView.swift:358` — the toggle **"Remember Places"**.

This is the construction the onboarding pass already rejected, and the rejection
is written down two files away. `OnboardingView.swift:897`: *"And nothing here
watches you. Page four said 'It remembers where you were', which puts the app in
the role of something keeping track of a person."* The toggle says the same
thing in two words. What the switch actually does is written correctly in its own
footer and on the map: **the photograph keeps its place**. So the label should be
the thing, not the watcher — `Keep Places`, or `Places on Photos`. Nothing else
in the app's visible copy contains watch / watches / tracks / monitors / detects
/ "your face" / "where you were": the only other hits for those words are two
DEBUG log lines (`StoreAddedFieldsCheck.swift:32`, `StoreMigrationCheck.swift:61`).

The word **"habit"** appears in no user-facing string anywhere, which is the
brand rule from `docs/brand.md` §2 holding. (`Habit`, `HabitLog`, `HabitEntity`
are code, which that doc explicitly permits.)

### The app talking about itself

The owner has rejected this twice, in his words recorded in `CLAUDE.md`: *"The
words 'Your week' are the app talking about itself; a friend watching the video
does not need them."*

**The replay is clean.** `ReplayPeriod.title` still returns `"Your week"` /
`"Your month"` (`ReplayPeriod.swift:111`) and I checked every caller: `Replay.swift:87`
(a VoiceOver announcement), `MemoriesShelf.swift:333` (a VoiceOver label),
`ReplayFrame.swift:154` (a VoiceOver label) and
`ReplayVideoExporter.swift:102` (the exported file's name). **None of them
draws it.** The frame itself shows the count, the date range and nothing else,
which is the decision as recorded. Leave the property alone.

Where the construction does still appear, and my read of each:

| Where | String | Read |
|---|---|---|
| `SettingsView.swift:328`, `:332` | "Preview Your Week" / "Preview Your Month" | **Fine.** This is the feature's proper name, which is how you refer to a thing you are about to show somebody. |
| `ReplayReminder.swift:57` | "Your week is ready" | **Fine.** A notification is the app addressing you; this is the one place it is allowed to. |
| `ProfileView.swift:862` | "Your head" / "Your heads" | **Fine.** A possessive section label over switches about your head, not a title over your own content. |
| `ProfileView.swift:217` | "Your name" | **Fine.** It is a placeholder standing in for an empty field, which is the one case where the app has to name the content because there is none. |
| `MemoriesView.swift:709` | "Your first month starts here" | **Fine**, and it is about to be the whole empty state once :712 goes. |
| `MemoriesMapView.swift:708` | "Your map starts here" | **Fine**, same shape. |
| `TowerWidgetView.swift:161` | "Your first win goes here" | **Fine.** A widget has no context but its own copy. |
| `ProfileView.swift:489` | "Your weeks will show up here." | **Fine**, and it is the surviving half of cut 5. |

No instance found where a title is narrating back a record the person is already
looking at, which is what the rejection was about.

### Two voice inconsistencies worth knowing, neither a cut

- **"photo" and "photograph" are both in use, by screen.** Settings, the
  privacy policy and Restore say *photograph(s)*
  (`SettingsView.swift:62`, `PrivacyPolicyView`, `RestoreBackupView.swift:124`);
  the camera, the viewer, the map and the add sheet say *photo*
  (`PhotoViewer.swift:401`, `MemoriesMapView.swift:717`,
  `AddWinSheet.swift:255`). `PhotoCollectionView.swift:122` says *photographs*
  while its own count line two lines up says *photos*. Not worth a sweep, but
  if one is picked, the short word belongs on the screens somebody uses and the
  long one on the documents.
- **`Habit.currentConsistencyLabel` (`Strata/Models/Habit.swift:311`) returns
  "Active" / "On a roll" / "On fire" / "Unstoppable" / "Legendary" and has no
  callers.** Five scoreboard words sitting in the model of an app whose brand
  doc says *"a tracker keeps a score, and a score can be lost"*. They are not
  counted in this audit because nothing draws them, but they are the exact voice
  the design removed, and a future session reaching for a streak label will find
  them first. They belong in the dead-code sweep, not in copy.

---

## Screen by screen

Each section lists every visible string on that screen with its class.
**F** Fact · **A** Action · **G** Guidance · **E** Explanation. A `✂` marks a
cut-list entry and gives its tier.

### 1. Wins — the tower
Nine strings, 42 words. **The header draws no text.** `towerHeader`
(`MainAppView.swift:854`, `towerHeader`) is a `Spacer` and one `checklist`
`GlassIconButton` whose only word is an accessibility label.

| | file:line | string | class |
|---|---|---|---|
| | `BlockContent.swift:127` | the win's own title, on the block | F |
| ✂1 | `MainAppView.swift:3026` | "Nothing yet today" | E |
| | `MainAppView.swift:3033` | "Tap the slot to log your first win." | G |
| | `MainAppView.swift:481` | "Nothing was deleted" (alert title) | F |
| | `MainAppView.swift:482` | "OK" | A |
| | `MainAppView.swift:484` | "Strata could not reset your data, so every win and photo is still here. Try again." | G |
| | `MainAppView.swift:486` | "Couldn't save that win" | F |
| | `MainAppView.swift:487` | "OK" | A |
| | `MainAppView.swift:489` | "Nothing was added. Try again." | G |

### 2. Add a win
Twenty-six strings, 50 words. Short already: a title, a placeholder, two field
labels, a picker and a well.

| | file:line | string | class |
|---|---|---|---|
| | `AddWinSheet.swift:193` | "Add a win" / "Edit" (sheet title) | F |
| | `AddWinSheet.swift:111` | "What did you do?" / "Name" (placeholder + prompt) | G |
| | `AddWinSheet.swift:151` | "Colour" | G |
| | `AddWinSheet.swift:154` | "Size" | G |
| | `Habit.swift:95–97` | "Quick" / "Regular" / "Deep" | A |
| ✂12 | `AddWinSheet.swift:509` | "Add a photo" (under the camera glyph) | E |
| | `AddWinSheet.swift:361` | "Cancel" | A |
| | `AddWinSheet.swift:370` | "Add" / "Save" | A |
| | `AddWinSheet.swift:716` | "Delete" | A |
| | `AddWinSheet.swift:198` `:199` `:200` `:202` | "Delete this?" / "Delete" / "Cancel" / "The block leaves the tower." | G A A G |
| ✂13 | `AddWinSheet.swift:262` | "Add a photo" (dialog title, `titleVisibility: .hidden`) | G |
| | `AddWinSheet.swift:263` `:264` `:266` `:271` | "Take Photo" / "Choose from Library" / "Remove Photo" / "Cancel" | A |
| | `AddWinSheet.swift:255` `:256` | "Replace Photo" / "Remove Photo" | A |
| | `AddWinSheet.swift:997` `:1005` | "Replace Photo" / "Remove Photo" (menu) | A |

### 3. Camera — viewfinder, refused, review
Fourteen strings, 38 words, **nothing to cut.** Every glyph on the viewfinder
carries its state in an accessibility label and nothing else; the review is two
words and two pickers.

| | file:line | string | class |
|---|---|---|---|
| | `CameraView.swift:455` | "Strata cannot use the camera" | F |
| | `CameraView.swift:458` | "A win can be a photograph. Turn the camera on for Strata in Settings and this becomes the viewfinder." | G |
| | `CameraView.swift:467` | "Open Settings" | A |
| | `CameraView.swift:223`, `:1340` | the countdown and timer numerals | F |
| | `CameraView.swift:616` `:643` | "Retake" / "Use Photo" | A |
| | `CameraView.swift:695` | "Quick" / "Regular" / "Deep" | A |
| | `FilmLook.swift:48–51` | "None" / "Air" / "Bright" / "Silver" | A |

Note on the look names: these are **not** a caption repeating the swatch. The
swatch is a thumbnail of the photograph under that grade, and Air and Bright are
not distinguishable from each other at 48pt. They earn their place. "None" is
the weakest of the four and still stays, because three named options and one
unnamed one is worse than four named ones.

### 4. Memories — the month
Fifteen strings, 30 words. Almost all of it is the person's own data.

| | file:line | string | class |
|---|---|---|---|
| | `MemoriesView` (`MemoriesTitle`) | "Memories" (screen title) | F |
| | `MonthTowerView.swift:346` | the month name in the picker (and `:319`, the menu's months) | F |
| | `MonthTowerView.swift:130` | the day numeral on a month block | F |
| | `MonthReplayRow.swift:67` | "N win" / "N wins" | F |
| ✂2 | `MemoriesShelf.swift:101` | "Collections" | E |
| | `AlbumCarousel.swift:47` | the album's own title | F |
| | `Album.swift:185`, `AlbumMoment.swift:122` | "N PHOTOS" | F |
| | `Album.swift:276` | the album's short date | F |
| | `AlbumMoment.swift:59`, `:61`, `:63` | "A year ago today" / "N years ago today" / "This week last year" / "Last month" | F |
| | `PhotoGalleryGrid.swift:148` | the gallery's date headings | F |

### 5. Memories — empty
Two strings, 18 words. After the cut: one line.

| | file:line | string | class |
|---|---|---|---|
| | `MemoriesView.swift:709` | "Your first month starts here" | G |
| ✂11 | `MemoriesView.swift:712` | "Every win you log becomes a block, and they collect here by month." | E |

### 6. Memories — the map
Seven strings, 35 words, **nothing to cut.** Every line is on a screen with
nothing on it, and the duplicate of :718 is in Settings, which is where the cut
belongs (✂10).

| | file:line | string | class |
|---|---|---|---|
| | `MemoriesMapView.swift:708` | "Your map starts here" / "Places are off" | G / F |
| | `MemoriesMapView.swift:717` | "Strata can't tell where a photo was taken." | G |
| | `MemoriesMapView.swift:718` | "Photos you take in Strata keep the place they were taken, and land here." | E |
| | `MemoriesMapView.swift:753` | "Open Settings" / "Turn On Places" | A |
| | `MemoriesMapView.swift:1464` | the win count badge on a block | F |

### 7. Day album
Three strings, 13 words, **nothing to cut.** Title, count, and one sentence for
a state only a debug flag can reach.

| | file:line | string | class |
|---|---|---|---|
| | `DayAlbumDetailView.swift:168` | "Today" / "Yesterday" / the date | F |
| | `DayAlbumDetailView.swift:189` | "N win" / "N wins" | F |
| | `DayAlbumDetailView.swift:92` | "Nothing logged this day." | F |

### 8. Place collection
Three strings, 9 words, **nothing to cut** — see the note above on the count
already being hidden when the title is a count.

| | file:line | string | class |
|---|---|---|---|
| | `PhotoCollectionView.swift:249`/`:254` | "N here", until the place name arrives | F |
| | `PhotoCollectionView.swift:154` | "N photo" / "N photos" | F |
| | `PhotoCollectionView.swift:122` | "No photographs here." | F |

### 9. Photo viewer
Eleven strings, 37 words, **nothing to cut.** The caption is three facts the
picture cannot show and a place name; the delete confirmation is load-bearing.

| | file:line | string | class |
|---|---|---|---|
| | `PhotoViewer.swift:350` | the win's own title, on the photograph | F |
| | `PhotoViewer.swift:465` | "Quick · 8 September · 6:26 PM" | F |
| | `PhotoViewer.swift:446` | the place name | F |
| | `PhotoViewer.swift:388` `:392` `:401` | "Share" / "Save to Photos" / "Saved to Photos" / "Remove Photo" | A / F |
| | `PhotoViewer.swift:198` `:201` `:202` `:206` | "Remove this photo?" / "Remove Photo" / "Cancel" / "The win stays on your tower. Only the photograph is deleted." | G A A G |

### 10. Plan
Five strings, 17 words, **nothing to cut.**

| | file:line | string | class |
|---|---|---|---|
| | `PlanSheet.swift:81` | "Plan" | F |
| | `PlanSheet.swift:143` | "Done" | A |
| | `PlanSheet.swift:335` | "Write what you mean to do, then press its block when you have." | G |
| | `PlanSheet.swift:466` `:469` | "Options" / "Delete" | A |

### 11. Plan line
Seven strings, 36 words. **The worst ratio in the app**: 32 of its 36 words are
on the cut list. Three controls and 25 words explaining one of them.

| | file:line | string | class |
|---|---|---|---|
| | `PlanItemDetailSheet.swift:66` | "Line" | F |
| ✂20 | `PlanItemDetailSheet.swift:28` | "What do you mean to do?" | G |
| | `PlanItemDetailSheet.swift:35` | "Colour" | G |
| | `PlanItemDetailSheet.swift:49` | "Repeats" | A |
| ✂3 | `PlanItemDetailSheet.swift:60` | "Comes back on these days. Ticking it off keeps it until the day turns." | E |
| ✂3 | `PlanItemDetailSheet.swift:61` | "A one-off. It clears once the day it was finished is over." | E |
| | `PlanItemDetailSheet.swift:217` | "Done" | A |

### 12. Profile
Fifty-six strings, 257 words. **The densest screen in the app** and the one the
pass changes most: six cuts, 30 words, and the trend block restructured from a
title-plus-subtitle into one medium-weight line.

| | file:line | string | class |
|---|---|---|---|
| | `:92` | "Profile" | F |
| | `:217` | "Your name" (placeholder) | G |
| | `:243` `:249` `:255` `:261` `:266` | "Use Photo or Initials" / "Use My Head" / "Use <name>" / "Choose Photo" / "Background Colour" / "Remove Photo" | A |
| | `:363–369` | "Green" / "Blue" / "Purple" / "Amber" / "Coral" / "Pink" / "No colour" | F |
| | `:399` | "Streak" | G |
| | `:382` `:383` | "Current" / "Best" | F |
| | `:426` | "day" / "days" | F |
| | `:402` | "Log a win to start one." | G |
| | `:450` | "Day" / "Week" / "Month" | A |
| | `:479` | "Wins per week" | G |
| ✂4 | `:485` `:486` `:487` | "You're logging more wins lately." / "You're keeping a steady pace." / "A quieter stretch lately." | E |
| | `:488` `:489` | "Keep logging to see your trend." / "Your weeks will show up here." | G |
| | `:501` `:506` `:508` `:510` | the four number sentences | F / G |
| ✂5 | `:512` | "Log a win and it's counted here." | G |
| | `:550` `:554` `:557` `:560` `:542` | the selected bar's date and count | F |
| | `:862` | "Your head" / "Your heads" | G |
| ✂14 | `HeadPickerRow.swift:98` | the head's name, under its face | E |
| | `:701` | "Make Your Head" | A |
| | `:729` `:770` `:774` `:799` `:810` `:821` `:837` `:854` | "Use as Profile Picture" / "Look" / the look's name / "Let My Head Onto the Tower" / "Show My Head on the Map" / "Add My Head to Photos" / "Add Another Head" / "Delete <name>" | A / F |
| | `:870` | "About fifteen seconds in front of the camera..." | G |
| | `:876` | "The head you pick above is the one that appears where you switch it on." | E (stays) |
| ✂6 | `:878` | "It only appears where you switch it on." | E |
| | `:126` `:128` `:132` | the delete-head confirmation | G A G |
| | `:891` `:932` | "Settings" / "Done" | A |

### 13. Settings
Fifty strings, 255 words. Seven section headings, twelve rows, five footers,
four alerts. Three cuts, 41 words — all of them footers.

| | file:line | string | class |
|---|---|---|---|
| | `:580` | "Settings" | F |
| | `:268` `:315` `:336` `:367` `:481` `:530` `:566` | "Notifications" / "Sounds & Haptics" / "Replays" / "Camera" / "Data" / "Support" / "Debug" | G |
| | `:209` `:235` `:257` | "Daily Reminder" / "Reminder Time" / "Weekly and Monthly Replays" | A |
| | `:272` `:273` | "Notifications are disabled in system settings." / "Open Settings" | G A |
| | `:297` `:307` | "Completion Sounds" / "Haptic Feedback" | A |
| | `:328` `:332` | "Preview Your Week" / "Preview Your Month" | A |
| | `:344` `:358` | "Save to Photos" / "Remember Places" | A · **voice, see above** |
| | `:58` `:62` | "No photographs stored yet." / "N photographs, 14.2 MB." | F |
| | `:376` | the denied-location footer | G (stays) |
| ✂10 | `:377` | "Photographs you take in Strata keep the place they were taken, and appear on your map." | E |
| | `:388` | "How Strata Works" | A |
| ✂15 | `:400` | "The short walkthrough you saw when you first opened the app." | E |
| | `:411` `:441` `:457` `:563` | "Back Up Everything" / "Restore From a Backup" / "Reset All Data" | A |
| | `:485` | the backup footer | G (stays; it is the one ✂9 defers to) |
| | `:469` `:473` `:478` | the reset confirmation | G A G |
| | `:502` `:523` `:546` | "Send Feedback" / "Rate on App Store" / "Privacy" | A |
| ✂19 | `:553` | "Everything you log stays on this device. Strata has no account and no server." | E · **owner's call** |
| | `:720` | "Done" | A |
| | `:601` `:602` `:604` `:606` `:607` `:612` `:626` `:629` `:631` | four alerts and their OKs | F G A |
| | `:623` `:782` `:809` | three "Strata could not..." messages | G |

### 14. Privacy
Nineteen strings, 402 words, **nothing to cut.** Nine headings and nine bodies,
`PrivacyPolicyView.swift:48–90`. 18% of the app's words and the only text in it
with a legal reason. Do not shorten.

### 15. Replay
Ten strings, 17 words, **nothing to cut**, and this is the screen that proves
the pass is possible: a count, a word, a date and four button labels, on a
60-second film. The owner already removed a title, a busiest-day sentence and a
"Your week" from it.

| | file:line | string | class |
|---|---|---|---|
| | `ReplayFrame.swift:168` `:276` `:282` | "win"/"wins" / the date range / "Sample" | F |
| | `ReplayView.swift:342` | "Replay" | A |
| | `ReplayView.swift:674–677` | "Save Video" / "Saving…" / "Saved to Photos" / "Couldn't save" | A / F |
| | `ReplayView.swift:790` | "Share" / "Couldn't share" | A / F |

### 16. Head maker
Nineteen strings, 86 words. One cut. The nine coaching lines stay — see "doing
real work".

| | file:line | string | class |
|---|---|---|---|
| | `:466`–`:483` | the nine capture prompts, "Got it", "Making your head…" | G / F |
| | `:460` `:461` | "Turn the camera on for Strata in Settings." / "The camera isn't available here." | G F |
| | `:593` | "Try Again" / "Open Settings" / "Close" | A |
| | `:754` `:783` | "Retake" / "Save" / "Try Saving Again" | A |
| | `:862` | the suggested head name (placeholder) | F |
| ✂7 | `:895` | "Your head is ready. It only shows up where you turn it on." | E |
| | `:897` | "Your head is ready, but it won't blink or wink. Retake if you'd like to try again." | G (stays) |

### 17. Onboarding
Thirty-one strings, 195 words across six pages. Six cuts, 28 words — three of
them (✂8) are the mock-up's tab labels, which are a factual error as well as
tiny text.

| | file:line | string | class |
|---|---|---|---|
| | `:903` `:920` | "Everything you did, stacked up" / "Finish something and it becomes a block." | G |
| | `:904` | "Quick, regular or deep" | G |
| ✂21 | `:904` | "That's how every win is made" (after the draw) | G |
| | `:922` `:923` | the two size subtitles | G |
| | `:905` | "A win can be a photograph" | G |
| ✂21 | `:924` | "Take it here and the picture becomes the block." | E |
| | `:906` | "Every photo keeps its place" | G |
| ✂21 | `:925` | "Your wins land on the map where you took them." | E |
| | `:907` `:927` `:928` | the head page | G |
| | `:908` `:929` `:760` `:763` `:806` | the thank-you page | F / A |
| | `:1003` | "Not now" | A |
| | `:1082`–`:1087` | "Let me try" / "What else" / "Go on" / "Turn on places" / "One more thing" / "Make my head" / "Start" | A |
| | `:1060` | "Not yet. Draw a block to go on." | G |
| ✂8 | `MemoriesStill.swift:139` | "Wins" / "Camera" / "Memories" under the mock tab glyphs | E |

### 18. Restore
Forty-nine strings, 398 words. Two cuts. Everything else is a count, a date or a
statement of what was *not* changed, and it stays.

| | file:line | string | class |
|---|---|---|---|
| | `:83` `:113` | "Restore" / "wins in this backup" | F |
| | `:121` `:123` `:124` `:130`–`:133` | the seven summary facts | F |
| | `:181` `:187` | "None" / "N, N restorable" | F |
| | `:139` `:145` `:152` | the three plan lines | F |
| ✂9 | `:160` | "Restoring only adds. Nothing already on this phone is deleted or changed." | G |
| | `:170` `:174` | "Everything in this backup is already on this phone." / "Add N wins" | F A |
| | `:195` `:209` `:216`–`:222` | the report | F |
| ✂16-adj | `:224` | "Wins untouched" / "everything you already had" | F / E |
| | `:232` `:237` `:243` `:355` | "Done" / "This backup can't be read" / "Close" / "Done"/"Cancel" | A F |
| | `:396` `:421` | two failure messages | G |
| | `BackupArchive.swift:153`–`:156`, `:239`–`:255` | twelve error messages, **one of which carries the em dash (`:251`)** | G |
| | `BackupRestore.swift:113` `:287` `:334` `:360` `:407` | five restore problems | G |
| | `BackupExport.swift:22` | "Strata Backup <date>" (the file's name) | F |

On `:224`: the value `"everything you already had"` is an Explanation in a column
of numbers — every other `fact(` on the report takes a count. A row whose value
is a sentence is a row that does not belong in a table of facts; either give it a
number or drop the row, since "untouched" is the default the whole screen has
been promising.

### 19. Store unavailable
Four strings, 49 words. One trim (✂16), 17 words. The screen that has to be
right when nothing else is.

| | file:line | string | class |
|---|---|---|---|
| | `SharedModelContainer.swift:352` | "Strata could not open your wins" | F |
| ✂16 | `SharedModelContainer.swift:353` | "Nothing has been deleted. Your wins are on this phone and Strata cannot read them right now, so it is showing you this instead of an empty tower." | G |
| | `SharedModelContainer.swift:354` | "Still not opening. Close Strata from the app switcher, then open it again." | G |
| | `StoreUnavailableView.swift:112` | "Try Again" | A |

### 20. The widget
Ten strings, 29 words, **nothing to cut.** A widget has no screen around it to
carry context, so its copy is doing work the app's would not have to.

| | file:line | string | class |
|---|---|---|---|
| | `StrataWidget.swift:25` `:26` | "Today" / "Today's wins, and what they looked like." | F G |
| | `TowerWidgetView.swift:143` `:161` `:179` | "win"/"wins" / "Your first win goes here" / "Nothing yet today" / "today" | F G |
| | `TowerWidgetView.swift:204`–`:207` | "N day streak" / "Add one" / "Day one" / "N altogether" | F G |

### 21. Notifications
Six strings, 32 words. Two cuts (✂17), 16 words — both bodies.

| | file:line | string | class |
|---|---|---|---|
| | `DailyReminder.swift:25` `:26` | "Nothing on today's tower yet" / "Anything you finished counts." | F G |
| | `ReplayReminder.swift:57` | "Your week is ready" | F |
| ✂17 | `ReplayReminder.swift:57` | "Seven days of wins, stacked into one tower." | E |
| | `ReplayReminder.swift:58` | "<Month> is ready" | F |
| ✂17 | `ReplayReminder.swift:58` | "A month of wins, stacked into one tower." | E |

`DailyReminder`'s body stays. "Anything you finished counts." is the sentence the
brand doc was written around and it is not describing a component.

### 22. Siri, Shortcuts and Spotlight
Forty-two strings, 145 words. One cut (✂18). These are not screens — they are a
vocabulary iOS searches, and the duplication between `StrataShortcuts`'s three
phrasings of one intent is deliberate (it is how voice matching works).

| | file:line | string | class |
|---|---|---|---|
| | `LogWinIntent.swift:17` `:18` `:23` | "Log a Win" / "Add a win to today's tower." / "Name" / "What did you do?" | A G |
| | `LogWinIntent.swift:42` `:43` | "Logged <name>. That's 4 today." | F |
| | `LogWinIntent.swift:65` `:66` `:79` `:80` `:83` | "Today's Wins" and its answers | A G F |
| | `StrataShortcuts.swift:10`–`:23` | the six spoken phrases and two short titles | A |
| | `CategoryAppEnum.swift:6`–`:14` | "Category" and the six category names | G F |
| | `HabitEntity.swift:7` `:11` `:14` `:17` | "Win" / "Title" / "Category" / "Completed Today" | G |
| ✂18 | `HabitEntity.swift:32` | "A win in Strata" (Spotlight subtitle) | E |
| | `OpenHabitIntent.swift:4` `:6` | "Open Win" / "Win" | A G |
| | `StrataFocusFilter.swift:4` `:5` `:12` `:15` | "Filter Wins" / "Show only one kind of win during this Focus." / "Show Health wins" / "Show all wins" | A G F |
| | `SiriSnippetViews.swift:17` `:19` `:46` | "A win" / "The first on today's tower" / "and N more" | F |
| | `SharedModelContainer.swift:357` | the spoken store failure | G |
| | `ImageManager+Restore.swift:57` | "it is not a photograph Strata can open" | G |

---

## Appendix A — accessibility strings, excluded from the count

Sixty-nine strings across 27 files. **None of these is visible text**, and they
are allowed to be explicit — the whole point of them is to say out loud what the
screen says by being looked at. Removing a visible caption does not remove the
spoken one, and three of the cuts above rely on that:

- Cutting the Wins empty headline leaves `MainAppView.swift:2883`
  (*"Today's tower, 12 wins"*) untouched.
- Cutting the `MemoriesStill` tab labels leaves the real tab bar's
  `accessibilityLabel("Wins")` / `("Camera")` / `("Memories")`
  (`MainAppView.swift:612`, `:636`, `:642`) untouched — they are already the
  only place those words live on the shipping screen.
- Cutting `AddWinSheet.swift:509` leaves `:549`
  (*"Add a photo" / "Replace the photo"*) untouched.

The fuller set, by file: `ReplayView` 10 · `HeadSticker` 6 (including three
`accessibilityAction(named:)`) · `HeadMakerView` 5 · `PlanSheet` 4 ·
`MemoriesMapView` 4 · `CameraView` 4 · `MainAppView` 4 · `ProfileView` 3 ·
`PhotoViewer` 3 · `AddWinSheet` 3 · `SettingsView` 2 · `OnboardingView` 2 ·
`NextSlotButton` 2 · `MonthTowerView` 2 · `MonthCalendarView` 2 ·
`MemoriesShelf` 2 · and one each in `StrataMark`, `StoreUnavailableView`,
`ProfileAvatar`, `PlanItemDetailSheet`, `PhotoGalleryGrid`, `MonthReplayRow`,
`HeadMarker`, `CachedImageView`, `AlbumCarousel`, `Replay`, `TowerWidgetView`.

Two spoken-only strings worth knowing about, because they are copy somebody
wrote and nobody can see:
- `AllClearCelebration.swift:123` — *"Every win logged today."*, posted as a
  `UIAccessibility` announcement because the celebration is particles with
  nothing to read.
- `ReplayPeriod.spokenRange` / `Replay.swift:87` — *"Your week, 7 to 13
  September. 31 wins."* This is the one place "Your week" is still said, and it
  is correct there: VoiceOver reads "9/7-9/13" as slashes.

---

## Appendix B — what was not in scope

- **`StrataTests/`, `StrataUITests/`, `tools/`, `ci_scripts/`** — test fixtures
  and scripts, no user reads them.
- **`DebugHarness`, `PerfProbe`, `HeadTrace`, `StoreSyncStatus`,
  `StoreMigrationCheck`, `StoreDedupe`, `StoreStamp`,
  `StoreAddedFieldsCheck`** — about 120 `NSLog` and `Logger` strings behind
  `#if DEBUG` or on the console only. The em-dash sweep covered them anyway; the
  one hit (`DebugHarness.swift:615`) needs no action.
- **`ZipArchiveReader`'s low-level failures** (`:115`, `:134`, `:144`, `:167`,
  `:228`, `:262`) are counted only where `BackupArchive` wraps them into an
  alert. The raw ones name byte offsets and compression methods; they reach a
  person only as the `(detail)` inside a wrapped message, which is already in
  the count.
- **`Info.plist` usage descriptions.** They are user-facing, they belong in a
  copy audit, and they could not be read from this checkout without building —
  `CLAUDE.md` is explicit that the keys are duplicated across both build
  configurations and must be read out of the **built** plists, not the source.
  **Not done, and the one gap in this pass.** Someone with a build should check
  `NSCameraUsageDescription` and `NSLocationWhenInUseUsageDescription` in both
  configurations against the voice rules — they are exactly the strings most
  likely to read as surveillance, and `CLAUDE.md` records that the app has
  already shipped usage descriptions for resources it did not use.
