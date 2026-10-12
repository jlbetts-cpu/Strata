# The flows, rated

The owner, 2026-10-11: "rate the flows out of 10 and work in tandem on
unifying the experience. I want whoever uses the app to instantly
understand how to do things; the app should feel familiar even though
they've never used it." And: "similar flows should feel the same."

A flow is a 10 when a person who has never seen the app does it right the
first time, with no hint, and the next flow like it works the same way.
The rules that make flows alike are in `docs/ten.md`.

| Flow | Now | What holds it back |
|---|---|---|
| Add a win (press the slot, name it, Add) | 8 | Nothing says the block itself is pressable for a photo or doodle until you press it. |
| Quick win (hold the slot, or draw it out) | 6 | The app's signature and its least familiar move: a hold that DOES the thing. Taught once in onboarding and once by a tip. |
| Photo win from the Camera tab | 8 | The size words on the review. |
| Plan from the plan sheet | 8 | The row of days scrolls and Repeating is off the right edge. |
| Plan from the add sheet (Now) | 6 | "Now" does not look pressable, and you type in a different place from the plan sheet. |
| Finish a planned win | 7 | A press opens the camera, which surprises anyone who only wanted to tick it. Library and no-photo are behind a hold. |
| Edit or delete a win | 8 | Fine. |
| Move, replace or remove a photo | 6 | All behind a hold on the block. |
| Journal (note, mood, sketch) | 8 | Fine. |
| Start a crew and invite | 7 | The link still says github; a first-timer does not know a crew needs iCloud until told. |
| Crew chat and reactions | 7 | Hold a win for reactions is not hinted. |
| Memories (month, day, albums) | 8 | Hold an album is new and unhinted. |
| Photo strip (develop, doodle, share) | 7 | "Shake to develop" is the only way shown. |
| Settings, backup, restore | 8 | Fine. |

## The three holes a new person can fall in

1. **Everything good is behind a hold.** Doodle, Move Photo, Choose from
   Library on a planned win, Remove Album, Skip Today, reactions. A hold is
   invisible. iPhone apps answer this the same way every time: the thing
   also has a visible "more" control, or the first press opens a menu.
2. **The slot does two things.** Press opens Add; hold logs at once. A
   person who holds by accident has made a win (Undo covers it), and a
   person who never holds never finds the fast way.
3. **A planned win opens the camera.** It is a checkbox, and a press does
   not tick it.

## What would unify them (for the owner to choose)

One rule would close all three: **a press on a block-shaped thing opens
the same short menu everywhere.** The add sheet's empty block already does
this (Take Photo, Choose from Library, Doodle). A planned win would open
the same menu plus Log Without a Photo, in place of going straight to the
camera. A block holding a photo would open Move, Replace, Remove. Then
nothing is hold-only, and learning one block teaches all of them.


## Done on 2026-10-11, night

The owner chose the one rule: **a press on a block-shaped thing opens its
short list.** A planned win opens Take Photo, Choose from Library, Log
Without a Photo, Edit, Not Today. The add sheet's block opens Take Photo,
Choose from Library, Doodle and its colours. Planning from the add sheet
is the plan sheet itself. Expected ratings after: finish a planned win 9,
plan from the add sheet 8, add a win 9. To be confirmed on a phone.


## The pass to a 10 (2026-10-12)

The owner: "could you implement all the changes and updates to get it to a
10". Six changes, one for each thing the table said was holding a flow back.

| Was | Now |
|---|---|
| A block with a photo opened the photo; Move, Replace, Remove were hold-only | A press opens the block's menu whatever is on it: View Photo, Move Photo, Take Photo, Choose from Library, Doodle, Remove Photo |
| "Now" on the add sheet read as a caption | A chip that says what it does: Plan for Later |
| Repeating was the eighth word, off the edge of a row that scrolls | A repeat glyph stands still at the end of the row |
| The hold on the slot was taught once, in onboarding | The empty tower says it every morning: "Tap the slot to add a win. Hold it for a quick one." |
| The strip could only be shaken | "Shake or tap to develop" |
| An album could only be removed by a hold on the shelf | Its own page has a "more" button: Remove Album, Never Show |

| Flow | Before | After | What is still short of 10 |
|---|---|---|---|
| Add a win | 9 | 9 | The block is pressable but nothing says so until it is pressed |
| Quick win (hold the slot) | 6 | 8 | Still a hold that does the thing; now said every morning and undoable |
| Finish a planned win | 9 | 9 | Fine |
| Plan from the plan sheet | 8 | 9 | Fine |
| Plan from the add sheet | 8 | 9 | Two steps (chip, then a day) |
| Move or replace a photo | 6 | 9 | Fine |
| Memories, albums | 8 | 9 | Fine |
| Photo strip | 7 | 8 | Its tools are glyphs with no words |
| Crews | 7 | 7 | The invite link still says github; a waiting send looks sent. Both need things outside this code (the domain, real iCloud) |

**Honest total: about 9, not 10.** What is left is the crew side, which
waits on the domain and on a test with two real phones, and the fact that
none of this has been watched in the hands of someone new. These ratings
are mine, from the simulator.
