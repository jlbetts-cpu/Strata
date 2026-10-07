# What is settled, what has a range, and what is open

Written 2026-10-02, from a video the owner sent about keeping a `design.md` so
that an agent builds his taste rather than a competent average. Its one
structural idea is the thing this project did not have: **separate the decisions
that are final from the ones that are open to interpretation.**

Everything in this repository already records WHY. Nothing recorded **whether it
may be reopened**, and the cost of that is measurable. In one evening:

- The Plan sheet's empty state was recomposed onto the golden section, which
  moved the invitation 420pt away from where the first line lands. The owner had
  to say "it was supposed to show the bullet point."
- The heading weight was taken to Semibold and stopped there on my judgement
  after he had asked for thicker. He had to say "why no bold i mean thats what I
  asked."
- Earlier passes reopened the white block labels and the 8pt corner radius, both
  of which he had already settled, and both had to be reverted.

Each time the information needed to prevent it was in the repository, in a
comment, somewhere. **This file is the index of what cannot be changed without
asking**, so that the reasoning stays where it is and the permission does not
have to be hunted for.

---

## How to read it

| | What it means | What to do |
|---|---|---|
| **LOCKED** | The owner decided it, usually after seeing it both ways. Several were decided AGAINST a measurement. | Do not change it. Do not re-propose it. If new evidence genuinely bears on it, say so in one line and let him answer. |
| **GUIDED** | A rule with a number and a range. The number is argued; the next value inside the range is a judgement call. | Work inside it. Moving the number needs a measurement and a note at the site. |
| **OPEN** | Not decided, or waiting on something he is making. | Propose freely. Render alternatives rather than picking one. |

**A measurement does not promote a LOCKED item.** Four of the entries below are
there precisely because he overruled a measurement, and he was right about what
the measurement was for every time: the white labels measured worse and read
better; the corner radius measured inconsistent and looked right.

---

## LOCKED

Each line carries the date and, where there is one, his own words.

### The app's shape

