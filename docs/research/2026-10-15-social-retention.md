# Social retention: how small-circle apps keep people and spread (research, 2026-10-15)

The brief: a casual person picks up Some Wins, understands why it exists,
wants to share it with a friend, and wins every day, sending wins to the
people they love and getting cheered on. And: "help those that are scared to
invite people feel like they aren't alone on the app."

Read-only. No Swift was changed to write this. Tags as the other research
docs use them: **(a)** a study, paper or primary rule, **(b)** a shipping
product, its own blog or its press, **(c)** inference.

## What this does not repeat

These are already written up, and this doc only adds to them:

- Locket's TikTok growth, Gas's lockouts, Lapse's forced invites, Path's
  address book, Partiful's link-first loop, K-factor maths, the Facebook "7
  friends in 10 days" line (`invites-research-2026-10-13`, `launch-plan`).
- Strava kudos (Lambert et al.), BeReal's late label and decline, Retro's
  share-to-see, Day One shared journals, Beli, Letterboxd, Poparazzi, Dispo,
  Deci on contingent rewards, Silverman and Barasch on broken streaks
  (`research/concept-and-social`).
- Partiful's boop, Finch's waves, Widgetable's Miss You, phatic pings, STEP
  UP, the Köhler effect, Habitica party damage, Duolingo Friends Quests and
  nudges, Apple Fitness competitions, Snap streak survey, Instagram Notes,
  and the five corner candidates Wave, Drop, Note, Roll and Week
  (`crew-corner-new-feature-2026-10-14`).
- Read receipts, typing indicators and the chat's MUST list (`qol-research`).
- Snapcodes, usernames, contact matching, Your People, Your Code
  (`friends-research-2026-10-14`).
- Gollwitzer and Lally on plans and habits (`planning.md`).

