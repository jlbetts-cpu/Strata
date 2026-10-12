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

### What was built

**A plan line has a day.** Today, tomorrow, any of the next six days, or it
repeats. No times, no durations, no priorities: a day and some words.

**Today's plan stands on the tower.** Each open line is a clear glass
outline behind the slot: one Quick cell, no colour, its words and the plan's
empty box. Repeating lines appear on their days by themselves.
- Press one: the camera opens. The shot goes on a win already named and
  coloured as the line was; Add is one press, and the size can still change.
- Hold one: Take Photo, Log Without a Photo, Edit, Not Today (a one-off
  goes to tomorrow; a repeating line is skipped for the day).
- The slot is unchanged and comes first, so an unplanned win is as fast as
  it was and lands where the slot is. Outlines are never counted: the ring
  counts wins.
- At most eight outlines (two rows). A longer plan is all in the plan and
  the queue moves up.

**The plan sheet has days.** One row of words: Today, Tomorrow, the week,
Repeating. The bar adds to whichever is chosen, a line a Return, and a list
pasted in becomes a line each. Repeating is where a routine is set up: a
line added there comes back every day, and its days are one press away.

**The add sheet has one new word, Now.** Under the name, quiet. Pressed, it
is the same row of days with Now first. Choose a day and the sheet writes
plans instead: "What do you mean to do?", a line a Return, no colour, size
or photo. Choose Now and it adds a win as before. A fresh Add is otherwise
untouched.

**Nothing is ever "missed".** A one-off whose day went by is not on the next
day's tower or list. It waits in the plan under Earlier, where one word
moves them all to today and a swipe lets one go. No mark, no count, no
colour, and nothing is deleted for you.

### Your test

"Plan their entire next day in under 15 seconds." Timed on the simulator,
from pressing the slot to the plan made, three lines typed at a thumb's
pace (four characters a second): **13.0 seconds**. Through the plan sheet it
is one press shorter. The test is kept (`testPlanningTomorrowIsQuick`) and
fails if it ever goes over 15.

### Decisions you may want to undo. REVIEW

- **Outlines reverse an earlier removal.** The tower once drew unfinished
  habits as faded blocks and stopped, because they made it busy. These are
  not blocks (glass, clear, small, uncounted), and it is what you asked
  for, but it is the one place this pass goes against the app's own notes.
- **Leftovers do not roll over.** The research is firm that auto-rollover
  grows a backlog and that "missed" marks hurt, so yesterday's undone line
  goes to Earlier rather than onto today's tower. Before this, a one-off
  stayed on today's plan every day until done. If you would rather they
  carry over, it is one rule (`PlanItem.belongs`).
- **Your existing plan lines get today's date** the first time this build
  runs, so tomorrow they will be under Earlier, not in today's list.
- **No typed dates.** "tomorrow" or "every weekday" typed into a line is not
  read. The row of days is one press and cannot mangle a title. Reminders
  does read them; say if you want it.
- **No "Teemo".** I could not find a planner by that name (teemo.app is a
  parked domain) and read it as Tiimo. If you meant another app, tell me.
- **No reorder.** There has never been a way to reorder plan lines; the
  tower's queue follows the order they were written in.
- **The day is stored in an existing field**, so nothing has to be deployed
  in the CloudKit console. A proper field would be cleaner and needs that
  deploy from you.
- Pressing an outline opens the camera, as you asked. On the simulator the
  camera has no permission, so I saw the camera screen open but never took
  a photo through it; the hand-off after the shot is the same one the plan's
  tick has always used.
- The plan sheet's own bar could not be typed into by a script (a simulator
  keyboard problem with that field, not the app's). I timed the add sheet's
  door and checked the bar's lines by reading them back.

### The independent review, and what it changed

Thirteen findings. The ones that would have reached you:

- **A dated line was invisible on a phone still on an older build**, and my
  own test claimed the opposite. Fixed: the day is written so an older
  build shows the line on its day.
- **Your existing plan would have been deleted two weeks after updating.**
  I had added a quiet two-week expiry for Earlier lines, and the update
  gives every old line a day. Removed: nothing unfinished is ever deleted
  for you.
- **A repeating line done today showed as done tomorrow**, and pressing it
  on tomorrow's page took today's tick off. Only today's page ticks now; on
  another day a line's box opens the line.
