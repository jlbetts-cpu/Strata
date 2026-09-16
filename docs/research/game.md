# A game inside Strata: research, concepts, recommendation

Written 2026-09-16. Read-only research: no code was changed, nothing was built or run.
Owner's brief: "I want to add a game of some sort to the app, could you research more into it."

## The answer in five lines

- **Yes, but a toy, not a game system.** The job is delight and reflection at a moment that already exists. Retention and social are the jobs that would hurt a win tracker.
- **Build first: Topple.** When a replay's tower stands finished, it goes loose: flick it, throw your head at it, watch your week come down with real physics, and it rebuilds itself with the app's own drop. No score, no unlock, no notification.
- **Second: Stack Your Week.** Last week's actual blocks swing in one at a time and you balance them into a freestanding tower. A real game, but its pieces are capped by a closed record, so it cannot be grinded.
- **Avoid: a daily puzzle** (pack today's blocks, one a day). It is the most "retention" shaped idea and the worst fit: an appointment, a streak, a nag, and tidiness, which the owner has rejected in his own games.
- **Where it lives:** inside the replay close (and the month tower's day view later), found by touching the tower. No tab, no badge, no row that says "Game". It is free.

---

## 1. Should Strata have a game, and what job would it do?

### What the code says Strata already is

Everything below is anchored in what ships in `owner-head`:

- A win is logged in one tap and becomes a block (`BlockSize` 1x1, 2x1, 2x2) that falls with real gravity: `GridConstants.dropGravity` 4200 pt/s², `t = sqrt(2d/g)`, no ease-out, squash and stretch linear in mass (`squashScaleY(mass:)` etc.), placed by `GridPacker.firstFit` on a 4-column grid.
- The tower dances every tenth win (`danceEvery = 10`).
- Replays (`ReplayScript`, a pure function of time) rebuild a week or month, pull out, dance, and close on the whole tower standing still on the screen (`Phase.closed`). They export to video.
- The head (`HeadRig`, `LivingHeadView`, twelve `HeadTake`s) is optional, off by default, and paid as part of "Strata Everything".
- The rule that settles every argument (`docs/product-direction.md`): **recording a win must be the fastest thing in the app.** And from the replay spec: "A replay that grades you is one people stop opening."
- There is no SpriteKit, SceneKit or physics engine in the app today. All motion is SwiftUI with `GridConstants` tokens. The app no longer touches CoreMotion.
- `tasks/personality.md` notes the app is built with people with ADHD in mind, which raises the cost of any mechanic that produces guilt or compulsion.

### The five jobs, judged for a win tracker

| Job | Helps or hurts | Why |
|---|---|---|
| **Delight** (a reward moment) | Helps, if unexpected and unconditional | Unexpected, non-contingent pleasure does not undermine motivation; expected, contingent rewards do (Deci et al. 1999, below). The drop and the dance already are delight; a toy extends them. |
| **Reflection** (revisit the record playfully) | Helps most | Positive reminiscence and "three good things" have RCT support for wellbeing (Seligman et al. 2005; Bryant et al. 2005). The replay spec already rests on exactly this. A game that makes you touch and re-read your own wins is reminiscence with hands. |
| **Rest** (a break) | Neutral to helpful | Fine as long as it is short and ends on its own. A win tracker is not the place for an endless game; it would pull time away from the life being recorded. |
| **Retention** (a reason to open the app) | Hurts | Retention mechanics (daily puzzles, streaks, timers, appointment rewards) are what turn a record into an obligation. The only honest reason to open Strata is that you did something. A game that gives you another reason creates pressure to log so you can play, which is fake wins, which destroys the record. |
| **Social** (share or play with friends) | Hurts as competition; fine as sharing | Strata transmits nothing (`NSPrivacyCollectedDataTypes` is empty). Multiplayer needs a server or Game Center, and head-to-head on wins is comparison, which is grading. Sharing an artefact (the replay video already does this) is fine. |

### What the research says

**Rewards undermine intrinsic motivation when they are expected and contingent.** Deci, Koestner and Ryan's meta-analysis of 128 experiments found engagement-, completion- and performance-contingent rewards all reduced free-choice intrinsic motivation (d = -0.40, -0.36, -0.28); unexpected rewards and verbal, informational feedback did not.
Source: Deci, Koestner, Ryan, *Psychological Bulletin* 125(6), 1999. https://depts.washington.edu/techdocs/papers/deciExtrinsicRewardsAndIntrinsicMotivation99.pdf ; follow-up in *Review of Educational Research*, 2001: https://journals.sagepub.com/doi/10.3102/00346543071001001

Implication for Strata: **the game must never be earned by logging.** No "log 5 wins to unlock a round", no coins per block. If the toy is there whatever you logged, it is informational ("look at what you built"), not a payment.

**Points, levels and leaderboards raise output, not motivation.** Mekler et al. found these elements increased quantity of work but did not change intrinsic motivation, autonomy or competence; they worked as progress indicators.
Source: Mekler, Brühlmann, Tuch, Opwis, *Computers in Human Behavior* 71, 2017. https://bruehlmann.io/publication/mekler-towards-2017/

Implication: a score in a win tracker would raise the NUMBER of logged wins, which is the one number Strata must not inflate artificially. The tower count is already the "points"; adding a second currency invites gaming it.

**Punishment and counterproductive effects: Habitica.** In a two-week field study of 45 Habitica users, all participants experienced counterproductive effects to some degree (for example being punished in productive periods because tasks were not ticked in time), and only 49% rated the rewards as appropriate.
Source: Diefenbach and Müssig, *International Journal of Human-Computer Studies* 127, 2019. https://www.sciencedirect.com/science/article/abs/pii/S1071581918305135

Implication: never a failure state that costs the record. A tower that falls in a game must not be the tower.

**Broken streaks demotivate.** Across seven studies, highlighting an intact logged streak increased later engagement compared with a broken one, independent of actual behaviour; the effect was stronger when people blamed themselves and weaker when a streak could be repaired. One reported example: 58% continued strength training after a broken streak against 66% with it intact.
Source: Silverman and Barasch, "On or Off Track: How (Broken) Streaks Affect Consumer Decisions", *Journal of Consumer Research* 49(6), 2023. https://academic.oup.com/jcr/article-abstract/49/6/1095/6623414 ; summary, Psychology Today, June 2023: https://www.psychologytoday.com/gb/blog/ulterior-motives/202306/how-broken-streaks-sap-motivation

Implication: a daily game adds a second streak on top of the one Profile already shows gently ("no red, no streak lost", `docs/profile-and-head-plan.md` 4.2). Two streaks is two ways to feel you failed.

**Duolingo's lesson: leniency retains better than pressure.** Duolingo's own growth team reported that a Weekend Amulet (skip weekends without losing the streak) made learners 4% more likely to return a week later and cut streak loss 5%, and that learners who binged were much more likely to abandon.
Source: Duolingo blog, Kai Herng Loh, 10 May 2017. https://blog.duolingo.com/how-streaks-keep-duolingo-learners-committed-to-their-language-goals/
Duolingo won the 2023 Apple Design Award for Delight and Fun, and its later games (Chess, June 2025, then PvP) are separate courses, not rewards for lessons.
Sources: Apple Newsroom, June 2023, https://www.apple.com/newsroom/2023/06/apple-announces-winners-of-the-2023-apple-design-awards/ ; Duocon 2025, https://investors.duolingo.com/news-releases/news-release-details/duolingo-unveils-major-product-updates-turn-learning-real-world

Implication: Duolingo's delight comes from characters and motion, which Strata already has (blocks, the head). Its streak machinery is a growth engine for a subscription business, which Strata explicitly is not (`docs/monetization.md`: no subscription).

**Apple Fitness rings: Apple itself backed off.** watchOS 11 (announced June 2024) added Pause Rings for a day, week or month without losing award streaks, after years of "close your rings" becoming a compulsion for many users.
Source: 9to5Mac, 16 July 2024. https://9to5mac.com/2024/07/16/close-your-ringsbut-in-watchos-11-its-okay-if-you-dont/

**Finch: the pet never dies.** Finch ties self-care to a pet that goes on adventures; it avoids punishment and nagging and uses widgets and gentle rhythm instead. Deconstructor of Fun reports about 10M MAU and D1/D7 retention of 54%/37%.
Source: Deconstructor of Fun, 31 March 2026. https://www.deconstructoroffun.com/blog/x0hd2ssr80y5n7gv0w967pg7hwd7tl
Implication: Finch's success comes with a full economy (energy, outfits, decor, timer-gated adventures). That is a different product. The part worth borrowing is the absence of punishment, not the economy.

**Gentler Streak: rest counts.** 2024 Apple Design Award for Social Impact. Its makers reject "push all the time" and celebrate a 15-minute walk the same as a hard workout.
Sources: Apple Newsroom, June 2024, https://www.apple.com/newsroom/2024/06/apple-announces-winners-of-the-2024-apple-design-awards/ ; Behind the Design, 11 July 2024, https://developer.apple.com/news/?id=3m0ht22s

**Headspace and Calm.** Headspace won the 2023 ADA for Social Impact for a minimalist interface, not for gamification. Where these apps are playful it is in short, self-ending interactive exercises (Calm's 60-second Breathe Bubble, Headspace's "Breathe with the Balloon"), not games with scores.
Sources: https://www.apple.com/newsroom/2023/06/apple-announces-winners-of-the-2023-apple-design-awards/ ; https://www.headspace.com/content/mindful-activity/breathe-with-the-balloon/4512 ; https://www.calm.com/
Implication: a toy that ends by itself in under a minute is the proven shape in wellbeing apps.

**Gamification in wellbeing apps, the evidence base.** Systematic reviews find gamification is mostly justified as "engagement" and rarely tested element by element (Cheng et al., *JMIR Mental Health* 6(6), 2019, https://mental.jmir.org/2019/6/e13717/). Some RCTs do show reduced attrition with gamified apps (Litvin et al., *PLoS ONE*, 2020, https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7467300/), but those are whole gamified interventions, not a game bolted onto a tracker.

**Reminiscence and good things.** Three Good Things (one week of evening writing) raised happiness and lowered depressive symptoms for six months against placebo (Seligman, Steen, Park, Peterson, *American Psychologist* 60(5), 2005, summary at https://ggia.berkeley.edu/practice/three-good-things). Positive reminiscence twice daily for a week increased time spent feeling happy against a control (Bryant, Smart, King, *Journal of Happiness Studies*, 2005, https://link.springer.com/article/10.1007/s10902-005-3889-4).

### What this means for Strata specifically

1. **The game plays with the record; it never feeds the record.** Nothing in it can create, delete, reorder or move a win, or be unlocked by logging one. The toy tower is a copy.
2. **No score that persists, no streak, no timer, no notification, no daily reset.** A score shown for the length of one throw is fine; a "best" that you have to beat tomorrow is not.
3. **It must end by itself**, in about a minute, and hand you back to the app.
4. **It should happen where reflection already happens** (the replay, a past day), so the game's hidden job is getting you to look at your wins again.
5. **The failure state is funny, never costly.** A tower collapsing should be the best moment, not a loss. This is also the owner's own taste (section 2).

---

## 2. The owner's taste, from his own games

From `/Users/jaydenbetts/Downloads/portfolioo_v392/CLAUDE.md` section 5:

- Soccer: **"Never make the match calmer, tidier or better-spaced."** He rejected separation steering, roles and zones three times. What he wants is **verticality**: airborne ball, flips, unpredictable bounces. The only chaos worth removing is chaos that STOPS play (a wedge, a deadlock, jitter that reads as a bug).
- Marble race: fairness is measured, stuck states are hunted down with seeded sweeps, and "parking" of heads on geometry is a defect.
- The heads cast contact shadows because they stand on something; a head in free fall gets none.
- Tournament: "Simulate runs the real match", never a dice roll, because the result matters to him.

Read across to Strata: **physics chaos with personality, real simulation not fakery, nothing that jams, and the head as a character.** Things he would likely reject: tidy puzzles, tile matching, grids to optimise, anything that asks the player to be neat.

There is a tension to name honestly: Strata's own design law is "premium is subtraction" and calm, while his games are loud. The resolution is containment. The chaos lives in one place, for under a minute, entered by a gesture, and then the calm app comes back. That is how Chrome's dino and Android's version Easter eggs coexist with sober products.

---

## 3. Concepts

Seven concepts. Build size: S is under a week, M one to three weeks, L more. Every one obeys the rule: **it must never create, remove, move or fake a win.**

### Concept A: Topple (recommended first)

**Core loop.** When a replay finishes and the whole tower stands on screen, the tower becomes a real physics object. Flick a block, or throw your head, and the week comes down block by block with rigid-body physics. Let go and after a beat every block lifts off and falls back into its exact `GridPacker` slot with the app's real drop, so the toy always ends as the true record.

- **What you touch:** the standing tower at the replay close. Drag a block to pull it out (a Jenga pull), flick to throw, or, with a head, pull the head back like a slingshot and release.
- **Session:** 10 to 45 seconds. Ends by itself: once every body is asleep for ~1.5s the rebuild starts. A second flick during the rebuild knocks it down again, which is the "one more go" without a counter.
- **Connection to real wins:** the pieces are exactly that period's blocks, with their colours, sizes, titles and photographs. Knocking one loose and watching it tumble past you is re-reading it. The record is untouched: the physics world is a disposable copy built from `ReplayFrame` data; the rebuild proves it by putting every block back where it was.
- **Visual language:** the real block faces (rim lit from above, blurred bottom band) baked to textures once. No new chrome at all: no button, no score, no title. Landings use the existing `SoundEngine.impact` and `HapticsEngine.squish(mass:)`, scaled by impact speed. The head, if thrown, plays `HeadTake` surprised on launch and grin or doubleTake on its first hit, and gets its contact shadow only when it comes to rest standing on a block, which is the portfolio rule exactly.
- **Owner-taste fit:** very high. Vertical, chaotic, physical, a head as a projectile, and the chaos cannot wedge because it always resolves into the rebuild.
- **Risks:**
  - *Cheapening the record:* a wrecked tower could feel like destroying your week. Mitigated by the rebuild, which should be the emotional peak (your week reassembling itself), and by never letting the wreckage persist or be saved.
  - *Gesture conflict:* the replay uses tap to pause/skip (`ReplayView.onTapGesture`). Topple only arms in `Phase.closed`, and needs a drag or flick threshold, so a tap still means what it means now. On the live Wins tab a gesture on a block starves the ScrollView (CLAUDE.md measured 0.0pt), which is a reason NOT to put it there first.
  - *Rasterising the block:* `BlockSurface` must not get `.drawingGroup()` because rasterising re-clips the soft bottom edge. Baking a texture is the same operation, so render with padding round the block so the blur is inside the bitmap. Verify against a live block by pixel sampling.
  - *Reduce Motion:* skip the physics; a flick gives a small spring nudge on the touched block only.
  - *Exported video:* the toy is live only, not part of `ReplayScript` or the exporter.
  - *Scope:* one new framework (SpriteKit) in a contained view.
- **Build size: M.** SpriteKit `SKScene` inside SwiftUI `SpriteView` (iOS 14+, target is 18.0), one `SKPhysicsBody(rectangleOf:cornerRadius:)` per block with mass from `BlockSize` (1, 2, 4 cells), gravity scaled from `dropGravity`. Textures via `ImageRenderer` over `BlockFace`, the same decoded images `ReplayImages` already holds. Head as a circular body textured from the current `HeadRig` face, with `LivingHeadView` overlaid on the node's position if expressions must animate. Rebuild reuses the drop maths (`t = sqrt(2d/g)`, `dropFallCurve`, squash tokens) from the physics pose back to each block's `ReplayScript` final pose.

### Concept B: Stack Your Week (second choice)

**Core loop.** Last week's blocks arrive one at a time, in the order you logged them, swinging on a slow pendulum above a narrow plinth. Tap to let go; the block falls with real gravity and lands on the pile, which is free physics, not the grid, so it leans and sways. The game ends when your week runs out or the pile falls, and it shows how tall your week stood.

- **What you touch:** a single tap per block. That is the whole control, like Stack or Tower Bloxx.
- **Session:** as many drops as wins in that week, capped (for example 30). 20 to 90 seconds.
- **Connection to real wins:** each block shows its title and photo as it swings, so you read your week in order. **Only closed periods** (last week and older), so logging today does nothing for your next game, which removes the incentive to log fake wins. Your record is not changed.
- **Visual language:** the real blocks on the plain page, the header numeral counting height in `StrataNumerals`, nothing else.
- **Owner-taste fit:** good. Verticality and wobble, and a collapse is a spectacle. Less chaotic than Topple; it asks for skill and neatness, which is a risk with him.
- **Risks:** a height number invites a "best", and a best invites a streak; keep it for the session only. A heavy week is a longer game, which quietly rewards more logging; the cap and the closed-period rule contain that. It needs an entry point people find, and is more "game" than Strata's quiet chrome.
- **Build size: M to L.** Same SpriteKit foundation as Topple (build Topple first and this is mostly a new scene), plus a swing mechanic, joints or kinematic carriers, and tuning. A later add-on, not a separate engine.

### Concept C: Head on the tower (a toy, not a game)

**Core loop.** Your head stands on the top block of today's tower (already planned in `docs/profile-and-head-plan.md` 5.6: "stands on the topmost block, with a contact shadow, and smiles when a win drops"). Fling it: it arcs off, bounces down the side of the tower block by block, plays a `HeadTake` on each hit, and climbs back up to its perch. Every tenth win's dance throws it in the air.

- **Touch:** drag and release the head. **Session:** 3 to 10 seconds. **Wins:** none directly; it is personality on the record. **Visuals:** the existing `LivingHeadView` and contact shadow.
- **Taste fit:** very high (it is his portfolio companion heads, in the app).
- **Risks:** it lives on the Wins tab, above a scroll view, next to the empty slot, the most sensitive surface in the app ("never cover the empty slot or its drag"). The head is a paid feature, so this is only for unlocked users. Collisions with a scrolled, culled tower are fiddly.
- **Build size: S to M.** No engine needed: a hand-rolled 2D point-mass with bounce against the column tops, driven by `TimelineView`, since it is one body.

### Concept D: Where was this? (map memory)

**Core loop.** A photograph from one of your wins appears. You drop a pin on your own map where you think it was. The real block lands at the true place and the distance is shown; five photographs a round.

- **Touch:** pan and tap the map. **Session:** 1 to 2 minutes. **Wins:** strong reflection; every round is five memories.
- **Visuals:** the Memories map and its blocks; the answer block drops on its cell centre (`PlaceMap.Cluster.anchor`).
- **Taste fit:** low. Calm and quiz-like.
- **Risks:** photographs taken before location shipped have no place and never will (CLAUDE.md), so for most early users there is nothing to play. Location language must never read as surveillance ("where I am" is banned). MapKit inside new layouts has cost a lot already.
- **Build size: M.**

### Concept E: Pairs (photo memory match)

**Core loop.** Twelve of your photograph blocks lie face down; tap two to flip them (the tower already flips blocks, `FlippableBlockView`); a match stays up and shows the win's title.

- **Touch:** taps. **Session:** 1 to 2 minutes. **Wins:** reflection. **Visuals:** block backs in their colours.
- **Taste fit:** poor (tidy, a grid, no physics). **Risks:** needs 6+ photographed wins; feels like a generic mini game; a timer or move count creeps in.
- **Build size: S.**

### Concept F: Pack the Day (daily puzzle) (avoid)

**Core loop.** Today's blocks are shuffled beside an empty footprint; drag them in to fill the smallest tower. One puzzle a day, a share grid like Wordle.

- **Why it tempts:** Wordle proved one-a-day scarcity (Josh Wardle: it asks for about three minutes a day; TechCrunch, 12 January 2022, https://techcrunch.com/2022/01/12/josh-wardle-interview-wordle/).
- **Why to avoid:** Wordle's scarcity works because everyone solves the SAME puzzle; here everyone's is different, so it keeps the obligation and loses the community. It is an appointment mechanic and a streak, which the research above says costs a tracker. It rewards logging more blocks to get a puzzle. It is the tidiest idea on the list, the opposite of the owner's taste. And `GridPacker.firstFit` already packs; a puzzle that asks you to redo the app's own job is thin. Dragging blocks also collides with the existing rearrange (`.draggable`) semantics.
- **Build size: M.**

### Concept G: Replay race (friend challenge) (also out)

**Core loop.** Two people's weeks fall side by side; the taller tower wins.

- **Why out:** it grades you against someone else, which the replay spec rules out; it needs a server, Game Center, or file exchange, and Strata transmits nothing; a quiet week becomes a lost match. Sharing the replay video already covers the social job without comparison.
- **Build size: L.**

### Summary table

| Concept | Job | Session | Taste fit | Record risk | Size | Verdict |
|---|---|---|---|---|---|---|
| A Topple | delight, reflection | 10 to 45s | very high | low (rebuilds) | M | **Build first** |
| B Stack Your Week | reflection, rest | 20 to 90s | good | low to medium | M to L | **Second** |
| C Head on the tower | delight | 3 to 10s | very high | low | S to M | Later, paid users only |
| D Where was this? | reflection | 1 to 2 min | low | low | M | Not yet (no place data) |
| E Pairs | reflection | 1 to 2 min | poor | low | S | No |
| F Pack the Day | retention | 1 to 3 min | poor | high | M | **Avoid** |
| G Replay race | social | 20s | medium | high | L | No |

---

## 4. Precedents: hidden toys that felt premium

| Precedent | What it is | What made it premium rather than bolted on |
|---|---|---|
| **Chrome Dinosaur Game** (Sept 2014) | A runner on the "no internet" page, by Sebastien Gabriel, Alan Bettes, Edward Jung. About 270M plays a month by 2018. | It appears exactly when you cannot do the real task, uses the page's own grey pixel art, needs no instructions (space to jump), and never asks for your time otherwise. https://en.wikipedia.org/wiki/Dinosaur_Game ; https://mcvuk.com/development-news/what-game-is-four-years-old-has-270m-monthly-players-and-yet-makes-no-money-whatsoever/ |
| **Android version Easter eggs** (Lollipop, Oct 2014 onward) | Tap the version number in Settings repeatedly to get a Flappy Bird-style game. | Deliberately hard to find, drawn in that release's own visual language, costs nothing to ignore. https://techcrunch.com/2014/10/20/android-lollipop-easter-egg-casts-andy-the-android-as-flappy-bird |
| **Apollo Pixel Pals** (16 Sept 2022) | An opt-in pet walking on the Dynamic Island inside a Reddit client. Spun out into its own app: 3.33M installs, about 50K subscribers by Oct 2023. | Used a new piece of hardware playfully, opt-in, no mechanics, pure personality. Proof that a toy inside a utility can become the thing people talk about. https://www.macrumors.com/2022/09/16/apollo-pixel-pal-dynamic-island/ ; https://techcrunch.com/2023/10/18/reddit-may-have-killed-apollo-but-the-developers-new-pixel-pals-app-has-hit-50k-subscribers/ |
| **(Not Boring) Habits** (ADA Delight and Fun, 2022) | A habit tracker as a 66-level journey; the checkbox is a hold with SceneKit 3D, haptics, particles and sound. | The game lives in the core interaction itself, not beside it. Andy Allen: game designers turn "a one-button press" into something much bigger. Strata's drop already does this, which is why a separate game must justify itself. https://developer.apple.com/news/?id=9ab1g4r3 (29 Aug 2022) ; https://www.apple.com/newsroom/2022/06/apple-announces-winners-of-the-2022-apple-design-awards/ |
| **CARROT Weather** | 150+ secret locations, 80+ achievements, missions (no more than two a day), a snarky robot. | Personality with a consistent voice, and the secrets are in the weather itself (search for a place, weather events). Note the cost: it is maximalist, the opposite of Strata. https://9to5mac.com/2021/01/28/carrot-weather-receives-major-overhaul-now-free/ ; https://forums.macrumors.com/threads/carrot-weather-secret-locations.1862623/ |
| **Flighty Passport** (12 Dec 2023) | Lifetime and year stats in a passport design, built to share. Flighty won the 2023 ADA for Interaction. | Reflection on your own record made into an object worth showing, with no score against others. The closest analogue to Strata's replays. https://9to5mac.com/2023/12/12/flighty-year-in-review-features/ |
| **Duolingo** (ADA Delight and Fun, 2023) | Characters, animation, and later separate games (Chess, 2025). | Character and motion carry the delight; the separate games are courses in their own right, not prizes. Its streak machinery is the part NOT to copy (section 1). |
| **Metaballs** (ADA 2026 finalist, Delight and Fun) | A toy of spatial blobs you push and poke, with physics and lighting. | A physics toy with no goal was judged award-level delight. Direct support for Topple's "no score" stance. https://developer.apple.com/design/awards/ |
| **grug** (ADA 2026 winner, Delight and Fun) | Daily wisdom in Neolithic grunts, hand drawn, no login or cloud. | A tiny, committed personality with no account and no sync, which is Strata's own privacy posture. https://developer.apple.com/design/awards/ |
| **Calm Breathe Bubble / Headspace balloon** | Short interactive breathing toys. | Self-ending, one interaction, same visual language as the app. https://www.headspace.com/content/mindful-activity/breathe-with-the-balloon/4512 |
| **Railbound** (ADA Interaction, 2023) | Puzzle game praised for wordless onboarding. | The bar for "understood without instructions". https://www.apple.com/newsroom/2023/06/apple-announces-winners-of-the-2023-apple-design-awards/ |

Not verified, so not relied on: Halide and Tweetbot are often cited for hidden touches, but I could not find a primary source for a specific Easter egg in either; leave them out of any write-up.

**The pattern across all of them:** the toy is made of the product's own material (dino pixels, the Dynamic Island, the checkbox, your flights); it asks nothing (no account, no score to defend, no reminder); and it is found, not advertised. Strata's material is falling blocks and your head, and Topple is made of nothing else.

---

## 5. Where it lives and how you reach it

**Recommended entry points, in order:**

1. **The replay close (first).** When `ReplayScript` reaches `Phase.closed`, the tower is standing still, fitted to the screen, not inside a scroll view, and you have just watched it built. Touching a block and pulling arms the physics. There is no hint on the first replay; from the second, the top block gives one small idle wobble (a `danceRise`-sized nudge) once, a few seconds after the close, and never again after the first topple. That is discoverability without a label.
2. **A past day or month tower** (`StaticTowerView`, month tower day view) later, with the same gesture, once the replay version has proved itself. These are also not the live scroll view.
3. **The Wins tab head** (Concept C) only for people who have made a head and turned on the tower placement, and only after gesture conflicts are measured with `TowerGestureTests`.
4. **A dance bonus:** the tenth-win dance could, very occasionally and unpredictably, loosen the top block for a second. Unexpected, not contingent, so it stays on the right side of Deci et al.

**Never:**

- a Game or Play tab (the app is three tabs by decision)
- a badge, a red dot, "New!", or a Profile row saying "Play"
- a notification ("Your tower misses you", "Play today's puzzle")
- a daily reset, a streak, a best score, a leaderboard, coins
- gating it behind logging ("log 3 more wins to play")
- a widget that invites play (a widget is for the record)
- anything that writes to SwiftData
- putting the gesture on blocks in the live Wins tab tower (it starves the ScrollView; measured in CLAUDE.md)

The only words the feature might ever need, for VoiceOver: an accessibility action on the closed replay, "Knock the tower down", and when it rebuilds, nothing. No long dashes in any string.

---

## 6. Recommendation

**Build first: Topple.** It does the two jobs that help (delight, reflection), none of the jobs that hurt, it is made entirely of what Strata owns, it matches the owner's physics-chaos taste and his head-as-character instinct, and it cannot wedge because every session resolves into the rebuild. It lives in the replay, the app's existing reflection moment, where there is no scroll view to fight.

**Second: Stack Your Week.** The same engine with a real skill loop, gated by closed periods so it cannot become a reason to log.

**Avoid: Pack the Day.** Daily obligation, second streak, rewards logging, tidy, and a worse Wordle.

### How it is judged (measurable)

| Measure | Good | How to measure |
|---|---|---|
| Understood without instructions | 4 of 5 first-time testers knock a block loose within 10s of the close, told nothing | Hallway test on device; the Railbound bar |
| Frame rate | 120fps on ProMotion devices, no frame over 16.7ms during a full topple of a 60-block month; 60fps floor on non-ProMotion | `PerfProbe` display-link gaps, Instruments; note Strata does not set `CADisableMinimumFrameDurationOnPhone`, so SpriteKit is capped at 60 on iPhone until that key is added |
| Start latency | Physics armed within 1 frame of the touch-down that pulls (textures pre-baked during the replay) | Signpost from touch to first physics step |
| Session length | Median 15 to 40s; fewer than 10% of sessions over 2 minutes | DEBUG-only local log (Strata collects no analytics, so this is testing, not telemetry) |
| Never jams | 0 bodies still moving 6s after the last touch in 200 seeded random flicks; rebuild always completes | Seeded sweep, in the style of the portfolio's marble race sweeps |
| Record integrity | 0 SwiftData writes during a session; block positions after rebuild identical to the close, to the point | Unit test over the rebuild poses; `StoreSignature` unchanged |
| Fidelity | Baked block texture differs from a live `BlockSurface` by under 1% of pixels, soft bottom edge included | Pixel diff, as `tools/flatten_svg.py` verification does |
| Delight | Unprompted "again" or a second topple in over half of test sessions | Observation |
| Reduce Motion | No physics; one spring nudge; nothing else moves | Simulator with Reduce Motion on |

---

## 7. Monetization fit

`docs/monetization.md`: **the record is free, the keepsakes are paid.** A toy is neither record nor keepsake; it is part of the character of the app.

- **Topple is free**, on every replay a person can open. Your Week plays free, so everyone gets it; Your Month is paid, so buyers get a bigger tower to knock down, which is a natural, non-gated bonus.
- **Throwing your head is part of the unlock** automatically, because the head is already paid. No new gate is needed: without a head you flick blocks; with one you can throw yourself at your week.
- **Not a milestone gift.** A gift for "100 wins" is a completion-contingent reward, exactly the kind Deci et al. found undermines motivation, and it would make the toy something you log to earn.
- **Never the paywall trigger.** The unlock sheet stays where the doc puts it (Save video, Your Month, Make Your Head, the film looks). Stopping someone mid-topple to sell something would be a dark pattern.
- Stack Your Week, if built: free as well, for the same reasons. The keepsake hook, if wanted, is exporting a clip of the collapse, which would sit under "Saving a replay as a video" (paid) with no new product.

---

## 8. Build plan for Topple

### Prototype in one day (test the feel before committing)

A throwaway SwiftUI + SpriteKit scene in a scratch project or a DEBUG-only flag (for example `-strataTopple sampleWeek`), not wired into the replay:

1. `SpriteView` with an `SKScene`, a ground edge, 31 rectangles in the sample week's colours placed by `GridPacker.firstFit` at the replay close's cell size. Flat colours with rounded corners, no textures. (2 hours)
2. Drag to pull a block (an `SKPhysicsJointSpring` or a mouse-joint style node), flick velocity on release. (2 hours)
3. Gravity from `dropGravity`, densities by `BlockSize`, restitution about 0.1, friction about 0.6; try three settings side by side. (1 hour)
4. Rebuild: after bodies sleep, each block tweens up off screen and drops back to its slot on `t = sqrt(2d/g)` with the squash tokens. (2 hours)
5. Put it on a phone. The questions for the owner: does it feel like Strata's blocks (heavy, lit plane) or like a generic physics demo? Is the rebuild the payoff? Does a tap still clearly mean skip? (1 hour)

If the answer is "generic demo", stop there; the cost was a day.

### Full build, ordered

| # | Task | Size |
|---|---|---|
| 1 | `ToppleWorld`: pure value model of the bodies built from `ReplayScript` final poses (id, size, mass, pose). Unit tests that its rebuild targets equal the close's poses. | S |
| 2 | Texture baking: render each `BlockFace` once via `ImageRenderer` with padding for the blurred band, reusing `ReplayImages` decodes; pixel-diff test against the live block. | S to M |
| 3 | `ToppleScene` (SpriteKit): bodies, ground, walls off screen, sleep detection, impact callbacks to `SoundEngine` and `HapticsEngine` scaled by impulse and throttled (the replay's landing limit logic already exists). | M |
| 4 | Gesture: arm only in `Phase.closed`, pull threshold so tap keeps pause/skip; test in `ReplayGestureTests` (UI target, `-testPlan StrataFull`). | S to M |
| 5 | Rebuild choreography using the drop tokens; interruptible (a new flick during rebuild re-releases bodies from their presentation poses, per `docs/apple-design.md`). | M |
| 6 | Head as projectile: circular body, face texture, `HeadTake` on launch and first hit, contact shadow only when resting on a block. Only when `HeadStore` has a head. | S to M |
| 7 | Reduce Motion path, VoiceOver action, Dynamic Type unaffected (no text added). | S |
| 8 | Performance: 60-block month on the oldest supported device; decide on `CADisableMinimumFrameDurationOnPhone`; `PerfProbe` window around a topple. | S |
| 9 | Seeded sweep for jams (200 random flicks, 0 bodies moving after 6s, rebuild always completes). | S |
| 10 | Discoverability nudge (one-time idle wobble from the second replay) and a stored "has toppled" flag in `UserDefaults`. | S |

Roughly two to three weeks including tuning. Traps to carry in from CLAUDE.md: do not read animation state inside the `Equatable` block views; keep the scene out of `MainAppView.body` (type-checker ceiling); nothing in the toy touches SwiftData; claim only what was verified on the simulator, and say haptics and sound feel are unverified until a device run.

---

## Sources (all accessed 2026-09-16)

- Deci, Koestner, Ryan 1999: https://depts.washington.edu/techdocs/papers/deciExtrinsicRewardsAndIntrinsicMotivation99.pdf
- Deci, Koestner, Ryan 2001: https://journals.sagepub.com/doi/10.3102/00346543071001001
- Mekler et al. 2017: https://bruehlmann.io/publication/mekler-towards-2017/
- Diefenbach and Müssig 2019 (Habitica): https://www.sciencedirect.com/science/article/abs/pii/S1071581918305135
- Silverman and Barasch 2023: https://academic.oup.com/jcr/article-abstract/49/6/1095/6623414
- Psychology Today on broken streaks, June 2023: https://www.psychologytoday.com/gb/blog/ulterior-motives/202306/how-broken-streaks-sap-motivation
- Duolingo streaks blog, 10 May 2017: https://blog.duolingo.com/how-streaks-keep-duolingo-learners-committed-to-their-language-goals/
- Duocon 2025: https://investors.duolingo.com/news-releases/news-release-details/duolingo-unveils-major-product-updates-turn-learning-real-world
- watchOS 11 Pause Rings, 9to5Mac 16 July 2024: https://9to5mac.com/2024/07/16/close-your-ringsbut-in-watchos-11-its-okay-if-you-dont/
- Finch, Deconstructor of Fun, 31 March 2026: https://www.deconstructoroffun.com/blog/x0hd2ssr80y5n7gv0w967pg7hwd7tl
- Gentler Streak, Behind the Design, 11 July 2024: https://developer.apple.com/news/?id=3m0ht22s
- Cheng et al. 2019, JMIR Mental Health: https://mental.jmir.org/2019/6/e13717/
- Litvin et al. 2020, PLoS ONE: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7467300/
- Three Good Things (Seligman et al. 2005): https://ggia.berkeley.edu/practice/three-good-things
- Bryant, Smart, King 2005: https://link.springer.com/article/10.1007/s10902-005-3889-4
- Apple Design Awards 2022: https://www.apple.com/newsroom/2022/06/apple-announces-winners-of-the-2022-apple-design-awards/
- Apple Design Awards 2023: https://www.apple.com/newsroom/2023/06/apple-announces-winners-of-the-2023-apple-design-awards/
- Apple Design Awards 2024: https://www.apple.com/newsroom/2024/06/apple-announces-winners-of-the-2024-apple-design-awards/
- Apple Design Awards 2025: https://www.apple.com/newsroom/2025/06/apple-unveils-winners-and-finalists-of-the-2025-apple-design-awards/
- Apple Design Awards 2026: https://developer.apple.com/design/awards/
- (Not Boring) Habits, Behind the Design, 29 Aug 2022: https://developer.apple.com/news/?id=9ab1g4r3
- Chrome Dinosaur Game: https://en.wikipedia.org/wiki/Dinosaur_Game ; https://mcvuk.com/development-news/what-game-is-four-years-old-has-270m-monthly-players-and-yet-makes-no-money-whatsoever/
- Android Lollipop Easter egg, TechCrunch 20 Oct 2014: https://techcrunch.com/2014/10/20/android-lollipop-easter-egg-casts-andy-the-android-as-flappy-bird
- Apollo Pixel Pals, MacRumors 16 Sept 2022: https://www.macrumors.com/2022/09/16/apollo-pixel-pal-dynamic-island/
- Pixel Pals numbers, TechCrunch 18 Oct 2023: https://techcrunch.com/2023/10/18/reddit-may-have-killed-apollo-but-the-developers-new-pixel-pals-app-has-hit-50k-subscribers/
- CARROT Weather overhaul, 9to5Mac 28 Jan 2021: https://9to5mac.com/2021/01/28/carrot-weather-receives-major-overhaul-now-free/
- Flighty Passport, 9to5Mac 12 Dec 2023: https://9to5mac.com/2023/12/12/flighty-year-in-review-features/
- Wordle, TechCrunch 12 Jan 2022: https://techcrunch.com/2022/01/12/josh-wardle-interview-wordle/
- Headspace breathing balloon: https://www.headspace.com/content/mindful-activity/breathe-with-the-balloon/4512
- SceneKit soft deprecation (why SpriteKit, not SceneKit), WWDC25: https://developer.apple.com/videos/play/wwdc2025/288/

Project files read: `/Users/jaydenbetts/StrataWork/owner-head/CLAUDE.md`, `docs/product-direction.md`, `docs/profile-and-head-plan.md`, `docs/superpowers/specs/2026-09-13-your-week-design.md`, `Shared/GridPacker.swift`, `Strata/Models/GridConstants.swift`, `Strata/ViewModels/TowerAnimationCoordinator.swift`, `Strata/Models/HeadRig.swift`, `Strata/Models/HeadTake.swift`, `Strata/Models/ReplayScript.swift`, `Strata/Models/BlockSizeDraw.swift`; `/Users/jaydenbetts/Desktop/Strata-audit/docs/monetization.md`; `/Users/jaydenbetts/Downloads/portfolioo_v392/CLAUDE.md` section 5.