Checked against `docs/screens.md` (build 142) and the code at `92f64ba`
(build 144, which adds the crew widget and the crew's week). Already built,
so not proposed: the crew widget, the crew's week replay, the synchronized
crew evening (`CrewEvening.swift`), the first-win and first-reaction invite
card (`FirstWinInvite.swift`), the crew streak, crew plans, Do It Too, the
strip booth. **Not built**: any action on a crew notification (only the
daily reminder has actions, `DailyReminder.swift:57`), any reaction on a
widget, and any onboarding that knows the person arrived from an invite
(`OnboardingView.swift` has no crew or join path).

---

## The answer in seven lines

1. **The research supports the owner's sentence almost word for word.**
   Telling someone about a good thing raises your own day, and more so when
   they answer actively (Gable et al. 2004) (a). Composed messages from close
   friends move well-being; one-tap reactions from them barely do (Burke and
   Kraut 2016) (a). So a reaction should be the door to a reply, not the end.
2. **Invite fear is a measured illusion.** People underestimate how much a
   reach-out is appreciated (13 experiments, ~6,000 people) (a), how good a
   thank-you makes someone feel (a), and how much a new dorm mate likes them
   (a). The app can say this once, plainly, at the invite.
3. **The single highest-leverage gap is the invitee's first run.** Today a
   friend who installs from an invite goes through the full onboarding and
   meets a solo tower. Their first win should land next to the inviter's.
4. **Never fake company.** NGL paid about $5M and was banned from under-18
   anonymous messaging after the FTC found it sent fake messages that looked
   like friends (a, regulator). Any "you're not alone" content must be real
   and labelled.
5. **Daily return without guilt comes from good news arriving where you
   already look** (the widget, the lock screen) and from fresh starts, not
   from counts of missed days (a, b).
6. **Social features alone do not raise activity on average.** A systematic
   review of 19 mHealth studies found no significant effect on physical
   activity in its meta-analysis, and mixed preferences (a). Social must be
   warm, optional and close-tie, or it is noise.
7. **Ranked list of ten at the end.** Top three, all small to medium: the
   invited first run, reply starters on a friend's win, and react or reply
   from the notification.

---

## 1. Mechanics, what makes them work, and the risk

Only products and mechanics not already covered above.

| Product | Mechanic | Why it works | Evidence | Dark-pattern risk | Tag |
|---|---|---|---|---|---|
| **Duolingo** | Friend Streak, up to 5 pairs | Designed so it "doesn't require any real interaction"; the post compares it to studying next to a friend at the library. Presence, not conversation | Learners with one or more are **22% more likely to finish the daily lesson**, rising with more (company figure, relative, no baseline). Learners who add friends are **5.6x** more likely to finish a course (correlational) | High: losing it is loss aversion with a friend attached; the nudge screen says if they don't, you lose shared progress | (b) [D1][D2] |
| Duolingo | Friend Streak product lessons | The team found **the first invite was the biggest funnel bottleneck**, and a mass-invite "super friend" was not worth chasing; 5 slots was enough | 57% of users have at least one friend (company) | None in itself | (b) [D1] |
| Duolingo | Reminder bandit (KDD 2020) | Picks one of many hand-written reminders per learner per day; models **novelty decay** and lets a worn-out message "recover" before reuse | **+0.5% DAU, +2% new-user retention** over a strong baseline, on hundreds of millions of reminders | Medium: optimizing reminders for opens tends to drift to guilt (the meme owl) | (a) [D3] |
| **Hinge** | Comment on a specific photo or prompt; Convo Starters (Dec 2025) | The message is anchored to an object, so the opener writes itself | Likes with a comment are **2x as likely to lead to a date**; 72% more inclined to consider a like with a message (company) | Low; AI-written openers can feel fake | (b) [H1] |
| **Instagram** | DMs and story replies | Sharing moved from feed to Stories to DMs; a story reply is a DM anchored to a picture | Mosseri: more photos and videos are shared in DMs than in Stories, and far more in Stories than feed | Low | (b) [I1] |
| **Locket** | Celebrity Lockets (Aug 2025) | A real, named person on your home screen; scarcity ("one of just a few thousand") | 17% of one artist's 5,000 fans were new to Locket; company claims 80M downloads, 9M DAU, profitable in 2024 | Medium: parasocial, and it uses the friends' widget for broadcast | (b) [L1] |
| **BeReal** | WidgetMojis (2022) | Friends' reaction selfies appear on your home screen when they react to you | Shipped during BeReal's 2022 climb; no isolated effect published | Low | (b) [L2] |
| BeReal | RealPeople, RealBrands (2024) | Real public figures posting under the same rules as friends | None published | Low; ads arrived in 2025 | (b) [B1] |
| **Airbuds** | Home-screen widget of friends' listening; Tune Twins alerts when you and a friend played the same song; Sunday recap | Ambient presence plus a coincidence that prompts a reaction | 15M downloads, 5M MAU, 1.5M daily launches (company, 2025); core audience high school and college | **High**: the weekly recap shows only the top three until you invite friends, an invite gate | (b) [A1][A2] |
| **Life360** | Bubbles (2020) | Teens share a 1 to 25 mile circle for 1 to 6 hours instead of a pin; built after teens mocked the app on TikTok | Shipped; no outcome data | Shows that presence is accepted when the person controls its precision and its end | (b) [F1] |
| **Finch** | A pet you care for; friends send hugs and good vibes; missing days does not punish | Self-care as a side effect of caring for something | 10M+ downloads (Google); 4.9 stars on 550K reviews (third party) | Low; a pet can still guilt by looking sad | (b) [FN1][FN2] |
| **Strava** | Clubs, group activities (2024 report) | Accountability and company | Running clubs **+59%**, group activities ~40% longer and up to 55% more kudos; 34% cite group accountability; 40% of Gen Z want to exercise with friends more (company survey, via press) | Medium: leaderboards | (b) [S1] |
| **Beli** | Invite-only, 6 invites each | Scarcity makes an invite a gift | Most join by referral (already cited) | Medium: waitlists manufacture status | (b) [BL1] |
| **Saturn** | Paid campus leads, 5 to 10 ambassadors a campus, budget for clubs and free food | The atomic network is a campus, built by hand | 1M+ high schoolers (company) | Low | (b) [SA1] |
| **Snapchat** | Streak Restore: one free, then paid; more with Snapchat+ | Monetizes the anxiety the streak creates | Pricing varies by source | **High**, and the cautionary tale for any crew streak | (b) [SN1] |
| **NGL** | Fake "friend" messages to drive sign-ups | Manufactured social proof | FTC and LA DA settlement, about $4.5M plus $0.5M, ban on marketing anonymous messaging to under-18s (July 2024) | The line Some Wins must never cross | (a) [N1] |
| **Yope** (2025) | Private group photo walls | Small groups | 2M MAU, but only **40% active a week after sign-up** | Novelty without a daily reason | (b) [Y1] |
| **2026 newcomers** | Vlogit (one friend picked each day to film, May 2026), Flare (voice-first, an AI companion that keeps "friendship context", May 2026), Nospace (MySpace-style top friends, 500K waitlist) | Each is a small-circle app with no follower counts | Self-reported waitlists only | Vlogit's "you were picked" is a clock on a person | (b) [V1][V2][V3] |
| Streaks, Fabulous, Cosmos | Streaks is a single-player habit app; Fabulous is coach-led; Cosmos is a curation board | None of the three has a friend loop worth copying | Not researched further | n/a | (c) |

### What the studies add

- **Capitalization.** Telling others about a positive event is linked to
  higher daily positive affect beyond the event itself, and the benefit is
  larger when the listener responds *actively and constructively*
  (asking, elaborating) rather than passively ("nice") (a) [R1]. This is the
  scientific name for "sending wins to the ones you love and getting cheered
  on."
- **Composed beats one-click, from close friends.** In 1,910 Facebook users
  with server logs, composed, targeted messages from strong ties were
  associated with gains in well-being; one-click actions and weak ties were
  not (a) [R2]. Reactions still carry relationship meaning, more than their
  content (a) [R3], so they are worth keeping as the low-effort floor.
- **Small moments, close ties.** College students' Snapchat exchanges were
  rated more enjoyable and better for mood than calls, texts, email or
  Facebook, but less supportive; the interviews credited sharing mundane
  moments with trusted ties and lower self-presentation worry (a,
  experience sampling, N = 154) [R4]. A small win is a small moment.
- **Reaching out is appreciated more than we think.** Thirteen
  preregistered experiments, ~6,000 people: initiators underestimate how
  much a check-in is appreciated, more so when it is a surprise (a) [R5].
  Gratitude letter writers underestimate how good recipients feel and
  overestimate how awkward (a) [R6]. First-year students underestimated how
  much their dorm mates liked them for most of the year (the liking gap) (a)
  [R7].
- **Fresh starts.** Goal-directed behaviour rises after temporal landmarks:
  a new week, month, semester, a birthday. University gym visits jumped at
  the start of a week and a semester (a) [R8].
- **Social features are not magic.** A systematic review of 19 studies on
  social features in mHealth found no significant effect on physical
  activity in its meta-analysis; some users liked support and competition,
  others feared comparison (a) [R9].
- **Body doubling for ADHD is popular and thinly evidenced.** Recent
  papers note no conclusive evidence yet, and that some neurodivergent
  people find social presence uncomfortable (a, preprints) [R10]. Treat it
  as a promising option, not a proven one.

---

## 2. The four questions

### Q1. The lonely user and invite fear, options ranked

Some Wins already gives a solo person a companion (their own head on the
tower) and asks them to invite once after the first win and once after the
first reaction. Ranked, for what to add:

1. **Make the invitee's first run land in the crew** (feature 1). The
   person most likely to feel alone is the one who arrived because a friend
   asked. If their first screen after their head is the friend's tower,
   with the friend's win on it and their slot beside it, there is someone
   there, truly. Chen's "atomic network" for small-group tools is two to
   three people (b, secondhand) [C1]. (c)
2. **Say the research once, at the invite** (feature 5). The fear is
   measured and wrong in a known direction [R5][R6][R7]. One line in the
   voice beats any number of features. (a, c)
3. **Ask for one person, not a group.** Duolingo found the first invite is
   the bottleneck and mass invites are not worth chasing [D1]. The existing
   card asks "Who else should see it?", which invites a list; "one person"
   is easier to answer. (b, c)
4. **Invite from a moment.** Built (`FirstWinInvite`). Keep it.
5. **An honest, labelled companion from outside**: the maker's own tower
   (feature 8). Real person, real wins, clearly not a friend. Locket's
   Celebrity Lockets and BeReal's RealPeople are the shipping precedent
   [L1][B1]. (b)
6. **"Someone is waiting" signals, only when true.** The inviter's head
   and today's tower in the invitation (the crew-corner doc's optional
   card). Never "3 friends are here", never a fake. (c)