- **The photograph could be lost between the camera and the add sheet**
  (the sheet was asked for while the camera was still leaving). It waits
  for the camera to go.
- **Typing in the plan re-drew the whole main screen on every letter.** The
  plan's data is read by the small layer that draws the outlines now.
- Smaller: an outline whose win already exists ticks instead of logging it
  twice; suggestions only on today's page; Skip Today can be put back from
  the line's menu; a photo chosen before switching the add sheet to
  planning is not thrown away without asking.

**Left as found, for you to know**
- Deleting an old win made from a repeating line also unticks today's. It
  did before this pass.
- A line edited on an older build's detail sheet may be read there as a
  weekly repeat. It stops once that phone updates.

---

## 4. The ring comes forward to take a win

- When a win lands, the crest itself (your face in the ring, not a copy)
  lifts out of the header, grows to the middle of the screen, the segment
  the win earned is drawn round, your face gives way to your drawn check
  for a beat, the fraction counts up, and it goes home.
- About two seconds, starting once the block has landed. Touches pass
  through it and nothing has to be dismissed.
- A win saved from the add sheet plays it once the tower is back in view.
  Taking a win off, the first count after launch, and a second win during
  the moment play nothing.
- With Reduce Motion nothing travels: the check fades in where the crest
  sits, and out.
- The goal's dance and confetti are untouched and still follow when the win
  was the one that reached the goal.
- **Looked at frame by frame on a recording.** The first version lifted
  while the block was still falling and the block passed behind the ring;
  it now waits for the landing (0.9 seconds from the press).

**REVIEW**
- It plays for every win, about three seconds from press to home. That is
  your brief ("when a win is completed"), and I kept it calm, with no
  bounce, so it does not tire. If it is too much on a ten-win day, the
  natural cut is to play it only for the first win and the goal.
- The check is your `MarkCheck` drawing. With no head made, the middle is
  the plain person glyph, as in the header.
- My rating: 8.5. It reads at once and it is quiet. What would make it a
  10 is your eye on a real phone, where the glass has something to refract.

---

## The suites, and the build

- **Unit: 1,359 tests, passed**, no crash. 46 of them are new in this
  pass (crews 11, planning 18, the ring 6, and the gates they touched).
- **Full suite (unit and UI, 75 UI tests): passed**, no failure, no crash.
  The screenshot tests, mine among them, only run when asked for; each was
  run by hand and looked at.
- A release build was compiled before shipping (the last ship failed on a
  debug-only helper; this one was checked first).
- Three independent reviews in this pass (crews, planning) found 30 things
  between them. Every one that could reach a person is fixed or written
  above under REVIEW.
- **Build 117 is in TestFlight for you only.** I did not add it to the
  Friends group or send it for review: you were away, and that is yours to
  say. Until friends have it, their crews are not yet in the Keychain.

## For you, when you are back

1. Push: `cd ~/Desktop/Strata && git push origin main`.
2. Install 117 and open it once. That is the moment your crews are first
   kept in the Keychain.
3. Plan tomorrow with a stopwatch. Press an outline and finish it with a
   photo (the one path I could not walk on the simulator).
4. Log a win and watch the ring. Tell me if every win is too often.
5. Say whether 117 goes to friends.
6. Still open from before: the domain's DNS and GitHub Pages setting, then
   I switch the invite link to somewins.xyz and add the direct open.

---

## 5. The pass to a 10 (2026-10-10, evening, after "keep editing")

You asked for everything to rate a 10 for connectivity, look and function.
What I found by looking, by a fourth independent review, and fixed:

### The ring
- **It played over the goal's dance**, and the confetti came out of a crest
  that was not in its place. The order is now: block lands, ring takes the
  win and goes home, then the dance, then the confetti. Seen on a recording.
- **The header filled twice**: it showed the new count for most of a second
  and then the ring came out showing the old one. The header now holds the
  old count until the ring has drawn the new segment.
- **Undo did not stop it.** A win taken back inside the first second still
  played the ring up to a count that was no longer true. It cancels now.
- **It played over other screens**: a win logged on a crew's tower played
  your ring over the crew. It now plays only with the Wins tower in front
  and nothing over it.
- **A win ticked from the plan cut it off mid-air** when the plan sheet came
  back. It waits for the tower instead, for at most six seconds; past that
  the moment has gone and the count is just the count. The same six seconds
  stop it playing for a win that arrived from the widget or iCloud.
