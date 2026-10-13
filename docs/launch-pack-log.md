# Launch Pack: the running log

The owner's doc, "Some Wins — Launch Pack" (2026-10-12), worked item by
item. He chose, in chat the same day: **safe parts first** (voice, crew
wording, sharing copy, the listing sheet), **he pastes the listing
himself**, and **the new crew builds are designed first, then built**.

Each entry: what the doc asks, what the app already had, what changed,
and what is still open. A number out of 10 is mine and is about the item,
not the app.

## Where the doc and the app disagree

| The doc says | The app, as built | What was done |
|---|---|---|
| The crew chat's plus button "only offers challenges" | There is no plus button in crew chat and no challenge anywhere in the code | The plus row is a new build, in the design below, not a fix |
| Tip example: "Hold a win to make it bigger" | A hold on the slot logs a quick win; the size is drawn out of the slot | The real gesture is what is written (`docs/voice.md`, last section) |
| Keyword field 2 is English (U.K.) | The U.S. store does not read that field | The sheet has his fields as written and the same words arranged for the U.S. (`tasks/app-store-metadata.md`) |
| "35 unique keywords", field 1 "94/100" | 36 words; field 1 is 100 of 100 | Counted in the sheet |
| "habit" as a hidden keyword | Ruled out of the listing on 2026-10-05 | In, as the newer call, and said so in the sheet |

## 1. App Store listing

**Asked:** name, subtitle, three keyword fields, description, to paste.
**Done:** every field counted against Apple's limits and read against the
app. All fit. Nothing in the description is untrue. The sheet is
`tasks/app-store-metadata.md`. **His pick, 2026-10-12:** the arrangement
for the U.S. store. **10 once pasted.**

## 2. Voice and copy

**Asked:** one hand for every string. **Had:** the hard rules already held
(a sweep of 1,605 strings found no exclamation mark, long dash or stock
motivation line). So this was a judgement pass, by four readers working
apart (lock screen, crews, in the app, sharing), then me deciding.

**Changed, outside the app**
| Was | Is | Why |
|---|---|---|
| "Anything else today?" (7pm notification) | "Still room on today's tower." | No questions from the lock screen. The in-app bubble still asks. |
| "Your week is ready" / "September is ready" | "Your week, put together." / "September, put together." | His words |
| "A year ago today" + the win's name | "A year ago today." and nothing more | It invites; the name waits inside |
| "March 4" + the win's name | "A win from March 4." | The same, and it says what it is |
| "Roommates is sharing tonight's wins." | "Your crew's tower is open too." | Written hours before anyone had posted; and an unnamed pair read "Sam is sharing..." |
| Widget "Quiet here. Yet." on a day with wins and no photo | "3 wins today" | It was untrue |
| Lock screen widget "0 today" | The second line alone | An empty morning is not a score |
| Shortcuts "Completed Today" | "Logged Today" | One word per thing |

**Changed, in the app**
| Was | Is | Why |
|---|---|---|
| "What have you done so far?" | "Done something today?" | It reads as a telling-off |
| "Drag the slot sideways or up." | "Pull the slot sideways or up." | Onboarding says pull; one verb |
| "...dances and prints the day's strip." | "...dances. The day's photos print as a strip." | Untrue on a day with no photos |
| "None of the last 14 days reached 3 yet." | Nothing | A count held against you; the bars show it |
| "Keep logging to see your trend." | "A few more weeks to see your trend." | "Keep" anything is the stock line |
| "One More Thing" on two pages running | "Go On", then "Two More Things" | Two pages follow the second |
| "Today counts. Nice work, crew." | "Today counts." | Praise the day had not asked for |
| "...Add a time with @ 2." | "...Type @ 2 for a time." | It is typed |
| Backup errors with the system's text in brackets; "no wins.json inside it" | Plain, with what to do | No codes, no file names |
| "2 wins in this backup doesn't say..." | "...don't say..." | Grammar |
| Replay "Couldn't save", press again, fails for ever | The app's "Couldn't save to Photos", with Open Settings | A dead end |

**Kept on purpose:** the morning reminder (it exists only on a day with no
win, but it is one you set, and says nothing about the gap); "3 new in
Roommates" and "Look what your crew is building. 30 days." (both your
words); "We made this for you." is not added anywhere, because the recap
screens have no sentences at all and you chose that.