7. **Sample or ghost content.** Only as an obvious illustration in his
   drawings. Fake people or fake activity are what the FTC fined NGL for
   [N1]. **Do not build** anything that could be mistaken for a friend. (a)

### Q2. Why people message inside a niche app instead of iMessage

- **The thing is the opener.** Hinge's comments on a specific photo double
  dates [H1]; a story reply is the most natural DM [I1]; Airbuds' Tune Twins
  hands you a coincidence to react to [A2]. iMessage has no object; a crew
  win is one. The reply on a win already exists. What is missing is making
  the *first words* easy (feature 2). (b)
- **Low stakes.** College students enjoy small-moment channels because
  self-presentation worry is lower [R4]. The midnight-clearing chat already
  does this. (a)
- **Reactions are the floor, replies are the value.** One-tap from close
  friends maintains the tie, composed replies move well-being [R2][R3]. So
  each reaction surface should have a one-step path into words (features 2
  and 3). (a)
- **Prompts help only when they are about the object.** Hinge's starters
  are generated from the photo in front of you, and 35% of testers said
  they felt more confident reaching out (company, reported elsewhere) [H1].
  A generic "question of the day" competes with the group chat and loses.
  (b, c)
- **Where iMessage wins anyway**: logistics, long threads, anything not
  about today. That is fine. The crew chat should own "about this win", not
  everything. (c)

