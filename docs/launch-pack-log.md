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
`tasks/app-store-metadata.md`. **Open, his call:** which keyword
arrangement to paste.

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

Designed, not built, at your word: `docs/crew-plus-design.md`. It needs
four answers from you.
