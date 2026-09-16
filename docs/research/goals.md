# Strata: guiding people toward what they want, invisibly

Written 2026-09-16. Read-only research: no checkout was edited, nothing was built,
no simulator was run. Code claims come from `/Users/jaydenbetts/StrataWork/owner-head`.
Claims are tagged **(a)** research, **(b)** a shipping product, **(c)** my inference.

Owner's words: *"The app is great at helping me visualize my progress, which is the
main objective, but something I feel is missing is that the app guides you toward
your goals. Let's say your goal is to lose ten pounds: I feel like the app should
challenge the user based on what they want out of life, and all the preferences can
be built into the onboarding. I want it to feel invisible but help the user want to
get to their wins and goals."*

---

## Summary in ten lines

1. **Principle:** guidance lives inside what Strata already shows (the slot, the win sheet, the week's close), speaks only about wins that happened, and says nothing at all about a day or week that had none.
2. **Call them intentions, not goals.** An intention is a direction ("move more"), in the person's own words, with no due date, no checkbox and no way to be behind.
3. **Onboarding:** one optional page. Tap up to three coloured blocks for the areas you want more of, then write one line if you like. "Skip" leaves Strata exactly as it is today.
4. **Evidence for:** progress monitoring works when it is recorded (Harkin 2016, d = 0.40), self-chosen goals are pursued harder (Sheldon and Elliot 1999), small visible progress drives good days (Amabile), plans tied to a situation help (implementation intentions, MCII g = 0.34).
5. **Evidence against:** broken streaks and contingent rewards backfire, goals narrow attention and invite gaming (Ordonez 2009), AI-written goals lose ownership (Chi et al. 2026), and weight-focused tracking is associated with disordered eating (Simpson and Mazzeo 2017).
6. **v1:** intentions (onboarding + Profile), past-tense "small steps" offered in the win sheet, the empty slot leaning toward an intention's colour, and one line at Your Week's close only when the week moved toward one.
7. **v2, once v1 proves it causes no guilt:** a weekly challenge offered at Your Week's close ("Three walks next week?"), celebrated by the tower's own dance, which simply expires if missed.
8. **"Lose ten pounds"** becomes actions the person controls ("move more", "cook more"). Strata never stores weight, never shows a body number, and never writes body words back to anyone.
9. **On-device model later:** Foundation Models (iOS 26, Apple Intelligence devices) can phrase small steps from the intention and past win titles, filtered and cached, with curated lists as the fallback. Nothing leaves the phone, so the privacy manifest does not change.
10. **Do not build:** goal progress bars, per-intention streaks, "you haven't" notifications, weight charts, badges, or an AI that writes the intention for you.

---

## 1. The tension, stated plainly

On 2026-09-10 Strata removed habits, repeating tasks, the Today timeline and the Plan
tab (`CLAUDE.md`, "What this is"). The pivot is **record what you did, not what you
plan**, and the rule that settles arguments is that recording a win is the fastest
thing in the app (`docs/product-direction.md`). The owner's own evidence was that he
kept habits in a spreadsheet because the app asked him to plan before it let him
record.

Goals pull backward toward planning in three specific ways:

| Pull | What it becomes if unchecked | Where Strata already refused it |
|---|---|---|
| A goal implies a **schedule** | "Walk Mon/Wed/Fri", which is a repeating task | `PlanItem.repeatDays` exists only inside the Plan sheet, never on the tower |
| A goal implies a **gap** | "0 of 3 this week", a debt you carry | Profile's streak shows best alongside current, "no red, no streak lost" (`docs/profile-and-head-plan.md` 4.2) |
| A goal implies **grading** | a bar that is not full, a day marked empty | "A replay that grades you is one people stop opening" (replay spec) |

**How goal guidance exists without undoing the pivot.** Seven rules, and every
mechanism in this document passes all seven:

1. **An intention is a direction, not a task.** It has no date, no count, no
   checkbox. It cannot be done, so it cannot be undone. (A time-boxed challenge is the
   single, opt-in exception, section 5.)
2. **Only presence is ever shown. Absence is never shown.** Strata can say "four
   wins toward moving more this week". It never says "no wins toward moving more",
   never shows an empty ring, never draws a missing block.
3. **Guidance appears only where attention already is.** The slot you are about to
   press, the sheet you already opened, the replay you chose to watch, Profile. No new
   tab, no new notification of its own, no badge.
4. **Doing nothing is a complete answer.** Every suggestion is ignorable by not
   touching it, and ignoring it leaves no trace.
5. **The person's words, not the app's.** The intention is written by the person.
   Strata may offer ways to phrase a small step, never the goal itself.
6. **Suggestions are past tense.** "Went for a walk", not "Go for a walk". A
   suggestion is a way to name a win you already had, which keeps the record honest:
   nothing on the tower is something you meant to do.
7. **No body or diet numbers, ever.** Wins toward a health intention are counted as
   wins, not pounds, calories or steps.

The result is that a day with no progress looks exactly like a day with no progress
does today: an empty slot and nothing else.

---

## 2. Evidence

### 2.1 What works

**Goal-setting theory (Locke and Latham 2002)** (a). Specific, committed goals with
feedback raise performance; effects are smaller on complex tasks where learning
dominates, and commitment, self-efficacy and feedback moderate the effect.
*For Strata:* the feedback part is what the tower already does. The "specific
difficult goal" part is the risky part (see 2.2), so Strata takes the feedback and
the commitment, and leaves difficulty to the person.
Source: Locke and Latham, *American Psychologist* 57(9), 2002.
https://pubmed.ncbi.nlm.nih.gov/12237980/

**Progress monitoring (Harkin et al. 2016)** (a). 138 randomised studies, N = 19,951.
Prompting people to monitor progress promoted goal attainment (d = 0.40), and the
effect was larger **when progress was physically recorded**.
*For Strata:* a block is a physical record of progress. This is the strongest single
argument that Strata is already the right instrument and needs only to point it.
Source: *Psychological Bulletin* 142(2), 2016. https://pubmed.ncbi.nlm.nih.gov/26479070/

**The progress principle (Amabile and Kramer 2011)** (a). Across roughly 12,000 diary
entries, making progress in meaningful work was the most common trigger of a good
day, and small wins counted.
*For Strata:* "meaningful" is the missing word. An intention is what makes a small
win meaningful to the person logging it.
Source: HBR, May 2011. https://hbr.org/2011/05/the-power-of-small-wins

**Self-determination theory and self-concordance** (a). Goals pursued for autonomous
reasons get more sustained effort, are attained more often, and their attainment
raises need satisfaction (autonomy, competence, relatedness) and wellbeing
(Sheldon and Elliot 1999).
*For Strata:* the intention must be the person's, in their words, and changeable
without friction. Autonomy: nothing required. Competence: the tower shows what you
did. Relatedness: Your Week, and later sending a week (research-concept-and-social.md).
Source: *JPSP* 76(3), 1999. https://pubmed.ncbi.nlm.nih.gov/10101878/

**Mental contrasting with implementation intentions, WOOP (Oettingen)** (a). A
meta-analysis of 21 studies (N = 15,907) found MCII improves goal attainment,
g = 0.336, stronger when guided interactively (0.465) than by documents (0.277).
Separately, implementation intentions ("when X, I will Y") improved exercise
participation over motivation alone (Milne, Orbell and Sheeran 2002).
*For Strata:* the full WOOP exercise is too heavy for a one-tap app and is a
planning ritual. The part that transfers is **"when" without "must"**: a small step
tied to a situation ("after work, a walk") offered as a suggestion, and the
obstacle question asked once, optionally, at the week's close.
Sources: Wang et al., *Frontiers in Psychology* 2021,
https://pmc.ncbi.nlm.nih.gov/articles/PMC8149892/ ; Milne et al., *BJHP* 2002,
https://pubmed.ncbi.nlm.nih.gov/14596707/

**The fresh start effect (Dai, Milkman and Riis 2014)** (a). Searches for "diet", gym
visits and goal commitments all rise after temporal landmarks: a new week, month,
year, birthday.
*For Strata:* Your Week already arrives on Sunday and Your Month on the 1st
(`ReplayReminder`). Those are the moments to offer anything forward-looking, and the
only ones.
Source: *Management Science* 60(10), 2014. https://pubsonline.informs.org/doi/10.1287/mnsc.2014.1901

**Identity framing** (a, with a caveat). Asking about "being a voter" rather than
"voting" raised turnout (Bryan et al. 2011), the research root of "identity-based
habits". **A large field replication did not find the effect** (Gerber et al. 2016).
*For Strata:* use identity language lightly and never as a claim about who someone is
("You're a runner now" is a judgement). The honest identity move is the tower itself:
a month of green blocks says it without words.
Sources: https://www.pnas.org/doi/10.1073/pnas.1103343108 ;
https://www.pnas.org/doi/10.1073/pnas.1513727113

### 2.2 What backfires

**Goals gone wild (Ordonez, Schweitzer, Galinsky and Bazerman 2009)** (a). Specific
goals narrow attention to the measured thing, distort risk, invite cheating and can
reduce intrinsic motivation.
*For Strata:* a numeric goal inside a win tracker invites logging for the number,
which fills the record with wins that did not really happen. The record is only
valuable because it is true.
Source: *Academy of Management Perspectives* 23(1), 2009.
https://papers.ssrn.com/sol3/papers.cfm?abstract_id=1332071

**Progress as licence (Fishbach and Dhar 2005)** (a). Dieters reminded of their
progress chose a chocolate bar over an apple 85% of the time against 58% for those not
reminded.
*For Strata:* do not celebrate distance toward an outcome ("almost there"). Celebrate
the act. "You went for four walks" reinforces the behaviour; "you're 70% of the way"
licenses stopping.
Source: *Journal of Consumer Research* 32(3), 2005.
https://academic.oup.com/jcr/article-abstract/32/3/370/1867208

**Broken streaks and contingent rewards** (a). Already established in
`research-game.md`: broken streaks demotivate, most when people blame themselves
(Silverman and Barasch 2023); expected, contingent rewards reduce intrinsic
motivation (Deci, Koestner and Ryan 1999).
*For Strata:* no per-intention streak. No reward unlocked by reaching a challenge.

**AI-written goals lose ownership (Chi et al. 2026)** (a, preprint). In a
preregistered experiment (N = 470), LLM-generated goals scored far higher on SMART
criteria (d = 2.26) but participants felt less ownership, commitment and importance;
72.8% of self-authored participants acted on several goals against 46.6% with LLM
goals. The loss was worst for people with low self-efficacy.
*For Strata:* the on-device model may suggest *steps*, never the intention.
Source: arXiv 2605.12344, May 2026. https://arxiv.org/abs/2605.12344

**Weight and body tracking** (a). Among 493 undergraduates, calorie tracking was
associated with eating concern and dietary restraint, and fitness tracking emerged as
a unique indicator of eating disorder symptoms (Simpson and Mazzeo 2017). Reviews of
weight-neutral interventions report wellbeing gains and reduced internalised weight
bias without making weight the target, while weight-focused approaches carry risks of
weight cycling, self-criticism and stigma.
*For Strata:* never store weight, never show a body number, never message about body
size, and never let an activity suggestion become an exercise quota.
Sources: *Eating Behaviors* 26, 2017, https://pubmed.ncbi.nlm.nih.gov/28214452/ ;
Tylka et al. 2014, https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4132299/ ;
weight-neutral mixed-methods review 2025, https://pmc.ncbi.nlm.nih.gov/articles/PMC12053462/

### 2.3 How apps do it

| App | Mechanism | Lesson for Strata |
|---|---|---|
| **Apple Fitness** (b) | Ring goals adjustable per weekday; rings can be paused up to 90 days without breaking the award streak; a Monday summary offers to adjust next week's goal; Trends compares recent weeks to the longer average | Goals must bend to life, and the weekly landmark is where to offer a change. Pausing without penalty is the right shape of "let it rest". https://support.apple.com/guide/watch/adjust-your-activity-ring-goals-apd29b30023c/watchos |
| **Strava** (b) | Weekly, monthly and annual distance or time goals; progress goals are private; progress shown on the activity itself | Private by default; progress appears on the thing you just did, not in a separate dashboard. https://support.strava.com/en-us/articles/15401694-goals-on-the-strava-app |
| **Finch** (b) | Tiny self-set goals; the pet never dies, missing a day costs nothing, absence meets encouragement | The best evidence that no-punishment goal support retains people, especially people for whom other apps felt punishing. https://slate.com/technology/2026/09/finch-app-self-care-wellness-review.html |
| **Streaks** (b) | Up to 24 daily tasks, each a streak | The model Strata left. Useful as the contrast. https://apps.apple.com/us/app/streaks/id963034692 |
| **Structured** (b) | Visual timeline of the planned day, energy-based planning, marketed for ADHD | A planner done well is still a planner; Strata should not compete here. https://structured.app/ |
| **Fabulous** (b) | Long onboarding quiz, signed "commitment contract", then paywall; frequent coaching notifications | Criticised for a quiz that exists to sell a trial and for too many nudges. Strata's onboarding must be short, optional and ask for nothing it will not use. https://www.thebehavioralscientist.com/articles/fabulous-app-product-critique-onboarding |
| **Noom** (b) | Onboarding survey, weight-loss target, calorie budget, coaching | Criticised for low calorie goals and algorithmic weight targets; settled a $62M class action over trial auto-renewal; Privacy International questioned whether long surveys tailored anything. The cautionary tale for "lose ten pounds". https://en.wikipedia.org/wiki/Noom |
| **Headspace** (b, from product use, not re-verified today) | Asks what brings you (stress, sleep, focus) and tailors the home screen's recommendations | Onboarding intent used only to order suggestions, never to grade. The right weight for Strata's intentions. |
| **Duolingo** (b) | Streak freeze, streak wager (+14% day-14 retention reported) | Proves loss aversion retains; also exactly what Strata must not do, because it retains through fear of loss. https://econsultancy.com/six-a-b-tests-used-by-duolingo-to-tap-into-habit-forming-behaviour/ |
| **Rise** (b) | Sleep debt and a predicted energy schedule; nudges at the right time of day | Timing to the person's natural rhythm is the good idea; a "debt" framing is the one to avoid. https://www.risescience.com/ |
| **Oura** (b) | Readiness score, lowest band labelled "Pay attention"; framed as a planning signal | Even gentle scores can feed anxiety (orthosomnia). Strata has no score and should not grow one. https://en.wikipedia.org/wiki/Orthosomnia |
| **Apple Journal** (b) | On-device suggestions, reflection prompts | Prompts at the moment you are already reflecting, privately. |

### 2.4 What "invisible guidance" means in practice

Distilled from the above (c):

- **It changes defaults, not demands.** The slot's colour, the order of suggestions,
  the words at the close. The person never sees a new obligation.
- **It is located, not broadcast.** It appears inside an action the person already
  started, so it arrives as help, not interruption.
- **It is asymmetric.** It reflects wins toward the intention and is silent on the
  absence of them.
- **It is owned.** The intention is theirs; the app only reflects it back.
- **It is reversible without cost.** Change it, rest it, or turn any part off in
  Profile, and nothing is lost or marked.

The test for any future mechanism: **if the person never engages with it, would
they be able to tell it exists?** For v1 the honest answer should be "only by the
slot's colour and a line on Sunday".

---

## 3. Onboarding

### Where it goes

`OnboardingView` has six steps today: tower (0), workshop (1), camera (2), map (3),
head (4, `headStep`), thank you (5). The intention page goes **after the workshop
and before the camera** (new step 2), because it is about wins, and the person has
just drawn their first ones. It follows the file's own rules: full-bleed, one line of
title, at most two of body, the real app's objects rather than a picture of them.

### The page: "What do you want more of?"

**Stage:** `WarmBackground`. Six real blocks (`BlockSurface`, the six
`HabitCategory.selectable` colours with their icons), each with a short area name
beneath. Tapping one drops it into a small tower above, with the same fall the
workshop uses; tapping it again lifts it out. Up to three. Choosing literally builds a
tower, so the page teaches the idea it introduces.

**Area names** (onboarding and Profile only; the categories keep their names
elsewhere):

| Category | Colour | Name on this page |
|---|---|---|
| `health` | green `0x0EAD74` | Moving and health |
| `work` | blue `0x40A9FF` | Work |
| `creativity` | purple `0xAF9CFA` | Making things |
| `focus` | amber `0xFDB54F` | Learning |
| `social` | coral `0xF97066` | People |
| `mindfulness` | pink `0xEC85B4` | Calm |

**Copy, first state:**

- Title: **What do you want more of?**
- Body: **Pick up to three. Your wins will lean toward them.**
- Primary (disabled until one is picked, using the existing "different pill, not a
  faded one" style): **These ones**
- Secondary: **Skip**

**Second state, after "These ones"** (same page, the chosen blocks stay; one field
appears per chosen area, all optional):

- Title: **In your own words**
- Body: **One line each, if you like. Only you see it.**
- Field placeholder per area, by colour: health "Like: feel stronger",
  work "Like: finish the portfolio", creativity "Like: draw every week",
  focus "Like: read more", social "Like: call Mum more", mindfulness
  "Like: slow down in the evenings".
- Primary: **Done** (always enabled; blank fields keep the area name as the words)
- Secondary: **Leave it blank**

That is the whole questionnaire: at most three taps and three optional lines. No
age, no weight, no schedule, no "how many days a week", no commitment contract.

**If the words mention weight or body size**, the field shows one line under it
before Done, never a blocking dialog. See section 5.3.

### Skipping

"Skip" on the first state, or "Leave it blank" with nothing chosen, creates no
`Intention`. Every mechanism in section 4 checks for an active intention and does
nothing without one, so a person who skips gets today's Strata exactly: the slot's
least-used colour, no suggestions, no line at the close.

The existing Settings row "How Strata Works" replays onboarding and so reaches this
page again.

### Changing it later: Profile

A new section in `ProfileView`, above "Your head":

```
What you're building
  ● Moving and health     feel stronger            ›
  ● People                call Mum more            ›
  + Add one                                         (hidden at three)

  Suggestions when you add a win        [on]
  A line in Your Week                   [on]
  Challenge offers                      [off]        (v2)
```

Tapping a row opens a small sheet: the words (editable), the colour (the same six
circles as the win sheet), and at the bottom **Let it rest** (archives it; wins keep
any link; "Wake it up" restores it from a "Resting" list) and **Delete** (removes the
intention; wins keep their colour and category, the link is cleared).

Section footer copy: **Only on this phone. Nothing here is ever a to-do.**

Why "Let it rest" and not only delete: Apple Fitness's pause is the precedent, and
it lets an intention end without a failure word. There is no "Mark complete" either:
an intention is a direction, and declaring it finished would turn it into a goal
with a grade.

---

## 4. Invisible guidance mechanisms

Ratings: **Help** is expected usefulness toward the intention; **Push risk** is the
chance it feels pushy or guilt-inducing; **Effort** S (days) / M (one to two weeks) /
L (a month).

### M1. The slot leans toward an intention's colour

- **Looks like:** the empty slot's dashed outline and wash (`NextSlotButton`,
  `previewCategory`) wear an intention area's colour more often than chance.
- **When:** every time the slot rerolls (`rerollNextWinCategory`). Rule: if an
  intention area has no win yet today, the next colour is that area with probability
  1/3; otherwise `QuickWinService.spontaneousCategory` runs as today.
- **Why invisible:** the slot already previews a colour, and nobody knows why it
  picked this one. It is a colour prime, not a word. It stays a spontaneous colour,
  not a category (the "two facts" rule in `CLAUDE.md`), so it claims nothing.
- Help: low to medium. Push risk: very low. Effort: **S**.

### M2. Small steps in the win sheet

- **Looks like:** in `AddWinSheet`, below "What did you do?" while the field is empty,
  one row of up to three plain text chips in the area's ink:
  `Went for a walk` `Stretched` `Cooked a meal`. Tapping one fills the title, presses
  the swatch (so the category is *chosen*) and links the win to the intention. The row
  disappears the moment the person types.
- **When:** only when the sheet is opened to create a win and an intention is active.
  Never on edit, never on a draw-to-log (which skips the sheet by design), never from
  the camera review.
- **Why invisible:** it is a faster way to name something you already did, inside a
  sheet you opened. Past tense means it is never a to-do. Ignoring it costs nothing.
- **Chip source:** curated lists per area, first; the on-device model later (section 6).
  Ordered by the person's own past titles first, so after a week it mostly offers
  their words back.
- Help: high. Push risk: low (medium if the chips became imperatives, which is why
  they are past tense). Effort: **S** curated, **M** with the model.

### M3. One line at Your Week's close

- **Looks like:** under the finished tower at the replay's close, one quiet line in
  `inkSecondary`: **"5 of your wins went toward call Mum more."** or, with more than
  one intention, **"Most of this week went toward moving and health."**
- **When:** only when at least one win in the week counts toward an intention
  (definition in section 7). **A week with none shows no line at all**, not a softer
  line. Never in the exported video by default (a private line on a shareable
  artefact).
- **Why invisible:** it is in the replay, which is already a reflection the person
  chose to open, and it only ever reports presence.
- Must be driven by `ReplayScript` time like every other element of the close
  (`CLAUDE.md`, "Replays": no `withAnimation`).
- Help: high. Push risk: low. Effort: **S**.

### M4. The month tower shows balance, by colour alone

- **Looks like:** nothing new drawn. In Profile's "Wins per week" chart, the sentence
  gains a clause when true: **"About 18 wins a week, and more of them toward
  learning than last month."**
- **When:** only when the share of wins toward an intention rose by the existing 20%
  band that Profile already uses before calling anything a change. Falls are not
  mentioned.
- **Why invisible:** Profile already writes a sentence from the numbers; this is one
  clause in it, only in the good direction.
- Help: medium. Push risk: low. Effort: **S**.

### M5. The week's question, tied to the intention

- **Looks like:** the reflective line already recommended in
  `research-concept-and-social.md` (feature 3), but the question takes the intention
  when one moved: **"What helped with call Mum more this week?"** Otherwise the plain
  **"What made this week?"**. A single field, skippable by doing nothing.
- **When:** at the close of Your Week, after M3's line.
- **Why invisible:** one optional field at a reflective moment. It is the "obstacle
  and plan" half of WOOP turned around: it asks what *helped*, which people can
  answer on a good week and which becomes their own plan for next week.
- Help: medium to high. Push risk: low (medium if asked on weeks with nothing, so it
  never is: on those weeks it falls back to the plain question).
- Effort: **S** once feature 3 exists.

### M6. "On this day" favours wins toward an intention

- **Looks like:** the planned "On this day" card in the Memories drawer, when several
  past days qualify, prefers a day with wins toward an active intention, ideally with
  a photograph.
- **When:** wherever "On this day" appears; no new trigger.
- **Why invisible:** it only changes which memory is chosen. Nostalgia raises
  self-continuity (research-concept-and-social.md), which is identity without words.
- Help: medium. Push risk: very low. Effort: **S** on top of "On this day" (**M**).

### M7. The daily reminder learns the intention's natural time

- **Looks like:** the existing `DailyReminder` (only on a day with nothing logged,
  taken back when a win lands) keeps its title **"Nothing on today's tower yet"** and
  its body **"Anything you finished counts."**. What changes is only the *time*
  offered: Settings suggests the median hour at which wins toward the person's
  intentions are usually logged ("Most of your wins land around 7 pm").
- **When:** a suggestion under the existing time picker, never applied automatically.
- **Why invisible:** it changes when an already-opted-in reminder fires, and never
  names the intention. **A notification that names the goal on a day with nothing is
  the single most guilt-shaped thing this feature could do, and it is ruled out.**
- Help: low to medium. Push risk: medium (any notification carries some). Effort: **S**.

### M8. A light weekly challenge

- Fully specified in section 5. Offered at Your Week's close, accepted with one tap,
  celebrated by the tower's own dance, silent if missed.
- Help: medium to high for people who like a nudge. Push risk: **medium**, the
  highest here, which is why it is v2 and opt-in. Effort: **M**.

### M9. Wins toward an intention wear their meaning on the block card

- **Looks like:** on the flipped block card (`FlippableBlockView`), beneath the
  title, one small line: **"Toward feel stronger"**.
- **When:** only for wins that count toward an intention.
- **Why invisible:** the card is only seen by someone who flipped a block.
- Help: low to medium. Push risk: very low. Effort: **S**.

### M10. The fresh-start check-in

- **Looks like:** at Your Month's close (the 1st, a landmark), below the tower,
  one row per intention that has had **no linked wins for the whole month**:
  **"Still want more of learning?"** with **Keep it** and **Let it rest**. Doing nothing
  keeps it.
- **When:** monthly, only for intentions that went quiet, and only once per
  intention per quiet stretch.
- **Why invisible:** it is the one place Strata acknowledges a quiet intention, and it
  does so by offering to let it go, not by pointing at the gap. Stale intentions left
  in place would otherwise make every other mechanism slightly wrong.
- Caveat: this is the one mechanism that is *about* absence. It is phrased as a
  choice about the future, at a fresh-start moment, monthly at most.
- Help: medium. Push risk: medium. Effort: **S**. (Your Month is a paid keepsake per
  `docs/monetization.md`; the same row can appear in Profile for free users.)

### Summary table

| # | Mechanism | Help | Push risk | Effort | Ships in |
|---|---|---|---|---|---|
| M1 | Slot leans toward intention colour | Low to med | Very low | S | v1 |
| M2 | Small steps in the win sheet | High | Low | S / M | v1 (curated), v3 (model) |
| M3 | One line at Your Week's close | High | Low | S | v1 |
| M4 | Balance clause in Profile's sentence | Medium | Low | S | v1.1 |
| M5 | Week's question tied to intention | Med to high | Low | S | v1.1 |
| M6 | On this day favours intention wins | Medium | Very low | S (+M) | with On this day |
| M7 | Reminder time suggestion | Low to med | Medium | S | later |
| M8 | Weekly challenge | Med to high | Medium | M | v2 |
| M9 | "Toward ..." on the block card | Low to med | Very low | S | v1.1 |
| M10 | Fresh-start check-in on quiet intentions | Medium | Medium | S | v2 |

### Considered and rejected

| Idea | Why not |
|---|---|
| A progress bar or ring per intention | Shows absence by construction: an unfilled ring is a gap. |
| A streak per intention | A second and third streak, each breakable (Silverman and Barasch). |
| "You haven't moved this week" notification | Names the goal on the day with nothing. Guilt, and it reads as watching. |
| An intention colour marked on month-grid days that lacked one | Absence drawn on the record. |
| Badges for intention milestones | Contingent rewards (Deci 1999); the tower is the reward. |
| Converting intentions into Plan lines | Brings back the repeating task through the side door. `PlanItem` stays separate. |
| Showing intentions on the tower header | "Nothing sits under the tower", and the header is count, word, pill and Plan. |
| "Almost there" framing | Licenses stopping (Fishbach and Dhar). |

---

## 5. Challenges

### 5.1 Should they exist

Yes, **once**, as the only forward-looking object in the app, because the owner asked
for "challenge the user", and a challenge done this way is the most direct form of
the goal-setting evidence that still passes the seven rules. But v2, not v1: v1 must
first show that intentions alone do not make anyone feel behind.

### 5.2 The rules

1. **Opt-in, every time.** A challenge exists only when the person taps to accept one.
   There is no standing challenge and no auto-renewal.
2. **One at a time**, attached to one intention.
3. **Time-boxed to one calendar week** (the week `ReplayPeriod.week` already uses,
   locale-aware start). It starts the moment it is accepted and ends when the week
   closes.
4. **Small and counted in wins.** A number from 1 to 5 of a named kind of win
   ("3 walks"). Never minutes, distance, steps, weight, food or money.
5. **Suggested from the person's own recent pace.** Default offer = the median weekly
   count of wins toward that intention over the last four weeks, plus one, clamped to
   1...5. With no history, 2. The person can change the number with a stepper before
   accepting. Self-set is available from the intention's Profile sheet.
6. **Counts only wins that already count toward the intention**, and only those whose
   title matches the challenge's words or that were logged from its small-step chip.
   Untitled one-tap wins do not count, because their colour was not chosen.
7. **Reached: the tower celebrates, once.** The win that reaches the number triggers
   the existing dance (`GridConstants.danceEvery` machinery), not a badge, sound
   pack or sheet. Extra wins beyond the number are simply wins.
8. **Missed: nothing happens.** No message at the time, no notification, no mark on
   the week, no line at the close, no count of missed challenges anywhere. The
   challenge quietly expires with the week.
9. **Offered at most once a week**, only at Your Week's close, only when an intention
   is active and "Challenge offers" is on.
10. **Declining is data.** Two "Not now" in a row, or two expired challenges in a
    row, and Strata stops offering for four weeks. It never re-offers a smaller
    number to "make it easier", which would say "you failed the bigger one".
11. **No streak of challenges**, no history list, no "challenges completed" count.
12. **Private.** Never in the exported video, never shared.

### 5.3 Copy

**The offer**, at Your Week's close, below M3's line (or in its place on a week
with no linked wins, since this is forward-looking):

- Line: **"Next week, 3 walks?"** (words from the intention's most-used small step)
- Stepper on the number, in the numeral font
- Buttons: **Try it** · **Not now**

**While it runs**, the only surface is the small-steps row in the win sheet, where the
challenge's step is ordered first. No progress count is shown in-app. In Profile's
intention sheet, one line: **"This week: 3 walks."** (the target, not a fraction).

Why no "2 of 3": a fraction is a gap. The person knows how many walks they went on;
Strata celebrates when they get there.

**Reached** (the dance, plus one line in the win sheet's saved state if the sheet is
open, otherwise nothing): **"3 walks. That's the week you wanted."**

**At the next Your Week close, if reached:** **"You said 3 walks. You went on 4."**

**If missed:** no copy. The week's close shows M3's line if any wins counted, and
the next offer follows the rules above.

**Self-set, from Profile:** row **"Set a challenge for this week"** opens the same
stepper. Button **Start**. Footer: **"If the week gets away from you, it just ends."**

### 5.4 "Lose ten pounds", handled responsibly

**The principle:** Strata helps with what the person does, never with what their
body measures. Weight is an outcome people do not directly control, it fluctuates
daily, and tracking it is associated with disordered eating (section 2.2). The person
is free to want it; Strata will not measure it.

**In onboarding and Profile,** if the words contain weight or body terms (a short
local list: lose weight, pounds, lbs, kg, stone, weigh, weight, diet, calories, fat,
skinny, thin, slim, body, BMI), a single line appears under the field, not a dialog:

> **Strata can't see pounds, but it can see what you do. Want to put it as something you'd do more of?**

with three tappable rewrites in the health colour: **move more** · **cook more at home** ·
**sleep better**, and **Keep my words**.

- Tapping a rewrite replaces the words.
- **Keep my words** keeps them exactly, because the intention is theirs (autonomy,
  section 2.1). But Strata **never echoes those words back** anywhere it writes on its
  own: M3, M5, M8 and M9 use the area name ("moving and health") instead when the
  words matched the list. The person sees their words only where they wrote them.

**What Strata never does for a health intention:**

- Stores weight, body measurements, BMI, calories, macros or meal logs. There is no
  field for them. (If someone logs "weighed in" as a win, it is a win like any other,
  with no number extracted and no chart.)
- Suggests restriction: no skipping meals, fasting, cutting foods, "earning" food,
  or amounts to eat.
- Suggests exercise quotas or intensity beyond gentle, open-ended actions ("a walk",
  "stretched", "a swim"). The default challenge ceiling of 5 a week applies.
- Uses body words in any line it generates: no "slimmer", "burn", "toned", "guilt-free".
- Celebrates a number of anything body-related.

**The small steps offered** for a health intention with weight words are only
additive and self-caring: *Went for a walk · Cooked a meal · Got outside · Went to bed
earlier · Drank some water · Stretched · Moved with a friend*.

**If words suggest harm** (a small list: purge, starve, not eat, stop eating, laxative,
under 1000 calories, and similar), no suggestions and no challenges are ever offered
for that intention, and the area name is used everywhere. This document does not
recommend in-app crisis messaging: detecting it from a few words is unreliable, and
an app that responds to a private line with a clinical message reads as watching.
It is worth a one-off consultation with an eating disorder clinician before v2 to
confirm the lists and this decision (c).

**What "challenge" means here:** "Next week, 3 walks?" is the whole of it. The person
who wrote "lose ten pounds" gets exactly the same mechanism as everyone else, pointed
at a behaviour they control.

---

## 6. On-device intelligence

### 6.1 Can Foundation Models do it

Yes, for the small steps (M2), with limits (b, from Apple's documentation and
developer write-ups):

- `SystemLanguageModel.default` is the on-device model behind Apple Intelligence.
  Requires **iOS 26** and an **Apple Intelligence-capable device** with Apple
  Intelligence turned on and the model downloaded. Check
  `SystemLanguageModel.default.availability` every time; it can be unavailable for
  device eligibility, the setting being off, or the model not being ready.
- `@Generable` and `@Guide` give typed, structured output rather than free text.
- A default guardrail is always applied, and generation can throw a guardrail
  violation that must be handled.
- Apple's **Acceptable use requirements** prohibit using the framework for regulated
  healthcare services, among other things. Suggesting "went for a walk" is not a
  healthcare service; prescribing exercise or diet for a condition would drift toward
  one. The guard rails below keep it firmly on the first side.
- Strata's deployment target is **18.0**, so this is gated with `if #available(iOS 26, *)`
  and availability, and the curated lists are the product for everyone else.

Sources: https://developer.apple.com/documentation/FoundationModels/generating-content-and-performing-tasks-with-foundation-models ;
https://developer.apple.com/apple-intelligence/acceptable-use-requirements-for-the-foundation-models-framework/ ;
https://www.createwithswift.com/exploring-the-foundation-models-framework/

### 6.2 Shape

```swift
@Generable
struct SmallSteps {
    @Guide(description: "Past-tense phrases for small things a person already did, 2 to 5 words each, no numbers except minutes under 60", .count(6))
    var steps: [String]
}
```

- **Input:** the intention's words (or the area name when they matched the weight
  list), the area, and up to 20 of the person's own recent win titles in that area.
  Nothing else: no photos, places, names, or other intentions.
- **Instructions (fixed, not user-editable):** write past-tense, everyday, gentle
  actions; no food restriction, no amounts of food, no weight or body words, no medical
  advice, no intensity, nothing that implies the person should feel bad; prefer the
  person's own phrasing from their titles.
- **When it runs:** when an intention is saved or edited, and at most once a week
  after that, in the background. Results are cached on the intention. **It never runs
  while the win sheet is opening**, so logging stays the fastest thing in the app.
- **Mixing:** the chip row shows the person's own matching past titles first, then
  cached generated steps, then curated ones.

### 6.3 Guard rails, in code, after generation

A pure, tested `SmallStepFilter` rejects any phrase that:

1. Is not 2 to 5 words, or does not start with a past-tense verb from an allow-list
   (walked, went, cooked, read, called, drew, stretched, slept, wrote, made...).
2. Contains a number, unless it is "N minute(s)" with N under 60.
3. Contains any term from the weight/body list or the harm list in 5.4.
4. Contains food-restriction verbs (skipped, cut, avoided, fasted, only ate) or
   "should", "must", "need to", "didn't".
5. Duplicates a curated or existing chip.

If fewer than two phrases survive, or availability is not `.available`, or generation
throws, the curated list is used. Nothing generated is ever shown without passing the
filter, and the filter's tests include adversarial intentions ("lose 20 pounds fast",
"stop eating after 6").