- With Reduce Motion the check covered the ring itself. Only the face gives
  way now.

### The planner
- **An outline's words were bigger and heavier than a real block's title**,
  and a long line shrank to a size its neighbours did not have. They wear
  the block's own title type and place now, and truncate.
- **The day's one reminder knows the plan**: "Today: Morning walk, Laundry"
  under the usual title, up to three lines by name. No new notification.
- **The plan is in backups.** It never was. What is still to do and every
  routine go in, come back once, and the restore screen says so.
- A line can be moved to another day from its own sheet (the same row of
  days).
- Deleting an old win from a repeating line no longer unticks today's.
- Planning is not offered in the add sheet opened from a crew's tower.
- A friend's win put on your plan (Do It Too) is dated today, so it stands
  on your tower at once.
- The row of days fades at the screen's edge instead of cutting a word in
  half.

### Rated honestly, after this round

| Piece | Rating | What keeps it from higher |
|---|---|---|
| Crews outliving the app | 8 | Read four times, tested on rules; never run on real iCloud. |
| Doodle in the block's menu | 9 | Never saw a real photo take the freed place (simulator permission). |
| Outlines on the tower | 9 | Around a Deep block they fill its side gaps, which is where blocks would land but reads less like a queue. |
| Plan sheet's days | 9 | No reorder; no typed dates. |
| Add sheet's Now | 9 | One more row under the name on every fresh Add, quiet as it is. |
| Finishing from the tower | 8 | The camera hand-off after a real shot is unproven on a phone. |
| The ring's moment | 9 | Needs your eye on glass with a real head in the middle. |
| The reminder with the plan | 8 | Rescheduled on leaving the app and closing the plan; never seen on a lock screen. |

**Still for you to decide (REVIEW)**
- Your Three are not outlines on the tower. They are in the plan and in the
  row over the keyboard. If your three are really your daily routine, they
  could stand on the tower like repeating lines; I left them, since for a
  new person they are generic suggestions and three outlines would greet
  everyone every morning.
- Restoring an old backup can bring back a one-off you have since done (it
  lands under Earlier). The backup does not know what was finished later.
- Plan text now shows in the day's reminder on the lock screen, as a win's
  title already does in others.

**The suites and the build, after this round:** 1,367 unit tests pass; the
full suite (76 UI tests) passes with no failure and no crash. **Build 118 is
in TestFlight for you only.** Friends have 117, waiting on Apple's beta
review; say the word and 118 goes to them too.


## 6. The night of 2026-10-11: days for a repeat, and the check you asked for

You said two things before bed: a repeating plan could not be set for
Monday, Wednesday and Friday, and "double check everything is up to date,
working update to update and page to page".

### Days for a repeating plan

Under Repeating, a new line came back every day. Choosing days took writing
the line, opening its sheet, switching Repeats on, then the days.

- Seven letters now stand with the field the line is typed in: under the
  add sheet's row of days, and directly above the plan's bar on its
  Repeating page. All on is every day; press off the ones it is not for.
  They stay as set for the next line, and each line says its days under its
  name ("Mon Wed Fri").
- **Changed after looking at it.** My first version filled a chosen day in
  solid ink. In dark mode that was seven white squares, against your "light
  on light, dark on dark". A chosen day is now the tint the chat uses for
  your own reaction, with the letter in ink; a day that is off is a
  hairline and a grey letter.
- **Changed after the review.** I first put the plan page's chips under the
  row of days, above the list. The reviewer said they read as the existing
  lines' days. They are above the bar now.

### Update to update

Built build 113 (what friends had before 116) from its commit, installed
it clean on the simulator, seeded it, then installed tonight's build over
it and opened it three times.

| | Wins | Win logs | Plan lines | Journal | Tower |
|---|---|---|---|---|---|
| Build 113 | 41 | 41 | 5 | 1 | 1 |
| Tonight's build, first open | 41 | 41 | 5 | 1 | 1 |
| Third open | 41 | 41 | 5 | 1 | 1 |

The three old undated plan lines were given today's date and stand on the
tower as outlines; the weekday repeat was left as it was. No stored field
changed between 113 and now, so there is nothing for iCloud to migrate.
**Not covered:** crews across an update (the simulator has no iCloud), and
a phone that was signed in to iCloud while updating.

### Page to page

