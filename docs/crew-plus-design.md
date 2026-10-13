# The plus row, group plans and looking back in a crew

**Approved 2026-10-12**, all four as recommended: the row is Win, Plan,
Strip, Memory, Sticker with the doodle inside Sticker; a group plan has
one button, I'm In, and its strip stays inside the crew; a crew's look
back is shown to you and one tap sends it. What follows is the design as
approved; "From you" lines are answered.

From the Launch Pack (2026-10-12), items 4, 5 and 9. You chose "design
first, then build". Nothing here is built. Each part ends with what I need
from you.

## What is true today

- The crew chat's field is a message box and a send arrow. **There is no
  plus button and there are no challenges** anywhere in the app.
- A crew holds five kinds of thing, each sealed with the crew's key: the
  crew, a member, a win, a reaction, a chat line (words, or a doodle, or a
  quoted win). `CrewRecords` says outright that "a plan item is never in
  one". Group plans reverse that on purpose.
- A crew's records are kept for about two weeks. Nothing a crew did a year
  ago is on any server.
- None of the crew's syncing can be run on the simulator. Everything below
  ships to your phone first, after a second reader has gone through it.

## 1. The plus row

A plus sits to the left of the message field, the same glass button as the
send arrow. A tap swaps the keyboard for **one row** of five glyphs with
one word under each. A second tap, or choosing, puts it away.

| Order | Glyph | What a tap does | New code |
|---|---|---|---|
| 1 | Win | Opens Add a Win with this crew already ticked | None: the sheet exists |
| 2 | Plan | Starts a group plan (part 2) | New |
| 3 | Strip | Sends today's photo strip into the chat | Exists as a share target; this is a second door to it |
| 4 | Memory | Your past days that this crew saw; pick one to bring back (part 3) | New, small |
| 5 | Sticker | Your stickers and the doodle pad, sent as a chat line | The doodle exists; a sticker as a line is small |

No "more" drawer: five fit on the smallest phone at 44 points each, and a
drawer with nothing behind it is clutter. If a sixth thing ever arrives it
goes behind one.

**From you:** the order, and whether Doodle stays inside Sticker or gets
its own glyph.

## 2. A group plan

The brief: "a shared commitment where completion surfaces as living proof,
like 'Rildy just did the workout', with an optional shared photo strip.
Not a challenge, not competitive."

**What it is.** A plan line that a crew can see: "Workout", today, or
tomorrow, or a date, or the days of the week it repeats. Written in the
plan bar the app already has, opened from the plus row with the crew
chosen.

**What everyone sees.** One quiet card in the chat: the title, the day,
and a button, **I'm In**. A tap puts the line in your own plan, where it
behaves like any line of yours (the outline on your tower, Not Today, a
photo from the camera or the library). Not tapping does nothing and is
shown to nobody.

**When someone does it.** They finish the line the way they finish any
planned win, and it goes to the crew as their win. The card grows their
head, and the crew is told "Rildy just did the workout."

**What it never does.**
- No count ("2 of 5"), no list of who is in, no list of who is not.
- No deadline, no "ended", nothing red. After the day it rests as it is.
- No streak of its own. A repeating plan just comes round again.
- Nobody is told that someone did not.

**The strip.** When two or more people have done it with a photo, the
card offers **Make a Strip**: those photos, in the booth, sent back to the
chat. It uses only photos already sent to this crew, and it stays in the
crew: no Save to Photos for a strip of other people's pictures, which is
the rule crew albums already keep.

**Under the hood.** Two new kinds of sealed crew record: the plan (title,
days, who wrote it) and "I did this" (which plan, which win). A friend on
an older build sees the win arrive and no card. **No Deploy is needed from
you** (checked 2026-10-12): every crew item is one record type on the
server, "CrewItem", holding a kind as plain text and a sealed box, so a new
kind is new text and a new box, not a new field. What I have not checked
yet is exactly what an older build does on meeting a kind it does not know;
that is read before anything is written.

**From you:** yes or no to "I'm In" as the one button; and yes or no to
the strip staying inside the crew.

## 3. Looking back, in a crew

The brief: "the app posts into crew chat like a thoughtful friend": "A
year ago, you and your crew did this."

Two facts shape this. The crew's own records are gone after two weeks, so
the only memory of a crew's past is on each person's phone: the wins
**you** sent there. And nothing in the app can post by itself; a phone has
to do it.

So, my recommendation: **it is shown to you, and one tap sends it.** On a
day when you sent this crew a photo a year, six months or a month ago (the
same ladder as Memories), the top of that crew's chat shows your photo
with "A year ago today, you sent this here." and one button, **Send It
Again**. Sent, the crew sees it as a line from you: your photo, and "A
year ago today."

Why not post it without asking: the people in the crew may have changed
since. A photo you sent to three friends a year ago would land in front of
whoever is there now.

"We made this for you" belongs to albums and recaps, which is the next
piece: a crew's week put together as a recap is the same replay the app
already makes for your own week. I would do that after the plus row, not
with it.

**From you:** shown to you with one tap to send (recommended), or posted
by itself.

## 4. What I would not build, and why

- **Invite codes.** An invite link is long because it carries the crew's
  key, which is what keeps a crew sealed. A six-letter code cannot carry
  it. A code would need the key kept on a server where a code looks it up,
  which is the thing the sealing was built to avoid.