And the rule from Chi et al. 2026: **the model never writes, rewrites or suggests
the intention itself.** Only steps.

### 6.4 Curated fallback (ships first)

Six lists, about twelve past-tense phrases each, reviewed against the Words rules (no
long dashes, nothing that sounds like surveillance). Examples:

- Moving and health: Went for a walk · Stretched · Got outside · Went for a swim ·
  Cooked a meal · Went to bed earlier · Rode my bike
- Work: Finished a draft · Sent the email · Cleared my inbox · Shipped something ·
  Asked for help
- Making things: Drew something · Wrote a page · Played guitar · Took a photo I like
- Learning: Read a chapter · Practised for 20 minutes · Watched a lecture · Learned a word
- People: Called someone · Had dinner with friends · Sent a kind message · Checked in on someone
- Calm: Took a slow breath · Journalled · Sat outside · Put my phone away

The existing `CategorySuggestionEngine` keywords are the seed for matching a
person's own titles to an area.

### 6.5 Privacy

- On-device inference is not "collection" under Apple's definition (data processed
  only on device), so `PrivacyInfo.xcprivacy`'s `NSPrivacyCollectedDataTypes` **stays
  empty**. No new usage string.
- The privacy policy gains one sentence, because what the app claims must be true
  (`CLAUDE.md`): **"What you want more of, and any suggestions made from it, stay on
  this phone. Suggestions are written on your phone and never sent anywhere."**
