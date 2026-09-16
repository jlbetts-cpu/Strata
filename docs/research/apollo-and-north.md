# Apollo, North, and what they mean for Strata

Written 2026-09-16. Read-only research. 40 Notion pages were read in the owner's
logged-in Chrome by URL, with no clicks into text and no edits; the tab was closed
afterwards. No code checkout was edited, nothing was built, no simulator was run.
Strata claims are read from `/Users/jaydenbetts/StrataWork/owner-head` (HEAD `b252e01`)
and `/Users/jaydenbetts/Desktop/Strata-audit/docs/monetization.md`.
Claims are tagged **(n)** said in the Apollo Notion, **(s)** true of Strata's code or
docs, **(a)** outside research or platform documentation, **(c)** my inference.

The owner's words this answers: *"I've seen apps that text the user. I think it would
be cool if we are adding an AI. I was actually building an AI personality with my
friend Rildy"* and *"you can look through the whole Apollo Notion; maybe it can help
us understand what else we should add."*

---

## Summary in ten lines

1. **Apollo was the social, close-friends version of the same idea**: post a photo of a win, sized S/M/L, it stacks into a tower your friends see; pivoted on 13 May 2026 to "ADHD-native", no streaks, no shame. Strata is its private, on-device descendant (shared Figma "Apollo", same S/M/L sizes, same tower). Confirmed in substance, never stated in so many words.
2. **Strata already inherited the best of it** (the tower, wins not tasks, photos, look-back, replays as the "strip"/Wrapped, calm reminders) and **dropped the risky half** (feed, streak pressure, shark nudges, leaderboards, subscriptions, a server).
3. **Add, in order:** North's weekly line (S), "On this day" (M), a quiet comeback line (S), Your Year (M), Lock Screen logging (S). Each is grounded in both Apollo's research and Strata's current direction.
4. **North fits Strata** as a voice that reads your tower back to you, not as a friend who watches you. It speaks only about wins that happened, never on an empty day, at most once a week plus rare milestones.
5. **Channel:** local notifications written like a text (title "North"), the same sentence at Your Week's close, and a quiet North thread in Profile holding everything North has said. No SMS, no Live Activity, no chat tab.
6. **Technology:** Apple Foundation Models on device (iOS 26, Apple Intelligence iPhones) phrasing sentences over facts Strata computes itself, with deterministic templates as the floor for every other phone. Cost $0, offline, privacy manifest unchanged.
7. **Cloud (Claude via a server)** is about $0.07 a user a month on Haiku 4.5 and cannot be funded by a one-time $9.99 unlock; it also changes the privacy label and needs Apple's third-party-AI consent. Not now.
8. **Voice:** keep Rildy's warmth and specificity, keep the "premium" doc's restraint, and rewrite every line that sounds like surveillance ("quietly watching", "knows all your data", "North will be watching") or that names what you did not do.
9. **Money:** North stays free. It costs nothing on device, and words about your record are part of the record, which `monetization.md` keeps free. Reject Apollo's blurred-paywall-over-your-own-insight idea.
10. **v1:** a Sunday notification from North with a real fact in it, the same line under the finished weekly tower, and a North row in Profile listing past lines with three answerable chips. About 1.5 to 2 weeks.

---

## 1. Apollo in brief

### 1.1 What it was

**Positioning (n).** "Win. Every day." A close-friends iOS social app where you post
photo-based daily wins to 5 to 15 people. Problem statement: "Social media only has
room for the highlight reel, habit trackers are private and clinical, and nothing in
between exists for the daily progress that actually builds a life." Mission: "Make the
invisible visible."

