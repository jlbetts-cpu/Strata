# A new feature for the crew's top-right corner (research, 2026-10-14)

The owner, verbatim: "im not a big fan of the add friends button in the top
right of the crew since its already in the middle can we think of some other
feature to put there". Offered Plan, Today's Strip, Camera for this crew or
empty, he answered: "keep researching what about a feature the app doesnt
have rn".

Read-only pass over `~/Developer/Strata` at `9b8cd8b` (Build 139). Nothing was
built. This follows `docs/crew-corner-research-2026-10-14.md`, which chose
Invite (now in the corner at `CrewTowerView.swift:650-656`, and the thing he
wants gone). Tags: **(a)** research, data or Apple's docs, **(b)** seen in a
shipping product or its own help pages, **(c)** my inference. Sources at the
foot. Product claims rest mostly on press and help pages; dated ones are said
to be dated.

## The answer

**Wave.** A glass circle with `hand.wave` in the corner. One press: your head
pulls one of its own faces (grin, wink, laugh) and that same face pops onto
every friend's crew tower, with one quiet push, "Sam waved." Nothing to
write, nothing to answer, nobody singled out. It rides the chat's existing
line and ping, so **no CloudKit Console deploy**. Small build.

The ambitious alternative is **Drop** (rank 2): everyone's heads fall through
today's crew tower like the portfolio's marble race. More distinctive, and a
large build.

---

## 1. What the crew already has, so "new" means new

From the code. These are **not** candidates, because they exist:

| Asked about | Already in the app | Where |
|---|---|---|
| Weekly crew recap video | **Recent Days**: play a day or a week, saved as a video | `CrewStatsSections.swift:253-379` ("Play a day or a week to save it as a video.") |
| Group photo booth strip | Today's Strip, the booth, Make a Strip on a group plan | `CrewInfoSheet`, `Views/Strip`, `docs/crew-plus-design.md` §2 |
| A shared goal | Group plans ("Gym at 6", I'm In, "Rildy just did the workout") and the crew streak | `Social/GroupPlan.swift`, `CrewStatsSections` |
| Reactions with your face | Reactions are emoji and stickers. **Your head is never a reaction** | `CrewReactions.swift` |
| Something thrown onto the tower | **Removed** 2026-10-10: "dont understand the point of the feature" | `Social/CrewToss.swift` |
| A widget | Your own tower and Log a Win only. No crew widget | `StrataWidget/` |
| Any game | None in the app. His portfolio has head soccer, the marble race and a tournament | `~/Downloads/portfolioo_v392/play.html` |
| A way to say hi without words | **None** | |

The lesson of the removed toss (c): a tower toy has to explain itself on first
sight and leave nothing behind to tidy, or he takes it out.

### What the transport allows without the Console (c, from the code)

- Everything in a crew is one public record type, `CrewItem`, whose `kind` is
  a string and whose fields are a sealed box (`PublicCrewCloud.swift:1-25`). A
  new kind of thing needs **no new CloudKit field or type**, only client code.
- A chat line can carry a marker nobody types and be drawn as something else
  (group plans and strips already do: `GroupPlan.swift:9-14`,
  `CrewPingRecord.stripMarker`). Such a line is sealed, paced
  (`CrewSendThrottle`), word-checked and cleared at midnight for free.
- Pushes go by `Ping` records; each phone's subscription matches
  `kind IN crewKinds` (`CrewPingPlan.swift:35`). **Reusing the `message`
  kind needs nothing new; a new ping kind needs every phone to re-save its
  subscription, and older builds never hear it.**
- Under 16, a head never leaves the phone (`CrewAge.sendsPhotos`), so any
  head feature shows their placeholder to friends.

---

## 2. What other apps students use with close friends do

| Product | Feature | What it is | Tag | Take for us |
|---|---|---|---|---|
| **BeReal** | RealMoji | A reaction that is a photo of your own face; six, one per post; unlocks an Instant RealMoji | (b) [B1][B3] | **Your face as the gesture.** We already have the faces: the head's captured expressions |
| BeReal | Bonus BeReal | Post on time and earn two more posts that day | (b) [B2][B4] | Earn-by-punctuality is pressure. No |
| BeReal | Dual camera, 2-minute window | Front and back at once, at a random time each day | (b) [B5] | The window is a clock on you. No |
| **Locket** | Home Screen widget | Friends' live photos on your Home Screen, up to 20 friends | (b) [L1][L2] | Strong, but a widget is not a button (section 4) |
| Locket | Rollcall | A weekly photo dump each Sunday, visible for seven days, prompted by a **Live Activity**; ~80% of posters 13 to 17 (company figure) | (b) [L1] | Our Recent Days week already does this job |
| **Retro** | Weekly recap | Each friend's week as a card; recaps by week, month, year; private likes | (b) [R1][R2] | Exists here as the crew's week replay |
| **Snapchat** | Snap Games, Bitmoji Party | A rocket in the chat starts a game for the chat's people; Bitmoji Party, up to eight; 100M+ played (2019 to 2020 figures) | (b) [S1][S2] | **Games with your avatar, inside the group.** The precedent for Drop |
| Snapchat | Streaks | Daily back-and-forth count. 26% of 13 to 21 year olds felt their time was too high, 42% would drop the streak | (a, survey n=300) [S3]; (b) | The pressure the owner refuses |
| Snapchat | Snap Map (Zenly's tech) | Friends' locations on a map; Zenly shut 2023 | (b) [S4][S5] | Surveillance. No |
| **Instagram** | Notes | 60 characters above the inbox for 24 hours, to friends or Close Friends; replies land in DMs | (b) [I1][I2] | A status over your head: candidate 3 |
| **Partiful** | "Boop" | Send a random emoji to another guest instead of a message; shared photo roll | (b) [P1] | **A wordless poke is a shipping pattern for this age** |
| **Gas** | Anonymous compliment polls | "Who has the best smile", flames, paid hints at who | (b) [G1][G2] | Ranks people. No |
| **Finch** | Good vibes, visits | Send good vibes, hugs, "wave hello" to a friend's bird; no shared tasks | (b, reviews) [F1] | Warm, wordless, no pressure: the Wave's tone |
| **Habitica** | Party quests | Your missed dailies damage the whole party | (b, wiki) [H1] | Shame by design. No |
| **Duolingo** | Friends Quests, nudges | Paired weekly shared goal; nudges are prewritten "go practise" messages | (b) [D1][D2] | The quest is close to fine; the nudge is pressure |
| **Strava** | Group challenges, kudos | Up to 25 athletes; ranked leaderboards; kudos is the like | (b, press) [K1] | The rank is the problem |
| **Apple Fitness** | Competitions | 7 days, points from your rings, alerts when you fall behind | (b) [A1] | Head to head. No |
| **Discord** | Activities | Games and apps inside a voice channel (Embedded App SDK, 2024) | (b) [DC1] | Play together inside the group space |
| **Widgetable** | Co-raised pets, "Miss You" | Friends raise a pet together; a "Miss You" button; signals to a friend's screen | (b) [W1][W2] | Another wordless "thinking of you" |
| **Yope** | Group walls, games next | Private group photo wall, avg age 18; "soon, playing games" | (b) [Y1][Y2] | Small groups are moving toward games |
| **Lapse** | Disposable camera | 36 shots, you cannot see them; they develop later | (b) [LP1][LP2] | Candidate 4 |
| **Dispo** | Shared rolls | Shots develop at 9 AM next day; rolls shared with friends | (b, 2021) [DS1] | Candidate 4 |

### What the research says

- **Wordless pings sustain close ties.** "Phatic" technologies carry contact,
  not information; couples valued short emotional pings because they asked
  no reply (a) [Q1][Q2][Q3]. That is a wave.
- **Cooperation helps, but competition can help more, at a price.** In a
  randomized trial of 602 adults (STEP UP, *JAMA Internal Medicine* 2019),
  competition raised steps more than collaboration (a, via a secondary
  summary; verify against the paper) [Q4]. The Köhler effect makes partners
  try harder when the team depends on its weakest member, but always being
  the weak link erodes it (a, meta-analysis of 19 studies) [Q5]. Both argue
  that a ranked or weakest-link design works by pressure, which the owner has
  refused. Said plainly: the app gives up some measured lift to keep its
  tone (c).
- **Live Activities**: the HIG says not to offer one for a task over eight
  hours; the system ends it at eight (a) [AP1][AP2]. A friend's win reaching
  your Lock Screen needs a push to the activity's token, which is sent by a
  server (c). This app has none.

---

## 3. Five candidates

Each: what one press does, why it fits, why this corner, glyph, heads and
tower, what it must not become, build size, CloudKit.

### 1. Wave (recommended)

- **One press.** A light tap haptic. Your head, in the corner, plays one of
  its own captured faces (grin, wink, laugh; never the same twice running,
  the tower head's rule, `design.md` row 82) and that same face pops onto
  the crew tower for everyone: on an open crew screen, your head springs out
  of the top right, plays the face, settles. Anyone not on the screen gets
  one push, **"Sam waved."**, titled with the crew; opening the crew plays it
  once. A notification action, **Wave Back**, waves without opening the app.
- **Why it fits.** The one social act the app lacks is a way to say "here,
  thinking of you" that costs nothing to send or answer: Partiful's boop,
  Finch's wave, Widgetable's Miss You (b), phatic research (a). It makes the
  head the gesture, which is RealMoji's idea (b) done with the face the app
  already holds, and it pushes the heads-as-identity brief. College students
  in a crew of two to eight are exactly the strong-tie case the research is
  about (c).
- **Why this corner.** Used often, one press, no screen behind it, and it
  belongs to this crew. It is never a second door to something (Invite, the
  card, the chat, Plan).
- **Glyph.** `hand.wave`, on the page glass circle (`GlassIconButton`), the
  same clear glass as Back. Spoken "Wave", hint "Waves at this crew."
  (Owner's option: your own head small in the circle instead.)
- **Heads and tower.** The face is your real one. A head with one face (a
  photo head) does a small hop instead. Under 16, friends see the placeholder
  hop. The corner's frame stays in `parking.controls` so heads meet it.
- **Must not become:** aimed at one person ("Wave at Ana"); about an absence
  ("hasn't logged yet", "your crew is waiting"); counted ("3 waves"); a
  streak of waves; seen or read marks; a reminder to wave; automatic. No
  exclamation mark; folds as "Sam and Ana waved." with no number.
- **Pacing.** One wave a person a crew an hour, more is dropped quietly
  (`CrewSendThrottle`, a new `wave` kind, local only); pushes share the
  chat's one-a-crew-an-hour hold. Not shown as a chat line.
- **Build.** **Small**: a marked chat line (marker plus "👋", so an older
  build shows a hand), the arena playing a take on arrival, the extension's
  words, one notification category. Device test only (crews do not sync on
  the simulator).
- **CloudKit.** None. A marked `CrewMessage` with the existing `message`
  ping.

### 2. Drop (the ambitious one)

- **One press.** Every crew member's head falls from the top of the screen
  through **today's crew tower**, bouncing off the blocks as pegs, the
  portfolio's marble race on the crew's own wins. Ten seconds; the heads
  settle on the slot; the tower is back. The more the crew logged, the
  richer the course.
- **Why it fits.** The only candidate that could only exist in this app: his
  heads, his tower, his own games (b, portfolio). Snap Games and Bitmoji
  Party (b), Discord Activities (b) and Yope's roadmap (b) show groups want
  to play inside the group space. Pure chance, so no one is better at it.
- **Why this corner.** A toy you reach for while waiting on the crew; the
  heads are already loose on this screen.
- **Glyph.** `circle.grid.cross.down.fill` or his drawn marble; an owner
  call.
- **Must not become:** a leaderboard, a tally of who landed first, a daily
  "race is ready" push, anything won or lost, or something left on the tower
  after it ends (the toss lesson).
- **Build.** **Large**: the JS physics ported to Swift with a fixed timestep
  in a fixed logical space. A shared race (everyone sees the same fall) needs
  the seed and the block list sent as a marked line (c); a local-only first
  version needs no network.
- **CloudKit.** None (local); none for shared (a marked line).

### 3. Note

- **One press.** A one-line field, 60 characters. Your words float in a
  small bubble over your head on the crew tower until the crew's midnight:
  "library till 9", "ask me about the interview". Instagram Notes (b).
- **Why.** A status attached to your head, lighter than a chat line; it
  gives the floating heads something to say.
- **Against.** Close to the chat, which already clears at midnight; a
  second place to write (c). He may read it as the chat again.
- **Must not:** be a feed, keep history, show who read it, or say where you
  are.
- **Build.** Small to medium. **CloudKit.** None (a marked line, word-checked
  by `CrewWords`). Under 16 without writing: absent.

### 4. Roll (develop at midnight)

- **One press.** The camera opens on this crew's roll. Shots go to the crew
  undeveloped: blank frames on the tower beside your head. At the crew's
  midnight they develop into the morning's strip, "Last night's roll." Dispo,
  Lapse (b); the booth's develop already exists.
- **Why.** Photos are the crew's best engagement, and the camera is out of
  reach inside a crew (5 taps, earlier research).
- **Against.** It is a camera, which he just declined as an option. Under 16
  cannot send photos, so the button is dead for them. The photo check runs
  per shot. Biggest privacy surface of the five.
- **Must not:** reveal early, save friends' shots to Photos, count shots.
- **Build.** Large. **CloudKit.** No Console change: a new `CrewItem` kind
  with the photo in `a`. Ping: reuse `message` or a new kind (re-subscribe).

### 5. Week (a shared jar)

- **One press.** A card: one drawing of his (a jar, a tower outline) that
  fills with every win the crew logs this week toward a number the crew set.
  No split by person. Full: the dance and a strip.
- **Why.** Duolingo's Friends Quests (b); the Köhler lift (a).
- **Against.** His own brief for group plans: "Not a challenge, not
  competitive" (`crew-plus-design.md` §2), and "no challenges anywhere". A
  deadline and a number are streak pressure; Köhler's lift comes from the
  weak link, which is the person this would shame (a) [Q5]. Overlaps the
  crew streak.
- **Build.** Medium. **CloudKit.** None (a marked line holds the target).

### Rejected for the corner

| Idea | Why not |
|---|---|
| Crew widget | Good feature, wrong place: no API places a widget from the app, so the button could only explain how (c). Worth doing on its own; a ping could reload it from the notification extension (c) |
| Crew Live Activity | Friends' updates need a push server; eight-hour limit (a) [AP1] |
| Weekly recap | Exists (Recent Days, Play a week) |
| Photo booth together | Exists (Today's Strip, Make a Strip) |
| BeReal Bonus / timed "now" moment | A clock on people (b) [B2] |
| Nudge someone who has not logged | Notifies about an absence (`voice.md`) |
| Map or presence | Surveillance (b) [S4] |
| Polls about each other | Ranks people (b) [G1] |

---

## 4. Ranking

| Rank | Feature | Fits taste | Heads / tower | Often used | Build | Console |
|---|---|---|---|---|---|---|
| 1 | **Wave** | High | Your real face, on everyone's tower | Daily, many | Small | None |
| 2 | Drop | High, most "his" | Heads through the crew's own wins | Daily | Large | None |
| 3 | Note | Medium (chat overlap) | Bubble over the head | Daily | Small-medium | None |
| 4 | Roll | Medium (a camera) | Weak | Some days | Large | None |
| 5 | Week | Low (a challenge) | Weak | Weekly | Medium | None |

**Why Wave first.** It is the one thing the app cannot do today that people
do with close friends every day: reach out without words. It costs one
press, asks nothing back, makes the head the message, and adds no number,
no clock and no record type. It also does the job he wanted Invite to do,
bringing people back into the crew, without being a second door to the
middle. Drop is the better showpiece and could follow as the corner's hold
or its own release; it should not block a small, right thing.

## 5. The owner's calls

1. **Wave or Drop** in the corner (Wave recommended; Drop is larger and more
   his).
2. Wave's push: on (recommended, one a crew an hour) or in the app only.
3. Wave's glyph: `hand.wave`, or your own head in the circle.
4. **Wave Back** from the notification: yes or no.
5. Invite leaves the corner entirely (it stays in the card and the
   one-time "Just you so far." tip).

---

## Sources

Products
- [B1] BeReal, RealMoji: https://help.bereal.com/hc/articles/7536240858653
- [B2] BeReal, Bonus BeReal: https://help.bereal.com/hc/articles/10388190752669
- [B3] BeReal, Instant RealMoji: https://help.bereal.com/hc/en-us/articles/17845941900445-Instant-RealMoji
- [B4] Bonus BeReal launch: https://alternativeto.net/news/2023/4/bereal-announces-20-million-daily-active-users-and-introduces-bonus-bereal-feature-in-the-uk
- [B5] Dual camera copied by Instagram: https://www.digitalcameraworld.com/news/instagram-copies-bereal-with-a-dual-camera-feature-in-latest-update
- [L1] Locket, Rollcall and Gen Alpha (TechCrunch, 2025-11-03): https://techcrunch.com/2025/11/03/lockets-social-app-is-picking-up-steam-with-gen-alpha
- [L2] Locket listing: https://apps.apple.com/us/app/1600525061
- [R1] Retro recaps: https://techcrunch.com/2023/12/07/retro-lets-you-create-recaps-of-your-most-memorable-photos-and-send-the-best-ones-as-postcards
- [R2] Retro: https://techcrunch.com/2023/07/07/retro-is-a-deeply-personal-photo-journaling-app-for-close-friends/
- [S1] Snap Games launch: https://www.engadget.com/2019-04-04-snap-games-bitmoji-party-tiny-royale-snapchat.html
- [S2] Snap Games explained: https://www.techadvisor.com/article/733834/what-are-snapchat-games-and-how-do-i-play-them.html
- [S3] Snapchat gamification study, 13 to 21: https://edri.org/our-work/new-study-reveals-how-young-people-are-influenced-by-gamification-features-on-snapchat/
- [S4] Snap Map: https://techcrunch.com/2017/06/21/snap-map/amp/
- [S5] Zenly shutdown: https://blog.pragmaticengineer.com/zenly/
- [I1] Instagram Notes launch: https://iol.co.za/technology/2022-12-14-instagram-launches-new-features-including-notes-and-candid-stories/
- [I2] Notes, 60 characters, 24 hours, Close Friends: https://influencermarketinghub.com/instagram-notes/
- [P1] Partiful boop and photo roll: https://www.nbcmiami.com/news/business/money-report/meet-partiful-the-gen-z-party-planning-staple-thats-taking-on-apple/3595614/
- [G1] Gas: https://techcrunch.com/?p=2471372
- [G2] Gas: https://pcgamer.com/gas-was-exploding-so-discord-bought-it
- [F1] Finch friends (review): https://chiltonm.bearblog.dev/everyone-i-know-is-addicted-to-the-bird-app/
- [H1] Habitica, boss damage (community wiki): https://habitica.fandom.com/wiki/Rest_in_the_Inn
- [D1] Duolingo Friends Quests: https://blog.duolingo.com/friends-quests/
- [D2] Duolingo friend streaks and nudges: https://blog.duolingo.com/friend-streak/
- [K1] Strava group challenges (2021): https://www.bikeradar.com/news/strava-group-challenges
- [A1] Apple Watch, share and compete: https://support.apple.com/guide/watch/apd68a69f5c7
- [DC1] Discord Embedded App SDK: https://alternativeto.net/news/2024/3/discord-unveils-embedded-app-sdk-opening-game-and-app-development-within-the-platform/
- [W1] Widgetable listing: https://apps.apple.com/us/app/widgetable-besties-couples/id1641107226
- [W2] Widgetable: https://www.ithinkdiff.com/widgetable-long-distance-lock-screen/
- [Y1] Yope (TechCrunch, 2025-02-24): https://techcrunch.com/2025/02/24/yope-is-sparking-genz-and-vc-interest-with-an-instagram-like-app-for-private-groups
- [Y2] Yope, average age 18: https://fastcompany.com/91285942/yope-wants-to-be-your-inner-circles-instagram
- [LP1] Lapse: https://fueled.com/blog/lapse-disposable-camera-provides-retro-vibes/
- [LP2] Lapse, friends not followers: https://www.ypulse.com/newsfeed/2023/11/02/lapse-a-2021-launched-photo-app-with-the-motto-friends-not-followers-is-making-waves-in-the-social-media-scene/
- [DS1] Dispo: https://www.cnbc.com/2021/03/04/dispo-for-iphone-is-the-picture-sharing-app-everyones-talking-about.html

Research and Apple
- [Q1] Mediating intimacy, phatic technologies: https://cis.unimelb.edu.au/hci/projects/intimacy
- [Q2] Kjeldskov et al., couples' short emotional pings (CHI 2005 LBR): https://vbn.aau.dk/files/218296084/Kjeldskov_C28.pdf
- [Q3] Welight, phatic communication (CHI 2017 LBW): https://homes.cs.washington.edu/~luisceze/publications/welight-lbw-chi17.pdf
- [Q4] STEP UP trial summary (secondary; check the JAMA paper): https://getfitcraft.com/science/competition-vs-collaboration
- [Q5] Köhler effect meta-analysis: https://pmc.ncbi.nlm.nih.gov/articles/PMC6523870
- [AP1] HIG, Live Activities: https://developer.apple.com/design/human-interface-guidelines/live-activities
- [AP2] Live Activity eight-hour limit (Apple Developer Forums): https://developer.apple.com/forums/thread/797676

In the repo: `Strata/Views/Crews/CrewTowerView.swift` (header 633-656),
`CrewHeadArena.swift`, `CrewStatsSections.swift`, `Social/GroupPlan.swift`,
`Social/CrewToss.swift`, `Social/PublicCrewCloud.swift`,
`Social/CrewSendThrottle.swift`, `Social/CrewPingPlan.swift`,
`NotifyShared/CrewNotes.swift`, `Models/HeadTake.swift`,
`docs/crew-corner-research-2026-10-14.md`, `docs/crew-plus-design.md`,
`docs/heads-as-identity-2026-10-14.md`, `docs/voice.md`.