- Intentions sync with iCloud once that ships, like wins do, and the policy's iCloud
  paragraph should list them.
- Do **not** use any hosted model, even if a future framework version makes other
  providers available through the same API. The whole claim is "on this phone".

---

## 7. Data model

### 7.1 `Intention`

```swift
@Model
final class Intention {
    var id: UUID = UUID()
    /// `HabitCategory.rawValue`. The colour and the area.
    var areaRaw: String = HabitCategory.health.rawValue
    /// The person's words. Empty means "use the area name".
    var words: String = ""
    /// Set when `words` matched the weight/body list, so generated lines use the area name.
    var usesAreaNameInCopy: Bool = false
    /// Set when `words` matched the harm list: no suggestions, no challenges.
    var suppressesSuggestions: Bool = false
    var order: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    /// "Let it rest". Nil while active.
    var restingSince: Date? = nil
    /// Cached generated steps, newline-joined (a `[String]` cannot be used in a predicate
    /// and does not need to be).
    var generatedStepsRaw: String = ""
    var generatedAt: Date? = nil
    /// Social-ready. Intentions are never shared in any planned phase.
    var isPrivate: Bool = true

    var area: HabitCategory { HabitCategory(rawValue: areaRaw) ?? .health }
    var isActive: Bool { restingSince == nil }
}
```

