# Strata: a stronger concept, and a structure that turns social cheaply

Written 2026-09-16. Research only: no checkout was edited, nothing was built, no
simulator was run. Code claims were read from `/Users/jaydenbetts/StrataWork/owner-head`
(HEAD `b252e01`). Web sources carry URLs at the end of each section; every claim is
tagged **(a)** research, **(b)** a shipping product, or **(c)** my inference.

Owner's words: *"maybe a game wouldn't be the best idea. Let's focus on researching
features that can make the concept stronger. I want to eventually make this a social
media app, so making sure the structure would lend well when we convert would be great."*

---

## Summary in ten lines

1. **Concept:** Strata turns things you already did into blocks that stack into a tower of your days. Record, not plan; made visible, not measured.
2. **Build next:** (1) log from the Lock Screen and Control Center, (2) "On this day" resurfacing in Memories, (3) one optional line of reflection at the close of Your Week.
3. **Social model:** small invite-only circles (Locket/Retro scale, not followers). Friends get your *week*, once, after it closes, as the replay. They answer with a cheer, never a count.
4. **Everything is private until you send it.** Sharing publishes a *copy* of a week or a win to a circle; the private record never becomes the feed. Place is never included unless you add it per share.
5. **Structure today:** good bones (UUIDs on most rows, a pure `WinRecord` value type, pure replays, photos re-encoded with no EXIF). Missing: `updatedAt`, a stable user id, a time zone on a win, and any boundary between views and SwiftData.
6. **Now, change #1:** fold `updatedAt`, `id` defaults, `timeZoneIdentifier` and a random `profileID` into the same migration as the 31 CloudKit defaults the iCloud plan already needs. One schema change instead of two, and CloudKit schemas are add-only once live.
7. **Now, change #2:** put a `WinStore` repository between views and SwiftData, speaking `WinRecord`. The CloudKit mirror, later a shared zone or a server, becomes an adapter behind it.
8. **Now, change #3:** keep the shareable parts separable: `WinPhoto` as its own model (already planned), a small derivative size, and place kept off every shareable payload by a tested rule.
9. **The iCloud plan does not box Strata in**, provided social is a separate store. SwiftData cannot use CloudKit's shared or public databases; circles need `CKSyncEngine` or a real backend, and a real backend becomes necessary for invites to non-iPhone friends, moderation at scale, or anything bigger than 100 people.
10. **Never:** a public follower feed, like counts, streak leaderboards, "seen by", or a friends map of live location.

---

## 1. The concept, sharpened

### The idea in a paragraph