| Decision | When | His words, or the record |
|---|---|---|
| Three tabs: Wins, Camera, Memories | settled | — |
| The app opens on the **camera** | settled | "logging a win is meant to be the fastest thing in the app" |
| The tab bar is **his drawn icons with SF Pro labels under them**, idle tabs grey (Luma's way) | 2026-10-06 | reverses "icons only" (2026-10-01); his call after seeing Luma |
| **His drawn icons where you draw, SF Symbols where you navigate.** Drawn: the ink row's eraser (filled when on), undo and sticker, the day's sticker corner, the six category chips (`Doodle`, `docs/icons/slice_icons.py`). SF: back, close, share, trash, send, everything a glance must recognise. **A drawing never sits in a row beside a symbol** (why the strip booth's pencil, the composer's pencil and the sticker picker's Emoji stay SF). Settings, Profile and the month drawing rows have **no glyphs at all** | 2026-10-06 / 07 | "less is so much more to me"; "make sure the icons still look clean and premium" |
| The greys are **one warm family** in the idle tab's hue (`inkSecondary`/`inkTertiary`/`inkQuiet`, opaque) | 2026-10-06 | his pick, "Same warm grey family" |
| Profile lives on **Memories only**, never on Wins | settled | "the tower is today's record and its corner belongs to today" |
| **Replays live in Memories.** The week moved there with the month | 2026-10-01 | "the your month doesnt belong on the wins because its already in memories" |
| ~~The Wins top-left corner holds the **Crews button**~~ **MOVED 2026-10-05: the day's page is ONE glass button top LEFT, `checklist` (`DayIcon`), Crews stands alone top RIGHT** with its unread dot, the only dot on the header. It was a Journal and Plan glass pair for the morning of 2026-10-05, until the two became one page. Empty right corner while the Crews flag is off. Why the right: the HIG's trailing end is for what must stay available; Instagram and Strava put chat and notification entry points top right; a right thumb reaches top right more easily (Hoober). `WinsBatchTests.headerOrder`, `DaySheetTests.oneHeaderButton` | 2026-10-02, moved 2026-10-05 | "I want there to be a simple social button on the top left"; then the approved batch of 2026-10-05; `checklist` is his pick for the one button |
| ~~**The plan and the journal are one page for the day**~~ **REVISED the same evening: ONE SHEET WITH TWO TABS, Plan and Journal** (`DaySheet`). Still one button on Wins. Under the title, two plain words, centred: the chosen one in `inkPrimary` at the heading weight, the other `inkTertiary`; no capsule, no glass, no segmented control; a cross-fade (`crossFade`) and a light haptic; 44pt each; a tab bar to VoiceOver. **Plan** is the Plan screen as it was (`PlanLines`, "Add to the plan", its own Suggest, `PlanSuggestionsView`), top left empty. **Journal** is the journal as it was: the emoji's glass top left, the note, the faded question, the sketch under the note, its own Suggest and the pen. `SuggestTarget` is gone. **From Wins it opens on the tab used last** (`@AppStorage` `DayTabs.defaultsKey`, default Plan). **A past day is the Journal alone, no switch** (`DayTabSet.pastDay`): the model keeps no past plan (`PlanItem.sweep`). **Lock Journal asks when the Journal is chosen**; refused on the way in, the sheet opens on the Plan, which never asks. **The plan never reaches the saved entry** (`MoodLog.note` is the note alone). `DaySheetTests` | 2026-10-05 | merged: "the plan and journal screen could probably be merged... the plan stuff obviously wouldnt show up in the final journal entry"; then, on seeing it, "everything looks a bit weird", and he chose two tabs |
| **A sketch is drawn full screen**, the month editor's experience (`JournalSketchEditor`: 2:3 canvas, Cancel and Done), and shown under the note with a whole canvas fitted to 240pt (`JournalSketches.shownHeight`) | 2026-10-05 | "wish it could be a little bigger canvas for the journal like it is in the month" |
| **The pen is 1.5pt as seen**, everywhere (`InkPen.width`): his own drawings measured 1.3 (October) to 1.7pt (Crews). The editors scale it to where the drawing is shown. Calibration re-measured the same day: the line is 2.0x the tool | 2026-10-05 | a thinner pen everywhere |
| **No search** in Memories. It had one and it went | settled | — |
| No Today tab, no checklist, no badge on a tab | settled | — |

### Settled the morning of 2026-10-02

Each chosen from two renderings in `docs/design-review/`, put to him with the
measurement beside it.

| Decision | When | His words, or the record |
|---|---|---|
| Edit sheet's Delete is the kit's **red word**, not the native pill | 2026-10-02 | "Red word"; the pill measured 3.96:1 in dark, the word 5.73:1 (`block-card-delete-paths.png`) |
| A replay's block titles **fade out by the time the week comes to rest** | 2026-10-02 | "Fade them"; at rest they drew at about 7.5pt (`replay-titles-paths.png`) |
| Calendar day numerals **never below 15pt** | 2026-10-02 | "Raise to 15"; they were 7.9pt (`memories-numeral-15.png`) |
| Album card titles **wrap to two lines** rather than truncate | 2026-10-02 | "Wrap to two lines"; one line drew "Read a cha…" (`memories-album-options.png`) |
| Onboarding's map page draws **the map as it is now**: back disc, no title | 2026-10-02 | "Redraw it"; it drew the map as the Memories tab, which it stopped being on 2026-09-30 |
| A past day's lattice is **its tower plus one row** | 2026-10-02 | "Tower plus one row"; nothing lands on a past day |
| **The journal's mark**: an emoji day shows the emoji and nothing extra; a day with a note and no emoji shows a tiny ink dot where the emoji would sit; a past day's journal button stays hollow and gets the same dot. Hidden while Lock Journal is locked (`JournalMark`) | 2026-10-05 | his exact rule, in the approved batch |
| **Onboarding ends on the first win**: after the thank you, the tower's real slot with five examples ("Made the bed", "Drank water", "Replied to that email", "Went outside", "Called someone"); one tap logs it through `QuickWinService.logWin` and the app opens on Wins. It replaces the "Welcome" block (`OnboardingFirstWin`) | 2026-10-05 | approved in the batch |
| The head maker **switches to the light page** for its preview | 2026-10-02 | "Keep the switch"; the head is shown where it will live |
| Profile's Done stays **the title's ink** | 2026-10-02 | "Leave it"; monochrome like every other sheet |
| Add and Edit **read from the top**: name, its controls, the block, air below. The block is not floored | 2026-10-02 | "why is the spacing that spaced out looks odd"; it was 64 under the name and 197 over the block |
| Tapping the **tower head plays a face**, the camera's twelve, never the same twice running | 2026-10-02 | "when you click on it it will change faces just like the camera" |
| ~~Dragging the tower head shows a **glass bubble directly left of the Plan button, its size**. Let go in it and he parks; tap it and it pops~~ **REVERSED 2026-10-05: no head bubble on the Wins header**, so he is never parked (`CompanionParking.hasDock`) | 2026-10-02, reversed 2026-10-05 | "make the glass button right next to the plan and be the same size on the left of the plan right next to it"; then "remove the head from the main home screen because i feel like it would make too many buttons there since we added the journal component" |

### Crews

| Decision | When | His words, or the record |
|---|---|---|
| The groups are called **Crews** ("New Crew", "Leave Crew") | 2026-10-02 | his answer, over Circles, Squads and Builds |
| A crew is up to **8 people, you included**; up to 5 crews each | 2026-10-02 | "up to 8 people I think fits the best"; 8 includes you, his answer |
| Crews are reached from a **glass button on Wins** (top right since 2026-10-05), then a list like Messages, then the crew's tower | 2026-10-02 | "a simple social button on the top left... when you click into a group it shows the shared tower" |
| **One invitation after your very first win**, as a quiet line under the Wins header ("Your win is up. Who else should see it?"), once more after your first reaction received, then never. Not to under-13s, not with Crews off. A line, not a glass card: the header already holds the screen's three glass controls (`FirstWinInvite`) | 2026-10-05 | his Apollo research, approved in the batch |
| A crew's **members sit top middle**, name in a capsule under them, like a Messages group | 2026-10-02 | "it will have the members on the top middle just like imessage" |
| **Anyone in a crew** renames it, changes its picture and invites; only who started it removes people or ends it | 2026-10-02 | his answer: "Everyone, like Messages" |
| **A notification for every friend's win**, grouped by crew, with Hide Alerts per crew | 2026-10-02 | "notifications work just the same as on imessages" |
| Everyone's **heads float in the crew tower**, and dropped into the top bubble they are **crammed** | 2026-10-02 | "it should actually look like they are cramped in there" |
| Friends' heads are **fully alive** (blinks, faces) | 2026-10-02 | his answer |
| **13+ with limits**: under 13 no crews, 13 to 15 no photos | 2026-10-02 | his answer |
| Tapping a crowded bubble **fans its heads out** at a full tap size; one tap lets one out; **Let Everyone Out** is press-and-hold only and releases them one at a time | 2026-10-02 | "I dont wanna click one thing and then accidently pop all the heads out... pop them out one by one" |
| **Everyone in a circle**: a head sits on the disc a profile photo fills | 2026-10-02 | his answer, from the research and the mock |
| **A crew's picture is a photo** (no colour or emoji choice), offered first when starting one and never required: a crew without one shows its people's faces | 2026-10-02 | "the groups should need to be a photo", then, testing it: "why do I have to name or do a pfp to add people" |
| The right of a crew's header is **+ Add a win here**, not Add People | 2026-10-02 | "change the add button on the right because its already in the menu" |
| A crew block with a photo opens **the same viewer a past day's block does** | 2026-10-02 | "clicking on a block should have the same effect as clicking on a previous day" |
| **Reactions**: double-tap a friend's block for ❤️; the Figma bar + 🔥 👑 ❤️ where a tap leads; one per person per win | 2026-10-02 | "adding a way to like it by double tapping the win with clear visual and animation"; the bar is his Apollo Figma frame 12839:5135 |
| **Mute a crew** for 1 hour, 8 hours, 1 week or until turned back on; reactions have their own switch | 2026-10-02 | "make sure there is a way to mute chats turn on notifications all the necessary things" |
| Inviting is the **system share sheet** as a collaboration, not a contact picker of ours | 2026-10-02 | his "invite people from your contacts", met by the platform's own sheet: contacts first, and Messages carries the invitation |
| **Tap any block: the day's carousel**, every win in it (a win with no photo is drawn as its block). Who reacted is ONE capsule there, folded until tapped; Report or Remove is in its ⋯. **Hold a friend's block: the reaction bar, and only that.** Double-tap is the quick ❤️. No win sheet. Your own reaction leads its block's badge on a brighter chip | 2026-10-02 | "i couldnt figure out how to react shouldnt it be when you hold on a block?"; "the report and who reacted can be like in the actual carosel menu doesnt need to be in the hold that should just be to react"; "what is this sheet like when would this be needed?" |
| The crews list row is **who, the latest win and when**: no count of wins | 2026-10-02 | "I dont like the big number of wins outside the chat... just remove it" |
| A crew tower works as Wins does: **the + slot** for a one-tap win into that crew, **the tab bar stays**, the **tap ripple** answers, and heads are **one size** (the Wins head, 0.88 of a cell) | 2026-10-03 | "where is the + block for the crew chats they should function pretty much the exact same like the bottom tabs should still be visible"; "the ripple taps dont go in the crew chats"; "the head should be the same size on the crew and normal" |
| **Heads per crew, on or off**, in the crew's details: off is only the wins, on this phone | 2026-10-03 | "a way to shut off the heads for individual crew chats" |
| **No lines in Crews**: rows and cards are told apart by space | 2026-10-03 | "we dont use lines we use space throughout the app" |
| **The launch is the logo, held and faded**: no roll through the colours | 2026-10-03 | "its a clean logo but the animation doesnt really fit the clean theme" |
| **The camera grid is off by default** | 2026-10-03 | "turn off the rule of third lines off by default" |
| **Memories has no title**: map and Profile in the corners, **the month in the middle, and the month governs the page**: its calendar, then only its photos, on the calendar's grid (margin, gap, a block's corner). The curated carousel and the empty-state sentence are gone | 2026-10-03 | "we dont use titles anywhere else"; "twenty different ways to show the same thing just feels lazy"; "if you are going to make the october picker dictate the page then it should actually dictate the page" |
| **The app is called Some Wins** ("somewins" for the domain and handles). Only what people read changes; bundle id, App Group and iCloud container stay | 2026-10-03 | "Okay lets rename everything with the Some Wins name" |
| **Crew rules, agreed once** before anything in Crews: four plain lines (own wins only; nothing hateful, sexual, violent or cruel; reports looked at within a day; block anyone) and I Agree | 2026-10-03 | his "Fix safety first", for App Review 1.2 |
| **Memories' month stands at the foot of the page**, as the tower does on Wins; the room above is for the owner's drawing of each month (`MonthOctober` etc. in the catalogue). **Swipe the calendar** for the next or last month. The recap is **a play button beside Profile**, not a section. A day opens with the standard push | 2026-10-03 | "put the calendar and stuff near the bottom so it balances with the wins page"; "swiping left and right on the calendar should also be a way of changing months"; "instead of a bulky section lets just add a play button" |
| **Memories' photos fold under the calendar**: one quiet "4 Photos" line, closed by default; open, the camera roll, edge to edge | 2026-10-03 | "make the photos dropdown so the calendar gets its air"; "it should look like that camera roll thing" |
| **The photo is what the viewfinder showed** (cropped to its shape), and **a face gets a little polish, live on the front camera and on the photo** (`FaceRetouch`): clearer skin, a touch less redness, a little soft light, rested and clear eyes. No reshaping, nothing anyone could point at | 2026-10-03 | "the viewfinder should be accurate"; "your skin is a bit clearer but its not noticable enough that you can be like omg filter" |
| **One head**: no "Add Another Head". A first head starts **on the map and on photos**; tower and profile picture are off | 2026-10-03 | "I like the intimacy of just making your head"; "show head on map and add my head to photos is on by default while let my head onto the tower and use as profile picture should not be" |
| **Today's crew chat** from a glass `bubble.left` top right of a crew, with a dot for lines you have not opened. Text and emoji to 280, cleared at the crew's midnight; Reply and Doodle on a win post into it quoting the win; alerts grouped, one a crew an hour. No read receipts | 2026-10-05 | his decisions of 2026-10-05, approved as a set |
| **React to a chat line**: hold a friend's line for the win's bar (+ 🔥 👑 ❤️) and your stickers in one still glass capsule; small chips under the line, a count when several chose one, yours on a deeper fill. One a person a line. Report and Block moved from the hold to the bar's ⋯. A line's reaction is a `Reaction` record on the line's id (no schema change); a sticker travels as the `sketch` asset at 256px, photo-checked both ways, never from 13 to 15 | 2026-10-06 | "make it so you can react to chat messages with stickers and emojis" |
| A crew on screen stays **live**: its zone is checked every 3 seconds, so a friend's reaction lands within seconds | 2026-10-02 | "make sure the reactions update immediately... on everyones end" |
| A crew's page carries a **crew streak** (days everyone posted), **the same Day / Week / Month chart as Profile**, and its **Days**, each one playable and saved as a video. Counts are kept on the phone; photos still leave the cloud after a few days | 2026-10-02 | "the photos shouldnt be saved on the cloud overnight but... stats... streak where everyone in the group posted a win and the bargraph... in that middle area"; "save the day... as a video like the month and week ones" |
| **Heads start in the bubble**: a crew opened for the first time, and a head just put on your tower, begin contained, and a tap lets them out | 2026-10-02 | "the floating heads those should be contained on first open... so the users know they can go there" |
| With no head of your own, a crew's details offer **Make Your Head** under its name, a glass pill, and nowhere else; it goes once you have one | 2026-10-02 | "one of my friends didnt even realize you could make a head at all" |
| An unnamed crew is named by its people; with no name in Sturdy, their **iCloud first name** | 2026-10-02 | "if there is no name the name should be like imessage where its the peoples names" |

### The blocks and the tower

| Decision | When | His words, or the record |
|---|---|---|
| **White labels on every block colour**, not dark | 2026-10-01 | "I much prefered the white ink look over the dark ink" — decided against a measurement showing dark at 6.00 to 9.77:1 and white at 1.71 to 2.70 |
| A single block's corner radius is **8**, beside a merged run at 12 | 2026-10-01 | "Leave it at 8" |
| The tower is **today only**. No week or month filter | settled | — |
| A block **falls** on a constant-acceleration curve, with no ease at the end | settled | "All masses fall the same, because they do" |
| `TowerLattice` is **1.03:1 on purpose** and is not darkened | refused twice | the instrument cannot see it; that is the point |

### Colour and type

| Decision | When | His words, or the record |
|---|---|---|
| **One accent: ink.** No blue anywhere | 2026-10-01 | "lets just do the basic"; `accentPrimary` deleted, zero call sites |
| **Headings are Bold**, prose is Medium | 2026-10-02 | "why no bold i mean thats what I asked" |
| **One face.** SF Pro, until he adds his own | settled | "I hate when there is like one type of font next to another" |
| **Nothing below 15pt**, except three sites with a measurement | 2026-10-01 | "no tiny thin font anywhere" |
| The calendar's empty days are **wells**, not bare numerals and not ground | 2026-10-01 | chosen from three renderings; no measurement could separate them |
| Saturated colour means **a win or a photograph**. Chrome is ink and light | settled | — |

### Copy and voice

| Decision | When | His words, or the record |
|---|---|---|
| **No em dash** in anything a person reads | settled | one was found in a backup alert on 2026-10-01 and fixed |
| **Nothing may read as the app watching the person** | settled | "It remembers where you were" was rejected; "Remember Places" became "Keep Places" |
| The replay says **nothing about itself**. No "Your week" over it | 2026-09-15 | "the words 'Your week' are the app talking about itself" |
| A replay's date range is **numeric**: "9/28-10/4" | 2026-09-15 | "7 to 13 September read as a sentence where a glance was wanted" |
| The album card **keeps its count** | 2026-10-01 | — |
| Settings keeps "Everything you log stays on this device" | 2026-10-01 | the one sentence that sells the product's spine |
| **Less text, always.** A component that explains itself loses its charm | 2026-10-01 | "I truely want a minimal and etheral experience ... a place of piece and space" |

### Layout

| Decision | When | His words, or the record |
|---|---|---|
| The plan's **invitation is row one**, where the first line lands (now the Plan tab of the day's sheet) | 2026-10-02 | "it was supposed to show the bullet point" |
| The plan **keeps its tail** under the list: one row deep since 2026-10-05, holding "Add to the plan" in faint ink (no dashed ghost, no hairlines between lines), collapsed on an empty day where row one already invites | 2026-10-01, reshaped 2026-10-05 | it is the tap-to-write space; "it should be more clean... more minimal" |
| **Lots of white space**, and it has to be doing something | 2026-10-02 | "the white space is an aid but make it make sense" |
| The page margin is **16** | measured | 24 takes 4pt off every block; the cell is load-bearing |