**No target on the intention, on purpose.** The brief suggests an optional target
like "3 times a week". A standing weekly target on an intention *is* a repeating
habit with a quota, which is exactly what was removed on 2026-09-10. Targets live only
on a `Challenge`, which is one week long and opt-in each time. If a standing target
is ever wanted, it can be added later: CloudKit schemas are add-only, and an optional
field with a nil default is a safe addition.

### 7.2 `Challenge` (v2)

```swift
@Model
final class Challenge {
    var id: UUID = UUID()
    var intentionID: UUID? = nil
    var target: Int = 2               // 1...5
    var stepWords: String = ""        // "walks"
    var weekStart: String = ""        // yyyy-MM-dd, as DateUtils writes days
    var timeZoneIdentifier: String = TimeZone.current.identifier
    var acceptedAt: Date = Date()
    var reachedAt: Date? = nil
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}
```

Declines and expiries for rule 10 are two integers in `UserDefaults`
(`challengeDeclinesInARow`, `challengeOffersPausedUntil`), not records: they are a
preference about offers, not history, and they should not sync or accumulate.

### 7.3 Linking wins to intentions

- Add to `Habit`: `var intentionID: UUID? = nil`. A UUID, not a SwiftData
  relationship, following `planItemID`: no inverse to maintain, nothing to cascade
  when an intention is deleted, CloudKit-safe, and it survives a future move of
  intentions to another store.