**Held by test:** `VoiceTests`, and the tests that pinned the old words
were changed with the reason beside each. **7 of 10 until you have read the
new lines on a phone;** the judgement is yours.

## 3. Crew, item 1: any size

"Up to 8 friends / You included." is "You and a friend, or a few / Two is
a crew. So is eight." "Invite People" is "Invite". "Waiting for people to
join." is "Just you so far." Nothing advertises eight; the limit is still
said where it is a refusal. A pair with both in reads "You're both in
today." An unnamed crew's invite no longer reads "Join Sam on Some Wins".
**9.** Not done: a crew of one has no Invite on its own tower (it is two
taps away, in the crew's page).

## 4. Crew, items 2 and 3: no scorekeeping, and a quiet member

A reader mapped every place a crew counts, ranks or marks a person.
**Found none of:** a leaderboard, a badge, a stake, a penalty, a greyed
head, a "hasn't posted", members sorted by activity, anything red.

**Found one real one, and fixed it.** A pair's day needed both people. One
of them quiet for four days ended the pair's run, and it stayed at nothing
however much the other posted; in a pair "everyone sends a win" means one
known person. **A pair now keeps a day when either sends a win**, as three
keep it with two (`CrewHistory.needed`). For three or more nothing changed.

**To know:** each phone works the run out for itself, so while Friends are
on mixed builds a pair can see different numbers until both update.

**Left alone, said here:** the tower's "everyone's in" dance still needs
everyone (a bonus missed, not a penalty); reaction counts on a block are
still shown. **9.**

## 5. Crew, item 6: invites

**Had:** a link, a skip at every step, and the first win before any ask
(the card "Your win is up. Who else should see it?" comes 1.4 seconds
after the first win, and leaves by itself). **Fixed:** the invite's title,
and the link's card (the app's name, your line, the logo).
**Not built, with reasons, in `docs/crew-plus-design.md` part 4:** codes
and a link that installs and then joins. Contacts: the share sheet's own
row of people is that. **7**, held there by the address still saying
github until somewins.xyz points at the page.

## 6. Crew, item 7: notifications across crews

**Had:** one win sent to three crews makes one notification, not three;
chat rings at most once a crew every five minutes. So no flood.
**Found, not fixed:** the opposite. That one notification is filed under
one of the crews, so a friend who is only in the other two is not told at
all. The fix touches how a crew is pinged and the notification extension,
which is sync code I cannot run: it is in the design, to be done with a
second reader and your phone. **6.**

## 7. Crew, item 8: reactions