Every main screen photographed in light and dark and looked at: tower,
add, edit, plan (today, tomorrow, repeating), profile, settings, crews
list, a crew, its chat, a day, the month, the map, a replay. Nothing was
out of place. Two things were wrong with my own test set-up, not the app:
the tour's crew flags seeded no crew, and a camera permission prompt left
standing covered the first dark set.

### What an independent read found in the planner, and what I did

I had a second agent read the planner end to end, then a third try to
break my fixes. Both found real defects. All were in how a win and a plan
line meet.

| Found | Now |
|---|---|
| Logging "Study" today ticked Thursday's "Study", which was then cleared off the plan overnight | A win ticks the line open today, in the plan's order; never a later day's |
| Closing the app from the add sheet left a plan line ticked with no win; it was then cleared overnight | The waiting tick is written down and taken back at the next launch |
| A repeating line ticked days ago (app left open) could not be ticked again by name | Found by "open today", not "never ticked" |
| Repeats switched on made any line Monday to Friday, so a Saturday line left Saturday | It repeats on the day it was on; switched off, it goes back to that day |
| Skip Today, then Repeats off, hid the line everywhere until tomorrow | Only a repeating line can be skipped |
| Pressing off the last day in a line's sheet silently made it a one-off | The last day cannot be pressed off; the switch turns a repeat off |
| A win that ticked a line by name did not remember it, so deleting the win left the line ticked | It remembers; deleting unticks |
| Tick, untick, then tap the outline: a second win | The outline checks for the win first, as the plan's box did |
| Log Without a Photo used Quick, the plan's box used the line's size | Both use the line's size |
| A photo attached, then a day pressed: Plan threw the photo away | A sheet holding a picture is not offered a day |
| My own fix could untick a line whose win was saved but whose photo failed | The win is told its line the moment it exists, before the photo |
| Try Again and Done after a failed photo never ticked the plan | Same fix: the plan hears first |
| The reminder left out a line that had been skipped and then made a one-off | Uses the same rule as the tower |
| Do It Too said "on your plan" for a line whose day had gone by, and nothing stood on the tower | It is brought to today |

**Left, and why (REVIEW):** log "Gym" by name, untick it in the plan, log
"Gym" by name again: two wins name one line, and deleting the first
unticks the line while the second stands. It needs three deliberate steps
and loses nothing.

### The suites

After everything above: **1,376 unit tests pass.** The full suite ran with
no failure and no crash: 79 UI tests listed, 41 run and passed, 38 are the
screenshot tests that only run when asked for. The Release configuration
compiles.

**Rated honestly**

| Piece | Rating | What keeps it from higher |
|---|---|---|
| Days for a repeat | 9 | Above the plan's bar a very long Repeating list scrolls behind the letters. I tried backing them and it looked worse (the off days stood out white), so it is left. |
| A win meeting its plan line | 9 | Read three times and tested on rules; the two-wins-one-line case above is left. |
| Update to update | 8 | Proven for wins, plan, journal on the simulator. Crews across an update cannot be run here. |
| Page to page | 9 | Looked at in both appearances; not on glass. |

**For you**
- Build 119 is in TestFlight for you only. Friends are on 117.
- Everything since Build 117 is waiting for `cd ~/Desktop/Strata && git push origin main`.
- somewins.xyz still points at the registrar's parking page, so invite
  links still say github.


## 7. One pane, one chip, one lettering (2026-10-11, morning)

You, on build 119: the M to S chips looked round in the pop-up sheet and
square elsewhere; the + block "feels out of place next to the check mark
block when they should look the same"; and "the checkmark block font and
weight should be the same as the other blocks, decide which one is better".

- **The chips.** A line's own sheet drew its seven days itself, from a copy
  of the numbers: narrower in its form row and on a filled well, so it read
  rounder. All three places draw one component now (`WeekdayChips`), always
  square, with a block's corner at its size. In a line's sheet the chosen
  days still wear the line's colour, since that sheet is where its colour
  is picked. REVIEW: say so if you want those in the quiet grey as well.
- **The + block.** Both were the same glass already; the + drew a grey
  recess and a heavy hairline on top (set when it stood alone on a flat
  page), and the planned wins were dimmed to 82% behind it. Now one pane
  for both: no recess at rest, one shared edge (`SlotPane`), quiet in
  light where the glass lifts off the page by itself and stronger in dark
  where it does not. The + still deepens and darkens its edge under your
  finger. Onboarding and a crew's tower use the same slot and follow.