- **A link that installs the app and then drops you into the crew.** With
  no server, the only way is for the page to copy the invite and the app
  to read the clipboard on first launch, and iPhone then shows "Some Wins
  pasted from Safari". That reads as the app looking over your shoulder,
  which is the one feeling this app never gives. What does work: once
  somewins.xyz points at the page, a link opens the app straight away for
  anyone who has it.
- **Instagram's own sticker hand-off.** It needs an app registered with
  Meta. Today the strip saves on a clear background and drops onto a
  story by hand, with no link, QR or sticker on it, which is the brief.

## Order and proof

1. ~~Find out whether new record kinds need a Deploy.~~ They do not.
   Still to read: what an older build does with a kind it does not know.
2. The plus row with Win, Strip and Sticker, which need nothing new on the
   server. To your phone.
3. Group plans. A second reader on the diff, then your phone, then a
   two-phone try with a friend before Friends.
4. Looking back in a crew.

Every step is unproven on real iCloud until you have tried it.

## Found by the audits, to build with these

- **A win sent to several crews tells only one of them.** The notification
  is filed under one crew, so a friend who shares only another crew with
  you is never told. The fix: one ping per crew, and the phone folds the
  copies into one. With step 3, behind a second reader.
- **A sticker on a win**, as a chat line can already take one. With the
  plus row's Sticker.
- **A code you can show** instead of a code you type: the invite link as a
  QR on the crew's page, for a friend sitting next to you. It keeps the key
  in the link. Small, and needs nothing on the server.
- **An Invite on a crew of one's own tower**, where today it is two taps
  away.

## As built (2026-10-12)

Built to the design above, with these differences, each for a reason:

- **A group plan is a chat line, not a new kind of record.** It is marked
  the way a photo strip already is, followed by words anyone can read
  ("Plan: Workout (tomorrow)"). So it is sealed, paced, word-checked and
  cleared exactly as every line is, a friend on an older build sees those
  words as a plain line, and none of the syncing code changed. There is no
  second "I did this" record either: the proof is the win. The card names
  whoever sent the crew a win of that name that day.
- **What that costs:** the proposal is one day long, like every line. On
  the plan's own day the card is drawn on your phone from your own plan,
  so it shows to the people who tapped I'm In, and not to someone who did
  not. They still see the wins arrive.
- **The card says names, not heads:** "Today. Sam did it." It is the app's
  one card (`TipCard`), which has no row of faces, and a new card for this
  alone would have been a second drawing of the same thing.
- **Strip opens your booth** for today, and its Share sends it to the
  crew. It does not send by itself: the strip still develops when the
  day's goal is reached, here as on the tower.
- **Memory is a sheet** of your photos this crew saw, newest first; a tap
  sends one with its date under it. The look back itself is a card over
  the chat on the day, with Send It Again.

**The rest, built 2026-10-13** (you: "build the rest of the things"):

- **A sticker on a win**, a third word beside Reply and Doodle. It travels
  as a star with the picture beside it, so a friend on an older build sees
  a star, and so does every notification.
- **A win sent to several crews tells every crew.** Each is told unless
  everyone in it has already heard from an earlier one, and a phone that
  still gets two folds them into one.
- **The invite as a code**: a small glyph in the top left of a crew's
  page, opposite Done. A friend beside you points their camera at it. It
  was a row of its own first; you moved it. Dark on its own light paper in
  both appearances, and it leaves the screen when you look away.
- An Invite standing on a crew of one's screen was built and taken off the
  same day, at your word ("I dont like how invite is just there").
- **The crew's plans show on the crew's own screen**, as the same card,
  floating under the header (you: "make sure the crew plan shows up on the
  crew page as well"). Two at most.
- **Your own win takes your reaction** (from a tester, through you).
  Nobody is told of it.
- **This Week and Last Week** in a crew's Recent Days: the replay the app
  makes of your own week, of the wins the crew holds. Asked for, never
  announced.

**Proven:** on the simulator with a seeded crew (looked at), and by a test
that sends a plan from one phone to another over the pretend cloud.
**Not proven:** anything on real iCloud, or between two real phones.

**Changed at your word, 2026-10-13, later the same day:**

- **A plan you are in is a box on the crew's tower**, not a card under its
  header. The clear box your own tower draws for a planned win, by the
  same view, after the slot, holding only that crew's lines. Press it:
  Take Photo, Choose from Library, Log Without a Photo, Edit, Not Today.
  Whoever says I'm In gets the box on their own phone. Two crews with two
  goals are two towers with two sets of boxes.
- **The card under the crew's header is only a plan still waiting for
  your answer.** Closing it closes it there, for the day, and nowhere else.
- **A plan's line in the chat has no close and is never hidden.** It was
  hidden for the day by closing its card, here or on the crew's screen.
- **A plan done is said as done**: "Sam just did Evening walk".
- It is still a line of your own plan, so the same box stands on your own
  tower. One win finishes both, and goes to that crew.
- **Strip in the plus row shows today's strip and Send sends it.** It
  opened your booth, which develops only at the goal: "you can't even
  send it to the chat" (you, 2026-10-13).
- A box pressed on a crew's tower makes a win for that crew alone.
