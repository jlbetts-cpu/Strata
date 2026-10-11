# Master update pass: decision log

Started 2026-10-10, late afternoon. Four items, done in order. Anything
marked **REVIEW** is a call I made that you may want to undo. Newest at the
bottom of each section.

---

## 1. Crews "deleted on every new TestFlight build"

### What I found

**Where crew data lives.**
- The crew itself (members, wins, chat, photos) is in iCloud's **public
  database**, in the **Production** environment. TestFlight and App Store
  builds both use Production; only a build run from Xcode uses Development.
- What a phone keeps: each crew's key (without it the crew's records cannot
  be opened) and which person in the crew this iCloud account is. Both were
  in the app's own settings on the phone, with one copy in your **private**
  iCloud.

**The schema is not the cause.** I exported both environments and compared
them: Production and Development are identical, and `CrewItem`, `Ping` and
`CrewKeys` are in Production with the indexes the app queries by.

**An ordinary update does not wipe crews.** I read every path that drops a
crew or a key. None is tied to a build number, and an update in place keeps
the app's settings and files. I could not look at your phone or at the
server's records (that needs your iCloud sign-in), so this is from the code.

**What does lose crews, and all three are real:**

1. **Build 114 itself, once.** Up to 113, crews lived in the starter's
   personal iCloud. 114 moved them to the shared database and did not carry
   the old ones over; it also deleted the old ones to give the storage back.
   Your friends met this on 116, coming from 113. That is the "new build,
   crews gone" most people saw, and it does not repeat.
2. **Deleting the app, or a new phone, with a full iCloud.** The only copy
   of the keys off the phone was the one in private iCloud, and a full
   iCloud refuses it. Yours is full: that is why crews left personal iCloud
   in the first place. So for you, deleting and reinstalling the app lost
   every crew for good, with the crews still on the server and no key to
   open them. The same refusal also failed a set-up step on every launch.
3. **One failed read.** If the app started and could not read a crew (no
   signal, a cache that would not open), it took the crew for gone and
   threw away its photos and the streak your phone had counted for it. The
   crew came back on the next good read; the streak did not.

### What changed

- **The keys and your identity are now also kept in the Keychain**
  (`CrewVault`). It stays when the app is deleted, it reaches your other
  devices and a new phone through iCloud Keychain, end to end encrypted, and
  it uses none of your iCloud storage. Kept per iCloud account.
- The two copies are read as one, by the rules that were already there and
  already reviewed: a crew you left stays left, a key another phone took is
  taken, one phone never erases another's crew.
- **A crew that could not be read is never taken for one that is gone.** It
  stays in the list as it was, streak and all, until it can be read.
- A full iCloud no longer stops the set-up step.
- Signing out of iCloud still clears your crews off the screen, and signing
  back in to the same account now brings them back.

**From which build:** the protection starts the first time this build runs
on a phone, because that is when the Keychain copy is first written. A crew
lost before then cannot be brought back.

**REVIEW**
- The Keychain copy stays on the phone after sign-out, readable only by the
  app and only for that account. The 2026-10-02 audit said nothing of the
  old account's crews may stay. I think a sealed key in the Keychain is the
  right trade for not losing crews, but it is your call.
- **The App Store build.** Crews are switched on only in TestFlight builds
  today. Someone who moves from TestFlight to the App Store version keeps
  every crew (same database, same keys), but the crews button is hidden
  until crews are switched on for the App Store. That is the launch
  checklist's step 3 and still waits on your two-phone test.
- Not proven on real iCloud, like all crew code. Ten new tests cover the
  rules; an independent review read the rest (below).

### The independent review of this fix, and what it changed

Read by a second reviewer before commit, as crew code always is. It found
no way an ordinary update loses crews either, and four real faults in my
fix, all corrected:

- **An identity made on a blank phone could travel.** A new phone with
  nothing on it makes itself a fresh identity; my first version wrote that
  to the Keychain, where your other phones could have taken it for who you
  are. Now it is written only when it is known to be you: private iCloud
  says so, or the phone has already been that person in a crew. A phone
  that is nobody yet learns who it is from its own records in its crews.
- **Two phones that had each joined as their own person** (possible only
  with a full iCloud) are left as they are. Neither takes the other's
  identity, which would have left a second you behind in every crew.
- **A crew that could not be read could have stayed frozen.** It is now
  asked for whole on the next refresh, and a listing that shows nothing at
  all for a crew you are in is treated as a listing gone wrong, never as an
  emptied crew.
- **Signing out while a sync was waiting** could have put the keys back for
  the next account. The sync now stops if the account changed under it.

