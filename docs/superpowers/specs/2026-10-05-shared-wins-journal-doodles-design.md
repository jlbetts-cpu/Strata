# Shared wins, the day's journal, and doodles

The owner approved all three on 2026-10-05, from the research passes recorded
below. Every rule in CLAUDE.md (Strata) applies: minimal, airy, no long
dashes, no wording that sounds like watching, and the motion and type gates
in the test suite.

## 1. Shared wins ("with Sam")

**Why.** People who remember an event together recall it more positively
(Maswood, Rasmussen and Rajaram, 2019). Instagram and Facebook both offer tag
review, and untagging after the fact is not enough control (Besmer and
Lipford, CHI 2010).

**Tagging.**
- On the Add Win sheet, a quiet **"With…"** row sits under the crew chips. It
  shows only when the win is going to at least one crew.
- It lists the people in the chosen crews (never your contacts) and lets you
  pick up to 3.
- It saves into the shared win's `withPeople` field: comma-separated profile
  ids. The field is already in the development schema.

**What the tagged person sees.**
- When their phone first sees a crew win that tags them, it asks once, with
  a system alert: **"Sam added you to a win"**, the message "Morning run.
  Keep it on your tower too?", and two buttons, **Keep** and **Not This One**.
- Saying no is silent; the tagger is never told.
- Answers are remembered on the phone, keyed by win id.

**Keeping a win.**
- **Keep** writes a copy into the tagged person's own record through the
  app's normal logging path. The copy has the same title, colour and size,
  the win's own date, and the photograph if the phone has it.
- It counts toward their tower and streak like any win.
- The copy is theirs: the tagger editing or withdrawing the original later
  does not touch it.

**On the crew tower.** The block's sender line reads "Sam with Ana".
Stacked heads on the block are a later step.

**Safety.**
- A tag of someone you have blocked, or from someone who blocked you, is
  ignored.
- Removing someone from a crew drops them from its tags.
- Under-13 phones never see crews anyway. A phone with no age shared can
  still be tagged and keep, because a tag carries no new text or image.

**Copy.**
- Under the row: "They'll be asked if they want to keep it too."
- In the privacy policy: "Tag someone and they are asked whether to keep a
  copy; only your crew sees who a win was with."

## 2. The day's journal

**Why.** Expressive writing helps, but modestly (d ≈ 0.15 across 146 trials).
Once a week beat three times a week (Lyubomirsky, Sheldon and Schkade, 2005),
so the journal is always available and never asked for: **no streak, no
reminder**. Day One's follow-up questions read as an interview and were
turned off, and AI summaries read as bloat, so the helper asks and never
writes.

**Storage.**
- Each entry is a `MoodLog`, one per `dateString`. The model is unused, is
  already in the CloudKit schema, and syncs through the private database, so
  no new schema is needed.
  - `note` holds the text.
  - `videoURL` (dead) holds the day's emoji, behind a computed `symbol`.
  - `imageURL` (dead) holds the sketch's file name, behind a computed
    `sketchFileName`.
  - `mood` and `motivation` are not used.
- Notes never go into crew records.

**Entry points.**
- **Wins tab:** a glass journal button beside the Plan button at the top
  right (SF Symbol `book.closed`, or `book.closed.fill` when today has a
  note).
- **A past day** (Memories, then a day): the top-right corner opens that
  day's note, with the same icon rule.

**The sheet.**
- It is the Plan sheet's shape: a large detent and the same chrome.
- The title is the day ("Today", "Sunday 5 October").
- Beside the title is the **emoji slot**: a dashed circle that opens the
  system emoji keyboard. It is the day's *symbol*, not a mood score, so it
  carries no scale and no chart.
- Then a plain text editor with the placeholder "What happened today?"
- **Sketch**:
  - A pen button opens a sketch strip inside the note: one pen in ink, an
    undo, and nothing else, so there is no tool picker.
  - It is drawn with PencilKit and saved as a PNG beside the photographs.
  - The finished sketch shows under the text, and a tap edits it.