- **A win counts toward an intention when** it is a tower block by the replay rule
  (`Replay.isBlock`) **and** either:
  1. `intentionID` equals the intention's id (set by a small-step chip, or chosen on
     the block card later), or
  2. its **chosen** `category` equals the intention's area.
- **`spontaneousCategoryRaw` never counts.** A one-tap win wearing green because the
  slot leaned green (M1) was not chosen as a health win, and counting it would claim
  something untrue. This keeps "two facts" intact, at the cost that unnamed one-tap
  wins do not count. That cost is honest and is the incentive M2 relies on: naming a
  win in one tap from a chip.
- With two active intentions in the same area, rule 2 credits both; lines at the close
  use the area name to avoid double claims.
- One pure function, `IntentionCredit.counts(_ record: WinRecord, toward: Intention) -> Bool`,
  with tests, used by the replay line, Profile and challenges, so they cannot disagree
  (the lesson of the pill's `hasWins` and the replay disagreeing, `CLAUDE.md`).

### 7.4 CloudKit and social readiness

- Every attribute optional or defaulted; no `@Attribute(.unique)`; no required
  relationships. Passes the checks in `research-icloud-backup.md`.
- `updatedAt` and `id` defaults from day one, matching change #1 in
  `research-concept-and-social.md`, so this lands in the same migration rather than a
  second one if the timing allows.
- `isPrivate = true`, and `WinRecord` snapshots for any future share must **never
  include** `intentionID` or intention words. A test should assert it, alongside the
  existing "place is never on a shareable payload" rule.
- Toggles (suggestions, week line, challenge offers) live in `UserDefaults` beside
  `replayRemindersOn`, and belong in the backup export's preferences list.

---

## 8. Recommendation

### The smallest version that proves invisible guidance (v1)

1. **Intentions:** the onboarding page and the Profile section; up to three areas,
   optional words, "Let it rest"; the weight-word reframe line. (No challenges.)
2. **Small steps (M2) with curated lists, plus the slot lean (M1):** past-tense chips
   in the win sheet that name a win and link it in one tap; the slot's colour leans
   toward an intention area not yet touched today.
3. **One line at Your Week's close (M3):** only when the week moved toward an
   intention.

Everything in v1 is invisible to someone who skips onboarding, and silent on a week
with nothing.

### Defer

- **v1.1:** M4 (Profile clause), M5 (week's question, once the reflective line exists),
  M9 (block card line).
- **v2:** challenges (M8) and the quiet-intention check-in (M10), after v1 passes the
  guilt test below.
- **v3:** Foundation Models steps, after the curated lists have taught what good
  chips look like, and M7 (reminder time).
- **With "On this day":** M6.

### How to judge whether it helps

Strata sends no analytics and must not start for this. Judge it the way the app is
built: on-device counts, a DEBUG export, and the owner plus a small TestFlight group
over four weeks against their own previous four.

What the person should do differently, if it works:

| Signal | Why it matters | Healthy direction |
|---|---|---|
| Share of wins **named** (not untitled) | M2 makes naming one tap | Up |
| Share of wins in intention areas with a **chosen** category | Guidance actually pointed attention | Up, modestly |
| Chip taps per week | Suggestions are useful, not noise | Steady, and increasingly the person's own past titles |
| Total wins per week | Must not inflate artificially (Ordonez) or fall (guilt) | **Flat or gently up.** A sharp rise is a warning, not a win |
| Intentions still active after four weeks, and edits to the words | Ownership | Most kept; edits are good, deletions after a week are a warning |
| Your Week opens | The line gives the close meaning | Up |
| **Logging in the week after a week with no linked wins** | The guilt test | **Must not drop** below that person's baseline |

And one question, asked directly of every TestFlight tester at week four:
**"Did Strata ever make you feel behind?"** Any "yes" that traces to an intention
feature is a reason to remove that feature, not tune it.

For v2, the extra guilt test: logging in the week after an **expired** challenge must
not fall below baseline, and acceptance of the next offer should not collapse. If
either happens, challenges come out.

### What not to build

- Weight, calorie, food, step or body tracking of any kind.
- Progress bars, rings, fractions ("2 of 3") or percentages toward an intention.
- Streaks per intention or per challenge; a challenges history.
- Notifications that name an intention, or any notification on a day with nothing
  beyond the existing reminder.
- Badges, unlocks or rewards for reaching anything.
- AI that writes, rewrites or recommends the intention.
- A goals tab, a goals dashboard, or intentions on the tower header.
- A long onboarding questionnaire, or asking for anything Strata will not use.
- Turning intentions into `PlanItem`s or repeating anything.

---

## 9. Build plan

Sizes: S (a day or two), M (up to a week), L (more). Each step ships on its own.

| # | Step | Size | Notes |
|---|---|---|---|
| 1 | `Intention` model, `Habit.intentionID`, defaults, migration (fold into the iCloud defaults migration if it has not shipped) | S | Tests: CloudKit rules (all defaulted), a deleted intention leaves wins intact |
| 2 | `IntentionCredit` pure function + tests (chosen category counts, spontaneous never does, `Replay.isBlock` rule, two intentions in one area) | S | The one source every surface reads |
| 3 | `IntentionWords` checks: weight/body list, harm list, flags on the model + tests | S | Lists reviewed once by a clinician before v2 |
| 4 | Profile section "What you're building", the intention sheet, Let it rest / Wake it up, three toggles | M | Section footer copy; accessibility labels; Dynamic Type at xxLarge |
| 5 | Onboarding page (new step 2): block picker with the real fall, words state, reframe line, Skip; shift `headStep`/`lastStep`; `-strataOnboardingStep` still works | M | Verify on device and simulator; check the Skip path creates nothing |
| 6 | Curated step lists + `SmallStepFilter` (also used on curated lists, so they cannot drift) + tests | S | Grep for long dashes |
| 7 | Win sheet chip row (M2): empty-field only, create-only, presses the swatch, sets `intentionID`, own past titles first | S | Measure: sheet open time unchanged |
| 8 | Slot lean (M1) in `rerollNextWinCategory` + tests on the probability rule | S | Colour stays spontaneous |
| 9 | Your Week close line (M3) in `ReplayScript`, excluded from export by default | S | VoiceOver: appended to the close announcement |
| 10 | Privacy policy sentence; backup export includes intentions and toggles | S | Manifest unchanged; confirm in both built configurations |
| 11 | DEBUG counters and export for the signals in section 8; `-strataSeedIntentions` flag | S | No network, ever |
| | **v1 total** | **about 2 to 3 weeks** | |
| 12 | v1.1: M4 Profile clause, M9 block card line, M5 (after the reflective line exists) | S each | |
| 13 | v2: `Challenge` model, offer at Your Week close, stepper, rules 1 to 12, dance on reach, decline/expiry pause, self-set in Profile | M | Guilt test first; every rule gets a test, especially "missed shows nothing" |
| 14 | v2: M10 quiet-intention check-in at Your Month close and in Profile | S | |
| 15 | v3: Foundation Models `SmallSteps` generation, availability gating, weekly cache, filter, adversarial tests | M | Real device with Apple Intelligence required; simulator cannot prove it |
| 16 | v3: M7 reminder time suggestion | S | |
| 17 | With "On this day": M6 selection preference | S | |

---

## Sources

Research (a):
- Locke and Latham 2002: https://pubmed.ncbi.nlm.nih.gov/12237980/
- Harkin et al. 2016: https://pubmed.ncbi.nlm.nih.gov/26479070/
- Amabile and Kramer 2011: https://hbr.org/2011/05/the-power-of-small-wins
- Sheldon and Elliot 1999: https://pubmed.ncbi.nlm.nih.gov/10101878/
- Wang et al. 2021, MCII meta-analysis: https://pmc.ncbi.nlm.nih.gov/articles/PMC8149892/
- Milne, Orbell and Sheeran 2002: https://pubmed.ncbi.nlm.nih.gov/14596707/
- Dai, Milkman and Riis 2014: https://pubsonline.informs.org/doi/10.1287/mnsc.2014.1901
- Bryan et al. 2011: https://www.pnas.org/doi/10.1073/pnas.1103343108
- Gerber et al. 2016 (replication): https://www.pnas.org/doi/10.1073/pnas.1513727113
- Ordonez et al. 2009: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=1332071
- Fishbach and Dhar 2005: https://academic.oup.com/jcr/article-abstract/32/3/370/1867208
- Chi et al. 2026 (preprint): https://arxiv.org/abs/2605.12344
- Simpson and Mazzeo 2017: https://pubmed.ncbi.nlm.nih.gov/28214452/
- Tylka et al. 2014, weight-inclusive approach: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4132299/
- Weight-neutral interventions review 2025: https://pmc.ncbi.nlm.nih.gov/articles/PMC12053462/
- Deci, Koestner and Ryan 1999; Silverman and Barasch 2023: as cited in `research-game.md`

Products (b):
- Apple Watch ring goals: https://support.apple.com/guide/watch/adjust-your-activity-ring-goals-apd29b30023c/watchos
- Pausing rings: https://tomsguide.com/wellness/smartwatches/how-to-pause-activity-rings-on-your-apple-watch
- Strava goals: https://support.strava.com/en-us/articles/15401694-goals-on-the-strava-app
- Finch: https://slate.com/technology/2026/09/finch-app-self-care-wellness-review.html
- Streaks: https://apps.apple.com/us/app/streaks/id963034692
- Structured: https://structured.app/
- Fabulous onboarding critique: https://www.thebehavioralscientist.com/articles/fabulous-app-product-critique-onboarding
- Noom: https://en.wikipedia.org/wiki/Noom ; https://wittelslaw.com/cases/noom-weight-loss-program-auto-enrollment-class-action
- Duolingo tests: https://econsultancy.com/six-a-b-tests-used-by-duolingo-to-tap-into-habit-forming-behaviour/
- Rise: https://www.risescience.com/
- Oura readiness: https://ouraring.com/blog/readiness-score/ ; orthosomnia: https://en.wikipedia.org/wiki/Orthosomnia
- Foundation Models: https://developer.apple.com/documentation/FoundationModels/generating-content-and-performing-tasks-with-foundation-models
- Acceptable use requirements: https://developer.apple.com/apple-intelligence/acceptable-use-requirements-for-the-foundation-models-framework/
- Framework overview: https://www.createwithswift.com/exploring-the-foundation-models-framework/

Code read (owner-head): `CLAUDE.md`; `docs/product-direction.md` (partly stale: its Today checklist and four tabs predate the 2026-09-10 removals); `docs/profile-and-head-plan.md`;
`Strata/Views/OnboardingView.swift`, `PlanSheet.swift`, `AddWinSheet.swift`, `ProfileView.swift`,
`SettingsView.swift`, `NextSlotButton.swift`, `MainAppView.swift` (header, `rerollNextWinCategory`);
`Strata/Models/PlanItem.swift`, `Habit.swift`, `CategoryColors.swift`, `ProfileStore.swift`;
`Strata/Services/QuickWinService.swift`, `DailyReminder.swift`, `ReplayReminder.swift`,
`CategorySuggestionEngine.swift`. Also `research-game.md`, `research-concept-and-social.md`,
`research-icloud-backup.md`, and `Strata-audit/docs/monetization.md`.
