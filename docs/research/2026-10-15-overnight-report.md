# The night of 2026-10-15: what was researched, what was built, what is yours

**Your brief:** a native chat pull-up, Memories as your profile with a wins score, a fuller Crews page, a chat people would rather use than iMessage, matching icons, Liquid Glass consistency across look-alike flows, everything to the letter of the law, and research written down as it went. Everything below was built, photographed and checked in light and dark, and the unit suite passes.

## Research written tonight (docs/research/)

| Doc | What it answers |
|---|---|
| `2026-10-15-native-chat-sheet.md` | How to build the chat as a persistent native sheet, its pitfalls, and the architecture that shipped |
| `2026-10-15-social-retention.md` | How close-friend apps keep people and lower the fear of inviting. A ranked list of ten things |
| `2026-10-15-chat.md` | What makes a chat feel native, set against our code. A ranked list of ten things |
| `2026-10-15-profile.md` | Memories as the profile, and the score's definition and risks |
| `2026-10-15-social-compliance.md` | App Store 1.2, age laws, COPPA, CSAM reporting and the widget. Gaps ranked |
| `2026-10-15-consistency-pass.md` | 18 places where look-alike things differ, with file and line |
| `2026-10-15-missing-round-two.md` | A second round: first week, notifications, identity, HEYTEA and Muse, dark mode |

## Built tonight

**The chat is a native sheet.** It has three heights:

- Resting, which shows the newest line over the composer.
- Reading, at 62%.
- Full height, which writing takes, with the crew's name on top.

A drag or a tap on the resting line lifts it. The + at rest rises with its row out. The viewer, the week's replay, the crew card and Report all open from the sheet. Add a Win and a planned box's camera come from the app root, so the chat steps aside for them and comes back afterwards. `-strataDrawerChat 1` brings back the old drawer for a side by side.

**Memories is your profile.**

- At the top: your head, your name, and a row of Score, Wins and Crews, with the streak as one quiet line.
- The score is Quick 1, Regular 2, Deep 3. It is counted from your wins every time, so deleting one lowers it and Undo restores it.
- A press on the figures opens Your Score: how it adds up, plus the streak and the trend that used to be on Profile.
- Profile is now Edit Profile.
- Settings is the gear where your picture was.

**Crews opens on who is winning today.**

- A row of every friend's head across your crews.
- A friend who logged today has a ring in their newest win's colour, and a press opens that win.
- A friend who hasn't logged yet is faded.
- An Invite circle at the end asks one more friend into your smallest crew.

**The chat:**

- One to three emoji draw large, with no bubble.
- Links open in Safari.
- A tap on a reaction chip shows who chose it.
- Replying to a friend's win offers three starters that fill the field and never send on their own.
- Send gives a light haptic.
- Pictures hold their place while they load.
- A "New" marker shows where you left off.
- A friend's line can be hidden for you.

**Notifications:** a friend's win alert offers 🔥, ❤️ and Reply, and a chat alert offers Reply. Both work without opening the app.

**Crew tower cards**, one at a time:

- Catch Up: the days you missed, replayed.
- The crew's week, from Sunday at five.
- A one-time tip about the crew widget.

**Consistency and Liquid Glass:**

- Crews' corner buttons now sit where Wins and Memories have theirs, with the same glyph size.
- The Plan's days, the add sheet's When, Quick/Regular/Deep, and Day/Week/Month now all use one glass bar.
- "Plan for Later" is glass.
- Every writing bar's placeholder uses the app's quiet ink.
- Settings and its pages use the glass back button.
- The stickers sheet closes with Done.
- Doodle's disabled Send is dimmed once.

**Dark mode:**

- Page glass is lifted, so the field, + and Send are visible again.
- Your chat line is a raised grey instead of white.
- Sheets stand a step lighter than the page.
- Widgets keep their colour on tinted Home Screens.

**To the letter:**

- Crew names, first names and win titles are word-checked on every phone that receives them.
- A crew can't be named with refused words.
- Report has "It involves a child".
- The rules say zero tolerance and link the Terms.
- The widget is privacy-sensitive on a locked phone.
- The privacy policy now describes the widget.

**Also built tonight:**

- **Catch Up:** back in a crew after a day or more away, a card plays the days you missed. It counts friends' wins, never the days you were gone.
- **Do It Too in the chat:** a friend's win line offers Do It Too in its hold menu.
- **Increase Contrast:** the app now responds to the setting; the greys and the glass step up.
- **A dark-mode seam is gone:** the light edge on the top of the tower now stays inside the block.
- **Small fixes:** the Journal's empty line now matches the chat's, and two buttons no longer tick twice.

**Two code reviews, every finding fixed:**

- The tagged-win question shows again.
- What opens from under the chat steps the chat aside: a crew plan box's menu, the plan card's strip, your blank head's maker, and the list's alerts.
- Opening a crew from a notification no longer races the old crew's chat.
- Reply works when the chat is already up.
- Answers from a notification read the crew first and never lose a typed reply in silence.
- **Crew names:** they're kept as typed and filtered only where they're shown. Before, a new crew photo could save a blanked name for everyone.
- Names are checked by whole words and endings, so "Kyson" passes and plurals of slurs don't.
- The glass size bar is accessible again. The UI tests caught it.

**Checked:**

- The unit suite passes: 1596 tests.
- The tower, touch-target and launch UI tests pass.
- Every screen was photographed in light and dark.

## Left for you (decisions, not done)

1. **The resting chat is a floating card.** On iOS 26 a native sheet below full height floats with rounded bottom corners, and nothing can turn that off. It's the curve you rejected on 2026-10-14. On the simulator it reads clean. Look at it on your phone. If it's still a no, `-strataDrawerChat 1` shows the drawer for comparison.
2. **Should crew mates see your score?** The research recommends no for now, because it would turn into comparison.
3. **Planning with a crew from the tower's slot** still goes through Add a Win's plan mode. From the chat and the Crews list it opens the plan sheet. The audit wants one path; the code says the Add a Win path was a deliberate choice.
4. **The Plan/Journal switch is plain words** under the new glass day bar. Your design doc has that switch locked as no glass, so it's your call.
5. **Deleting a plan line from its own sheet still asks first**, while a swipe deletes it with Undo.
6. **Compliance items that need you:**
   - Where to sell 1.0: the audit says US, CA and NZ first.
   - NCMEC registration and a CSAM runbook.
   - The new social-media age-rating questions in App Store Connect.
   - Review Notes with a seeded crew.
   - Whether Reset All Data should also leave every crew.
7. **Needs your drawings or a new target:**
   - A seasonal head look each month.
   - Numbered monthly photo-strip papers.
   - A notification content extension.
   - A Messages sticker pack of your head.
8. **From the fresh-eyes critique** (`2026-10-15-fresh-eyes-critique.md`), these touch things you have settled:
   - **The crest past the goal** reads like a date ("14/3").
   - **The Journal's `text.alignleft` icon** looks like a hamburger menu.
   - **Truncation:** one-cell blocks cut titles to one line.
   - **The crew back button** reads "‹ 1".
   - **Dark-mode switches:** the on track is close to off.
   - **New Crew's glyph** looks like "new message".
   - **Memories:** it is titled "October" above your profile.
   - **The replay's falling blocks** cover its header.
9. **The invited first run:** someone who arrives by a link goes straight to the friend's tower and sends their first win there. Research ranks it first, but it means reworking onboarding.