Most self-improvement software starts from the future: a goal, a schedule, a streak
you might break. Strata starts from the past. You did something, you tap, and it
becomes a block that falls into today's tower. Nothing asks what you should do next,
nothing grades the size of the thing, and nothing is lost if you skip a day. Over
weeks the towers become a record you can walk back through: a month of blocks, the
photographs you attached, the places they happened, and a replay that rebuilds your
week in eighteen seconds. The psychology behind this is the best-supported idea in
the whole space: small, visible progress is the strongest everyday driver of good
days (Amabile and Kramer's 12,000 diary entries), and looking back at good things
you did improves wellbeing more than planning more of them (Seligman's "three good
things"). Strata is that research turned into an object you can hold.

**The sentence a stranger should understand:**

> Tap when you've done something, and watch your days stack up into something you built.

### What makes it different, specifically

| App | What it is built around | Where Strata differs |
|---|---|---|
| **Habit trackers** (Streaks, HabitKit, Habitica) (b) | A list of things you *should* do, checked daily; streaks punish gaps | No list, no schedule, no gap. The owner kept habits in a spreadsheet because the app demanded planning first (`docs/product-direction.md`). Strata records the unplanned win as readily as the planned one. |
| **Day One** (b) | Writing. A blank entry, optional media, "On This Day" | Words are optional. The unit is one tap and one block, and the accumulation is *visual* rather than a list of entries. |
| **Apple Journal** (b) | Writing prompted by on-device suggestions (photos, workouts, places) and reflection prompts | Also private and on-device, but Journal asks you to write about moments; Strata asks nothing and shows you a structure. Journal has no sense of accumulation. |
| **1 Second Everyday** (b) | One second of video per day, compiled into a film | 1SE records *what the day looked like* and obliges a daily capture. Strata records *what you did*, any number of times a day, zero times on a bad one, and its film is the replay. |
| **BeReal** (b) | A random daily alert, two minutes to post both cameras, friends only | BeReal decides *when* and the audience is the reason to post. Strata is yours first; you choose when; nothing is late. |
| **Strava** (b) | Measured performance: pace, distance, segments, leaderboards, kudos | Strava's value is the number. Strata refuses to measure quality: a walk and a marathon are both a block, and the size is your call. |
| **Locket** (b) | A photo sent straight to up to 20 friends' home screens | Locket is ephemeral and has no record. Strata is cumulative; the photo is attached to a thing you did. |
| **Retro** (b) | Your week's photos, shared with close friends, reciprocal | The closest cousin. Retro is "what my week looked like"; Strata is "what I did this week". Retro's weekly rhythm and small audience are the model to learn from (section 3). |
| **Partiful** (b) | The future: an event, invites, RSVPs, by link | Opposite tense. Its lesson is distribution: an invite that works for people without the app. |

Sources: Amabile & Kramer, "The Power of Small Wins", HBR, May 2011, https://hbr.org/2011/05/the-power-of-small-wins (a) · Seligman et al., *American Psychologist* 60(5), 2005, as cited in `research-game.md` (a) · Apple Newsroom, "Apple launches Journal app", Dec 2023, https://www.apple.com/newsroom/2023/12/apple-launches-journal-app-a-new-app-for-reflecting-on-everyday-moments/ (b) · 1 Second Everyday, https://en.wikipedia.org/wiki/1_Second_Everyday (b) · Retro, TechCrunch, 7 Jul 2023, https://techcrunch.com/2023/07/07/retro-is-a-deeply-personal-photo-journaling-app-for-close-friends/ (b) · Locket friend limit, https://help.locket.com/en/articles/7915024-how-many-friends-can-i-have-on-locket (b) · Partiful, CNBC, 19 Apr 2025, https://www.cnbc.com/2025/04/19/meet-partiful-the-gen-z-party-planning-staple-thats-taking-on-apple.html (b)

---

## 2. Features that strengthen the core, before social

Judged on four axes. **Depth**: how much it deepens "I did something, I can see it,
I can look back at it". **Cost**: S (days), M (one to two weeks), L (a month or a
new target). **Minimal risk**: how much it threatens the one-tap, nothing-in-front
feel. **Award fit**: whether it reads as craft (Apple Design Award categories:
Delight and Fun, Interaction, Innovation, Social Impact, Visuals and Graphics).

| # | Feature | Depth | Cost | Minimal risk | Award fit | Verdict |
|---|---|---|---|---|---|---|
| 1 | **Log from the Lock Screen and Control Center** (iOS 18 `ControlWidget` running the existing `LogWinIntent`; Action button for free) | High: makes the core rule literally true from outside the app | S | None: it removes steps | Interaction | **Build** |
| 2 | **"On this day"**: a card at the top of the Memories drawer when a past date has wins, opening that day's tower and photos | High: a reason to return that is a gift, not an obligation | M | Low if it is one card, no badge, no notification by default | Delight | **Build** |
| 3 | **One line of reflection at Your Week's close**: "What made this week?" A single optional field under the finished tower; skippable by doing nothing | High: turns a record into meaning; becomes the caption if the week is ever sent | S | Low if it never blocks the replay and never nags | Social Impact | **Build** |
| 4 | **Your Year**: the year's towers side by side, and a year replay in late December | High, once a year; the natural share moment (Letterboxd's Year in Review, Spotify Wrapped) | M | Low | Visuals | Next, before December 2026 |
| 5 | **Block icons** (fully specced in `research-block-icons.md`) | Medium: character without a photograph; makes blocks legible to others later | M | Low: it is the block's own relief | Visuals | Next |
| 6 | **Tag people in a win** ("with Maya"): a name, optionally from `CNContactPickerViewController` (no Contacts permission needed) | Medium now, high later: it is the seed of "together wins" in a social version | M | Medium: a second field on the win sheet; keep it behind the existing detail, never on the slot | Social Impact | Later; store the data shape now (section 4) |
| 7 | **Journaling Suggestions**: "wins you might have done" from workouts, photos, places, people, picked by the user in Apple's picker | Medium: helps the forgetful evening log | M | **High**: it is a suggestion list, which is one step from a to-do list, and it needs the `com.apple.developer.journal.allow` entitlement and a device to test | Innovation | Later, and only as a picker the person opens |
| 8 | **Apple Watch one-tap log** | High for people who wear one | L: a new target, a new sync path before iCloud exists | Low on the watch, but it splits engineering time | Interaction | After iCloud sync ships (a watch without sync is a second, disagreeing record) |
| 9 | **Win templates / "again"**: long-press the slot to repeat one of your own recent titles | Medium: speed for repeat wins | S | Medium: the road back to a habit list, which was deleted on purpose | None | Only as recents of your own past wins, never a list you maintain |
| 10 | **Place memories**: on the map, "You were here before" when a new win lands inside a cluster that already has wins | Low to medium | S | **Copy risk**: this is exactly where "watching" language creeps in | Delight | Later, with copy reviewed against the Words rule |
| 11 | **Live Activity for logging** | Low | M | Medium | None | **Do not build.** A Live Activity is for an event in progress with an end; logging a finished win has no duration. The Control widget does the job. |

### The top three, and why

**1. Lock Screen and Control Center logging.** The product's settling rule is that
recording a win is the fastest thing in the app. The fastest path is not opening the
app at all. `LogWinIntent` already exists (`Strata/Intents/LogWinIntent.swift`) and
the widget already supports `.accessoryRectangular`, so this is wiring, not design.
Evidence: the owner's own behaviour (a spreadsheet beat an app that added steps) and
the Fogg behaviour model's point that ability, not motivation, is the cheapest lever (a).

**2. "On this day".** Nostalgia is one of the few return triggers with evidence of
*benefit* rather than compulsion: experimentally induced nostalgia raises meaning in
life, self-continuity and social connectedness (Sedikides and Wildschut, many studies
since 2006) (a). Day One ships "On This Day" and Apple Photos' Memories and Google
Photos' resurfacing are both built on it (b). Unlike a streak it cannot be broken,
and unlike a notification it asks nothing. It also rehearses the social version: a
past week arriving is the private analogue of a friend's week arriving.