- **The lettering.** The face and weight were already the block's
  (footnote, Medium). What made it read lighter was the ink: secondary
  grey, under the 82% dim. **I chose the block's**: full-strength title
  ink, dark on the light pane and white on the dark one, as a block's title
  is white on its colour.
- **Left as it was:** a planned win's name may run to two lines (a Quick
  block's is one line and cut with an ellipsis). The words are all an
  outline has. The replay's dashed waiting slot is a different thing and
  was not touched.

**An hour later, you:** "why in dark mode is there an outline on everything,
it should just be liquid glass like it is in light mode". Right. I had given
the dark pane a stronger hairline because dark glass on a dark page came out
the page's own colour. The line is gone in dark. The glass itself carries a
little white there (10%), so the pane is a raised charcoal tile, the way the
light one is a brighter tile, with no drawn edge. Build 121.


## 8. What a 10 is, and the pass against it (2026-10-11)

You: "keep editing till everything is a 10 and be very specific what we
define as a 10. The usability consistency needs to be a 10."

**The definition is `docs/ten.md`**: nine rules, each with a check, and a
count of breaks. A screen is a 10 at zero breaks a person could notice. It
also lists nine written exceptions (things that look like breaks and are
your decisions, or what iPhone's own apps do).

Four independent readers each took two or three rules over the whole app
and came back with 71 findings. I looked at every screen in both
appearances before and after.

### The score

| Rule | Found | Fixed or decided | Part done | Left |
|---|---|---|---|---|
| 1 One thing, one drawing | 13 | 6 | 1 | 6 |
| 2 One action, one gesture | 2 | 2 | 0 | 0 |
| 3 One sheet, one layout | 9 | 9 | 0 | 0 |
| 4 One word per thing | 16 | 16 | 0 | 0 |
| 5 Every press answers | 6 | 4 | 1 | 1 |
| 6 Both appearances | 6 | 2 | 2 | 2 |
| 7 Type, space, shape | 12 | 4 | 1 | 7 |
| 8 Every state is drawn | 3 | 2 | 0 | 1 |
| 9 The same unseen | 4 | 3 | 1 | 0 |
| **All** | **71** | **48** | **6** | **17** |

**Rules 2, 3, 4 and 9 are at zero.** Rules 1 and 7 are not, and what is
left there is listed below so you can see it is not hidden.

### What changed that you will notice

- **Words.** Buttons are Title Case everywhere ("What Else", "Make My
  Head", "Not Now"). A photo is a "photo" in every sentence (it was
  "photograph" in about twelve and "picture" in three). The month
  drawing's caption is "words", since "line" is the plan's. "Start a Crew"
  and "Invite People" each have one name. The plan's bar says "Plan for
  today", "Plan for tomorrow", "Plan something that repeats". A plan line's
  hold menu says Edit, as its outline's does.
- **Nothing is lost at one press.** A swiped plan line offers Undo. A win
  drawn out of a crew's slot offers Undo. A drawing editor's Cancel asks
  when something was drawn. Taking a win off a crew, going back to the
  original month drawing, and removing a journal sketch each ask.
- **Failures speak.** Saving to Photos from the viewer and both strip
  screens says when it could not, with Open Settings. A reply that is held
  back says why. A crew slot's win that fails says so.
- **Sheets match.** Done and Cancel are bare words on the crew sheet, Start
  a Crew, Your Day and Your Three, as on every other sheet (they sat in
  the system's glass pill). Your Three are kept however the sheet closes.
  The album page has the glass back button its neighbour has.
- **Presses.** Opening a crew, the goal, your day's rows, a strip, and the
  crew's details gives the light tap everything else gives. Choosing ticks.
  "Unblock", the crew photo's "Edit", the sticker list's "Edit" and the
  plan's "Others" and "Hide" are full 44 point targets.
- **One of each.** One unread dot (it was 8, 9 and 10 points). One quiet
  second word. The crew sheet's row glyphs are the app's form glyph. A
  member with no photo gets an initial in the app's own face.

### Left, and why (REVIEW)

**Needs a phone or real iCloud, so I did not guess:**
- A crew send that is waiting or failed looks sent. Showing that touches
  the crew's sync, which I cannot run here.
- The camera's size words sit in interactive glass, a pairing that has
  swallowed taps elsewhere. If Quick, Regular, Deep on the camera ever
  ignore a press on your phone, this is why.

**Looks the same today, so it is duplicated code, not a visible break:**
the chat's writing bar is a copy of the plan's; the plan's row is built in
six places; the word tab in three; Suggest in two; the tick chip in two;
the small filled pill in two; counts in three places outside the shared
readout. Each is a refactor with risk and nothing to see. Next pass, one at
a time, with screenshots.

**Small, and I was not sure of your taste:**
- The empty segments of the goal ring are very faint. You asked for a ring
  that only fills, so I left it.
- The crew fan's panel has a 28 point corner, which is on no ladder.
- Glass capsules have five slightly different insets.
- About fifty spacing numbers in the crew screens are written as numbers.

**The suites:** 1,385 unit tests pass, with a new suite (`TenTests`) that
holds each fixed rule in place. The full run had two UI failures, a first
launch that waited too long for the film and a camera gesture; both pass
when run alone, and neither touches what changed.

**Also, at your word the same morning:** the Settings logo is the camera
drawing in ink on the page, with no dark tile behind it.


## 9. The asks that came in while that ran (2026-10-11)

**Hints.** A reader listed every hint in the app (ten), with its words,
where it stands, what shows it and whether it is still true.
- **They wait their turn now.** Each checked only that the add sheet was
  shut, so one could be spent behind the plan, a crew or the booth, and
  each landed while the ring was out in the middle of the screen. All wait
  for a clear tower and for the ring to go home. The invite card leaves by
  itself after 12 seconds; it used to stay until closed and block the
  day's cue.
- **Words.** "Hold the slot and pull it out." gave no direction: now "Drag
  the slot sideways or up." "One more and your tower dances." wrapped: now
  "One more and it dances." Onboarding promised the tower "prints the
  day's strip", and a day of plain blocks prints none: now "The day's
  photos print as a strip."
- **A new one.** The first time a planned win stands on the tower:
  "Planned wins wait here. Tap to take it. Hold for more." Planned wins,
  the add sheet's Now and the block's menu had no hint anyone could see.
- **A real dead end, found on the way.** With Reduce Motion on, the slot
  only makes Quick blocks, and onboarding's first page waited for a bigger
  one. Nobody with Reduce Motion could get past page one. Fixed.
- One style: the tip card, under the header. The house card's second line
  now uses the tip's type.

**The + and the checkboxes in dark, again.** You: they "have a different
hue from the other liquid glass elements". They did: I had lifted them
with white in the glass. They are the page's own glass now, the same
recipe as every round button and capsule on a page. No outline, no hue of
their own.

**Quick, after choosing Regular or Deep.** The camera hands back Quick
when you only press the shutter, and that overwrote the size chosen on the
sheet. A size is taken from the camera only when one was drawn there.

**Move Photo.** Hold the block on the add or edit sheet, or hold a photo
in the strip's editor: Move Photo opens the picture in its frame, and it
follows your finger. The block on the sheet now shows the crop (it drew
the middle whatever the crop was, even one set at the camera). Seen
working on the add sheet. **Not seen on the strip**: the simulator's
seeded strip has one flat picture and no row of photos to hold.

**Albums.** Hold one: Remove Album, or Never Show (that title, that crew,
or past days). Undo for five seconds; Settings, Memories, Removed Albums
brings any back. Wins and photos are never touched. Cards are 152 points,
up from 108. Making your own album: not built; the reasoning and the
cheap version are in `docs/research-2026-10-11.md`.

**Add sheet and plan sheet.** The field says the same thing in both
("Plan for tomorrow"); a planned line is the same height in both; the row
of suggestions is not offered while planning (it planned things twice).
**Not done:** the add sheet still types in a bold field at the top where
the plan types in a bar at the foot, and Return behaves differently. That
is the biggest difference left and it is a rebuild of the add sheet's
plan mode.

**Your Three: kept, and connected.** One is not listed twice when a plan
line has the same words; hold one in the plan for Change Your Three.
**Not done:** they are still not in backups.

**Research, written up in `docs/research-2026-10-11.md`:** albums, strip
templates, scanning a paper journal page, and moving colours into the
block's menu (which waits for your yes, since it overturns three of your
earlier calls).