**Had:** a double tap hearts a win; a hold opens 🔥 👑 ❤️ and a plus for
any emoji; a chat line takes those and your stickers. **Fixed:** two likes
on two blocks inside half a second showed the second and quietly dropped
it; the pace is per block now. **Not built:** a sticker on a win (it uses
the reaction's record in a new way, so it goes with the crew builds). **8.**

## 8. Sharing

| The brief | Now |
|---|---|
| A post: the strip alone, no link, QR or sticker | As it was: the share sheet hands over the picture alone, on a clear ground |
| "Never a name or words stamped onto the image" | The strip's foot is the wordmark and the date. It read "Jayden · Oct 6", your pick of 2026-10-07; a crew's strip carried the crew's name. Both off. |
| A message: the strip, your line, the link as its own card | New row in the strip's share sheet, **Text a Friend**: the picture, "Today was a good one. Some of it's in here." (yours to change before sending), and the app's page on the last line |
| The card: Some Wins, your line, the app logo | Done on the invite page and on a new plain page for the app |
| One smart link | Not built; why is in the design, part 4 |

The link on a strip is the app's page, never a crew's invite: an invite
link is the crew's key. **Unseen on a phone:** whether Messages draws the
link as its own card. **7 until you have sent one.**

## 9. Crew, items 4, 5 and 9: the plus row, group plans, looking back

Designed first, at your word: `docs/crew-plus-design.md`. **Approved
2026-10-12, all four as recommended, and built the same night**; the
design's last section says what differs from it and why. The plus row has
Win, Plan, Strip, Memory and Sticker. A group plan is a card with I'm In;
finishing it sends the win to that crew; the card names who did it. A day
this crew saw is shown to you and sent by a tap. **7 until two real phones
have tried it**: none of it has touched real iCloud.

## 10. The rest of the crew list, and the listing entered (2026-10-13)

You: "build the rest of the things". Built: a sticker on a win; every crew
told of a win sent to several; the invite as a code; a crew's week as a
replay. A second reader found six real faults in them (a sticker turning
into a bare star the next day was the worst) and they are fixed. What
changed at your word the same day is in `docs/crew-plus-design.md`.

The App Store listing was entered by a separate agent at your word: name,
subtitle, description and the U.S. keyword arrangement, in three
languages, on version 1.0. Read back and matched. Nothing submitted.
**Still empty there:** screenshots, a build, the support URL, the age
rating.

**Still 7 for the crew work as a whole:** none of it has run on real
iCloud or between two phones.

## 11. The doc checked against the app (2026-10-13)

You: "check the doc make sure you executed everything and check your work,
rate it, if it's under a 10 fix the changes". Read again line by line. What
the first pass left out, and what was done about each:

| The doc | What the app had | Now |
|---|---|---|
| "Your best Sunday in three weeks." / "Day three. Don't look now.", with the full detail inside the app | Nothing: the evening had only "Still room on today's tower." | `DayNote`. Said only when true (three wins at least, and more than the same weekday for two weeks back that the app has any record of; or day 3, 7, 14, 30, 50, 100 running). It takes the evening's one quiet 8pm slot in place of the past win, so the evening still holds one line. In the app, after eight, once: "Eight wins today." over "Your best Sunday in three weeks.", with "Good one to look back on." about one day in three. It follows the Past Wins switch. |
| Empty: "Nothing logged yet. Just the start of the day." | "Tap the slot to add a win. Hold it for a quick one.", every morning, to everyone | His line, once someone has five wins and so knows the slot. The teaching line stays for anyone new. |
| Quiet stretch, in the app only: "You've been quiet a few days. No rush." | Nothing | The empty tower says it after three days without a win. Never in a notification, never a number. |
| "Your crew had a day." | The crew's evening always said "Your crew's tower is open too." | Said when it is already true as it is written: friends have sent three wins there today. Otherwise the line that is true whoever posts. |
| "Rildy just did the workout." | A crew plan done read like any win: "Sam: Workout" | "Sam just did Workout", in the app's own notification and the one iPhone draws when the app is shut. |
| "We made this for you." | Left out on purpose: the recap screens carry no sentences | Under the month's recap notification, once a month. Still nowhere on the recap's own screens, and not under the week's, where fifty times a year would wear it out. |
| "This day last month" | "A month ago today" | His words. |
| Landing headline "Win with your people." and "Every win stacked." | The page said the link card's line | On the app's page. The link card keeps your card line. |
| Validate the keywords in Google Trends | Not done | Done, U.S., past 12 months, four terms compared: "adhd app" leads most of the year (about 45 on average, 75 at its June peak), "photo journal" is close behind, "habit tracker" spikes once at New Year (100) and otherwise sits near 30, "accountability app" is the weakest (about 12). Rising under "adhd app": "adhd cleaning planner". So the listing's lead words are the right ones, and "accountability" earns its place only as a hidden keyword, which is where it is. All four fall together in mid July, which reads as Trends changing its sampling, not as people. |

**Written down as not built, with the reason:** invite codes that are typed
and one link that installs and then joins (`docs/crew-plus-design.md`, part
4); inviting from Contacts (the share sheet's own row of people is that,
and reading Contacts would be a permission this app has never asked for).

### Found the same day, by you

- **A crew's plan is a box on the crew's tower.** "When you plan something
  in the crew chat they should show up as a checkbox block in the crew
  tower ... if the other person accepts it it also goes as a checkbox on
  their crew tower." Your own tower's box, drawn by the same view, holding
  only that crew's lines. Press it for the same menu. It is still a line of
  your own plan, so it stands on your own tower too.
- **The plan's line stays in the chat.** "Why did it disappear from the
  chat when I dismissed the notification." Closing the card, in the chat or
  on the crew's screen, hid the line in your chat for the day. The line has
  no close now, and a card closed on the crew's screen closes only there.
- **One album for mostly the same photos.** "The album shared with, like
  there is two and it's just duplicate photos." The check caught exact
  twins only. A crew's album now shows when most of it is new.

### The marks, after this pass

| Item | Was | Now | What holds it there |
|---|---|---|---|
| 1. Listing | 10 once pasted | 10 | Entered and read back. Screenshots, build, support address and age rating are still empty there, and are yours. |
| 2. Voice and copy | 7 | 9 | Every line the doc wrote is in the app. One short of 10 until you have read them on a phone. |
| 3. Any size | 9 | 9 | |
| 4. No scorekeeping | 9 | 9 | |
| 5. Invites | 7 | 7 | The address still says github. It is your three steps at the registrar and GitHub (`tasks/unification-log.md`, "somewins.xyz"). |
| 6. Notifications across crews | 6 | 8 | Built on 2026-10-13. Unproven between two phones. |
| 7. Reactions | 8 | 9 | A sticker on a win, and your own win takes yours. |
| 8. Sharing | 7 | 7 | Until you have sent one and seen the card in Messages. |
| 9. Plus row, plans, looking back | 7 | 8 | The plan is a box on the crew's tower now. Unproven on real iCloud. |

## 12. The flows, read end to end (2026-10-13)

You: "look through all the flows and doc to see if we are missing anything
or can help the user's experience become smoother", and four things you
found yourself the same afternoon. Three readers went through the code
apart (the keyboard and every popup; every flow against these docs; then
the day's own changes, looking for what they broke).

**Yours, fixed**

| You said | What was wrong | Now |
|---|---|---|
| "When I click to add a photo in the add a win it doesn't pop up right when the keyboard is there" | With the name being typed the block sits just above the keys and its menu hangs below it: 20 to 90 points of room for a menu of 213 | The keyboard is put away first and the menu opens into the room. The same for Who Was There and the two Replaces. Walked on the simulator: three rows, all pressable |
| "The strip, you can't even send it to the chat" | The plus row's Strip opened your booth, which develops only once the goal is reached | Today's strip is shown and Send puts it in the chat |
| "When editing a planned win should have the option ... just for that day or change it for all" | A rename changed every day | Done on a renamed repeating line asks: Just Today, Every Time. Just Today keeps the repeat's name, takes it off today and puts a one-off with the new words in its place. Not asked of a crew's plan |
| "It still sends me the url" | Checked with the phone's own link previewer against the live page: the link makes a card with the logo and "Some Wins". The address under it is github's, and a tap goes through a web page | Both end when somewins.xyz is on: `tasks/launch-checklist.md`, part 2. The page that lets a link open the app is in the repo, waiting |

**Found by the readers, fixed**

- An invitation is kept until it is answered. It lived in memory: close
  the app at the rules, or during the first run, and it was gone.
- Not Today on a planned box says what it did and can be taken back.
- Add waits for a photo chosen from the library.
- "In your plan · Undo" no longer lies on the chat's message field.
- A crew notification tapped the next morning opens its win.
- Never Show Past Days stops the evening's "A year ago today." as well.
- A crew plan finished from one crew's tower goes to that crew alone. As
  first built it also went to whichever crew your last win did.
- Tonight's note is worked out when it is shown, so it cannot say three
  over a tower of four; and a Sunday with nothing on it ends the count
  ("in eleven weeks" after a lapse was a count of the gap).

**Found, not done: yours to call**

1. **A build from the App Store has no crews.** They are on in TestFlight
   only, by design, until you say so. An invite link does nothing in a
   store build, and the page's Get Some Wins button points at TestFlight.
2. **Onboarding, page one.** A plain hold drops a block, but only a block
   pulled wider lets you go on, and only VoiceOver is told why.
3. **Replays and Past Wins in Settings** show as on before notifications
   were ever allowed, and then send nothing.
4. **Delete, then Undo, on a win a crew has.** The crew's copy goes at
   once and Undo brings back only yours. Sync code: wants a second reader
   and your phone.
5. **Joining without iCloud.** The account is checked last, after the
   rules and the age; the alert has only OK.
6. **The booth marks the day as printed before it opens.** Close it early
   and today's strip has no way back in from the tower.
7. Smaller: Settings never says iCloud is off; the note's notification
   tapped next morning lands on a bare tower; one join error still speaks
   of "a different Apple Account".

**A note on a win, in the journal** (your idea, researched, not built):
`HabitLog.note` already exists, is in backups, is held out of crews by a
test, and no screen uses it. So no new iCloud field. The quiet apps
(BeReal's caption, Things, Gentler Streak) add the note after the thing
exists, at the thing, with nothing drawn until then. Recommended: one line
under the name in a win's Edit sheet; once a day has a note, the journal
draws that day's wins above your own words, live, never saved into them.
Not in Add, where a second line would push the block behind the keys.