**3. One reflective line at the week's close.** Writing down what you learned for
15 minutes at the end of a day improved test performance 23% in a field experiment
(Di Stefano, Gino, Pisano, Staats, 2014) (a); Apple Journal ships reflection prompts
on gratitude, kindness and purpose for the same reason (b). Strata's version must be
far smaller: one line, one moment a week, at the place attention already is (the
replay's close). It makes the replay mean something and gives any future shared week
its caption without asking anyone to write a post.

**Retention caution** (from `research-game.md`, which stands): expected rewards tied
to logging reduce intrinsic motivation (Deci, Koestner, Ryan 1999) and broken streaks
demotivate (Silverman and Barasch 2023). None of the three above is contingent on
logging, and none can be failed.

Sources: Di Stefano et al., "Learning by Thinking", HBS WP 14-093, 2014, https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2414478 (a) · Van Tilburg, Sedikides, Wildschut, Vingerhoets, *EJSP* 2019, https://onlinelibrary.wiley.com/doi/abs/10.1002/ejsp.2519 (a) · Sedikides & Wildschut, *Emotion Review* 2025, https://journals.sagepub.com/doi/10.1177/17540739241303497 (a) · Apple, Journaling Suggestions, https://developer.apple.com/documentation/journalingsuggestions (b) · Letterboxd 2025 Year in Review, https://letterboxd.com/journal/2025-letterboxd-year-in-review-faq/ (b)

---

## 3. Social: what kind, and why

### How comparable apps went social

| App | What they did | What happened | Lesson for Strata |
|---|---|---|---|
| **Strava** | Kudos (one tap), comments, clubs, public segments and leaderboards | Received kudos measurably make people run more and more often (Lambert et al., *Social Networks*, 2022) (a). Qualitative work finds the same kudos bring comparison and "self-surveillance", worst when injured (a). The 2018 global heatmap exposed military bases because sharing was on and privacy settings were confusing (b). | A one-tap response works. Leaderboards and default-public location do not belong in a record of small wins. |
| **BeReal** | Random daily alert, two minutes, both cameras, see friends only after you post | Peaked ~20M DAU in 2022, down ~48% by early 2023; sold to Voodoo in 2024 for ~€500M (b). Research shows the "late" label created the very pressure the app claimed to remove (a). | Reciprocity ("post to see") works. A clock you can fail does not. Friends-only apps die when the circle goes quiet, so the app must be worth opening alone. |
| **Locket** | Up to 20 friends; photos land on their home screen widget | 70M+ downloads (b). The cap is marketed as the anti-pressure feature; unlimited friends is the paid tier (b). | A hard small cap is a feature, and a natural paid line. The home screen is the feed. |
| **Retro** | Your week's photos, to close friends; you see four weeks back; a "key" for more; nudged to share one photo a week to see friends'; no likes, no follower counts | Launched 2023; raised a $21M Series A in Aug 2026; monetises with a subscription for extras, not ads (b). | **The closest template.** Weekly, reciprocal, small, no metrics. |
| **Instagram Close Friends** | Stories (2018) then feed posts (Nov 2023) to a chosen list | Widely used; proves people want an audience selector per post (b). The Aug 2025 Instagram Map launched to backlash because users believed location was on by default (b). | Audience per share, chosen at share time. Location is off, visibly, and explained. |
| **Instagram hidden likes** | 2019 tests hid like counts "to depressurize Instagram"; 2021 made it optional | Few creators hide them (<3%) (b), which says counts are sticky once they exist. | Never ship counts; you cannot take them away later. |
| **Day One Shared Journals** | Jan 2024: separate shared journals, up to 30 people, comments and reactions, E2E encrypted, Premium only; private journals can never be shared | Kept the private product intact (b). | Private record and shared space are **separate objects**. Social is a paid-tier candidate in a journal. |
| **Beli** | Log restaurants, rank them, friends' lists, leaderboards and streaks | 75M reviews by 2024; 80% of users under 35; most join by referral (b). | Logging-first apps can go social because friends' logs are useful. Beli's leaderboards suit taste, not personal wins. |
| **Letterboxd** | Private-feeling diary of films, then follows, lists, reviews | 30M+ members by mid-2026; Year in Review is its biggest moment (b). | A diary first, social second, works. The year recap is the viral artefact. |
| **Goodreads** | Public reviews and ratings at scale | Review bombing and weak moderation drove readers to StoryGraph (b). | Public, comment-heavy spaces need moderation Strata cannot staff. |
| **Path** | Private network capped at 50, then 150 | Raised the cap to grow, lost distinctiveness, had an address-book upload scandal in 2012, shut down 2018 (b). | Keep the cap; never upload contacts. |
| **Poparazzi** | Only friends could post photos of you; hype-driven launch | 4M MAU peak to a few thousand; shut down May 2023 (b). | A novelty mechanic is not a reason to return. |
| **Dispo** | Delayed "developing" photos | Founder scandal, then updates that lost users' photos (b). | For a record app, losing data is fatal. Sync must be boring. |
| **Partiful** | Link-based invites that work with no account and no app | ~400% YoY growth (b). | The invite must open for someone without Strata. That needs a web page, which needs a server. |
| **Snap Map** | Location sharing off by default; Ghost Mode; choose which friends | Default-off is now the expected norm (b). | Same default, and Strata never needs live location at all. |

Research on wellbeing: passive scrolling of others' highlights is linked to envy and
upward comparison (Verduyn et al. 2017, 2022) (a), though a 2024 meta-analysis of 141
studies finds the associations small (a). The design implication is modest but clear:
favour sending and answering over browsing an endless feed.

### The patterns that fit a record of small wins

1. **Close friends, not followers.** A small, named circle; no public profile, no discovery.
2. **A weekly recap, not a feed.** A week is big enough to be worth sending and small enough to be honest. Strata already makes the artefact: Your Week.
3. **Reactions, not comments; and no counts.** One tap says "I saw it and I'm glad". Comments invite judgement and need moderation.
4. **Reciprocity, gently.** Retro and BeReal both show that "share to see" gets people posting. Strata's version must not be a gate that punishes a quiet week: a week with one block is a full week.
5. **No clock.** Nothing is late. Your week is ready Sunday evening and stays ready.
6. **Sending is a deliberate act per share.** Never auto-share. Private by default, forever.

### Strata's social model, concretely

**Who you connect with.** A **circle** of up to 12 people you invite by link or
Messages (Locket caps at 20; 12 keeps it "people you'd have dinner with"). You can
be in a few circles (family, friends from school). No usernames to search, no
suggested friends, no contact upload.

**What they see, and when.**
- **Your Week**, once, after it closes (Sunday evening local time), if you choose
  **Send to circle**. It arrives as the replay itself, played on their phone from
  data rather than a flattened video, so blocks and photos are sharp and the tower is
  *yours*: your colours, your head on top if you use one.
- **Your one line**, if you wrote one.
- **A single win**, if you send one on purpose ("Send this win") from the win's own
  sheet. This is for the big ones: the job offer, the first 10k.
- **Never included by default:** place, the map, notes, photos you did not choose,
  any win you marked private, any count across weeks, anything from before you
  joined the circle.
- **What they see of you is four weeks back** (Retro's rule): a circle is a window
  on now, not an archive to scroll.

**What they can do.**
- **Cheer** a week or a win, with one of a small set of block-shaped reactions
  (drawn in the block's own relief, like the icons). The sender sees who cheered.
  **No one sees a number.**
- **"Me too"**: tap a friend's win to log the same thing in your own tower
  ("Maya ran 5k, you ran with her"). This becomes a **together win** when both
  towers hold it, and it is the only way wins cross between people.
- **No comments, no DMs.** Messages already exists and is better at it; a "Reply
  in Messages" link opens a thread.
- **Leave, mute, remove, report.** Always one tap away.

**What stays private by default.** Everything. The record, the map, the gallery,
albums, the head maker, mood, notes. A new install has no circle and never nags you
to make one; the circle row sits in Profile.

**Words the app says** (no long dashes, nothing that reads as watching):

| Moment | Say | Never say |
|---|---|---|
| Sunday close, first time | "Send your week to your circle?" · Buttons: "Send" / "Keep it to myself" | "Share with followers", "Don't break your streak" |
| After sending | "Sent. They'll see it next time they open Strata." | "Delivered and seen" |
| A cheer arrives | "Maya cheered your week." | "Maya viewed your tower", "Maya is looking at your wins" |
| A friend's week arrives | "Sam's week is ready." | "Sam posted! Don't miss out" |
| Place toggle on a sent win | "Add where this was" (off) | "Share my location" |
| Invite | "Start a circle. Just the people you'd tell anyway." | "Find friends on Strata" |
| Empty circle week | "Quiet week. That counts too." | "You haven't posted" |

Sources: Lambert et al., "Kudos make you run!", *Social Networks* 72, 2023, https://www.sciencedirect.com/science/article/pii/S0378873322000909 (a) · Couture, "Reflections from the Strava-sphere", *QRSEH* 13(1), 2021, https://www.tandfonline.com/doi/abs/10.1080/2159676X.2020.1836514 (a) · Strava heatmap, TechCrunch, 29 Jan 2018, https://techcrunch.com/2018/01/29/strava-simplify-privacy-options-review-features/embed/ (b) · BeReal decline, PetaPixel, 22 Feb 2023, https://petapixel.com/2023/02/22/bereal-may-be-on-the-out-users-have-nearly-halved-since-peak/ (b) · "Always-on authenticity", Snyder, *Media, Culture & Society*, 2024, https://journals.sagepub.com/doi/10.1177/01634437231209420 (a) · Retro Series A, TechCrunch, 28 Aug 2026, https://techcrunch.com/2026/08/28/friend-focused-photo-sharing-app-retro-snags-21m/ (b) · Instagram Close Friends on feed, TechCrunch, 14 Nov 2023, https://techcrunch.com/2023/11/14/instagram-brings-close-friends-feature-to-the-main-feed/ (b) · Instagram Map backlash, CNBC, 7 Aug 2025, https://www.cnbc.com/2025/08/07/instagrams-map-feature-spurs-user-backlash-over-privacy-concerns.html (b) · Hidden likes, CreatorIQ, https://www.creatoriq.com/blog/less-than-3-of-instagram-creators-are-hiding-public-like-counts (b) · Day One Shared Journals, TechCrunch, 22 Jan 2024, https://techcrunch.com/2024/01/22/day-one-gets-social-collaborative-shared-journals-feature/ (b) · Beli, YPulse, 23 Sep 2025, https://www.ypulse.com/newsfeed/2025/09/23/beli-is-gen-z-and-millennial-foodies-new-yelp/ (b) · Letterboxd, https://en.wikipedia.org/wiki/Letterboxd (b) · Goodreads, The Conversation, Feb 2025, https://theconversation.com/amazons-goodreads-builds-community-but-breeds-division-indie-rival-storygraph-is-playing-it-safe-and-gaining-ground-250523 (b) · Path, Gizmodo, 17 Sep 2018, https://gizmodo.com/path-the-doomed-social-network-with-one-great-idea-is-1829106338 (b) · Poparazzi, TechCrunch, 1 May 2023, https://techcrunch.com/2023/05/01/once-hot-photo-sharing-social-app-poparazzi-is-shutting-down/ (b) · Dispo, Fast Company, https://www.fastcompany.com/90644409/inside-photo-sharing-app-dispo-second-shot-instagram-killer (b) · Partiful, https://en.wikipedia.org/wiki/Partiful (b) · Snap Map, https://values.snap.com/privacy/privacy-by-product/snap-map (b) · Verduyn, Gugushvili, Kross, *CDPS* 2022, https://journals.sagepub.com/doi/10.1177/09637214211053637 (a) · Meta-analysis of 141 studies, *JCMC* 29(1), 2024, https://academic.oup.com/jcmc/article/29/1/zmad055/7595758 (a)

---

## 4. Structural readiness for social

### 4.0 The one architectural decision that makes the rest cheap

**Sharing publishes a copy. The private record is never the shared object.**

Day One made this call (private journals can never be shared; shared journals are
separate) and it is the right one for Strata (c). Concretely: when you send your
week, the app builds a `SharedWeek` snapshot (win ids, titles, sizes, colours,
icons, the chosen photos as derivatives, your line, your head's small avatar) and
publishes that to whatever social store exists. Editing or deleting a win later
updates or withdraws the copy through a small outbox. Consequences:

- The iCloud private database plan (`research-icloud-backup.md`, option a) stays
  exactly as designed. Social never touches it.
- Moderation, reporting and deletion obligations apply only to what was sent.
- The social backend can be swapped (CloudKit shared zones now, a server later)
  without migrating anyone's record.
- Privacy defaults are enforced in one place: the snapshot builder.

### 4.1 Identity

**Today (code):** there is no user identity at all. `ProfileStore` keeps
`profileName` and a 600px photo in `UserDefaults` and Application Support;
`HeadStore` keeps the head's PNGs and `head.json` in Application Support with
switches in `UserDefaults` (`Strata/Models/ProfileStore.swift:24-31`,
`Strata/Models/HeadStore.swift:149-166`). The iCloud plan adds an `Identity` model
keyed `"me"` and de-duplicated on sync (`research-icloud-backup.md` §5.7, §11.6).

**What CloudKit gives:**
- `CKContainer.userRecordID()`: a stable, app-scoped, opaque id per iCloud account.
  Good as an internal key; it is not a display name and cannot be shown to others.
- `CKShare` participants: identity is the invitee's Apple Account (email or phone
  lookup), with a name only if they allow discoverability. **Max 100 participants
  per share** (b). iPhone-only; no Android, no web.
- The public database: readable by anyone using the app; the developer is
  responsible for its content.

**What a real backend gives:** accounts via Sign in with Apple (a stable `sub`),
handles, invites that open on the web, server-side blocking and reporting.

| Recommendation | Size | When |
|---|---|---|
| Add `profileID: UUID = UUID()` to the planned `Identity` model, generated once and never changed. It is the id every future system (share records, a server's user row) keys you by. `userRecordID` and a Sign in with Apple `sub` get *mapped* to it; neither becomes it. | S | **Now**, in the iCloud migration |
| Keep the head as the avatar, but add a **derived avatar still**: one 256px PNG of the neutral face, written whenever the head is saved. Friends never need the rig, the twelve takes or 600px faces. | S | Before social |
| Display name = `profileName`, which already exists. **No handles** until there is discovery, and there should never be discovery. | none | Decide now: no handles |
| The head is paid ("Strata Everything"). A friend must still see your head avatar whether or not *they* paid. Gate making it, not showing it. | S | Before social |

### 4.2 Data model: every `@Model`, checked

Schema in `SharedModelContainer.swift`: `Habit`, `HabitLog`, `MoodLog`, `Tower`,
`PlanFolder`, `PlanItem`. `Album`, `Replay`, `WinRecord`, `WinPlace` are pure value
types (good: replays and albums are derived, so they never need syncing or sharing
as rows).

| Model | Stable UUID | createdAt | updatedAt | Owner | Audience | Soft delete | Notes |
|---|---|---|---|---|---|---|---|
| `Habit` | `id: UUID`, **no default** | yes | no | no | no | no | A quick win is a `Habit` + `HabitLog` pair (`QuickWinService.logWin`, `isQuickWin = true`). Title, size and colour live on `Habit`. |
| `HabitLog` | `id = UUID()` | **no** (only `completedAt`) | no | no | no | no | `dateString` is local `yyyy-MM-dd` with **no time zone stored**. Place is three `Double?`s. Photo is `imageFileName`. |
| `MoodLog` | `id`, no default | no | no | no | no | no | Keep private forever. |
| `Tower` | `id`, no default | yes | no | no | no | no | |
| `PlanFolder` | `id`, no default | yes | no | no | no | no | Legacy (Plan tab removed). |
| `PlanItem` | `id = UUID()` | yes | no | no | no | no | Legacy. |

**What a social version needs, and what to do:**

1. **Stable UUIDs with defaults on every model.** Already part of the 31 CloudKit
   defaults. **Now.** S.
2. **`updatedAt: Date = Date()` on `Habit`, `HabitLog`, `Tower`, and the new
   `WinPhoto` and `Identity`**, set in one `willSave`-style helper in the repository.
   A shared copy needs to know whether it is stale; CloudKit's own modification
   date belongs to the *record*, not to your edit, and is not available through
   SwiftData. Backfill existing rows to `completedAt ?? createdAt`. **Now, in the
   same migration as the CloudKit defaults** (once a CloudKit schema is live it is
   add-only; adding is allowed, but one migration and one backfill is cheaper than
   two). S.
3. **`createdAt` on `HabitLog`.** `completedAt` is when the win *happened* (and is
   editable in principle); `createdAt` is when it was *logged*. A shared feed needs
   the second to order arrivals honestly. Now. S.
4. **`timeZoneIdentifier: String = ""` on `HabitLog`.** `dateString` is correct for
   you, but a friend in another zone cannot recover which day your "Sunday" was, and
   the week boundary for a sent week is *your* week. Record `TimeZone.current.identifier`
   at log time. Now. S.
5. **Owner field: not on private rows.** Everything in your private database is
   yours by construction. The owner lives on the *shared copy* (`SharedWeek.ownerProfileID`).
   Decide now; costs nothing.
6. **Audience field: `isPrivate: Bool = false` on `HabitLog`, meaning "never
   include in anything sent".** Not a multi-valued `visibility` on the private row;
   audience is chosen per send and stored on the copy. Before social. S.
7. **Soft deletes: not on private rows.** CloudKit tombstones handle private deletes
   (`research-icloud-backup.md` §11.5), and a `deletedAt` would have to appear in
   every predicate in `MemoriesViewModel`, which is how a feature silently shows
   deleted wins. Instead, deleting a win that was sent **enqueues a withdrawal** in
   the outbox. Before social. M.
8. **The win as one shareable unit.** `WinRecord` (`Strata/Models/Album.swift:15`) is
   already the right shape: a pure value with title, category, size, photo, place.
   Add `id`, `createdAt`, `updatedAt`, `timeZoneIdentifier`, `isPrivate`, and later
   `iconName` and `with: [PersonRef]`. Every shareable thing is built from
   `WinRecord`s, never from `@Model`s. Now (extend) S; before social (snapshot
   builder) M.
9. **People on a win (for tagging now, together wins later):** store
   `withNames: [String] = []` locally. When social exists, a tag can additionally
   carry a circle member's `profileID`. Never store contact identifiers or phone
   numbers in a synced model. When tagging ships.
10. **Never rename or remove** (CloudKit rule, already in the iCloud plan). That
    means naming decisions made now are permanent: prefer `isPrivate` over
    `visibility`, since a Bool with a clear meaning will not need renaming.

### 4.3 Storage and sync

**Does the CloudKit private database plan box Strata in?** No, with the 4.0 rule.
It does limit *how* social can be built:

- **SwiftData only supports CloudKit's private database.** Shared and public
  databases are unsupported; Apple's suggestion is Core Data `NSPersistentCloudKitContainer`
  alongside, or file a Feedback (b). So a circle cannot be "the same SwiftData store,
  shared".
- **Option A: CloudKit shared zones via `CKSyncEngine`.** One custom zone per
  circle, owned by the circle's creator, shared with a zone-wide `CKShare`. Sent
  weeks, cheers and withdrawals are records in that zone. No server, no cost,
  consistent with "no server" in `monetization.md`. Limits: 100 participants,
  iPhone/iPad/Mac only, invite acceptance goes through Apple's share UI, **you cannot
  read the content to moderate it**, no server-side push logic (CloudKit
  subscriptions can notify), and account deletion is simply the user's iCloud.
- **Option B: the CloudKit public database as a feed.** Rejected. Everything is
  readable by any app user unless you build access control in app code, the free
  tier is 40 requests/second and 10 GB assets shared across the whole user base,
  and you own moderation of all of it (b).
- **Option C: a real backend** (Supabase: Postgres with row-level security, Sign in
  with Apple, storage and a CDN; or Firebase). Needed when any of these become true:
  (1) invites must open for people without Strata or without an iPhone (Partiful's
  lesson), (2) moderation needs to see reported content, (3) circles or reach grow
  past what zone sharing handles, (4) server logic is needed (Sunday delivery,
  push on cheer, abuse rate limits). Cost becomes real, which changes monetisation
  (4.6).

**Recommendation:** prove circles on Option A, but write it so Option C is a
contained swap:

| Layer | Owns | Today | Change |
|---|---|---|---|
| Views | Drawing | Read `@Model` directly (`@Query` in `MainAppView`, `FetchDescriptor`s in `MemoriesViewModel`) | Gradually read through `WinStore` |
| `WinStore` (new protocol) | Local-first reads and writes, speaks `WinRecord`, stamps `updatedAt`, enforces `isPrivate` | none | **Now for new code paths; migrate call sites opportunistically** |
| `SwiftDataWinStore` | The private record, mirrored to the private database by Apple | the store | Implements `WinStore` |
| `CircleService` (new protocol) | Publish a snapshot, withdraw, fetch friends' weeks, cheer, block, report | none | Before social |
| `CloudKitCircleService` / `ServerCircleService` | Transport | none | A then C |
| `Outbox` (a small model) | Pending publishes and withdrawals, retried until acknowledged | none | Before social |

The seam is `CircleService`, and because it takes snapshots built from `WinRecord`
it never sees SwiftData. Swapping CloudKit for a server is one new conforming type
plus a migration of *circles* (which are small), not of anyone's record.

### 4.4 Photos and media

**Today (code):** `ImageManager.save` resizes to a 2560px long edge and writes HEIC
at 0.85 (JPEG fallback) to `Documents/strata-images`, named
`<logID>_<seconds mod 100000>.heic` (`Strata/Services/ImageManager.swift:161-196`).
Every path re-encodes a `UIImage`, so **no EXIF or GPS metadata survives** (CLAUDE.md,
location section). Thumbnails are memory-only. The widget keeps 600px copies in the
App Group. The iCloud plan adds `WinPhoto` as its own model with the bytes as
external storage.

| Recommendation | Size | When |
|---|---|---|
| Keep `WinPhoto` separate from `HabitLog` (as planned). It is also exactly the unit a share needs: a photo can be withdrawn without touching the win. | M (already planned) | Before iCloud ships |
| **Make "no metadata in any written image" a test**: encode, read back with `CGImageSource`, assert no `{GPS}` and no `{Exif}` dictionaries. Today it is true by accident of re-encoding; a future "save original" path would break it silently. | S | **Now** |
| Add a **share derivative**: 1080px long edge, HEIC 0.8 (about 150 to 300 KB), generated at send time, not stored for every photo. A circle never receives the 2560 original. | S | Before social |
| Content addressing (a SHA-256 name) is **not needed** for the private record: `imageFileName` is already the key everywhere and renaming files breaks the iCloud materialiser's contract. For the shared copy, name derivatives by hash so a re-sent week does not re-upload. | S | Before social |
| **Place is never in a shared payload unless added per share**, and then coarsened to a neighbourhood or city name (the geocoded name, not coordinates). Enforced in the snapshot builder, pinned by a test. | S | Before social |
| A server feed needs a CDN (Supabase Storage and Firebase both front one) and moderation: Apple's on-device `SensitiveContentAnalysis` framework can check an outgoing photo before send; a server can add a hosted check on reports. | M | Option C |

### 4.5 Privacy, safety and App Store rules

**Guideline 1.2 (user-generated content)** requires, for any app where users share
content: a method for filtering objectionable material, a way to report content with
timely responses, the ability to block abusive users, and published contact
information (b). For Strata's model:

- **Filter:** invite-only circles are the main filter; add `SensitiveContentAnalysis`
  on photos before send.
- **Report:** a "Report" action on any received week or win. On Option A, write a
  report record (reporter, sender `profileID`, snapshot id, reason) to the public
  database or a simple endpoint, and act by email. On Option C, a moderation queue.
- **Block:** removes the person from every circle you own and hides them in circles
  you share; they are never told. One tap.
- **Contact:** a support email in-app and on the product page.

**Guideline 5.1.1(v):** once there are accounts (Option C), in-app account deletion
is mandatory (b). On Option A there is no account to delete, but "Leave all circles
and withdraw everything I sent" should exist anyway.

**Minors.** iOS 26's age ratings are 4+, 9+, 13+, 16+, 18+, and the Declared Age
Range API returns an age band (never a birth date); several jurisdictions (Utah,
Louisiana, Brazil, Australia, Singapore) now require developers to use it (b).
Recommendation: rate 13+ once circles exist; ask Declared Age Range at circle
creation; under 13, circles are off; 13 to 15, circles on but photos and place off
in anything sent (c). No location sharing to anyone under 16, ever.

**`PrivacyInfo.xcprivacy` and the policy.** Today `NSPrivacyCollectedDataTypes` is
empty and must stay so while nothing leaves the device (CLAUDE.md, "What the app
CLAIMS"). Note in passing: its comment says "there is no app group", which is stale
(the entitlements carry `group.JaydenBetts.Strata`).
- **Option A (CloudKit shared zones):** data lives in users' iCloud accounts and the
  developer cannot access it. Apple's "collect" definition turns on developer access,
  so this arguably stays "not collected", but reports sent to you *are* collected
  (User Content: Other, Identifiers: User ID). Declare those. (c: confirm against
  Apple's App Privacy Details page when building.)
- **Option C (server):** declare, all *linked to the user*, *not used for tracking*,
  purpose App Functionality: Name, User ID, Photos or Videos, Other User Content,
  Coarse Location (only if place can be sent), and Email if Sign in with Apple relays it.
- **The privacy policy gains:** who can see what you send and when; that nothing is
  sent unless you send it; retention and withdrawal; blocking and reporting; minors;
  and, on Option C, where the server is and who processes the data.

### 4.6 Monetisation compatibility

`monetization.md`: free record, paid keepsakes, one $9.99 unlock, no subscription
because there is nothing ongoing to fund.

- **Social must be free to join and to cheer.** A circle is only worth anything if
  your friends are in it; a paywall on receiving kills the network (c). Locket gates
  *more* friends, not friends (b).
- **Sending your week stays free.** Saving the replay as a video stays paid, as now.
  A sent week is played from data inside Strata, so it does not undercut the video.
- **The head:** making it stays paid; showing a friend's head is free (4.1).
- **Option A adds no cost**, so the no-subscription reasoning holds.
- **Option C adds real ongoing cost** (storage, CDN, moderation time). That is the
  first time a subscription becomes honest under guideline 3.1.2(a). If it comes,
  follow Retro and Locket: an optional plan for *more* (bigger circles, full history
  for friends, more reactions), never for the core or for being in a circle.
  Day One's choice (shared journals Premium-only) works for a paid journal but would
  stunt a network that has not formed yet (c).

---

## 5. Phased roadmap

Each phase ships on its own and is worth having if the next never comes.

### Phase 0: Solid ground (now, through iCloud backup)
- iCloud backup as designed, **with** the structural changes: `updatedAt`, `createdAt`
  on logs, `timeZoneIdentifier`, `profileID`, id defaults, `WinPhoto`, the
  no-metadata test, `WinStore` for new code.
- **Proves:** nobody loses a win; the structure is ready.
- **Metric to move on:** restore tested on a second device with photos intact; zero
  in-memory fallbacks in the field.

### Phase 1: A record worth keeping (single player)
- Lock Screen and Control Center logging; "On this day"; one reflective line at
  Your Week's close; then Your Year before December; block icons.
- **Proves:** people come back to look, not only to log.
- **Metric to move on:** at week 8, a majority of active users open at least one
  replay or "On this day" per week, **and** 15% or more of weekly replays are
  exported or shared through the existing share sheet, sustained for four weeks.
  The second number is the direct evidence that people already want friends to see
  their week; without it, social is a guess (c: thresholds are judgement, set before
  looking at the data).

### Phase 2: Send, don't post (no accounts)
- **Send your week to a person** through Messages as a link that opens the replay in
  Strata (and the existing video for anyone without it). Receiving a week shows it in
  a small "From friends" row in Memories. Cheer back.
- Transport: `CloudKitCircleService` with a two-person share per sender and
  recipient, or a record in a shared zone.
- **Proves:** a one-to-one exchange of weeks has pull, with no network required.
- **Metric to move on:** 30% or more of people who receive a week open Strata within
  48 hours; senders send again in two of the next four weeks.

### Phase 3: Circles
- Circles of up to 12, weekly sends, cheers, "me too" together wins, four weeks back,
  block, report, Declared Age Range, the privacy manifest and policy updates.
- Still `CloudKitCircleService` if the audience is iPhone-only.
- **Proves:** a small group keeps each other going without performance.
- **Metric to move on:** circles with 3 or more members still sending in week 6;
  invited users' 30-day retention above organic users'. If the ceiling is invites
  that cannot open (Android, no app), that is the trigger for Phase 4.

### Phase 4: A real service
- `ServerCircleService` (Sign in with Apple, Postgres with row-level security,
  storage and CDN), web-openable invites and week pages, server moderation queue,
  account deletion, optional plan for *more*.
- Private record stays in iCloud; only circles migrate.
- **Proves:** Strata can grow by invitation beyond iPhone owners.

---

## 6. What not to do

| Don't | Why |
|---|---|
| **A public follower feed** | It changes who a win is *for*. Passive browsing of others' highlights is linked to envy and upward comparison (a), public spaces need moderation Strata cannot staff (Goodreads) (b), and every friend-network that widened to chase growth lost what made it different (Path) (b). |
| **Like counts, cheer counts, follower counts** | A count turns a small win into a score against other people's. Instagram tried to remove them and found they could not be taken back (b). Show *who* cheered, to the sender only. |
| **Streak leaderboards, or streaks shown to friends** | Broken streaks demotivate, most when people blame themselves (Silverman and Barasch 2023) (a); leaderboards raise output, not motivation (Mekler et al. 2017) (a). A leaderboard of personal wins would reward logging for the audience, which corrupts the record. |
| **A clock** ("post before 9pm", "late") | BeReal's late label produced the pressure it claimed to remove (a). Nothing in Strata is ever late. |
| **Friends' live location, or a friends map** | Strava's heatmap and Instagram Map's 2025 backlash show what default-visible location does (b). The map is yours; place is added to a send by hand, as a name. |
| **"Seen by", read receipts, "X viewed your tower"** | It reads as watching, which the owner has ruled out, and it creates obligation to respond. |
| **Comments** | Moderation surface, judgement, and a slower way to do what Messages does. Reactions plus "Reply in Messages" cover it. |
| **Auto-sharing, or "suggested to share"** | Every send must be a choice. One accidental share of a private win costs more trust than the feature earns. |
| **Contact upload or "find friends"** | Path's 2012 address-book scandal (b); Apple's contact picker without permission is enough to invite. |
| **Rewards for posting** (unlocks, badges, "share to unlock") | Contingent rewards undermine intrinsic motivation (Deci et al. 1999) (a), and they push fake wins into a record that is only valuable because it is true. |
| **Sharing the private store itself** (CKShare on your record) | It welds privacy to storage, makes every edit a broadcast, and cannot be moved to a server later without migrating everyone's history. Share copies. |

Sources: Silverman & Barasch, *JCR* 49(6), 2023, https://academic.oup.com/jcr/article-abstract/49/6/1095/6623414 (a) · Mekler et al., *CHB* 71, 2017, https://bruehlmann.io/publication/mekler-towards-2017/ (a) · Deci, Koestner, Ryan, *Psych. Bulletin* 125(6), 1999, https://depts.washington.edu/techdocs/papers/deciExtrinsicRewardsAndIntrinsicMotivation99.pdf (a)

### Technical sources (sections 4.3 to 4.5)

- SwiftData supports only the CloudKit private database: Apple Developer Forums, https://developer.apple.com/forums/thread/731334 and https://developer.apple.com/forums/thread/756721 ; Use Your Loaf, WWDC23 SwiftData lab notes, https://useyourloaf.com/blog/wwdc23-swiftdata-lab-notes/ (b)
- CKSyncEngine, WWDC23 session 10188, https://developer.apple.com/videos/play/wwdc2023/10188/ (b)
- CKShare 100-participant limit: Apple Developer Forums, https://developer.apple.com/forums/thread/721997 ; Tact, "How CloudKit share permissions and participants work", https://blog.justtact.com/cloudkit-share-permissions/ (b)
- CloudKit public database free tier (40 req/s, 10 GB assets, 100 MB DB, scaling per user): Apple Developer Forums, https://developer.apple.com/forums/thread/113318 and https://developer.apple.com/forums/thread/660009 (b; confirm the current numbers in the CloudKit Console before relying on them)
- App Store Review Guidelines 1.2, 1.3, 5.1.1(v), fetched 2026-09-16: https://developer.apple.com/app-store/review/guidelines/ (b)
- Declared Age Range: https://developer.apple.com/documentation/declaredagerange ; WWDC25 session 299, https://developer.apple.com/videos/play/wwdc2025/299/ ; Apple Developer News on regional age requirements, https://developer.apple.com/news/?id=f5zj08ey (b)
- Journaling Suggestions entitlement: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.journal.allow (b)

### Code read for this report

`CLAUDE.md` (What this is, Product direction, Settled, Removed on 2026-09-10,
Memories, What the app CLAIMS, Profile and your head, Replays, Words the app says);
`docs/product-direction.md`; `Strata/Services/SharedModelContainer.swift`;
`Strata/Models/{Habit,HabitLog,MoodLog,Tower,PlanFolder,PlanItem,Album,WinPlace,ProfileStore,HeadStore}.swift`;
`Strata/Services/ImageManager.swift`; `QuickWinService.logWin`;
`Strata/Strata.entitlements`; `Strata/PrivacyInfo.xcprivacy`;
`StrataWidget/StrataWidget.swift`; `Strata/Intents/`. Constraint documents:
`Desktop/Strata-audit/docs/monetization.md`, `research-icloud-backup.md`,
`research-game.md`, `research-screen-control.md`, `research-motion-layering.md`,
`research-block-icons.md`.