---

## GUIDED

A number, a reason, and the range it may move in.

| Rule | The number | The range | Where it lives |
|---|---|---|---|
| Spacing ladder | 8 / 12 / 16 / 24 / 32 / 64 | nothing between 32 and 64; the app had 25 distinct values in that gap | `GridConstants.gap*` |
| Type sizes | 34 / 17 / 15 | three, and a floor of 15 | `Typography.tier(_:)` |
| Type weights | Bold / Medium | two, 34.4% of stroke apart | `Typography.titleWeight`, `.bodyWeight` |
| Text contrast | 4.5:1 | against the ground it actually sits on, sampled | check 9 |
| Shape contrast | 3:1 | same | check 9 |
| **Structure ink** | 4 levels | nothing carrying information may sit under it, in any state | check 12 |
| Structure that scales with content | 8.2 levels bare, 3.3 full | crossing at 45% of the grid | `MonthCalendarCell.wellInk(filled:)` |
| Motion | 5 rungs plus 4 bounce rungs | 9 animations, against the 40 the app had | `docs/motion-audit.md` |
| Press | 3 rungs: glyph, word, surface | one component | `PressResponse` |
| Selection | **a ring on the chosen shape's own edge, and nothing moves** | two declared exemptions | `ColourSwatch` |
| Destructive ink | one red, 5.65:1 | — | `AppColors.destructiveInk` |
| Targets | 44pt, measured off the built screen | — | check 8 |

