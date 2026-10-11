# Planning ahead

Written 2026-10-10 with the feature. What it is, why each choice was made, and
what the references do. Every claim about another product or a study is
marked: (product) seen in its own docs or listing, (study) a source, (ours) an
inference of ours.

## What it is

- **A plan line has a day.** Today, tomorrow, any of the next six days, or
  it repeats on weekdays you choose. No times, no durations, no priorities.
- **Today's open lines stand on the tower** as clear glass outlines behind
  the slot: one Quick cell each, no colour, the line's words and the plan's
  empty box. A press opens the camera to finish one; a hold offers Take
  Photo, Log Without a Photo, Edit, Not Today.
- **The plan sheet has a row of days**: Today, Tomorrow, the week, Repeating.
  Its bar adds to whichever is chosen. A pasted list becomes a line each.
- **The add sheet has one word, Now.** Pressed, it is the same row of days
  with Now first; choose a day and the sheet writes plan lines, a line a
  Return.
- **Nothing is ever "missed".** A one-off whose day went by is not on the
  next day's tower or list. It waits in the plan under Earlier, where one
  word moves them all to today and a swipe lets one go. It is never deleted
  for you. A repeating line simply returns on its next day.

## The test it was built to

The owner's: "plan their entire next day in under 15 seconds: open it, type a
few bullet-point wins, done". Measured in the simulator, slot to tower, three
lines typed at four characters a second: **13.3 seconds**
(`FeedbackShots.testPlanningTomorrowIsQuick`). Through the plan sheet it is
one press shorter.

## Why each thing is the way it is

**An outline, not a block.** The tower once drew unfinished habits as faded
coloured blocks and stopped: they made it busy, and "the tower is the record".
Colour is what the app spends on things that happened. A planned win is the
slot's own glass, quieter than the slot.

**Always Quick.** A win's weight is decided when it is done, at the shutter
or in the sheet. A plan that asks for it is asking too early.

**Behind the slot.** The slot stands where the next block lands, and a block
drawn out of it has to land in it. So outlines queue after it and step along
as the tower grows. When one is finished its block lands at the slot's cell
and the slot hops into the cell the outline left: the others do not move.

**Eight at most.** Two rows. The rest of a long plan is in the plan, and the
queue moves up. An outline is a cue; a wall of them is a debt.

**Not counted.** The goal counts wins.

**No new stored field.** The day is written into the field the weekdays use,
with its weekday in front (`2,d:2026-10-12`). A new field needs the iCloud
schema deployed from the console before a TestFlight or App Store phone can
save one, and until then that phone's whole sync stalls. A phone still on a
build from before reads the number and shows the line on that weekday; a
bare `d:...` would have been hidden there (found by review).

**Only today's page ticks.** On another day's page, or under Repeating, a
line's box opens the line. A repeating line done today is not shown done
tomorrow.

**Nothing is deleted for you.** For a few hours an Earlier line was let go
after two weeks. The update gives every existing line a day, so a person's
whole old plan would have gone a fortnight later with nothing said. The
app's older rule stands: an unfinished plan never expires by itself.

**Skip Today** for a repeating line is kept beside the model, on this phone,
by day: the model has one row per line and nowhere to put "not this Tuesday".

## What the references do

The owner named Teemo, Ellie, Structured, Google Calendar, Notes and
Reminders. No planner called Teemo was found (teemo.app is a parked domain);
it was read as **Tiimo**, the ADHD planner.

| | Worth taking | Worth avoiding |
|---|---|---|
| Tiimo | "Anytime" tasks need no clock time; an optional end-of-day "remaining tasks" with one press to move to tomorrow (product) | Streaks and trophies; its own psychologist writes that streak tracking can deepen a shame spiral (product) |
| Ellie | "No dates, no decisions" at capture; repeat and due dates off until asked for (product) | "Anything unfinished rolls over"; its own guide recommends a monthly clean-out of the list (product) |
| Structured | Repeat is one row: Daily, Weekly, Monthly. Leftovers handled one card at a time, off by default (product) | A new item asks for a title, an icon and a duration; a badge marks tasks moved three times (product) |
| Google Calendar | Repeating tasks appear by themselves; leftovers collapse into one entry (product) | That entry is a running count going back a year (product) |
| Notes, Reminders | Return continues a list; a typed "tomorrow" is offered as a chip and applied only on a press, so a title is never mangled (product) | Reminders' Today list puts Overdue first (product) |

Sources:
tiimoapp.com/resource-hub/how-to-start-planning,
tiimoapp.com/resource-hub/designing-routines-for-adhd-brains,
ellieplanner.com, guide.ellieplanner.com/features/the-brain-dump,
help.structured.app/en/articles/338178, .../4511874, .../338114,
support.google.com/calendar/answer/9901136,
workspaceupdates.googleblog.com/2022/02/manage-overdue-tasks-in-google-calendar.html,
support.apple.com/guide/notes/apd93c815aa0/mac,
macstories.net/stories/ios-and-ipados-13-the-macstories-review/12.

## What the studies say, and do not

- If-then plans raise follow-through (d = 0.65 across 94 tests; Gollwitzer
  and Sheeran 2006) and helped children with ADHD in small samples (Gawrilow
  and Gollwitzer 2008). (study)
- Planning for several goals at once can lower commitment, because it shows
  how much there is (Dalton and Spiller 2012). (study) So: no backlog, and
  no more than two rows of outlines. (ours)
- Adults with ADHD report criticism for lapses as the most damaging
  (qualitative, n = 162; PMC8856522). (study) A "missed" mark is criticism
  from the app. (ours)
- **Not found:** that planning the night before raises follow-through. The
  one study (Baylor, 2018) is about falling asleep nine minutes sooner. So
  the plan does not open on Tomorrow in the evening by itself.
- No number of items a day is empirical (1-3-5, Ivy Lee's six, three "most
  important tasks" are all advice).

## Not built, on purpose

- Times, durations, reminders per line. One cue a day stays the rule.
- Typed dates ("tomorrow", "every weekday") turned into chips. The row of
  days is one press and cannot mangle a title. Worth adding if people ask.
- Reordering lines. There has never been a way; the tower's queue follows
  the order they were written in.