**REVIEW, and one question for you**
- The reviewer's best guess for "crews gone after a new build", if it was
  not build 114's one-time move: the app being run from Xcode onto your
  phone between TestFlight builds. An Xcode build talks to the Development
  database, finds none of your crews there, and (before this fix) dropped
  them. I do not think you do this, since this Mac's Xcode has no Apple ID
  signed in. If you ever have, that was it, and it can no longer drop a
  crew.
- Someone whose two phones each joined a crew as a separate person shows
  in that crew twice. That needs a full iCloud and two phones; I left it,
  because merging two people's posts into one is not a thing to guess at.
- After signing out of iCloud and back in, crews return but the streak
  count this phone had kept for them starts again from the last two weeks.
- For you, with a full iCloud, one clean-up runs for the first time on
  this build: the old pre-114 crews in your personal iCloud are deleted,
  which gives that storage back. It is what 114 meant to do.

---

## 2. Doodle leaves its own block

- The pen tile beside the block in the add sheet is gone. What follows the
  block now is the day's first photograph (or, before you have allowed the
  library, the one tile that asks for it).
- **Doodle is in the block's own menu**: press the empty block and it
  offers Take Photo, Choose from Library, Doodle. That is the place a
  photograph is chosen, so drawing one sits beside the two ways of getting
  one.
- With a drawing on the block: a press still opens it to edit; a hold
  offers Replace Doodle and Remove Doodle, the way a photograph offers
  Replace Photo and Remove Photo. The menu says Edit Doodle and Remove
  Doodle when there is one.
- Nothing about a doodle itself changed: it is still a block's picture on
  the tower, in recaps, Memories and the strip.
- Looked at on the simulator: the strip without the tile, the menu, and the
  doodle sheet opening at the block's shape. **Not seen:** a real photograph
  in the freed place; the simulator's photo permission prompt would not take
  a scripted tap. The strip's code for the photographs is unchanged.

---

## 3. Planning woven into the tower (working notes, written before building)

### What exists today (read 2026-10-10)

- `PlanItem` (SwiftData, syncs in private iCloud): text, order, colour,
  repeat weekdays, size, done time. **No day.** A one-off line belongs to
  "today" every day until done; nothing can hold "do this Thursday".
- The plan sheet is the Plan tab of the day sheet (`DaySheet`, `PlanLines`,
  `DayComposer`): a checklist, Your Three pinned on top, and the message bar
  ("Add to the plan"), where Return adds the line and keeps the keyboard.
  Repeat lives in a line's detail sheet (`PlanItemDetailSheet`).
- Ticking a line opens the add sheet with the line's name on it; saving the
  win marks the line done. Done one-offs are swept at the next launch.
- **Nothing planned is drawn on the tower.** It was once (outlined "ghost"
  blocks for unfinished habits) and was removed: "They made the tower busy.
  The tower is the record; the planning lives elsewhere." No dated word of
  yours is attached to that removal. Your new brief reverses it, with a
  different object: not a faded coloured block but a clear glass outline,
  small, colourless. I am following the brief.
- The slot ("+") is glass and is "the absence of a block". A press opens the
  add sheet; a hold or draw logs at once.
- The goal crest counts today's completed wins; the goal dance counts
  placed blocks. A planned placeholder must not be counted by either.
- The camera is a tab. No title or plan line can be handed to it today.

### What the research says (sources in the session; the reference named
"Teemo" does not exist as an app, teemo.app is a parked domain: I read it as
**Tiimo**, the ADHD planner)

- **Capture:** Ellie's "no dates, no decisions"; Tiimo's Anytime tasks need
  no clock time; Notes continues a list on Return. Structured asks for an
  icon and a duration per item, which is the thing to avoid.
- **Day:** one control for the whole batch (Today / Tomorrow / a day this
  week). Reminders highlights a typed "tomorrow" and applies it only when
  you accept it, so a title is never mangled.
- **Repeat:** one row (Structured: Daily / Weekly). Google Calendar's
  repeating tasks appear by themselves on their days.
- **Unfinished at day's end:** every product that rolls leftovers forward
  grows a backlog that then needs cleaning (Ellie recommends a monthly
  clean-out; Google shows a running pending count; Reminders lists Overdue
  first). Adults with ADHD report being criticised for lapses as the most
  damaging thing (qualitative, n=162). Recommendation: **quiet expiry**, no
  missed marker; a one-off not done is offered once more, never re-added by
  itself; a repeating one simply returns on its next day.
- **How many:** no empirical number. About three outlines reads as a plan;
  no hard cap, no warning.
- Not found in any source: that planning the night before raises
  follow-through (the one study is about falling asleep faster).
