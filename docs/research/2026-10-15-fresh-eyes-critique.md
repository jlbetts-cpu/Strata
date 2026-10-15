# Fresh-eyes critique, 2026-10-15

A senior product designer's first pass over 25 screenshots (light and dark),
read against `docs/ten.md`, `docs/voice.md`, `docs/screens.md` and the decision
notes in the code. Things already settled are left alone: the tower lattice,
the slot's pane and hairline, white block titles, one title size with honest
truncation (no scale factor), Quick/Regular/Deep, dark on dark, the chat
sheet's "Today" title, the Plan for Later chip, the version plate, past-tense
Your Three. Fixture artifacts (letter circles, "Sam", identical timestamps,
photo captions that do not match the photo, the Crew Alerts debug block) are
ignored.

Effort: S is under an hour, M is an afternoon, L is more.

---

## Per screen

### Wins tower (tour-wins, tour-crews, dark-tour-wins, dark-tour-crews)

Works: the tower reads instantly as "my day, stacked". Colour, size and photos
carry the meaning with almost no chrome. The tab bar is calm. The crest sits
where the eye lands first.

Issues:
- **The crest caption reads "14/3".** Past the goal, a fraction where the top
  beats the bottom reads as a date (14 March) or a broken count. And the ring,
  split into fourteen segments, looks dashed, which reads as loading or
  incomplete, the opposite of "full past the goal" (`GoalRing.swift`,
  `GoalRingStroke.segments` and `CrestCaption(text: "\(shown)/\(goal)")`).
  Smallest fix: once `wins >= goal`, draw one unbroken ring and show the count
  alone ("14"). This keeps the settled rule (only fills, count keeps going).