### Q3. Daily return loops with no guilt and no absence notifications

- **Good news where you already look.** Locket, BeReal's WidgetMojis and
  Airbuds all put friends on the home screen [L2][A1]. The crew widget is
  built; reactions to *your* wins are not on it (feature 4). Opening the
  app to see who cheered is a pull, not a push. (b)
- **Answer from the lock screen.** A friend's win arrives as a
  notification already; letting someone react or reply from it turns a
  read into a cheer in two seconds (feature 3). It adds no notification.
  (c)
- **Fresh starts, not debts.** Return after a gap is framed by the
  landmark (a new week, a new month, the first day of the quarter), with a
  short catch-up of the crew's days, never a count of missed days (feature
  6) [R8]. (a)
- **Rotate the words.** If the one daily cue stays, give it many
  hand-written lines and do not repeat a recent one; Duolingo measured the
  novelty decay [D3]. In the voice, specific over generic. (a)
- **Already doing it right**: one cue a day, the synchronized crew
  evening, the crew's week on Sunday. Do not add a second cue. (b)
- **Avoid**: paid or free streak repair (Snapchat [SN1]), nudging a friend
  who has not logged (Duolingo's nudge), anything that says a friend
  "hasn't". (b)

### Q4. A college student's first win sent to friends within ten minutes

Two different people. Times are estimates from the screens, not measured (c).

**The invited student** (a friend sent the link). Today: tap link, App
Store, install (1 to 2 min), reopen link (the invites doc's fix), full
onboarding (film, name, head, first win, quick win lesson, reminder, three
permissions, lock journal, about 4 to 6 min), then the join, then find the
crew and log again. Ten minutes is possible but the first win goes to the
solo tower. **With feature 1** it is: name, head, the friend's tower, your
first win into the crew, in about 4 minutes, and the friend gets "Ana
joined" and her first win together. This is the path to optimize.

**The organic student** (found it on TikTok). They can log a first win in
about 3 minutes, and the invite card appears. But a crew needs the friend to
install, be on iOS 26 and signed into iCloud. Within ten minutes that only
happens when the friend is **in the room**. So:

- Lean on in-person moments: the dorm floor, the study group, the gym
  partner. The crew QR already exists; the launch plan's seeded crews and
  Saturn-style campus leads [SA1] are the marketing half. (b, c)
- The first win should be a college win. A first-win row of starters
  written for week one of a semester ("Went to class", "Ate a real meal",
  "Did laundry") makes the first block one tap. Small; could fold into the
  onboarding rebuild, which is planned for last. (c)
- Semester start is a fresh-start landmark [R8]: launch and campus pushes
  belong in the first two weeks of a term. (a)

---

## 3. Ten features for Some Wins, ranked

None of these is built (checked against `screens.md` and the code). Wave
(the crew-corner doc's rank 1) is already proposed and not repeated; it
would sit around rank 3 here.

**1. Invited first run.** *What*: when the app's first launch opens from a
crew link, onboarding becomes name, head, then the crew's tower with the
inviter's wins and your slot; your first win goes to that crew by default;
the rest (quick-win hold, reminder, lock) is taught later by the existing
tips. Age gate, iCloud and iOS 26 checks stay. *Why*: activation for this
app is "in a crew with one other person" (invites doc); Duolingo's biggest
loss was the first social step [D1]; the person who most needs company is
the newcomer [R7]. (b, c) *Effort*: M. *Risk*: two onboarding paths to
maintain; a broken link at first launch must fall back to the normal path;
interacts with the planned onboarding rebuild.

**2. Reply starters on a friend's win.** *What*: Reply on a win offers two
or three editable starters built from that win's own name and size, as
questions: "How did Gym go?", "What made today the day?". Tap one, edit,
send. No AI, no canned praise. *Why*: active-constructive responding is
what makes sharing good news pay off [R1]; composed replies from close
friends are what move well-being [R2]; Hinge's object-anchored openers
double outcomes [H1]. (a, b) *Effort*: S. *Risk*: starters can read as
templates if they repeat; must pass `voice.md`; under 16 without writing
gets none.

**3. React or reply from the notification.** *What*: a friend's win
notification gets actions: the three reactions and Reply (a text input
action). Answered in the background, no app open. *Why*: the cheapest
possible cheer at the moment of attention; responders are glad to hear
from you [R5]; reactions keep ties [R3]. Only the daily reminder has
actions today. (a, c) *Effort*: S to M (categories in the notification
extension, a background CloudKit write through the outbox). *Risk*: the
background write can fail silently, so the outbox must retry; text from
the lock screen must still pass `CrewWords`.

**4. Cheers on the widget.** *What*: when someone reacts to your win, the
crew widget (or the Today widget) shows their head with the emoji beside
your block until the crew's midnight. Good news only. *Why*: BeReal's
WidgetMojis put friends' reactions on the home screen [L2]; capitalization
says the response is the reward [R1]; it brings people back with no push.
(a, b) *Effort*: S to M (the publisher exists). *Risk*: a home screen is
semi-public, so first names and emoji only, nothing when Lock Journal is
on; under 16 heads stay placeholders.

**5. The invite says the true thing once.** *What*: the invite card asks
for one person and carries one research-true line, in the voice, for
example "People are gladder to be asked than we guess." Same two moments,
no new prompt. *Why*: invite fear is a measured underestimate [R5][R6][R7];
asking for one person matches Duolingo's finding [D1]. (a, b) *Effort*: S.
*Risk*: it can read as a fortune cookie, which `voice.md` forbids; he should
choose the words.

**6. Fresh start and catch-up.** *What*: on the first open of a new week,
month or term, or after a few days away, the Wins header names the
landmark ("New week."), and a crew you have not opened in days offers
**Catch Up**: a short replay of the days you missed (the crew's week
replay already maps the data), ending on the slot. No count of days away,
no push. *Why*: fresh-start effect [R8]; broken streaks demotivate
(already cited). (a) *Effort*: S to M. *Risk*: drifting into "you've been
away" copy; must stay in the app, per `voice.md`.

**7. Rooting for you, on a crew plan.** *What*: on a friend's crew plan, a
one-tap **Rooting for You** (their head shows a small flag beside the
plan). When they log it, the win carries "Sam was rooting for this." If
they do not, nothing is ever said, and it clears at midnight. *Why*:
cheering before the act gives the planner a reason to follow through,
without a penalty; Strava members cite group accountability [S1]; it is
the positive half of Duolingo's nudge [D2] with the threat removed. (b, c)
*Effort*: M (a marked line, as plans and strips are). *Risk*: an
unfinished plan with a cheer on it can feel like a debt; the planner
should be able to clear it.

**8. The maker's tower.** *What*: for someone with no crew, the Crews
list shows one read-only card, **Jayden's Day**: the maker's real tower,
updated from a static file on the app's site, labelled as the person who
built the app. No reactions, no chat, a link to start your own crew. Off
once you are in a crew, and switchable off. *Why*: a real person winning
small every day is honest company; Locket and BeReal ship real public
figures [L1][B1]; NGL is the version not to build [N1]. (a, b) *Effort*:
M. *Risk*: daily upkeep for him; a network request to his site needs a
line in the privacy label; it may read as marketing; it must never look
like a friend.

**9. Together for a while (body doubling).** *What*: from a plan line,
**Start**: your head sits at a little desk on the crew tower for up to 50
minutes; a crewmate can tap **Join** and their head sits beside yours; it
ends on its own or when you log the win. A local Live Activity shows your
own timer. *Why*: presence without conversation is what Duolingo designed
for ("studying next to a friend at the library") [D1]; body doubling is
widely used by people with ADHD, with thin evidence so far [R10]; Life360
Bubbles shows presence is accepted when the person sets its scope and end
[F1]. (a, b) *Effort*: L. *Risk*: it is a presence signal, which `ten.md`
rule 4 treats with suspicion; only ever started by the person, never shown
as "online"; needs his call.

**10. Some Wins in iMessage.** *What*: a Messages app extension that drops
today's tower, a win or a strip into any thread as a card with "Join my
crew". *Why*: 86% of young people are in a private group chat that shares
content (Ypulse) [V3]; the group chat is where invitations happen anyway.
(b, c) *Effort*: M. *Risk*: it can pull conversation out of the crew chat,
the opposite of the owner's goal; another target and review surface. Last
for that reason.

---

## Sources

Products
- [D1] Duolingo, Product lessons from building Friend Streak: https://blog.duolingo.com/product-lessons-friend-streak/
- [D2] Duolingo, friends and social features (5.6x, 22%, nudge, high fives): https://blog.duolingo.com/friends-social-features/
- [D3] Yancey and Settles, "A Sleeping, Recovering Bandit Algorithm for Optimizing Recurring Notifications", KDD 2020: https://research.duolingo.com/papers/yancey.kdd20.pdf
- [H1] TechCrunch, Hinge Convo Starters, 8 Dec 2025: https://techcrunch.com/2025/12/08/hinges-new-ai-feature-helps-daters-start-better-convos-moving-beyond-boring-small-talk ; 35% figure via Vice: https://www.vice.com/en/article/hinge-convo-starters-feature
- [I1] Mosseri on private sharing (DMs over Stories over feed): https://www.businessinsider.nl/instagram-head-adam-mosseri-on-the-paradigm-shift-from-posting-in-public-to-sharing-in-private
- [L1] TechCrunch, Locket Celebrity Lockets, 6 Aug 2025: https://techcrunch.com/2025/08/06/photo-sharing-app-locket-is-banking-on-a-new-celebrity-focused-feature-to-fuel-its-growth
- [L2] TechCrunch, the home screen as a social platform (Locket, BeReal WidgetMojis), 16 Jun 2022: https://techcrunch.com/2022/06/16/the-next-big-social-platform-isthe-smartphones-homescreen
- [B1] TechCrunch, BeReal RealBrands and RealPeople, 24 Jan 2024: https://techcrunch.com/2024/01/24/bereal-which-now-has-23m-daus-is-onboarding-brands-and-celebs
- [A1] Airbuds funding and usage: https://www.digitalmusicnews.com/?p=329385 and https://www.techbuzz.ai/articles/airbuds-scores-5m-as-gen-z-music-app-hits-5m-users
- [A2] Deconstructor of Fun, Golden Mechanics: Airbuds: https://www.deconstructoroffun.com/blog/golden-mechanics-airbuds
- [F1] TechCrunch, Life360 Bubbles, 12 Oct 2020: https://techcrunch.com/2020/10/12/family-tracking-app-life360-launches-bubbles-a-location-sharing-feature-inspired-by-teens-on-tiktok
- [FN1] Android Developers Blog, #WeArePlay (Finch): https://android-developers.googleblog.com/2025/07/weareplay-app-game-founders-across-the-us.html
- [FN2] Paste, Finch founders: https://www.pastemagazine.com/article/finch-app-mental-health-virtual-pet-self-care
- [S1] Strava Year in Sport 2024, via press: https://gearjunkie.com/endurance/strava-year-in-sport-trend-report-2024 and https://athletechnews.com/strava-2024-fitness-report-highlights-trends
- [BL1] Beli invites, student review: https://spoonuniversity.com/school/brown/beli-the-new-app-personalizing-restaurant-reviews-and-recommendations/
- [SA1] Saturn Campus Lead postings: https://edtechjobs.io/jobs/116180426-campus-lead
- [SN1] TechCrunch, Snapchat streak restore and pause, 1 Mar 2023: https://techcrunch.com/2023/03/01/snapchat-will-now-let-you-pause-your-snap-streaks/
- [N1] FTC, NGL Labs: https://www.ftc.gov/ngl ; coverage: https://www.socialmediatoday.com/news/ftc-fines-ngl-over-deceptive-practices/720931/
- [Y1] YPulse on Yope, 27 Feb 2025: https://www.ypulse.com/newsfeed/2025/02/27/a-new-instagram-like-app-yope-is-catching-gen-zs-attention-but-maybe-not-their-time/
- [V1] Vlogit launch release: https://www.newsfilecorp.com/release/292621
- [V2] Flare on Product Hunt: https://www.producthunt.com/products/flare-9/launches/flare-10
- [V3] Nospace, Business Insider: https://businessinsider.nl/nospace-is-a-new-nostalgia-filled-social-media-app-for-gen-z-thats-already-got-a-500000-person-waiting-list/ ; YPulse private groups figure: https://www.ypulse.com/?p=44322
- [C1] Andrew Chen, The Cold Start Problem, atomic network (talk summary): https://notes.laratranslate.com/andrew-chen-the-cold-start-problem-how-to-start-and-scale-network-effects-talks-at-google-ef7d2bfd/summary

Research
- [R1] Gable, Reis, Impett and Asher (2004), "What do you do when things go right?", JPSP 87(2): https://pubmed.ncbi.nlm.nih.gov/15301629/
- [R2] Burke and Kraut (2016), Facebook use and well-being by communication type and tie strength, JCMC 21: https://worlddatabaseofhappiness.eur.nl/publications/the-relationship-between-facebook-use-and-well-being-depends-on-communication-type-and-tie-strength-15305
- [R3] Hayes, Carr and Wohn (2016), "One Click, Many Meanings", J. Broadcasting & Electronic Media 60(1): https://digitalcommons.njit.edu/fac_pubs/10732
- [R4] Bayer, Ellison, Schoenebeck and Falk (2016), "Sharing the small moments", Information, Communication & Society 19(7): https://yardi.people.si.umich.edu/pubs/Schoenebeck_Snapchat16.pdf
- [R5] Liu, Rim, Min and Min (2023), "The surprise of reaching out", JPSP 124(4): https://pubmed.ncbi.nlm.nih.gov/35816566/
- [R6] Kumar and Epley (2018), "Undervaluing Gratitude", Psychological Science: https://news.uchicago.edu/story/people-underestimate-value-sending-letters-appreciation
- [R7] Boothby, Cooney, Sandstrom and Clark (2018), "The Liking Gap in Conversations", Psychological Science: https://journals.sagepub.com/doi/abs/10.1177/0956797618783714
- [R8] Dai, Milkman and Riis (2014), "The Fresh Start Effect", Management Science: https://faculty.wharton.upenn.edu/wp-content/uploads/2014/06/Dai_Fresh_Start_2014_Mgmt_Sci.pdf
- [R9] Tong and Laranjo (2018), social features in mHealth for physical activity, npj Digital Medicine: https://pmc.ncbi.nlm.nih.gov/articles/PMC6550193
- [R10] Body doubling evidence, preprints: https://arxiv.org/pdf/2509.12153v1 and https://arxiv.org/pdf/2609.21254