---

## OPEN

| Thing | Status |
|---|---|
| **The six illustrations** | He is drawing them. `docs/illustrations.md` has the rules, corrected 2026-10-01 after somebody finally opened heytea.com: they are **open line art, not filled silhouettes**. Rule 1 was describing their logo. |
| **A custom typeface** | He has said he will add one. `Typography.tier(_:)` and `StrataFont.relative` are the two lines it lands on. |
| **Tracking** | HEYTEA sets everything at +0.10 em; this app's only tracked token is 0.053. Worth trying on titles and measuring. Not applied. |
| **Widget interactivity** | He asked for it. The cost is the SwiftData schema in the extension, against the budget `WidgetSnapshot` exists to stay inside. Sized at `StrataWidget.swift`, not built. |
| **A URL scheme** | The app has none, so a widget tap cannot land on the tower. |
| **StandBy** | Never looked at. The widget has a photograph behind it and StandBy at night renders monochrome red. |
| **Personalisation by journey stage** | The one applicable idea from four videos that is entirely unbuilt. The honest shape here is the first week being allowed to look different from the fiftieth, which is a product decision. |
| **Lowercase headings** | HEYTEA is lowercase throughout. This app capitalises. His call, not a layout one. |

---

## The atomic kit: a rule is a type, not a paragraph