- **Suggest**:
  - It sits at the bottom, as on the Plan sheet.
  - It asks **one question** about one of the day's actual wins, under 12
    words, generated on device (Foundation Models) from the day's win
    titles. For example: "What made the early run happen?"
  - The question appears as the editor's placeholder and inserts nothing.
    Tap again for another.
  - With no model or no wins, it falls back to a short fixed list in the
    5 Minute Journal style ("What made today good?").

**The calendar.** A day with an emoji shows it small in the corner of its
cell, like a reaction badge on a post.

**Lock.**
- Settings has a "Lock Journal" switch, off by default, using Face ID or the
  passcode (LocalAuthentication). It is asked once per app session before a
  note opens.

**Do not build:**
- journaling streaks or reminders
- AI summaries
- mood charts or a "Year in Pixels" view
- sharing notes with crews
- templates
- a tool picker

## 3. Doodles

**In the journal**, as above.

**As a crew reply.**
- The Reply alert gains a sibling: **Doodle**. It opens the same one-pen
  sketch strip in a small sheet, with Send.
- The doodle is a PNG (1080 px longest edge at most, about 100 KB), carried
  on the reaction record's new `sketch` asset.
- Like a reply, the win's owner (and you) see it, and it clears when the
  crew's day ends.
- It passes the same photo safety check as crew photos before it is sent
  (`CrewSafety.photoIsFine`), and the receiving phone checks it again.
- It can be reported.
- Off for an age not shared, as replies are.
- **Schema:** `Reaction.sketch ASSET`, added to the development schema with
  `tools/cloudkit/add-crews-schema.sh`. Production needs the owner's Deploy.

## Order

1. Shared wins.
2. The journal, without the sketch.
3. The sketch strip, used by both the journal and doodle replies.

Each part ships on its own with its tests.

## 4. Your own month drawing (approved 2026-10-05)

**Why it is shaped this way.**
- Lock Screen editing by long press alone had no affordance, and Apple added
  a Settings path in iOS 16.1.
- NN/g: hidden gestures need clues and another way to do the action.
- Meta's Animated Drawings needs a humanoid rig and a server.
- Image Playground replaces your lines.

**Entry.**
- A long press on the month drawing opens a system context menu: "Draw Your
  Own", and "Use Original" once a custom drawing exists. There is no edit
  button.
- A TipKit tip appears once, on about the third visit after the drawing has
  played, and is invalidated on first use.
- The same action also sits in Settings.

**The ink canvas (`InkCanvas`).**
- PencilKit, `drawingPolicy = .anyInput`.
- One black `.monoline` pen at the house width, an eraser toggle and undo.
  There is no `PKToolPicker`.
- Export it under a light trait, so the ink stays black.
- The same component serves the journal sketch and doodle replies.

**The editor.**
- A full-screen sheet with a canvas at the month art's aspect ratio, and
  Cancel and Done.
- One switch, "Bring It to Life", on by default.

**The animation.**
- **Draw-on:** the saved `PKDrawing`'s strokes replay in order along their
  interpolated points. It is time-compressed to about 1.8 s, with a cap per
  stroke.
- **Settle:** then one gentle sway of the whole drawing, using the existing
  `IllustrationMotion` springs.
- **Boil:** a light boil (2 to 3 jittered frames) only while it draws, never
  at rest.
- **When:** once on appear and again on tap, like the scarecrow. It never
  loops.
- **Reduce Motion:** a short fade only.

**Storage.**
- One file per calendar month (`2026-10`): the `PKDrawing` data plus a
  cached template PNG, beside the photographs.
- A month with no file shows the default drawing. "Use Original" deletes the
  file, and the default is never touched.

**Do not:**
- AI restyling
- a colour picker
- an idle loop
- an edit mode straight from the hold
- edit chrome on the calendar