**Team (n).** Jayden (product, design, iOS), Darius (backend: Supabase, Cloudflare R2),
Rildy (voice, North's personality, notifications, behavioural design), plus growth and
technical advisors. HackDavis 2026 pitch; launch was planned for Q2 2026 with an
"early access" framing.

**Audience (n), in two eras.**
- *April 2026:* Gen Z college students and young adults (personas: Marcus, 20, ex-football
  player at UC Davis; Sofia, 21, overcommitted; David, 38, founder with young kids;
  Jordan, 24, laid off and quietly low). The persona test: "on a regular Tuesday when
  everything is kind of fine and kind of a mess, would they open Apollo and feel like
  it was made for them."
- *13 May 2026, the v2 pivot:* **"ADHD-native."** "A daily keepsake and accountability
  ritual designed from the ground up for ADHD brains", marketed explicitly, "social, not
  clinical", "ADHD-friendly not ADHD treatment". The $122.8B cost-of-ADHD figure was kept
  for investors only, never user-facing, because users would "correctly read it as
  exploitative".

**Core loop (n).**
- *v1:* open, see friends' wins in a feed of towers, shoot a win (photo + name + size),
  it lands in the circle's feed, streak continues, friends react and leave stickers on
  the back of a "polaroid" card.
- *v2:* the unit becomes the **day**. Wins are captured privately through the day and
  consolidate at local **sunset** into one mosaic post. Before sunset an "orbit" shows
  only friends who kept something today; inactive friends are invisible. Memories below.

**Features, by the time the Notion stops (n).** Camera-only capture (no camera roll);
S/M/L win sizes; the tower; a 3D polaroid viewer with stickers on the back; reactions
with no counts in v2; Find tab (people, albums); Memories calendar and "on this day";
North; the North "strip" (yesterday's photos as a shareable image); Apollo Wrapped (nine
cards on 1 January); Challenges (time-boxed shared collections, join by App Clip);
mascots (an otter for empty states, a shark that swims under a friend's empty slot);
a designed haptic vocabulary; optional sounds; widgets.

### 1.2 What was decided, and why

| Decision | Why (n) |
|---|---|
| **No streak counters, no "Day N"** (v2, "Hard No") | Streak loss is shame; ADHD users are "uniquely vulnerable to shame, RSD" (the ADHD AI page). Reversed April's view that "the streak is the heartbeat of the app". |
| **Notifications signal witness, not attendance** | "Someone witnessing you: notification. You haven't shown up: silence, dignity, your business." Never "you haven't posted", never streak loss, never re-engagement nudges. |
| **No red badge, no count, dot clears on tap** | Badge counts exploit the Zeigarnik effect; ADHD users are more prone to "sign-tracking". |
| **North is not a nav tab** (v2) | It lives in the feed at the Today/Yesterday seam as a persistent daily line, tap to open. |
| **North observes, never prescribes** | "You've skipped reading 4 times this week is North. You should read more is not North." |
| **No "AI" in the UI** (Plain Language rules) | "Users know North is AI. Saying it is unnecessary and slightly clinical." "Message North" over "Ask North anything". |
| **No streak restore IAP, no status badge, no leaderboards, no tiered "free reward"** (v2 pricing draft) | "Nobody buys dopamine." Streak restore was named "anxiety-monetization". |
| **Follower counts: documented v2 candidate, not approved** | "Easy to add later and nearly impossible to remove." |
| **Pricing deferred** until 10 to 20 ADHD users were interviewed | v2 draft: Free / Apollo+ $3.99 / Pro $9.99 with a printed year book. |

### 1.3 What the research concluded

**Retention and conversion (n, "Retention, Conversion & Growth Research", 3 May).**
25% abandon after one use; average Day 7 retention 10.7%; days 2 to 10 are the churn
window; freemium conversion median 2 to 5%. Personalised notifications cut churn 15 to
25%; "specific beats generic". Onboarding "first session: get them posting a win
immediately". What makes people *love* an app is a character people screenshot
(Duolingo), a recap people share (Wrapped), and a visual "wow" moment.
*Caveat (c):* this page predates the pivot and recommends streak-at-risk and "X friends
posted, you haven't" notifications, both of which v2 later banned. Treat its numbers as
context, its tactics as superseded.

**What makes North feel premium (n, 3 May).** "The underlying model is almost irrelevant."
Premium comes from **personality, specificity and restraint**: one consistent voice with
tone that shifts; "Eight wins today. Your best Sunday in three weeks" is premium, "You had
a great day!" is free; no "great job", no "I feel", no exclamation marks, no generic
advice; "if a sentence could appear in any app's push notification, it doesn't belong".
The moat: "Every other habit AI is forward-looking only... North is the only AI in
Apollo's category that has months of real behavioural data."

**What kind of AI is best for ADHD (n, 12 May).** An **observer and memory prosthetic**,
not a coach. Non-judgmental, patient, available, no social overhead. Reactive by
default with optional gentle weekly summaries. Explicitly **not**: a streak protector, a
goal-setter, "you got this". A safety layer from day one: if something sounds like real
distress, point gently to human help. Its own open question is the one that matters for
Strata: "More data = better insights, but also more surveillance-feeling."

**Competitive gap (n, 28 April).** Journaling AIs only know what you type; habit analytics
(Exist.io) show facts without meaning; BeReal Memories is a passive drawer; Wrapped stops
at "what". North's claimed gap is photos + social signal + your own words + a voice.

**Unit economics (n, 28 April).** Claude Haiku 4.5 with batch and caching, about $0.022
per Pro user a month for daily, weekly and monthly insights. That model assumed a $9.99
monthly subscription and a server Apollo was already paying for. Strata has neither
(section 5).

**Rildy's deliverables (n).** Deliverable 1 answers and the synthesised Voice Document are
complete. Deliverable 2 has 30 research-tagged chips. Deliverable 3 has Social (10) and
Habit Reminders (13) written; Milestones, Re-engagement and Sunday Summary are empty.
**Deliverable 4 (Quote Bank) is empty**: rules and examples only. "North's Personality &
Brain" adds poems in the morning, a four-times-a-day notification rhythm, frequency
capping as an open question, a power-word bank and a banned-word list.

**The documents disagree with each other (n).** The Voice Document is "sassy", "a little
extra", "honey, I saw that", "Bestie". The Premium page is "dry", "observational, like a
good journalist". The ADHD page is "warm but not motivational". The Insight Engine PRD
ends a monthly insight with "North will be watching." The v2 pivot doc itself flags "a
full reconciliation pass across the whole workspace is still owed". Section 3.4 is that
reconciliation, for Strata.

### 1.4 Strata as Apollo's descendant

**Confirmed in substance (s, n).** Strata's `CLAUDE.md` says the block is "From Figma
'Apollo' (`248:14`)", the same file the Apollo Notion links. Apollo's L/M/S win sizes are
Strata's `BlockSize` (1x1, 2x1, 2x2). Both are built around "wins", a tower, and looking
back. Strata's `tasks/personality.md` says it is built "for people with ADHD", which is
Apollo v2's audience. Neither workspace says "Strata replaces Apollo" in words.

| Apollo | In Strata today | Verdict |
|---|---|---|
| A win is a thing you did, sized by you | Same; a block, 1x1/2x1/2x2 | **Inherited** |
| The tower | The home tab, with real gravity | **Inherited, much deeper** |
| Photo on a win | Optional photo; Camera tab | Inherited, relaxed (camera roll allowed; no camera-only rule) |
| Memories calendar, "on this day" | Memories (albums, month tower, map); "on this day" not built | Half inherited |
| North strip, Apollo Wrapped | Your Week / Your Month replays, video export | **Inherited as replays**; Your Year not built |
| Sunset reveal ritual | Sunday and 1st-of-month replay windows and notifications | Inherited in spirit |
| Calm notifications, no count badges | `DailyReminder` (only on an empty day), `ReplayReminder` (only when the period has wins) | Inherited, with one tension (3.3) |
| No shame, no streak loss | Profile shows a streak gently, "no red, no streak lost" | Inherited |
| Close-friends feed, reactions, stickers, orbit | None; social researched as "later" | **Deferred** |
| Streak pressure, shark, group streaks, leaderboard, midnight reset | None | **Dropped**, correctly |
| Mascots (otter, shark) | None; visual-cohesion research rejects a mascot | Dropped |
| Goudy/EB Garamond, grayscale UI, polaroid frames | SF Pro Rounded, the owner's numerals and lettering, coloured blocks | Dropped for Strata's own identity |
| Subscriptions, affiliate payouts | One-time unlock, no subscription | Dropped |
| Supabase, R2, Claude API | Nothing leaves the phone; `NSPrivacyCollectedDataTypes` is empty | Dropped |
| Challenges | Proposed as the v2 "weekly challenge" in `research-goals.md` | Carried as an idea |
| **North** | **Not built** | The open question this report answers |

---

## 2. What Strata should add

Ranked on: grounded in Apollo's research **and** Strata's direction (minimal, invisible
guidance, record what you did, social later); cannot be failed; costs nothing in the core
loop. Effort: **S** days, **M** one to two weeks, **L** a month or more.

| # | Add | Why, from Apollo | Why it fits Strata now | Effort |
|---|---|---|---|---|
| 1 | **North's weekly line**: one specific sentence about the week, in the Sunday notification and under the finished Your Week tower | Personalised notifications cut churn 15 to 25%; "specific is premium"; North's Sunday summary was a planned category (n) | `ReplayReminder` already fires Sunday only when the week has wins, but its body is generic: "Seven days of wins, stacked into one tower." (s). The close already announces "Thursday was your biggest day" to VoiceOver (s), so the facts exist | **S** templated, **M** with Foundation Models |
| 2 | **"On this day"** in Memories | Apollo Memories PRD: "the feature that makes people open Apollo on a random Tuesday" (n) | Already the #2 recommendation in `research-concept-and-social.md`; a gift, not an obligation; cannot be broken | **M** |
| 3 | **A quiet comeback line**: the first win after 4 or more empty days gets one line on the landing ("Back on the tower.") and nothing else | The "comeback card" is the one Apollo Wrapped card "nobody else has"; the strategic pivot's struggling user needs "a witness to their resilience" (n) | Rewards presence only; never counts the gap; never fires on the empty days themselves | **S** |
| 4 | **Your Year**: the year's towers and a year replay in late December | Wrapped was Apollo's "primary organic growth engine" (n) | Already #4 in the concept research, before December 2026. **Cut Apollo's "honest card"** ("You posted Relationships twice... You told yourself it mattered"): it names absence, which the goals research forbids | **M** |
| 5 | **Log from the Lock Screen and Control Center** | Locket's growth came from being visible on the Lock Screen and home screen (n, Viral Feature Strategy) | #1 in the concept research; `LogWinIntent` and an `accessoryRectangular` widget already exist (s) | **S** |
| 6 | **Answerable chips** in a North row: "What was my biggest day?", "What did I do most this month?" | Rildy's 30 chips (n); "most users won't know what to ask" (Insight Engine PRD) | Computed, not generated; a memory prosthetic in three taps; no free text needed in v1 | **S** to **M** |
| 7 | **Milestone lines**: the 100th win, the biggest week ever, the first win of a new colour | Milestones are "identity-defining" (Rildy's D3 brief, n) | Fires on something that happened; a rare, earned message; the tower's dance already marks every tenth win (s) | **S** |

**What to avoid, and why** (each appears somewhere in the Apollo Notion):

- **Streak-at-risk and "you haven't posted" messages.** Apollo v2 banned them; the goals research bans "any notification on a day with nothing". North must never be the voice of absence.
- **A blurred preview of your own insight behind a paywall** (North Screen Access & Paywall Spec, 3 May). It is a conversion trick built on showing people their own words locked away, and `monetization.md` rules out dark patterns.
- **The shark, group streaks, the midnight leaderboard reset, "react with a win" chains.** Social pressure mechanics designed for a feed Strata does not have; three of them are streaks in disguise.
- **A daily quote bank** ("same quote for every Apollo user on the same day"). It was never written, and it contradicts North's own rule that a sentence that could be sent to anyone does not belong. Generic lines also dilute the specific ones.
- **Morning poems and a four-a-day notification rhythm** (Personality & Brain). Four touches a day is the opposite of "rarely, and only when it's true"; poems are the one place North would be generic by design.
- **Photo-reading insights** ("your face looks more rested in your morning gym photos", Competitive Research). Reading faces in photographs is exactly the surveillance Strata's Words rule forbids.
- **HealthKit correlations, calendar access.** Apollo itself deferred them; Strata removed HealthKit and CoreMotion on purpose (s).
- **A chat-first North screen with a thread that resets at midnight** (Insight Engine PRD). A daily reset is a daily appointment; Strata's North keeps its words, like the tower keeps its blocks.

---

## 3. North in Strata

### 3.1 What North is here

> **North reads your tower back to you.** It only knows what you put on it, it only
> talks about what is there, and it speaks rarely enough that each line is worth opening.

Not a coach, not a friend who has been watching, not a chatbot. The Apollo docs' best
idea survives intact: an observation grounded in your own data, in a consistent voice,
with restraint. Two ideas do not survive: that North accumulates a picture of you "without
you doing anything", and that it should speak daily.

### 3.2 Channel: how North "texts" you

| Channel | Role | Verdict |
|---|---|---|
| **Local notification written like a text** (title "North", one or two short sentences) | The main voice. Scheduled on the phone with `UNUserNotificationCenter`, exactly as `ReplayReminder` already does (s). No server, no push certificate. | **Yes, v1** |
| **The replay close** | The same sentence sits under the finished tower, so tapping the notification lands on the thing it describes. | **Yes, v1** |
| **A North thread in Profile** | A plain list of everything North has said, newest at the bottom, like a Messages thread with one sender. Three chips at the bottom. It makes North a record too, which is what Strata is. | **Yes, v1** (read-only plus chips) |
| **Free-text "Message North"** | Ask anything about your wins. | **v2**, on-device model only, after v1 shows people open the thread |
| **Lock Screen widget line** | The current week's line on the existing rectangular widget. | Later, optional; it is always visible, so the line must be one people are comfortable having on a Lock Screen |
| **Communication Notifications** (`INSendMessageIntent`, avatar on the notification like a real message) | Would look most like a text. | **No.** Apple intends it for messages between people; dressing an app persona as a contact is a review risk and a small deception (c) |
| **Live Activity / Dynamic Island** | | **No.** A Live Activity is for an event in progress; a message is not one (concept research agrees) |
| **SMS or iMessage** | Truly texting | **No**, section 4.4 |

### 3.3 When North speaks, and how rarely

**Default cadence (c, grounded in Apollo v2 and the goals research):**

| Moment | Condition | Max frequency |
|---|---|---|
| **Your Week is ready** (Sunday, the existing replay time) | The week has at least one win | 1 a week |
| **Your Month is ready** (the 1st) | The month has wins | 1 a month, replaces that week's message if they coincide |
| **Milestone** | 100th / 250th / 500th win; biggest week ever; first win in a colour never used before | 2 a month, never on the same day as another message |
| **Comeback** | First win after 4+ empty days | In-app line only, never a notification |

**Hard rules.**
1. **Never on a day or week with nothing.** Silence is the message.
2. **Never between 9pm and 9am** (quiet hours; configurable later).
3. **Backs off by itself.** If two North notifications in a row are not opened, North pauses notifications until the person next opens the app on their own. `DailyReminder` already stops after a fortnight of no opens (s); same principle.
4. **One notification per day, total**, across North, `DailyReminder` and `ReplayReminder`. North's Sunday line replaces `ReplayReminder`'s body; it is not a second message.
5. **Opt in, at the right moment**: at the close of the person's first Your Week, one sheet: "Want a line from North when your week is ready?" / "Yes" / "Not now". Never in onboarding, which is already about logging a first win.
6. **Mute is one tap** from the thread ("Pause North") and from Settings, and a long-press on the notification offers it too.

**A tension to decide (flagged, not resolved).** `DailyReminder` ("Nothing on today's
tower yet / Anything you finished counts.") fires *because* a day is empty (s). That is
the one existing message Apollo v2 and the goals research would forbid. It is gentle and
opt-in, so it may stay, but **North must never deliver it**; if North's voice ever speaks
on an empty day, the whole "only about what happened" promise breaks.

### 3.4 The voice, adapted to Strata's rules

**Keep (from the Voice Document, Premium page and ADHD page):** always specific, real
numbers and the person's own win titles; short, one idea; warm on a big week, quieter on
a small one; never tells you what to do; never "I feel", "I understand", "great job",
"crushing it", "grind", "let's work on"; no exclamation marks; human voice, not human
identity.

**Change, because of Strata's Words rule** ("no long dash", "nothing that sounds like
surveillance"):

| Apollo said | Why it cannot ship in Strata | Strata says instead |
|---|---|---|
| "your most attentive friend, the one who has been quietly watching, knows exactly what you've been doing" (Voice Document) | Watching, knowing | "North reads your tower back to you. It only knows what you put on it." |
| "who also happens to know all your data" | Surveillance framing | "It works from your wins, on your phone." |
| "North has been watching since day one, silently" (Final Definition, Strategic Pivot) | Watching, silently | Do not describe North's data at all in the product; describe it once, plainly, in the opt-in sheet |
| "North will be watching." (Insight Engine, monthly) | A threat, however affectionate | End on the fact. "Your biggest month so far." |
| "honey, I saw that" / "Bestie, those are not the same commitment" | "I saw that" is watching; and the line compares a strong area to a weak one, i.e. names absence | Drop the callout register entirely. Sass, if any, only about what happened: "Four walks and a 6am one. Ambitious." |
| "North noticed:" / "I've noticed" | Noticed is observation of a person; the Voice Doc also banned "I've noticed" as therapist talk | State the fact without a verb of perception |
| "Evening reading? Only twice." | Names what did not happen | Only presence: "Reading showed up twice this week." Or say nothing about reading |
| "30 days gone. The streak broke. You didn't." | A message about loss, timed to loss | No message at the moment of a break, ever |
| Long dashes throughout the Notion examples | Owner's rule | Commas, colons, full stops |

**Tone ladder (c).**

| Week | Energy | Example (every example uses only facts the tower holds) |
|---|---|---|
| Biggest week so far | Warmest, one beat of acknowledgement | "31 wins. Your biggest week yet, and Thursday carried nine of them." |
| An ordinary week | Plain, affirming by being specific | "12 wins. Most of them before noon." |
| A small week (1 to 3 wins) | Quietest, never measured against other weeks | "Two wins this week. Both on Saturday." |
| First week | Welcoming, no comparison possible | "Your first week: 6 wins, and the biggest was 'Finished the essay'." |
| Toward an intention (goals research) | Names the direction the person chose, only when it moved | "Four walks this week. Moving more is showing up." |
| Milestone | Brief, identity-light | "That was your 100th win." |
| Comeback (in-app only) | One line | "Back on the tower." |

**Banned outright (additions to Rildy's list):** watch, track, see, saw, notice, know,
monitor, follow, "keeping an eye", "paying attention"; any body, weight, food or calorie
word; "missed", "skipped", "behind", "only", "still", "yet" when it implies a shortfall;
"should"; streak loss language; long dashes.

### 3.5 What North may reference

| May use | Never uses |
|---|---|
| Win titles, as the person wrote them | Photographs' content (no vision model, ever) |
| Counts per day, week, month; the biggest day | Place, the map, cities, "where you were" |
| Block size and colour (the category the person picked) | Notes, if any, and anything marked private |
| Day of week; morning / afternoon / evening buckets | Exact timestamps ("11:58pm"), which read as logged surveillance |
| Personal records (biggest week, 100th win) | The head, faces, the head maker |
| The person's own intentions, in their words (goals research) | Other people's names, tagged or not |
| Whether this week is bigger than the person's own previous weeks, only when it is | Comparisons that make this week smaller than another |

### 3.6 North and the goals idea

`research-goals.md` proposes **intentions** (a direction in the person's own words, no
due date) and invisible guidance: suggestions in the win sheet, the slot leaning toward
an intention's colour, one line at Your Week's close when the week moved toward one.
**North is the natural owner of that one line** (c). The division of labour:

- The intention is always the person's; North never writes or proposes it (the goals research cites Chi et al. 2026: AI-written goals lose ownership).
- North speaks about an intention only when wins moved toward it, and never names an intention on a week that did not.
- The v2 weekly challenge ("Three walks next week?") is offered by North at the close, and simply expires unmentioned if missed.
- Weight goals are reframed to actions at onboarding, so North never has a body word to repeat.

### 3.7 Suggestion chips and the quote bank

**Chips.** Rildy's 30 split cleanly into two kinds (c):
- **Answerable from the tower** (Consistency & Patterns, Progress): "What time of day am I actually consistent?", "Which wins feel automatic now?", "How much have I done in 30 days?", "What's the most underrated win I have?" These become **v1 chips**, answered by code, not a model: a computed fact phrased by a template (or Foundation Models when available).
- **Therapeutic** (Identity, Difficulty, Meaning): "Is something wrong with me?"-shaped questions such as "Do I actually want to do this?", "Am I doing this for me or for others?", "What am I actually trying to prove?" **Do not ship.** They invite North to interpret a person's psyche from a list of blocks, which is where an AI stops being a memory aid and starts being a therapist; the ADHD research page says North must not be that.

Rename the concept: "Ask North" is fine in the thread, "Message North" (the Plain Language
pick) once free text exists.

**Quote bank.** Do not build (reasons in section 2). If a line is ever needed where there
is no data (the thread before the first week closes), use one fixed sentence, not a
rotating bank: "North writes here when your first week is ready."

### 3.8 Guard rails

- **Health.** No weight, food, calories, body shape, sleep or medical terms in any output; enforced by the fixed instructions and a post-generation word filter. Apple's acceptable-use requirements for Foundation Models exclude regulated healthcare uses (a); North stays far from them.
- **Distress.** v1 has no free text, so nothing to detect. When "Message North" arrives: a keyword and classifier check on the person's message; if it reads as distress, North does not answer about wins and shows one line with 988 (US) and "talk to someone you trust", as Apollo's ADHD page asked for "from day one".
- **No shame.** Structural, not just stylistic: the fact generator never emits a zero, a decline or a missing category, so no phrasing can turn one into a sentence.
- **Honesty about what North is.** Apollo chose never to say "AI". Strata should say it **once**, where it matters: the opt-in sheet ("North is written by software on your phone from your wins") and Settings. Not on every message. (c; see 4.3 for the App Store angle.)
- **No claimed feelings.** No "I", no "proud", no "miss you". North can have a voice without a self.
- **Opt-in, pause, delete.** Off until the person says yes; "Pause North" in the thread and Settings; "Clear North's messages" deletes the thread (the wins are untouched).
- **Adversarial tests** for generated lines: win titles containing profanity, names, medical words, prompt-injection text ("ignore previous instructions"); the output must still pass the filter or fall back to the template.

---

## 4. Technology and privacy

### 4.1 The architecture that fits either model

Whatever writes the words, **Strata computes the facts** (c):

```
Wins (SwiftData) -> NorthFacts (pure function, unit tested)
                 -> [biggestDay, count, record?, topTitle, intentionMoved?...]
                 -> Phrasing: Template (always) | Foundation Models (if available)
                 -> Filter (banned words, length <= 100 chars body)
                 -> Schedule local notification + store in NorthMessage
```

The model never sees raw data it could misread and never decides what is true; it only
chooses words for facts already checked. This is the Apollo Premium page's claim ("the
model is infrastructure") made literal, and it means the template path is a complete
product on every phone.

### 4.2 On-device (Apple Foundation Models) vs cloud (Claude via a server)

| | **Foundation Models, on device** | **Claude API via a small server** |
|---|---|---|
| Availability | iOS 26+ and an Apple Intelligence-capable iPhone with it switched on and the model downloaded; must check `SystemLanguageModel.default.availability` every time (a). Strata targets iOS 18.0 (s), so templates remain the product for many users | Any iOS version with a network connection |
| Quality | Small model; good at rephrasing short structured input with `@Generable` output, weak at open-ended reasoning (a) | Much stronger; could answer free-form questions well |
| Cost | **$0** | Haiku 4.5: $1 / $5 per million input / output tokens; Sonnet 5: $2 / $10; Batch API halves both (a, Anthropic pricing as of 2026-06). Estimate below |
| Server | None | Required: the API key cannot ship in the app. A small proxy (e.g. a Cloudflare Worker) with App Attest and rate limiting |
| Offline | Works | Fails; needs the template fallback anyway |
| Latency | Sub-second to a few seconds; irrelevant for a line generated ahead of Sunday | 1 to 3s per call; also irrelevant for pre-generated lines, noticeable for chat |
| Background | Generation should happen while the app is active, or opportunistically in `BGAppRefreshTask`; the scheduled notification always has a template body already, replaced when a better one is generated (c) | Same constraint unless the server sends remote pushes, which needs APNs and a device token store |
| Privacy manifest | **Unchanged.** Nothing leaves the phone | **Changes** (4.3) |
| Privacy policy | One sentence | A new section: what is sent, to whom, retention |

**Cloud cost estimate (c, from the pricing above).** Assume an active user gets 4 weekly
lines, 1 monthly, 2 milestones and asks 20 chip or chat questions a month: 27 calls, each
about 2,000 input tokens (instructions plus facts) and 120 output tokens. A prompt that
short is likely below the model's minimum cacheable length, so assume no caching.
- Haiku 4.5: 27 x (2,000 x $1 + 120 x $5) / 1M = **about $0.07 a user a month**, $0.84 a year.
- Sonnet 5: **about $0.14 a user a month**.
- Plus the proxy: about $5 a month flat at small scale.

At 1,000 active users that is roughly $900 a year on Haiku. Under `monetization.md`
(3% conversion, $9.99 once, about $8.49 net), those 1,000 users produce about 30 unlocks,
about $255, **once**. A per-user running cost cannot be paid by a one-time price (c).

### 4.3 What changes in the App Store paperwork if data leaves the phone

- **Privacy manifest and label (a, s).** Strata's manifest explains that
  `NSPrivacyCollectedDataTypes` is empty because nothing is transmitted. Sending win titles
  to a server that forwards them to an API provider is transmission. Unless the path is
  real-time only with **no retention anywhere** (the proxy logs nothing, and the provider
  retains nothing, which for Anthropic means an arranged zero-data-retention agreement),
  it must be declared: likely "Other User Content" (win titles) and "Product Interaction",
  linked or not linked to identity depending on the proxy's design. The App Store Connect
  answers must match.
- **Third-party AI consent (a, verify before building).** Apple's guideline 5.1.2(i), as
  revised in late 2025, requires apps to clearly disclose when personal data is shared with
  third parties **including third-party AI** and to obtain explicit permission first. A
  cloud North needs its own consent screen before the first call. On-device Foundation
  Models is Apple's own on-device framework, not a third party.
- **AI-generated content.** North generates text for one person from that person's own
  data; there is no user-to-user content, so the user-generated-content rules (1.2:
  reporting, blocking) do not apply to v1. They would apply to anything North writes that
  is ever sent to a circle.
- **Honesty.** Guideline 2.3 and general review practice expect an app not to mislead about
  what a feature is. A notification titled "North" that reads like a text is fine; one
  styled as a message from a real contact is not (hence no Communication Notifications).
- **The dead privacy-policy domain** (`strataapp.co`, `monetization.md`) blocks any
  submission that adds data flows, and arguably any submission at all.

### 4.4 True texting (SMS or iMessage) vs push notifications

| | Local notification | SMS | iMessage |
|---|---|---|---|
| Needs | Nothing new | The person's **phone number** (new personal data), a server, a provider (Twilio or similar), per-message fees, US A2P 10DLC or toll-free registration, TCPA consent records and STOP handling (a) | No general API exists for an app to send a person iMessages. Apple Messages for Business is for customer-service conversations the customer starts (a) |
| Privacy | Nothing leaves the phone | Win facts travel over carrier networks in plain text; the privacy label gains contact info | Not available |
| Feel | Arrives like a text, from the app | Arrives in Messages, next to real people | |
| Mute | iOS notification settings plus North's own toggle | Reply STOP | |

**Recommendation: against SMS and iMessage.** The "texting" feeling comes from the
writing, not the transport. SMS would make Strata collect a phone number, run a server and
pay per message to say something a local notification can say for free, and it would
place an app's words in the same inbox as the person's friends, which is the most intimate
channel a phone has and the least appropriate one for software to occupy uninvited (c).

### 4.5 Recommendation

**Build North on device.** Templates for every phone, Foundation Models phrasing where
available, `@Generable` output with a length guide, a banned-word filter, and a weekly
cache so each line is generated once. Revisit the cloud only if free-text "Message North"
proves popular *and* on-device answers are measurably not good enough, and even then only
with a monetization model that has recurring revenue (section 5).

---

## 5. Monetization fit

`monetization.md` settles the frame: free download, one $9.99 unlock ("Strata Everything"),
no subscription because "Strata runs entirely on the phone with nothing to fund", and "the
record is free, the keepsakes are paid" (s).

| Option | Verdict |
|---|---|
| **North free, on device** | **Recommended.** It costs nothing to run. Your Week already plays free; the line about the week is part of that record. And North is how the free app earns the trust that later sells the unlock. |
| North in "Strata Everything" | Possible for a *keepsake* form of North only, e.g. North's line printed onto the saved replay video (saving video is already paid). Do not gate the notification or the thread. |
| A North subscription (cloud) | **Not now.** It is the one thing in Strata that would genuinely have an ongoing cost, so it is the one honest case for a subscription under guideline 3.1.2(a). But it would add a server, a privacy label change, a consent screen and a recurring charge to an app whose whole promise is private and finished. If ever built: a separate optional tier for free-text chat only, never the weekly line. |
| Apollo's blurred-insight paywall | **Rejected.** "Your own words locked away" is the conversion lever; it is a dark pattern by the monetization doc's own tone rule. |

---

## 6. v1: prove North in the smallest shippable form

**What ships.**
- **The Sunday line from North.** When Your Week is ready, the notification is titled "North" and says one true, specific thing about the week ("31 wins. Your biggest week yet, and Thursday carried nine of them."). Only when the week has wins; one message, replacing today's generic replay notification body; opt-in at the first Your Week close.
- **The same line under the finished tower** in the Your Week and Your Month replays (and on their VoiceOver announcement, which already names the biggest day).
- **A North row in Profile** opening a quiet thread of every line North has written, with three computed chips ("What was my biggest day?", "What did I do most this month?", "What's my biggest week?") and a "Pause North" control.

**What v1 deliberately leaves out:** free text, milestones, comebacks, intentions (these
arrive with the goals v1), the widget line, anything cloud.

**How to know it worked (c).** Strata has no analytics and should not add them for this.
Use the owner and a TestFlight group: do people leave North on after a month, do they open
the Sunday notification more than the old generic one (ask), and does anyone report a line
that felt like being watched or judged. One such report is a fail.

### Build plan

| # | Piece | Size | Notes |
|---|---|---|---|
| 1 | `NorthFacts`: a pure function from a period's `WinRecord`s to a small fact set (count, biggest day and its count, top repeated title, personal record flags, first-week flag). Never emits zeros, declines or missing categories | **S** | Unit tests with Swift Testing; reuse `Replay.wins` so the rule matches the tower (s) |
| 2 | `NorthTemplates`: 15 to 25 hand-written sentence templates across the tone ladder, chosen deterministically per week so the same week always reads the same | **S** | Copy review against the Words rule; grep for long dashes and banned verbs in a test |
| 3 | `NorthFilter`: banned-word list, length cap (title 50 / body 100 characters, Rildy's limits), fall back to template on any failure | **S** | Tests include hostile win titles |
| 4 | `NorthPhraser` on Foundation Models: `@Generable` sentence with a length `@Guide`, fixed instructions, `if #available(iOS 26, *)` plus availability check, guardrail errors handled, one generation cached per period | **M** | Needs a real Apple Intelligence device to verify; the simulator cannot prove it (goals research) |
| 5 | `NorthMessage` SwiftData model (id, period, text, createdAt) | **S** | Fold into the CloudKit-defaults migration the concept research already plans, so the schema changes once |
| 6 | Wire into `ReplayReminder`: title "North", body from the phraser, regenerate on each app activation before Sunday (as today), template body always scheduled first | **S** | One notification, not two; respects the one-a-day rule |
| 7 | Opt-in sheet at the first Your Week close; Settings toggle; "Pause North" | **S** | Copy: "Want a line from North when your week is ready?" / "Yes" / "Not now". One sentence of disclosure |
| 8 | Replay close line in `ReplayScript` (script-driven, so it is in the video too) | **S** | Must go through the script, not `withAnimation` (s) |
| 9 | Profile row and thread view with three computed chips | **M** | Built to the tower screen's anatomy; no cards with rims, no bubbles with shadows (s) |
| 10 | Backoff: two unopened North notifications pause scheduling until an organic open | **S** | Needs the notification response delegate to record opens locally only |

**Total: about 1.5 to 2 weeks**, of which the Foundation Models phrasing (item 4) is the
only part with device-verification risk; items 1 to 3 and 5 to 10 are a complete North
without it.

**After v1, in order:** milestones and the comeback line (S), North's intention line with
the goals v1 (S once intentions exist), free-text "Message North" on device with the
distress path (M), a Lock Screen widget line (S).

---

## 7. Appendix

### 7.1 Notion pages read (40)

Rildy's workspace and North
1. Rildy's Workspace: https://app.notion.com/p/Rildy-s-Workspace-34fc3f3dc61181bf9a7ecb694b5287e2
2. Deliverable 1, North's Voice & Personality: https://app.notion.com/p/Deliverable-1-North-s-Voice-Personality-34fc3f3dc61181c59821e9ef457b5c36
3. Deliverable (Extra Credit), Voice Document: https://app.notion.com/p/Deliverable-Extra-Credit-Voice-Document-350c3f3dc611813cadbefef1ea2fd373
4. Deliverable 2, North Suggestion Chips: https://app.notion.com/p/Deliverable-2-North-Suggestion-Chips-34fc3f3dc611818c9578d4919fb4509a
5. Deliverable 3, Push Notification Library: https://app.notion.com/p/Deliverable-3-Push-Notification-Library-34fc3f3dc61181709e33e0b82074a552
6. Deliverable 4, Quote Bank: https://app.notion.com/p/Deliverable-4-Quote-Bank-34fc3f3dc61181ae814feb7d757421da
7. North, Research Accountability Checklist (Rildy): https://app.notion.com/p/North-Research-Accountability-Checklist-Rildy-350c3f3dc6118137b56be92fa289ca14
8. North, AI Personality Research Guide (for Rildy): https://app.notion.com/p/North-AI-Personality-Research-Guide-for-Rildy-350c3f3dc6118120bdbbc05f88db226a
9. Apollo, Retention, Conversion & Growth Research, May 3 2026: https://app.notion.com/p/Apollo-Retention-Conversion-Growth-Research-May-3-2026-355c3f3dc61181598655ce4fdde4e0e9
10. Apollo, What Makes North Feel Premium, May 3 2026: https://app.notion.com/p/Apollo-What-Makes-North-Feel-Premium-May-3-2026-355c3f3dc61181f6b659ffd2f372adc0
11. North's Personality & Brain (database, list view): https://app.notion.com/p/359c3f3dc6118011abc5c05c0f6153ed?v=35ac3f3dc611805ba231000c0860b6bd
12. Supportive Research: https://app.notion.com/p/Supportive-Research-351c3f3dc611801db242fdf839310d62
13. North (hub): https://app.notion.com/p/North-34fc3f3dc6118002a7abcfd7d8ea0516
14. Jayden's Workspace (contains only a "Notes" link, not opened): https://app.notion.com/p/Jayden-s-Workspace-351c3f3dc61180f9b409e274917d94d8
15. North, Rildy's Claude Prompt (research-backed): https://app.notion.com/p/North-Rildy-s-Claude-Prompt-research-backed-34fc3f3dc6118150af4aee238a478a07
16. North, Human Centered Interviews (interview notes section empty): https://app.notion.com/p/North-Human-Centered-Interviews-34dc3f3dc611811ba2ddc24ad8ab46c4
17. North, Final Definition, Apr 28 2026: https://app.notion.com/p/North-Final-Definition-Apr-28-2026-350c3f3dc61181409b6eedde28d8b663
18. North, Strategic Pivot, Apr 28 2026: https://app.notion.com/p/North-Strategic-Pivot-Apr-28-2026-350c3f3dc61181f6b0b1ee2050ff5b52
19. North, Competitive Research & Strategic Gap Analysis, Apr 28 2026: https://app.notion.com/p/North-Competitive-Research-Strategic-Gap-Analysis-Apr-28-2026-350c3f3dc61181cdba14e4ddbcb6e122
20. North, Insight Engine PRD, Apr 28 2026: https://app.notion.com/p/North-Insight-Engine-PRD-Apr-28-2026-351c3f3dc61181cfac00e1c68ad84981
21. North, What Kind of AI Is Best for ADHD: https://app.notion.com/p/North-What-Kind-of-AI-Is-Best-for-ADHD-35ec3f3dc611817e97f2c72fee5a31dc

Apollo product, positioning, growth
22. Apollo - Win. Every Day.: https://app.notion.com/p/Apollo-Win-Every-Day-968c3f3dc61183c498be81c9077b65ab
23. Apollo v2, ADHD-Native Positioning + Design Pivot, May 13 2026 (read to the sunset reveal animation spec; its final section was not read in full): https://app.notion.com/p/Apollo-v2-ADHD-Native-Positioning-Design-Pivot-May-13-2026-35fc3f3dc6118135a73ecd83e19a5b18
24. Apollo, What This App Is (AI Context): https://app.notion.com/p/Apollo-What-This-App-Is-AI-Context-358c3f3dc61181c8adb1cbcb00126d20
25. Why Apollo Will Work: https://app.notion.com/p/Why-Apollo-Will-Work-355c3f3dc611819eba76ed4edd9eb75a
26. Apollo Team Planner: https://app.notion.com/p/Apollo-Team-Planner-8c8c3f3dc6118301a342814f3ae9dcca
27. Apollo Private: https://app.notion.com/p/Apollo-Private-341c3f3dc611805fa0accb1b5e96cb59
28. Apollo, Complete AI Agent Brief (Read This First): https://app.notion.com/p/Apollo-Complete-AI-Agent-Brief-Read-This-First-358c3f3dc6118184b2f1c28acf7ce114
29. Apollo, Master Decision Log, Apr 27 2026: https://app.notion.com/p/Apollo-Master-Decision-Log-Apr-27-2026-350c3f3dc6118140bbaaec9860f937d4
30. Plain Language, UI Copy Rules: https://app.notion.com/p/Plain-Language-UI-Copy-Rules-34dc3f3dc61181b38c3cfeb2a211d3d6
31. User Persona: https://app.notion.com/p/User-Persona-343c3f3dc61181ebb9b1e971112e49db
32. Apollo, Complete Unit Economics (Full Cost Model), Apr 28 2026: https://app.notion.com/p/Apollo-Complete-Unit-Economics-Full-Cost-Model-Apr-28-2026-351c3f3dc611810cbb44f135b404fb2c
33. Apollo, North Screen Access & Paywall Spec, May 3 2026: https://app.notion.com/p/Apollo-North-Screen-Access-Paywall-Spec-May-3-2026-355c3f3dc6118152a02bfca875d39659
34. Apollo, Premium Feature Ideas, May 3 2026: https://app.notion.com/p/Apollo-Premium-Feature-Ideas-May-3-2026-355c3f3dc61181f4b12ae8e6a42bee07
35. Apollo, Viral Feature Strategy, May 6 2026: https://app.notion.com/p/Apollo-Viral-Feature-Strategy-May-6-2026-358c3f3dc61181d5a6b0fa21720baa6c
36. Apollo, Design-Led Viral Features, May 6 2026: https://app.notion.com/p/Apollo-Design-Led-Viral-Features-May-6-2026-358c3f3dc611810dbc93dab9f5308f95
37. Apollo, Notification Analytics Spec: https://app.notion.com/p/Apollo-Notification-Analytics-Spec-359c3f3dc611815b9676e41fa579a7ae
38. Apollo Wrapped, Full PRD, Apr 28 2026: https://app.notion.com/p/Apollo-Wrapped-Full-PRD-Apr-28-2026-351c3f3dc61181af9e52d77404506437
39. Apollo Memories, Feature PRD, Apr 28 2026: https://app.notion.com/p/Apollo-Memories-Feature-PRD-Apr-28-2026-351c3f3dc61181879a1bd7207393a970
40. Challenges, v1 Product Concept, May 11 2026: https://app.notion.com/p/Challenges-v1-Product-Concept-May-11-2026-35dc3f3dc61181628a38ff5df34d3dcf

### 7.2 Not opened

No page failed to open. These were seen in the Apollo trees and **skipped for the
40-page cap**, as lower priority for this question: Research on Problem Statement, App
Description, Growth Brief, PRD, Meeting Notes, Resources, Team Contacts, Notes (Jayden's
Workspace), Session Handoff May 12 2026, the older North series in Apollo Private (North
Screen LOCKED, PRD North Screen, Rildy's Creative Brief, Claude Prompt Template, Screen
PRD, Final Screen Spec with Photo Grid, Final Visual Design Spec, North Screen Claude
Design Prompt; the v2 pivot doc calls these "a stale sediment layer"), Three-Tier Pricing,
Unit Economics (earlier version), Business Plan, Achievements PRD, Daily Leaderboard PRDs,
Custom Win Categories Spec, Friends Screen Strategy, Friend Growth & Invite Psychology,
Motion Language & Visual Identity System, Olly Rosewell and Bloom CEO takeaways, and the
legal, equity and agreement pages (deliberately not opened).

### 7.3 Two things the owner may want to know

- **Two pages are link-public.** "North's Personality & Brain" and "Supportive Research"
  display "This page is visible to anyone with the link." Neither holds anything sensitive
  that I saw, but the setting may not be intended.
- **Apollo Private and the Team Planner hold equity, cap table and founding-agreement
  details.** They are not reproduced here.
