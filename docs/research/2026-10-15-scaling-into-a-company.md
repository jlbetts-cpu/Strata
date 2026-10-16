# Some Wins: how this becomes a big company

Researched 2026-10-15. Sources are linked inline. Anything marked **(inference)** is reasoning, not data.

**Summary of the recommendation**
1. The venture-scale version is "the private social layer for getting things done", not "a better ADHD journal". The journal alone tops out as a strong indie business (inference).
2. The crew is the product's atomic network. Everything for 6 months should serve one number: the share of new users who are in an active crew by day 7.
3. Launch campus by campus, starting with one dense school, the way BeReal and Gas did, using the strip and the crew invite as the two loops.
4. Keep the no-server, sealed-records architecture through launch; plan a minimal relay server for Android and push at roughly 50k MAU, and make "we cannot read your wins" a permanent promise.
5. Raise only after proving D30 retention of 25% or more and organic month-on-month growth of 20% or more; a first round of $250k to $1M on a SAFE capped near $10M is the realistic shape (inference from Carta 2025 data, section 7).
6. Revenue: Strata Plus as planned, then schools and ADHD clinicians as distribution partners rather than buyers of user data.

---

## 1. The market

### Sizes (treat all market-research figures as rough; estimates for the same market differ by 5x)

| Market | Size | Growth | Source |
|---|---|---|---|
| ADHD apps (global) | about $1.9B in 2025, North America 47% | 17.5% CAGR 2026 to 2033 | [Grand View Research](https://www.grandviewresearch.com/industry-analysis/adhd-apps-market-report) |
| Digital journal apps (global) | $5.69B in 2025 | 11.5% CAGR to 2029 | [The Business Research Company](https://www.gii.tw/report/tbrc1710205-digital-journal-apps-global-market-report.html) |
| Habit tracking apps (global) | $1.7B in 2024 | 14.2% CAGR to 2033 (single source, a mirror of Straits Research) | [Straits via mirror](https://skynex.alwaysdata.net/blogs/476/Habit-Tracking-Apps-Market-Growth-Productivity-and-Self-Improvement-App) |

The more useful number is people, not dollars. The CDC estimates 15.5 million US adults (6.0%) had a current ADHD diagnosis in 2023, about half diagnosed as adults, and about a third get no treatment ([CDC MMWR, Oct 2024](https://www.cdc.gov/mmwr/volumes/73/wr/mm7340a1.htm)). One Johns Hopkins poster puts college students at 10 to 14% ([poster, 2024](https://mdpsych.org/wp-content/uploads/2024/02/AluriJames_Poster.pdf)). **(inference)** The ADHD framing is a sharp wedge, but the reachable market for a social "small wins" app is all students and young adults who struggle to start things, which is far larger than the diagnosed group.

### Who has won, and what it looks like

| Company | What it is | Public numbers | Source |
|---|---|---|---|
| Duolingo | Streak-driven habit app | 50.5M DAU, revenue $271.7M in Q3 2025 (+41% YoY); 6M+ people on a 7+ day streak; a 7-day streak makes course completion 3.6x likelier | [SEC 8-K Q3 2025](https://www.sec.gov/Archives/edgar/data/1562088/000162828025049514/q3fy25duolingo9-30x25share.htm), [Duolingo blog](https://blog.duolingo.com/how-duolingo-streak-builds-habit) |
| Strava | Social graph around an activity | $2.2B valuation (May 2025), nearing $500M annual revenue | [Built In SF / WSJ](https://www.builtinsf.com/articles/strava-achieves-2b-valuation-20250523) |
| Locket | Friends' photos on the home screen widget | 80M+ downloads, 9M+ DAU, profitable in 2024, raised $12.5M, up to 20 friends | [TechCrunch, Aug 2025](https://techcrunch.com/2025/08/06/photo-sharing-app-locket-is-banking-on-a-new-celebrity-focused-feature-to-fuel-its-growth) |
| Retro | Private weekly photo sharing with friends | about 1.7M MAU, about 7.8M downloads, $21M Series A, $100M+ valuation (PitchBook est.), premium about $36/yr, no ads | [TechCrunch, Aug 2026](https://techcrunch.com/2026/08/28/friend-focused-photo-sharing-app-retro-snags-21m/) |
| BeReal | Daily dual-camera post | Daily use fell about 61% from Oct 2022 to Mar 2023; sold to Voodoo for about EUR 500M in June 2024 | [Engadget](https://engadget.com/bereal-the-buzziest-app-of-2022-has-been-bought-by-a-mobile-game-publisher-175016152.html) |
| Gas | School-based compliments app | 7.4M installs, almost $7M consumer spend in about 5 months, team of 4, acquired by Discord | [TechCrunch, Jan 2023](https://techcrunch.com/2023/01/17/discord-acquires-gas-a-compliments-based-social-media-app-for-teens) |
| Lapse | Disposable camera for friend groups | $30M Series A (Feb 2024); downloads fell about 70% from peak after forced invites | [TechCrunch](https://techcrunch.com/2024/02/27/lapse-the-app-turning-your-phone-into-an-old-school-camera-snaps-up-30m), [Appfigures](https://appfigures.com/resources/insights/20231117) |
| Tiimo | Visual planner for ADHD | 500k users, 50k paid (Aug 2024); Apple's iPhone App of the Year 2025; total funding about EUR 4.3M | [Wikipedia](https://en.wikipedia.org/wiki/Tiimo) |
| Inflow | CBT-based ADHD programme | $11M Series A (2023), about $200/yr | [Vator](https://vator.tv/2023-01-11-adhd-management-app-inflow-raises-11m/) |
| Day One | Encrypted journal | Bootstrapped 10 years, 15M downloads, about 200k annual subscribers, acquired by Automattic 2021 | [TechCrunch](https://techcrunch.com/?p=2165883), [TechBuzz](https://www.techbuzznews.com/day-one-award-winning-journaling-app-acquired-by-automattic/) |
| HabitKit | Solo-built habit tracker | About $602k revenue in 2025 (self-reported) | [Sebastian Röhl](https://sebastianroehl.substack.com/p/2025-the-year-that-changed-everything) |

No primary revenue or user figures were found for Finch, Habitica, Streaks or Structured; third-party estimates conflict, so they are left out.

**(inference)** The pattern: single-player ADHD and habit apps (Tiimo, Inflow, HabitKit, Day One) land at $1M to $20M revenue. The companies worth $500M or more (Strava, Duolingo, BeReal at sale, Locket at scale) all have either a social graph or a daily ritual that people share. Some Wins has both ingredients, which is the case for venture scale.

---

## 2. Venture-scale versus a good indie app

A good indie app needs a few thousand paying fans. A venture-scale company needs a credible path to $100M+ revenue, which at Retro's $36/yr price means roughly 3 million paying users, or about 60 to 100 million downloads at typical conversion (inference, using RevenueCat's 2.9% median download-to-paid for Health and Fitness, [RevenueCat 2026](https://www.revenuecat.com/state-of-subscription-apps/)). Only growth that compounds on its own (network effects plus shareable output) gets there.

### The three biggest risks

| Risk | Evidence | How comparables got past it |
|---|---|---|
| **1. Habit-app retention cliff** | Health and fitness apps keep 3 to 4% of users at day 30 (AppsFlyer) or about 8% (Adjust) ([Business of Apps](https://businessofapps.com/data/health-fitness-app-benchmarks)). 30% of annual subscribers cancel in the first month ([Subscription Insider on RevenueCat 2025](https://subscriptioninsider.com/article-type/news/revenuecats-state-of-subscription-apps-2025-report-ais-dominance-retention-challenges-and-the-shift-away-from-pure-subscriptions)) | Duolingo made the streak the product and measured every change to it ([Duolingo blog](https://blog.duolingo.com/how-duolingo-streak-builds-habit)). Strava made other people the reason to come back. For Some Wins the crew is the retention mechanism, not a feature (inference). |
| **2. Social cold start and fad decay** | BeReal lost about 61% of daily use in five months ([Engadget](https://engadget.com/bereal-the-buzziest-app-of-2022-has-been-bought-by-a-mobile-game-publisher-175016152.html)). Lapse lost about 70% of downloads in six weeks ([Appfigures](https://appfigures.com/resources/insights/20231117)) | Andrew Chen's fix is the "atomic network", the smallest group that sustains itself, then copied place by place ([summary of The Cold Start Problem](https://blas.com/the-cold-start-problem/)). Locket survived the BeReal wave by staying intimate (20 friends) and living on the home screen, and reached profitability ([TechCrunch](https://techcrunch.com/2025/08/06/photo-sharing-app-locket-is-banking-on-a-new-celebrity-focused-feature-to-fuel-its-growth)). |
| **3. No-server architecture limits** | CloudKit's public database starts around 40 requests per second, scaling with active users, with charges above the free tier, per developer reports rather than an Apple pricing page ([Apple Developer Forums](https://developer.apple.com/forums/thread/113318)). CloudKit has no Android or web client of its own, so it cannot run Android. | Retro, Locket and Lapse all run servers. Day One kept end-to-end encryption while running its own sync ([TechCrunch](https://techcrunch.com/?p=2165883)), which shows that a server and "we cannot read it" can coexist. |

---

## 3. Growth loops that fit this app

| Loop | Mechanism in Some Wins | Evidence from comparables |
|---|---|---|
| **Crew invite** | Making a crew sends a link; a friend joins to see the tower | Partiful lets guests RSVP from a text link with no account or install, so every event recruits its guests ([Wikipedia](https://en.wikipedia.org/wiki/Partiful)). Lapse shows the limit: forced 5-friend invites got it to No. 1, then downloads fell about 70% ([Appfigures](https://appfigures.com/resources/insights/20231117)). |
| **Home screen widget** | The crew widget shows friends' heads and wins | Locket's whole product is the widget and it reached 80M+ downloads ([TechCrunch](https://techcrunch.com/2025/08/06/photo-sharing-app-locket-is-banking-on-a-new-celebrity-focused-feature-to-fuel-its-growth)); it hit No. 1 days after launch from the founder's TikTok ([Appfigures](https://appfigures.com/resources/insights/20220114)). |
| **Shareable artefact** | Photo strips and weekly replay videos posted to Stories | Duolingo and Strava turned streaks and year recaps into shared objects; the strip is the Some Wins equivalent (inference). |
| **Campus seeding** | One school at a time, with student ambassadors | BeReal paid ambassadors, reportedly $30 per referral and $50 for a download plus a review, and ran campus events ([Brown Daily Herald](https://www.browndailyherald.com/article/2022/02/new-social-media-app-tells-students-to-bereal), [TechCrunch](https://techcrunch.com/2022/04/22/bereal-hype-or-hit-what-to-know-about-the-gen-z-photo-sharing-app-climbing-the-charts/)). Gas made you sign up with your school, which made each school a dense network ([TechCrunch](https://techcrunch.com/2023/01/17/discord-acquires-gas-a-compliments-based-social-media-app-for-teens)). |

**(inference)** The strongest combination for this app: invite after the first strip prints (an emotional peak, never during onboarding), a join link that previews the crew tower on the web before the install, and the widget as the daily re-entry point. a16z says no more than 10 to 20% of early users should come from paid sources ([a16z](https://a16z.com/do-you-have-lightning-in-a-bottle-how-to-benchmark-your-social-app/)).

---

## 4. Business model at scale

### Subscription benchmarks (RevenueCat 2026 report, 2025 data, [source](https://www.revenuecat.com/state-of-subscription-apps/))

| Metric | Health and Fitness median | Notes |
|---|---|---|
| Trial to paid | 37.7% (top quartile 51.4%+) | 5 to 9 day trials: 37.4% median across apps; 17 to 32 day trials: 42.5% |
| Download to paid by day 35 | 2.9% (top quartile 6.2%+) | Hard paywalls 10.7% versus freemium 2.1% |
| Revenue per install, day 60 | $0.66 | All categories $0.34 |
| Median yearly price | $34.80 (all apps) | Strata Plus at $24.99/yr sits below the median |
| Reach $10k monthly revenue within 2 years | 4.6% of apps | |

**(inference)** The planned pricing is sound for students. Two adjustments to test: a longer trial for the annual plan (the data favours trials longer than 7 days), and making crews the thing Plus extends, because social features are what people keep paying for. At $0.66 per install, 100k installs is about $66k in 60 days; the subscription alone does not make this venture-scale without very high volume.

### Adjacent revenue, ranked by fit with the privacy promise

| Source | Fit | Why |
|---|---|---|
| **Universities** (student wellness licence) | High | Schools already buy app access for students: one Texas Tech proposal priced Headspace at about $9 per student per year ([TTUHSC resolution](https://www.ttuhsc.edu/student-government/documents/resolutions/SR_21.07.pdf)). A school pays, students get Plus, and no data goes to the school (inference). |
| **ADHD coaches and clinicians** | Medium | A user-initiated "share my week with my coach" export keeps control with the user. Inflow shows ADHD users pay about $200/yr for structured programmes ([Vator](https://vator.tv/2023-01-11-adhd-management-app-inflow-raises-11m/)). Clinical claims bring regulation; stay on the wellness side (inference). |
| **Creator and brand challenges** | Medium | Locket's Celebrity Lockets brought fans in, 17% of one artist's fans were new to the app ([TechCrunch](https://techcrunch.com/2025/08/06/photo-sharing-app-locket-is-banking-on-a-new-celebrity-focused-feature-to-fuel-its-growth)). A sponsored "30 days of small wins" crew fits if it never reads private data (inference). |
| **Employers and wellness benefits** | Low for now | Slow sales cycle, and an employer near your wins conflicts with the private-circles promise (inference). |
| **Ads** | No | Locket added widget ads in Nov 2025 ([Moloco](https://moloco.com/case-studies/locket-widget)); Retro and Tiimo stayed ad-free ([Tiimo](https://tiimoapp.com/resource-hub/why-tiimo-went-freemium)). Ads break the "no ads" launch promise. |

---

## 5. The platform path

| Order | Step | Why this order | Architecture need |
|---|---|---|---|
| 1 | Web join page for crew invites | Removes the install step before someone sees value, the Partiful lesson | Static page plus sealed invite token; no server reading content |
| 2 | Apple Watch quick log and complications | Logging a win in two taps is the ADHD-first promise | CloudKit is enough |
| 3 | HealthKit and App Intents (workouts, sleep, focus as auto-suggested wins) | Fewer blank days, more reasons to log | On-device only |
| 4 | On-device coach (Apple Foundation Models) | Weekly reflection and gentle prompts without sending data anywhere | On-device; privacy promise intact |
| 5 | Android | Many college friend groups are mixed; a crew that cannot include an Android friend is a broken crew | **This is where a server becomes necessary**: an end-to-end encrypted relay (records stay sealed, server stores ciphertext) plus Firebase or APNs push |
| 6 | Graph of wins across crews, public "challenge" crews | Turns crews into a network that compounds | Server, moderation, abuse reporting |

**When to add a server (inference):** before Android, or when CloudKit request limits or push latency start to show, likely around 50k MAU. Keep three promises written down now so they survive fundraising: we cannot read your wins or photos; there is no public feed by default; your data is never sold or used for ads.

---

## 6. Moat and positioning

**(inference)** No single feature is defensible. Instagram copied BeReal as Candid Stories within months ([PetaPixel](https://petapixel.com/2022/12/13/instagram-launches-its-copycat-bereal-feature-candid-stories)). Apple's Journal added multiple journals and a map view in iOS 26 ([9to5Mac](https://9to5mac.com/2025/06/17/apples-journal-app-is-coming-to-ipad-and-mac-with-big-upgrades/)), and Apple launched Invites in direct competition with Partiful in February 2025 ([TechCrunch](https://techcrunch.com/2025/02/04/apple-launches-invites-a-new-app-for-creating-custom-invitations), [AppleInsider](https://appleinsider.com/articles/25/02/05/apple-invites-has-sherlocked-party-organizing-app-partiful)).

What is hard to copy:
- **Small dense crews that already exist.** A crew with 90 days of shared towers is switching cost; an Instagram close-friends list is not (inference).
- **Identity heads.** A drawn head made from your selfie is personal, recognisable in a widget and in a strip, and becomes the brand (inference).
- **The tower as a visual language.** Like Duolingo's flame or Strava's map, a recognisable shape makes the shared artefact identifiable without a logo (inference).
- **ADHD-first defaults.** Incumbents design for the median user; "one tap counts, a small win is a win" is a values position that big platforms will not commit to (inference).

How incumbents could copy: Apple could add friends and a tower to Journal; Snapchat or Instagram could add "wins" to close friends. The defence is speed to dense campus networks and the private, ad-free promise those companies cannot credibly make (inference).

---

## 7. Staged plan

Benchmarks below are from a16z's social app guide: D1/D7/D30 of 50/35/20% is "OK", 60/40/25% "good", 70/50/30% "great"; DAU/MAU 25/40/50%; monthly growth 20/35/50% ([a16z](https://a16z.com/do-you-have-lightning-in-a-bottle-how-to-benchmark-your-social-app/)).

### 0 to 6 months: launch and one campus

- Launch on iOS, seed UC Davis first: 10 to 20 student ambassadors, each starting crews with real friends.
- Measure crews per user, invite to install conversion, and retention for crew members versus solo users.
- Expand to a second and third campus only when the first one holds.

| Decides whether to continue | Target |
|---|---|
| D30 retention for users in a crew | 20% or more (a16z "OK"), versus 3 to 8% for solo health apps |
| Share of new users in an active crew by day 7 | 40% or more (inference) |
| K-factor (invites sent x conversion) | 0.3 or more; real referral programmes land at 0.2 to 0.8 (from `docs/launch-plan.md`) |

Also watch trial to paid against the 37.7% median.

### 6 to 18 months: prove it for a seed round

- 5 to 10 campuses, web join page, Watch, a first university wellness pilot.
- Build the relay server and an Android beta.
- Raise. Typical terms: in 2025 the median post-money SAFE cap was about $10M for pre-seed rounds of $250k to $1M and about $15M for $1M to $2.5M ([Carta, State of Pre-Seed 2025](https://carta.com/data/state-of-pre-seed-2025/)); one secondary source puts the median consumer seed at about $700k in Q1 2025 ([Causo, citing Carta](https://hub.causo.ai/guides/consumer-startup-funding-this-quarter)). Breakout consumer social apps raise much larger rounds once growth shows (Lapse $11M seed, then $30M A; Retro $21M A).
- Programmes that back student or very early founders: YC ($500k, [YC deal](https://ycombinator.com/deal)), Neo (accelerator plus a scholars programme for students, [Neo](https://neo.substack.com/p/neo-accelerator-2025-apply-now)), a16z speedrun and its student Alpha Fellowship ([Superscout listing](https://superscout.co/program/a16z-speedrun)). Also worth contacting, not verified here: Dorm Room Fund, Contrary, Pear, Z Fellows.

| Decides whether to continue | Target |
|---|---|
| Monthly active user growth, mostly organic | 20% or more month on month (a16z "OK"), paid under 20% |
| DAU/MAU | 40% or more (a16z "good") |
| Paid conversion of installs by day 35 | 3% or more (above the 2.9% Health and Fitness median) |

### 18 to 36 months: from app to company

- Android at parity, graph of wins across crews, on-device coach, university licences as a revenue line.
- Hire: one backend and security engineer first, then growth.

| Decides whether to continue | Target |
|---|---|
| M12 retention of crew cohorts | 25% or more (inference, roughly where Locket-scale apps must be) |
| Annual recurring revenue | $1M to $3M, the usual bar for a consumer Series A (inference) |
| Share of new users from existing users | Over half (inference) |

---

## 8. What to do this month

1. Ship to the App Store and get the first 50 real users at UC Davis in actual crews, not solo.
2. Add analytics that respect privacy: count events on device and send anonymous aggregates (crew created, invite sent, invite accepted, day 1/7/30 return). Without them none of the targets above can be measured.
3. Recruit 10 ambassadors; give each a free year of Plus and a simple goal of 3 crews.
4. Build the web join page so a crew invite previews the tower before the install.
5. Write down the three privacy promises and publish them on the website.
6. Post the strip and replay on TikTok and Instagram yourself, daily, for 30 days; the founder's own account launched Locket.
7. Apply to one programme on a rolling deadline (Neo, YC or speedrun) once you have 4 weeks of retention data.