The video's second idea is that the file is worth much more when it points at the
real components. The mapping, so that "make it consistent" has an address:

| If you are about to draw | Use | Never |
|---|---|---|
| a block, or anything with a block's body | `BlockSurface`, `EtherealFill`, `BlockRim` | a `RoundedRectangle` with a gradient |
| a colour chip | `ColourSwatch`, `ColourSwatchRow` | a `Circle().fill` |
| a round glyph button | `GlassIconButton` | a glyph in a `Circle` |
| a capsule control | `glassCapsule` | a `Capsule()` |
| the primary action | `PrimaryCapsule` | a filled `Capsule` with a label |
| a press | `.buttonStyle(.press)` / `.pressWord` / `.pressSurface` | `.plain`, unless it wraps glass |
| a section heading | `SectionHeading`, `FormSectionLabel` | a `Text` with kerning |
| a sheet's confirm or cancel | `.sheetAction()` | a `Text` with a tint |
| an icon at a size | `.iconSize(_:relativeTo:)` with a `GridConstants.icon*` token | `.font(.system(size:))` |
| an empty day, slot or well | `AppColors.slotInk` at the state's ink | a grey fill |
| a count | the shared count readout | a `Text("\(n) wins")` |
| a destructive word | `AppColors.destructiveInk` | `warmRed`, which is a block's fill |
| a hairline | ink at `1 / displayScale` | `Divider` |

**The app has deleted five private re-implementations of things on this list** —
`CardPress`, `PosterPress`, `zoomGlass`, `SlotGlass`'s copy and `ColourSwatch`'s
— and `docs/consistency-audit.md` found eight more live when it was written. A
private copy is not a style choice, it is the thing this table exists to prevent.

---

## Where the rest of it is

- `CLAUDE.md` — the standards, the traps, and the long-form reasoning.
- `docs/screen-audit.md` — the twelve checks, and every screen graded out of 10.
- `docs/space.md` — the spacing research, with sources and what was discarded.
- `docs/consistency-audit.md` — eighteen drifts, and the count of how many ways
  the app says one thing.
- `docs/motion-audit.md` — 147 call sites, and the collapse to nine.
- `docs/copy-audit.md` — all 399 visible strings, classed.
- `docs/reference-board.md` — his Pinterest board, five videos, HEYTEA measured,
  and what Dribbble's "minimal" actually returns.
- `docs/illustrations.md` — what to draw and where it goes.
