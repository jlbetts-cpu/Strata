# On this day: the flashback

The owner, 2026-10-12: "I feel like Snapchat does the memories the best,
being able to bring up previous memories from years prior ... research
into memories on Snapchat, understand what they do and finish that up ...
create a strict grading curriculum for it to pass and keep iterating until
it is intuitive, minimal and easy to use."

## What the others do

| Product | What triggers it | Where it shows | Leaving it |
|---|---|---|---|
| Snapchat Flashback | A saved Snap at least a year old, to the day; shown as a story | A featured story in Memories | Three dots, Dismiss; a Flashback switch in Settings |
| Google Photos | Time-based memories ("X years ago") | A carousel above the photo grid | Remove this memory; hide a date or a face |
| Apple Photos | Memories and featured photos | Collections, a widget | Hold, Feature Less |
| Timehop | The same date in any past year, new each morning | The whole app | Gone after 24 hours |
| Facebook | The same date, back to the account's start | A page and the feed | Hide people or date ranges |
| Day One | Entries from this date in past years | A tab, the calendar | Off per journal |

What they share: the exact date, one a day, and an easy way to say "not
this". What goes wrong when they do not: Facebook's year in review showed
people things they did not want to see ("inadvertent algorithmic
cruelty"), which is why removing must be one obvious step and why nothing
is pushed at you.

Not verified: where exactly Snapchat puts it on screen and its share
options (the help pages were read through search results, not opened).

## What Some Wins had

A "year ago today" album needed three photos from a date a year back, and
only showed under this month's photos when this month had a photo. **A
person at launch would see no flashback for a year.** The only thing from
the past was an 8pm notification about an old win.

## The design

1. **The exact date, on a ladder:** years ago, then six months, then one
   month. The furthest back that has something wins. One a day.
2. **One month is the youngest.** Anything nearer is last week, which the
   weekly replay already covers.
3. **Under a year, at most once a week.** Someone who photographs every
   day would otherwise get one every day.
4. **A date that does not exist is skipped.** March 31 has no "a month
   ago today".
5. **One photo is enough.** No photo, no card.
6. **It is the first card on the albums shelf** in Memories, and the shelf
   shows for it even when this month has no photos yet. Nothing new on the
   first screen: the owner took a past-win line off that screen once
   ("I liked the look of the memories screen before that was added").
7. **It is an album card like the others**, titled "A month ago today",
   with the real date under it.
8. **A press opens that day's page.**
9. **Hold it to remove it**, as any album: Remove Album, Never Show Past
   Days, with Undo, and Settings brings it back.
10. **It is gone at midnight.** It is worked out, never stored.

Not built, on purpose: a new section or heading, "a week ago", titles
written by a model, streaks, an archive of past flashbacks, friends'
flashbacks, a second notification.

## The rubric. Every line must pass.

**Honest**
1. Over every day of 2024 to 2028, a flashback's source day has today's
   day of the month, and its title's unit equals the real gap. March 31
   and February 29 produce nothing false. (unit test)
2. A source day with no photo gives no card. (unit test)
3. Over 90 days in a row, no source day shows twice in seven days, and
   cards under a year old number at most one in any seven days. (unit test)
4. After Remove, it is gone for that day and its wins and photos are
   untouched; after Never, there is none for 400 days. (unit test)

**Intuitive**
5. One press on the card opens a page whose title is the source date.
   (screenshot)
6. The title is one of a fixed set of strings, with no long dash and no
   "missed". (unit test)
7. The card is first on the shelf whenever it exists, including in a
   month with no photos yet. (unit test and screenshot)

**Minimal**
8. Never more than one flashback card. No new kind of card, button or
   heading was added to draw it. (unit test; reading the diff)
9. With no flashback due, Memories is pixel for pixel what it was.
   (screenshot compare)
10. Light and dark, looked at: no shadow, nothing white in dark. (screenshots)

**Easy**
11. Hold, Remove Album: the card goes, Undo brings it back first on the
    shelf. (unit test of the store; screenshot)
12. A store with exactly one photo, one month ago today, shows the card
    with its cover filled, and a press opens the day. (screenshot)
13. VoiceOver reads the title and the date, and both remove actions have
    names. (reading the code)

"One tap to dismiss" is not on the list: in this app a hold is the menu
(`docs/ten.md`, rule 2), so removing is a hold and a tap, as for every
album.