- **Dark mode: a flat light hairline runs across the top of the tower's
  highest row** (above "Wrote it down" on Wins; above Walk, Inbox zero and
  Sketch in the 3-win state; above Journal, the slot and Morning run on the
  crew). It is square-ended and overruns the blocks' rounded corners into the
  gutter, so it reads as a render seam, not a rim. Not visible in light.
  Likely the roofline or a row-level rim (`TowerBlocks.swift`,
  `BlockChrome.swift`, or the companion's roof in `TowerCompanionLayer.swift`);
  confirm in the view debugger.
- **One-cell blocks truncate the person's own words**: "Cooked...", "Read a
  c...", "Ten minu...", "Called M...", "Read 20...". The size rule is settled,
  but `.lineLimit(rowSpan > 1 ? 2 : 1)` in `BlockContent.swift` gives a 1x1
  block one line even though it has ~86pt of height and the title sits at the
  foot. Allowing two lines on every block removes most ellipses with no size
  change and no scale factor.
- **The top-right glyph (`text.alignleft`, the Journal) reads as a hamburger
  menu.** A newcomer will expect navigation, not "write about today"
  (`DaySheet.swift`, `JournalIcon.name`). A page or book glyph says journal.
- With 3 wins (tour-crews) the top 40% of the screen is a blank band above
  the lattice. The lattice is settled; noting only that the first screen a new
  person sees is mostly empty, which the onboarding's first win will cover.

### Edit a win (tour-block, dark-tour-block)

Works: clear sheet layout, Cancel/Edit/Save, red Delete at the foot (rule 3).
The size bar is the shared glass control.

Issues:
- **The right tile is a grey square with a photo glyph and no word.** It is
  "Show today's photos" (`AddWinSheet.swift`, `askTile`), but nothing says
  so; it reads as a disabled placeholder. Smallest fix: a one-line caption
  under the glyph ("Today's Photos").
- **Colour cannot be found.** It lives in the block's press menu, which nothing
  on the sheet hints at. A first-timer who wants a different colour has no
  visible path.
- The bottom 40% of a full-height sheet is empty below Delete. A medium detent,
  or the note field growing into that space, would make it feel designed.
- "Walk" is bold with no field cue; that it can be renamed is not obvious.

### Add a win (add-win)

Works: "What did you do?" is the right question in the right voice; ideas over
the keyboard are a strong ADHD affordance.

Issues:
- **The keyboard's idea bar sits on top of the photo blocks**, cutting the pink
  block in half and hiding the colour row entirely. Because the bar is glass,
  the pink block refracts through it and the first chip ("Drank some water")
  looks selected when it is not. Smallest fix: give the scroll content a
  bottom inset equal to keyboard plus bar so the block row lifts clear when the
  field is focused.
- The last chip is clipped mid-word ("Replied"); the edge fade is too short to
  read as "scrolls".

### Plan (tour-plan, plan, dark-tour-plan)

Works: Your Three pinned on top is a lovely idea; the day strip and composer
are clean; the checkbox in a category colour is the one spot of warmth.

Issues:
- **The second group has no label.** After YOUR THREE comes a ~60pt gap and
  five more lines with nothing saying what they are. Either a matching section
  label ("Today") or close the gap so it reads as one list
  (`PlanLines.swift`).
- **"Mon" is clipped by the repeat button** at the end of the day strip
  (tour-plan, dark-tour-plan). Either fade the strip's trailing edge or give it
  room (`PlanScope.swift`).
- Past-tense Your Three ("Drank some water") beside imperative plan lines
  ("Call the landlord") reads as two voices in one list. Settled as a choice;
  the section's footer line ("Small enough for your hardest day...") is what
  explains it, and it is not visible here.

### Crews list (crews-list)

Works: the Today row of heads is the best social moment in the app; rings in
the friend's newest win colour are a delightful, wordless signal. Rows are
Messages-familiar.

Issues:
- **Half the screen is empty below three rows, and the only way to start a crew
  is `square.and.pencil` in the corner**, which every iPhone user reads as "new
  message". A quiet "New Crew" row or the invite card at the foot of the list
  would make the social loop findable (`CrewsListView.swift`).
- The unread dot is solid black and sits outside the 16pt margin; it reads as a
  list bullet more than "new". Smaller, or in the Social coral the
  notifications already use.
- The Today row runs into the right edge with no gutter; fine as a scroll cue,
  but the last ring is sliced.

### Crew tower and chat (tour-crew, crew-chat-rest, crew-chat-reading, reply, dark-tour-crew)

Works: the chat resting at the foot is a genuinely good pattern; "Quiet here.
Yet. Today's chat clears at midnight." is the voice at its best. Reactions on
blocks are legible.

Issues:
- **Back button reads "‹ 1"**: an unread count with no noun. In Messages the
  number sits beside a word; alone it looks like a page number.
- **The crew face cluster is crammed**: three faces overlap and are clipped by
  the glass disc (tour-crew), and with four letters (crew-chat-rest) it is a
  bunch of balloons. Two faces max, plus a count, reads cleaner
  (`CrewFaces.swift`).
- **Reply composer (reply)**: the quote "↪ Shipped it ×" floats with no
  container, indented to x≈190 while the chips above start at the margin and
  the field below starts at the + button. Put the quote inside the field's
  capsule as a top line, as Messages does (`CrewChatSheet.swift`).
- Starter chips ("How did it go?") are semibold, heavier than any message, so
  they shout over the thread. Regular weight at the chip size.
- Emoji reactions on photo blocks sit directly on busy photos (the clap on
  "Read 20..."); a tiny glass disc behind the emoji would keep it legible.

### Memories, your profile (memories-profile)

Works: head, name and three numbers is the right profile; the streak line is
honest and small.

Issues:
- **The page is titled "October" but its first subject is you.** The month
  belongs to the calendar below. Move the month label down to the calendar
  section; leave the header untitled or the person's name
  (`MemoriesView.swift`).
- Empty calendar days are identical filled grey tiles; they look like 31
  pressable buttons. Plain numerals for empty days and a tile only where there
  is a win would make "15" sing (`MonthCalendarView.swift`).
- The month drawing peeks out from behind the tab bar at rest, reading as a
  smudge, not an illustration. Either it is fully above the bar or fully below
  the fold.
- "1 day in a row" sits 8pt under "Wins" and reads as Wins' caption.

### Your Score (your-score)

Works: the arithmetic table is honest and teaches the size system in one
glance. "A day off a week won't break it." is excellent.

Issues: a large empty band between the title and the 9; the score could sit
higher. Minor.

### Edit Profile (tour-profile, dark-tour-profile)

Works: plain, kind copy ("kept on this phone and never sent").

Issues:
- The name is a bare centred TextField with no edit cue.
- The Make Your Head row is a capsule and the Earlier Heads card is a rounded
  rectangle: two shapes stacked on one page.
- Earlier heads sit in grey square tiles, left-aligned with dead space right.
  Heads are identity; let them stand free on the card, centred.
- The smiley glyph is outlined in light and filled in dark (`ProfileView.swift`,
  `SettingsIcon(systemName: "face.smiling")`). One rendering.

### Settings (tour-settings, dark-tour-settings)

Works: grouped inset list, icons in one weight, plain labels.

Issues:
- **Dark mode switches: the on track is warm grey, close in value to the off
  track**, so on and off are told apart only by the knob's side. In light, on
  is near-black and unmistakable. Raise the dark on-track to at least 3:1
  against the off-track within dark-on-dark (`SwitchTrack.swift`).

### Replay (tour-replay, dark-tour-replay)

Works: the tower building itself with real photos is the most shareable thing
in the app.

Issues:
- **Falling blocks pass over the count-up header and the status bar**: "11
  wins" is half-covered by "Stretch" in dark and fully covered in light. The
  header should sit above the blocks' layer, or blocks enter below it
  (`ReplayView.swift`).

### A past day, empty (tour-day, dark-tour-day)

Works: says what is so.

Issues: the title is a left-aligned large title, unlike every centred title
elsewhere; the line is a bold headline used as body text; no drawing; the
rest of the screen is void. The code notes it is barely reachable, so low
priority (`DayAlbumDetailView.swift`). Voice-wise, "Nothing logged this day."
could take the one warm beat voice.md allows ("A quiet day. Those count too.").

---

## Ranked top 15, by impact on first impressions

| # | Issue | Smallest fix | Effort | File |
|---|---|---|---|---|
| 1 | Crest reads "14/3" with a dashed-looking ring past the goal | Past the goal: one solid ring, count alone | S | `Views/GoalRing.swift` |
| 2 | Dark: square hairline seam across the top row of the tower | Find and clip or remove the row-level line | S-M | `Views/TowerBlocks.swift` / `Views/BlockChrome.swift` |
| 3 | 1x1 block titles truncate the person's words | Two lines on every block, same size | S | `Views/BlockContent.swift` |
| 4 | Replay blocks cover the "11 wins" header | Header above the block layer | S | `Views/ReplayView.swift` |
| 5 | Journal glyph reads as a hamburger menu | A page or book glyph | S | `Views/DaySheet.swift` (`JournalIcon`) |
| 6 | Add: idea bar covers the photo blocks, first chip looks selected | Bottom inset so blocks clear keyboard plus bar | M | `Views/AddWinSheet.swift` |
| 7 | Crews: no visible way to start a crew, half-empty page | "New Crew" row or invite card at list foot | S | `Views/Crews/CrewsListView.swift` |
| 8 | Memories titled "October" over the profile; empty days look like buttons | Month label to the calendar; numerals only on empty days | M | `Views/MemoriesView.swift`, `Views/MonthCalendarView.swift` |
| 9 | Edit: unlabeled "today's photos" tile, colour hidden | Caption on the tile; a hint the block holds colour | S | `Views/AddWinSheet.swift` (`askTile`) |
| 10 | Chat reply quote floats uncontained and misaligned | Quote inside the field capsule | S | `Views/Crews/CrewChatSheet.swift` |
| 11 | Plan: unlabeled second group; "Mon" clipped | Section label or close the gap; edge fade | S | `Views/PlanLines.swift`, `Views/PlanScope.swift` |
| 12 | Dark switches: on and off too close | Raise on-track contrast to 3:1 | S | `Views/SwitchTrack.swift` |
| 13 | Crew header: "‹ 1" and crammed face cluster | Drop the bare count; two faces plus count | S | `Views/Crews/CrewTowerView.swift`, `Views/Crews/CrewFaces.swift` |
| 14 | Edit Profile: two shapes, boxed heads, smiley differs by mode, name has no cue | One shape; free-standing heads; one glyph | S | `Views/ProfileView.swift`, `Views/EarlierHeads.swift` |
| 15 | Empty past day: off-pattern title, bold body, void | Centred title, body weight, one warm line | S | `Views/DayAlbumDetailView.swift` |
