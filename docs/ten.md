# What a 10 is

The owner, 2026-10-11: "keep editing till everything is a 10 and be very
specific what we define as a 10. The usability consistency needs to be a 10."

A 10 is not a feeling. It is nine rules, each with a way to check it, and a
count of the places that break it. **A screen is a 10 when that count is
zero for anything a person using it could notice. The app is a 10 when
every screen is.** A rule broken on purpose is written down beside the code
with the reason, and then it does not count.

## The nine rules

**1. One thing, one drawing.** Each kind of control is drawn by one shared
component, everywhere it appears: the filled action, the outlined action,
the round glass button, a sheet's Cancel and Done, the weekday chip, the
plan's box, the slot's pane, a switch, the colour row, the size control, a
writing bar, an empty state, a count.
*Check:* no view draws its own copy of one of these. Count of private
copies: 0.

**2. One action, one gesture.** A press opens or does the main thing. A
hold opens a menu, the system's. A swipe on a row removes it. Nothing else
means these things, and these mean nothing else.
*Check:* list every pressable thing with what press, hold and swipe do.
Exceptions: 0.

**3. One sheet, one layout.** Title in the middle. The way out on the
left: "Cancel" when leaving throws work away, a back arrow on a pushed
page. The confirming word on the right: "Done" when everything is already
kept, "Save" for an edit, "Add" for a new win, "Plan" for plan lines.
Nothing that deletes sits in the title row. Deleting is red, at the foot or
in a menu, and is either confirmed or can be undone.
*Check:* a table of every sheet with its left word, right word and where
delete lives. Exceptions: 0.

**4. One word per thing.** Win. Block. Tower. Slot. Plan. Crew. Memories.
Buttons in Title Case, sentences as sentences. No long dash. Nothing that
reads as being watched. Never "missed" or "overdue".
*Check:* search every string a person can read. Banned words: 0. Two words
for one thing: 0.

**5. Every press answers.** Everything pressable is at least 44 by 44
points, moves or dims under the finger, and gives one haptic from the
app's four (a tick for choosing, a light tap for opening or switching, a
success once per win, a warning for a refusal).
*Check:* targets under 44: 0. Controls with no answer to a press: 0.

**6. Both appearances.** Light on light, dark on dark. Nothing white in
dark except the main filled button. No drawn outline where glass should
lift. Words at 4.5 to 1 or better, glyphs at 3 to 1. Colour only from the
app's named inks.
*Check:* every screen looked at in both. Raw colours on chrome: 0.

**7. Type, space and shape from the ladder.** Fonts from the type tokens.
Gaps from the spacing tokens. Corners from the block's corner or a
capsule. No shadow on chrome.
*Check:* literals in views that are not a named exception: 0.

**8. Every state is drawn.** Empty, loading and failed each say what is so
and what to do, in the app's voice. Every sheet has a way out. Every
failure can be tried again. No dead end.
*Check:* each list and each save walked with nothing, with a wait, with a
failure.

**9. The same for a person who cannot see it.** Every control has a name.
A chosen thing says it is chosen. What a hold offers is offered to
VoiceOver too.
*Check:* controls with no name: 0.

## Written exceptions

These look like breaks and are decisions. Each is the owner's, or follows
what iPhone's own apps do.

- **You log a win; the sheet's button says Add.** "Log" is the act (Siri,
  the widget, the slot's name for VoiceOver, "Nothing logged this day").
  "Add" is the word on the sheet that does it, and "Win added" after.
- **Delete and Remove are two words on purpose.** Delete: the thing is
  gone (a win, a plan line, a sticker, your head). Remove: it comes off
  something that stays (a photo off a win, a win off a crew, a sketch off a
  note).
- **The slot is the one place a hold does the main thing.** A press opens
  Add; a hold, or drawing it out, logs the win. It is the app's signature
  gesture and it offers Undo.
- **A hold on a crew's block or a chat line opens the reaction bar**, not
  the system's menu (the owner, 2026-10-02 to 06).
- **A crew's row swipes to Mute as well as Leave**, as Messages does; the
  hold menu offers the same two.
- **A drawing editor says Done, not Save.** It hands the drawing back to
  the sheet under it, which is what keeps it. Its Cancel asks first when
  something was drawn.
- **The plan-a-win sheet's left word becomes Done** once a line has been
  planned: leaving no longer throws anything away, and the right word is
  busy being Plan.
- **A full-screen page closes with an x on the right** (booth, story,
  replay, camera, head maker). **The photo viewer's is on the left**,
  because its right holds the menu, as in Photos.
- **A replay: a hold pauses and a press skips**, as stories do everywhere.

## How it is scored

For each area of the app: the count of breaks under each rule, before and
after. The table is in `tasks/master-update-log.md`. A break I chose to
leave is listed there with the reason, for the owner to overrule.
