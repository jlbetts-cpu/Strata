# How Strata should make money

Researched 2026-09-15 against the code in `/Users/jaydenbetts/StrataWork/owner-head`.
Read-only: nothing was edited, built or run.

---

## The recommendation, in ten lines

**Model:** free download, one non-consumable unlock called **Strata Everything**. No subscription.

**Price:** **$9.99** standing, **$5.99** for the first 60 days as a launch price.

**Free forever:** logging a win, the tower, your whole record however far back it
goes, the camera and photos, the map, albums, the month tower, the widget, Siri,
Spotlight, reminders, the backup export, and **Your Week** playing on screen.

**Paid:** saving any replay as a **video**, **Your Month**, **your head** (maker and
all three placements), and the **film looks**.

**The principle in one line:** the record is free, the keepsakes are paid.

**The moment you charge at:** the end of your first week's replay, when you reach
for Save video. Not on launch, not on a win, not after onboarding.

**Biggest risk:** it is not the paywall. Everything lives on one phone with no sync
and no automatic backup. Charging money turns "I lost my wins" into "I paid for
this and lost my wins". Fix or disclose that before you take a cent.

**Ship-blocker regardless of money:** `strataapp.co` is dead, and App Store Connect
requires a reachable privacy policy URL that review will open.

---

## 1. Readiness

### Where the app actually is

Pre-launch. `itunes.apple.com/lookup?bundleId=JaydenBetts.Strata` returns
`resultCount: 0` (checked 2026-09-15), the version is 1.0 (1), and the onboarding's
last page says "You're one of the first people to open my first app". So there are
no users, no retention numbers, no reviews and nobody has asked to pay.

### Scorecard

| Signal | Verdict | Evidence |
|---|---|---|
| Core value clear and differentiated | Ready | One tap logs a thing you already did, and it becomes an object. Nothing in the comparable set does this. |
| Retention | Not ready | Unknown. Zero installs. |
| People asking to pay | Not ready | Unknown. Zero installs. |
| Feature depth for a free/paid split | Ready | Replays, video export, the head, film looks, map, albums, widget, Siri. Plenty to draw a line through without touching the loop. |
| Differentiation | Ready | The block, the drawn numerals, the head, the replay. This is a craft app. |
| Polish | Ready | The level of measured detail in `CLAUDE.md` is not normal for a first app. |

**4 of 6. The monetization playbook's own threshold for 4 is "soft-launch pricing:
low price, gather data."** That is exactly the recommendation below: a low one-time
price, a permanently generous free tier, and no recurring promise you have to keep
funding.

### The single thing people would pay for

Not the logging. Logging is the thing that must stay free and fastest, and it is
also the thing that is cheapest to copy.

**The replay is the product you can charge for.** `ReplayScript` / `ReplayView` /
`ReplayVideoExporter` build a week or a month block by block into one tower, the
camera follows, then pulls out and the whole thing stands there, and it exports to
video. That feature is:

- emotional, which almost nothing else in a tracker is,
- unique, nobody in the comparable set below has it,
- **naturally time-gated**: you cannot experience it until you have used the app for
  a week, which means the paywall arrives after the person has invested, not before,
- **repeating**: it comes back every Sunday and every 1st, so the value is not spent,
- and it produces a file the person wants to keep or send, which is the oldest and
  cleanest thing to charge for.

The moment of value is precise: the replay finishes, the tower is standing there,
and the person reaches for Save video. That is where the money question belongs and
nowhere else.

Second and third: **your head** (the maker is fifteen seconds with the front camera
and it produces something nobody else has) and the **film looks**.

### What is missing before money is a fair ask

1. **A reachable privacy policy URL.** `tasks/app-store-readiness.md` records
   `000 https://strataapp.co/privacy`, meaning no response at all. Review opens that
   URL. Blocker for submitting at all.
2. **Terms of Use.** `grep -rn "Terms" --include="*.swift" Strata` returns nothing.
   A paywall has to link Terms and Privacy. Cheapest correct answer in section 5.
3. **No StoreKit code of any kind.** The only StoreKit reference in the tree is
   `requestReview` in `SettingsView.swift`.
4. **Durability.** Everything is SwiftData on the device. There is a manual
   "Back Up Everything" zip in Settings and nothing automatic. This is the one that
   would actually cost you. See section 8.
5. **Zero ratings.** The first fifty reviews set the rating for a year. Worth
   considering shipping 1.0 free and adding the unlock in 1.1 once a rating exists.

---

## 2. Model choice

All prices below were read from the US App Store product pages on **2026-09-15**
(the store lists an app's ten most popular in-app purchases, so several entries are
the same product at different regional or legacy prices).

| Model | Fit with this app | Conversion and revenue | Review risk | Work |
|---|---|---|---|---|
| **Paid up front** | Perfect mechanically. No StoreKit code at all, no server, nothing to maintain. Streaks does exactly this. | Removes the top of the funnel completely. For a first app with no audience and no ratings, almost nobody will pay before trying. Revenue is downloads x price, and downloads collapse. | Lowest of all. | XS, set a price. |
| **Freemium + one-time non-consumable** | **Best fit.** Entitlement is `Transaction.currentEntitlements`, which reads the device's own signed transaction store, so it works with no network and no account. Nothing expires, nothing renews, nothing to dun. | Freemium median Day-35 download-to-paid is 2.1% and revenue per install at Day 60 is $0.38, against $3.09 for a hard paywall ([RevenueCat, State of Subscription Apps 2026](https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026)). A one-time unlock takes the lower per-install number and gives you every install. | Low. Guideline 3.1.1 compliant with a restore button. | S to M. |
| **Subscription** | **Worst fit.** 3.1.2(a): "you must provide ongoing value" and the sanctioned examples are episodic content, media collections, SaaS and cloud. Strata has no server, no sync, no feed and no running cost. | Would earn more per converted user if it survived review and reviews. Annual subscribers churn roughly 72% within year one, so it is a treadmill you have to keep feeding with new installs. | **Highest.** The most likely 3.1.2(a) rejection in this whole set, and the most likely 1-star theme for a local-only app. | L: terms, EULA, expiry, grace period, intro offers, win-back. |
| **Free with a generous limit then a lifetime unlock** | This is the row above with a specific shape of line. **Recommended.** | Same numbers. The limit should be a *kind of feature*, not a count of your own data. | Low. | S to M. |
| **Tip jar** | No risk, no design cost, and it suits the app's voice. | Tiny. Tip take rates are a fraction of a percent of users (I found no credible primary benchmark, so treat any number as an **estimate**). Same StoreKit work as a real unlock, so "it is simpler" is false. | None. | S. |

**Recommend:** freemium with a single non-consumable unlock.
**Second choice:** paid up front at $4.99. Only if you decide you want zero paywall
UI inside the app and will trade installs for it. If you go that way, 3.1.1 sanctions
a free trial: "Non-subscription apps may offer a free time-based trial period before
presenting a full unlock option by setting up a Non-Consumable IAP item at Price Tier
0 that follows the naming convention: 'XX-day Trial.'"

One more argument against the subscription that is specific to you: it is the only
model here that a designer interviewing in the Bay Area would have to defend. Nobody
will ask you about a $9.99 unlock. Several people will ask about a subscription on a
local-only app, and the honest answer is not a good one.

---

## 3. What is free, what is paid

### The principle

**Never gate the core loop, and never gate a person's own record.** Logging a win
must stay the fastest thing in the app, and a win tracker that hides your past is
hostile in a way no price can repair. The line is drawn around things that are made
*from* the record, not around the record.

### The line

**Free, forever**

- Logging a win: the slot, the drag-to-size, one tap.
- The tower: today, week, month, all filters.
- **Your whole record, however far back it goes.** No history depth limit.
- The camera, and photos on wins. (`HabitLog.imageFileName` is a single optional, so
  "photos per win" is already one by design. There is nothing to limit.)
- Memories: the map, the drawer, the month tower, albums, the camera roll grid.
- The widget, Siri and Shortcuts, Spotlight, daily and weekly reminders.
- Back Up Everything.
- **Your Week, played on screen.** Every Sunday, free, forever.

**Strata Everything, $9.99 once**

1. **Save a replay as video.** Week or month.
2. **Your Month.**
3. **Your head.** The maker, plus profile picture, map marker and photo sticker.
4. **Film looks.** Air, Bright and Silver, on photos and on the head.

### What would feel mean, or would break the app's promise

- **History depth** ("last 30 days free"). Your data, on your phone, costing me
  nothing to keep. Gating it is the single most refund-generating move available.
- **The map.** Your own call on 2026-09-10 was that the map is "the most important
  add and the biggest focus". Gating the centre of the app after the screenshots
  showed it is near 3.2.2 territory and reads as a bait and switch.
- **The widget, Siri or Spotlight.** System surfaces. A locked widget is the most
  visible nag a phone can display, and it makes the app look broken on the home
  screen rather than unpaid.
- **Wins per day.** Core loop. Never.
- **The backup export.** Gating a person's ability to get their own data out of a
  no-server app is the worst gate on this list.
- **Your Week entirely.** Keep it free. A paywall on the only emotional moment in the
  app, before anybody has seen one, sells nothing. Let them watch it, then charge for
  keeping it.

### What comparable apps gate

| App | What is behind the paywall | Price (US, 2026-09-15) |
|---|---|---|
| Streaks | Nothing. Paid up front. | $5.99 |
| HabitKit | Unlimited habits, themes | Pro $1.99/mo, $11.99/yr, **$29.99 lifetime** |
| Daylio | Extra moods and colours, export, no ads | $4.99 to $35.99, top tier $59.99 |
| Way of Life | Unlimited habits, history, export | Premium $29.99, $4.99 lower tier |
| Do Habits (Done) | Unlimited habits, reminders | $8.99 one-time upgrade, $19.99 lifetime, $59.99/yr |
| Structured | Unlimited tasks, calendar sync | $2.99/mo, $29.99/yr, **$99.99 lifetime** |
| Gentler Streak | Advanced insights, coaching | $8.99/mo, $39.99/yr, **$59.99 lifetime** |
| Bearable | Advanced tracking and correlations | $4.49 to $49.99 across tiers |
| Finch | Extra pet content | $9.99/mo, $39.99/yr |
| 1 Second Everyday | Unlimited backup, **watermark removal**, Pro | $9.99/mo, $49.99/yr, watermark removal $4.99 |
| Day One | Sync, unlimited photos per entry | Silver $8.99/mo, $49.99/yr, Gold $74.99 |
| Reflectly | Everything | $9.99/mo to $59.99/yr |
| one sec | Unlimited interventions | $2.99/mo, $19.99/yr, **$99.99 lifetime** |
| Halide Mark III | Pro camera, editor, lessons | $19.99/yr, **$69.99 one-time** |
| Dark Noise | Custom mixes, icons | $2.99/mo, $19.99/yr, **$49.99 lifetime** |
| Flighty | Live tracking, history | $9.99/mo, $59.99/yr, **$299 lifetime** |
| Polarsteps | Plus | $9.99/mo, $34.99/yr |

Sources: `https://apps.apple.com/us/app/id<id>` product pages, fetched 2026-09-15,
and `https://itunes.apple.com/search` for prices and rating counts. Streaks:
$5.99, Health & Fitness, 27,350 ratings.

Note the pattern: **nobody hides your past entries.** They gate breadth (more habits),
looks (themes, icons), and getting it out (export, sync, watermark). 1 Second
Everyday charging $4.99 just to remove a watermark from an exported video is the
closest precedent to charging for replay export, and it is a well-liked app.

---

## 4. Price

### Where the comparable set sits

Lifetime unlocks in this genre cluster **$19.99 to $49.99** for apps with years of
reviews behind them: HabitKit $29.99, Gentler Streak $59.99, Dark Noise $49.99,
Done $19.99, Structured $99.99, one sec $99.99. One-time-purchase craft apps sit
higher: Halide $69.99. Paid-up-front trackers sit low: Streaks $5.99.

HabitKit is the closest comparable by shape (solo indie, habit grid, free with a Pro
unlock, one-time option at $29.99, 2,418 ratings). It also has three years of
reviews. You have none.

### The number

**$9.99 standing. $5.99 for the first 60 days.**

Reasoning:

- $9.99 is the highest price a person will pay without deliberating, and RevenueCat's
  2026 data says higher-priced apps convert downloads roughly 2x better than low-priced
  ones (2.8% median for high-priced against 1.4% for low-priced). Cheap does not mean
  more revenue.
- Below the genre's lifetime cluster, which is right: those apps have proof and you do
  not. You can raise it in a year. Lowering a price after launch annoys the people who
  already paid; raising it does not.
- Above Streaks' $5.99, which is fair given you are asking after they have used it,
  not before.
- $5.99 for 60 days is a real launch price, not a fake anchor. Apple supports scheduled
  and time-limited prices per storefront, so this is a setting, not a feature.

**Regional pricing:** take Apple's automatic conversions and then check the ten
storefronts that matter. The store has 900 price points across 175 storefronts and
44 currencies, with $0.10 increments under $10, so you can land a real local number
rather than a converted one
([Apple, App Store Connect pricing](https://developer.apple.com/help/app-store-connect/manage-app-pricing/set-a-price/);
[Apple Newsroom, 2022-12-06](https://www.apple.com/newsroom/2022/12/apple-announces-biggest-upgrade-to-app-store-pricing-adding-700-new-price-points/)).

**Introductory offers:** do not apply. Those are a subscription feature. The launch
price above is the equivalent and needs no code.

**Annual plus lifetime:** no. There is no annual, because there is no subscription.
The unlock *is* the lifetime option. Adding a subscription alongside it would put you
straight back into 3.1.2(a).

---

## 5. The paywall

### Where it appears

Three places, all reached by an action the person chose, plus one permanent quiet row.

1. **Save video**, at a replay's close.
2. **Your Month**, on the Replays shelf.
3. **Make Your Head**, in Profile.
4. A row in Profile above Settings: "Strata Everything", showing the price, or
   "Unlocked" once bought.

### Where it never appears

On launch. On first run. After onboarding. When you log a win. As a badge on the tab
bar. As a banner on the tower. Not once, not ever. The apps that get review-bombed
over paywalls are the ones that interrupt the loop.

### How it looks

A sheet, not a full-screen takeover, with a visible close control as well as the drag.
Light ground, SF Pro Rounded at the two weights. **No card, no white rim, no frosted
band**: those say "you built this and it is standing on something", which is a block's
claim and not a sheet's. The illustration is three real `BlockSurface` blocks, because
the app's own object is better than an icon list.

**Trap:** do not set the price in `Typography.numeral`. That font has ten glyphs and a
space, so `$` renders `.notdef`. Prices go in SF Pro Rounded, and always from
`product.displayPrice`, never hardcoded.

### The copy, in full

No long dashes. Nothing that sounds like watching anybody.

**Title**
> Strata Everything

**Subtitle**
> One payment. Yours for good.

**Rows**
> **Save your replays**
> Your week and your month, as a video you can keep or send.

> **Your Month**
> Every win in a month, falling into one tower.

> **Your head**
> Made on this phone, used as your picture, your marker on the map, and a sticker on
> your photos.

> **Film looks**
> Air, Bright and Silver, on your photos and on your head.

**Footnote, directly under the rows**
> Everything you already log stays free, including your whole record and Your Week.

**Button**
> Unlock for \(product.displayPrice)

**Under the button**
> Restore Purchase

**Foot of the sheet**
> Privacy · Terms of Use

**Dismiss**
> Not now

**While the purchase is waiting for approval (Ask to Buy)**
> Waiting for approval. Strata will unlock as soon as it comes through.

**On success**
> Unlocked. Thank you, genuinely.

**Restore, nothing found**
> No purchase found on this Apple Account.

**Purchase failed**
> That didn't go through. Nothing was charged.

**Profile row, before**
> Strata Everything
> Replays as video, Your Month, your head, and the film looks.

**Profile row, after**
> Strata Everything
> Unlocked. Thank you.

**Do not put a tip jar on the thank-you page.** `OnboardingView.swift` already carries
the reasoning and it is right: "asking for something on the screen where you are
thanking somebody turns the thank you into a transaction."

### The rules Apple enforces

- **3.1.1**: "If you want to unlock features or functionality within your app ... you
  must use in-app purchase", and "you should make sure you have a restore mechanism
  for any restorable in-app purchases." Hence Restore Purchase on the sheet.
- **3.1.1, trials**: the Price Tier 0 "XX-day Trial" non-consumable is the only
  sanctioned free trial for a non-subscription app. Not needed here, since the free
  tier is permanent.
- **3.1.2(a)**: the reason there is no subscription. "You must provide ongoing value
  ... examples of appropriate subscriptions include: new game levels; episodic
  content; multiplayer support; apps that offer consistent, substantive updates;
  access to large collections of, or continually updated, media content; software as
  a service ('SAAS'); and cloud support."
- **5.1.1(v)**: "If your app doesn't include significant account-based features, let
  people use it without a login." StoreKit needs no account. Never add one for the
  purchase.
- **Price and term clearly shown**: use `product.displayPrice` and say "One payment"
  in the subtitle, so there is no ambiguity about renewal.
- **Terms and Privacy links**: Apple's standard EULA is the default and is enough for a
  non-consumable. Link
  `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/` as Terms of Use
  until you write your own. I did not need the `legal` skill: there is no subscription
  wording to draft.
- **Family Sharing**: turn it on for the non-consumable in App Store Connect. It is a
  per-product switch, it costs nothing, Apple shows it on the product page, and for a
  personal app bought by one person in a household it is a genuine kindness.
- **Offer codes**: since **26 March 2026** you can no longer create promo codes for
  in-app purchases, and offer codes now cover every IAP type including non-consumables.
  100 codes per in-app purchase, 1,000 across all in-app purchases per app per six
  months, resetting 1 January and 1 July
  ([Apple, promoting your apps](https://developer.apple.com/app-store/promote/);
  [App Store Connect Help](https://developer.apple.com/help/app-store-connect/offer-promo-codes/request-and-manage-promo-codes)).
  Use them for press, for friends, and for anybody who writes in.
- **3.2.2 and 2.3.x**: the product page and screenshots must not show as core
  something the app then locks. With the line above they do not.

---

## 6. Implementation, in this codebase

| Piece | What | Size |
|---|---|---|
| Product id | `enum StrataProduct { static let everything = "JaydenBetts.Strata.everything" }` | S |
| `StrataStore` | `@Observable @MainActor final class StrataStore` with a `static let shared`, in `Strata/Models/` beside `HeadStore.swift` and `ProfileStore.swift`. Same shape as `HeadStore`: a `shared` singleton, no `didSet` on observed stored properties (`HeadStore` documents why), UserDefaults for the cached flag. | M |
| Entitlement | `func refresh() async` iterating `Transaction.currentEntitlements`, taking only `.verified` results with `transaction.revocationDate == nil`. | S |
| First-frame problem | `currentEntitlements` is async, but `HeadStore.init` reads its switches synchronously and the head must not flash locked. Seed `isUnlocked` from a UserDefaults cache written on every refresh, then correct it. The cache is a UX optimisation; the StoreKit result is always the truth. | S |
| Updates listener | `Transaction.updates` task started in `StrataApp.init`, calling `refresh()` then `await transaction.finish()`. This is how refunds, Family Sharing and Ask to Buy approvals reach the app. | S |
| Purchase | `product.purchase()`, handle `.success` / `.userCancelled` / `.pending`, verify, `finish()`. | S |
| Restore | `try await AppStore.sync()` then `refresh()`. | S |
| `UnlockSheet` | Hand-built SwiftUI, not `StoreView` or `ProductView`. Apple's store views bring their own card chrome, which collides with the no-card, no-rim rule. The cost is that the sheet must carry restore and the policy links itself, which the copy above does. | M |
| Call sites | Replay close, Replays shelf month card, Make Your Head, Profile row. Gate at the action, never at the screen. | S |
| Film looks | `HeadStore.setLook` and `FilmLookStrip` both need the check. Free stays on `.none`. | S |
| StoreKit config | `Strata.storekit` in the project, selected in the scheme's Run options. Test Ask to Buy with `.simulatesAskToBuyInSandbox(true)`, and refunds with Xcode's Debug, StoreKit, Manage Transactions, which can revoke a purchase and prove the app drops the entitlement. | S |
| Sandbox | A Sandbox Apple Account in App Store Connect, then a real device. Sandbox is the only place Family Sharing and a real restore behave truthfully. | S |
| App Store Connect | Enroll in the Small Business Program **before** launch. Create the non-consumable, set $9.99 with a scheduled $5.99 launch price, enable Family Sharing, add the review screenshot and notes, attach it to the version. | S |
| `PrivacyInfo.xcprivacy` | **No change needed, and this is deliberate.** A purchase is data **Apple** handles, not Strata. Apple's own definition is "transmitting data off the device in a way that allows you and/or your third-party partners to access it", and Strata never sees the transaction beyond the device's own signed store. `NSPrivacyCollectedDataTypes` stays empty. The UserDefaults cache is already covered by the existing `CA92.1` entry. Do not add a Purchases data type in the App Store Connect questionnaire either. | S |
| Privacy policy | Add one paragraph: the purchase is handled by Apple, Strata never sees a name or a card, and nothing about it leaves the phone except through Apple. The app's own rule is that what it claims must be true, and right now the policy claims nothing about money. | S |
| Terms of Use | Link Apple's standard EULA. | S |
| Hosted privacy URL | `strataapp.co` returns nothing at all. Either register it, or point App Store Connect at a page that exists. `docs/privacy.html` is the copy. **Blocker.** | M |
| Automatic backup | See section 8. Not strictly a monetization task, and I would not charge without it. | L |

**Refunds and expiry offline.** A non-consumable never expires, which removes the
hardest offline problem a subscription has. A refund arrives as a `revocationDate` on
the transaction and reaches the app through `Transaction.updates` the next time the
device syncs with the App Store. An offline device keeps access until then. Without a
server that is unavoidable, and for a $9.99 unlock it does not matter.

---

## 7. Numbers

**Assumptions, stated:**

- Free download, so downloads are the top of the funnel.
- Download-to-paid band of **1.5% (conservative) to 2.5% (good)**. Derived from
  RevenueCat's State of Subscription Apps 2026: North America median Day-35
  download-to-paid 2.6%, mid-priced apps 2.0%, freemium apps 2.1%. **Mark as an
  estimate**: that report measures subscription apps, not one-time unlocks, so I have
  taken the bottom of its range as the planning number.
- Price $9.99. **Small Business Program 15%**, so proceeds are **$8.49** per unlock.
- Refunds 2% of purchases. **Estimate.** I found no primary per-app refund benchmark.

| Lifetime downloads | Unlocks at 1.5% | Unlocks at 2.5% | Proceeds after Apple and refunds |
|---|---|---|---|
| 1,000 | 15 | 25 | **$125 to $208** |
| 10,000 | 150 | 250 | **$1,249 to $2,081** |
| 100,000 | 1,500 | 2,500 | **$12,480 to $20,801** |

**Now the honest part.** From the same report, which covers 115,000+ apps and $16bn of
revenue:

- The median app makes about **$72 a month** one year after launch.
- **17.3%** of newly launched apps reach $1,000 a month within two years.
- Only **4.6%** reach $10,000 a month within two years.
- Apps launched in 2025 or later account for **3%** of all subscription revenue.

100,000 lifetime downloads for a first app with no audience and no marketing budget is
a top-decile outcome, not a base case. **The base case for Strata is 1,000 to 5,000
lifetime downloads and a few hundred dollars in total.** That pays the $99 developer
programme fee and buys you dinner. Plan on it, and be pleasantly surprised.

Sources:
[RevenueCat, State of Subscription Apps 2026](https://www.revenuecat.com/state-of-subscription-apps/) and
[the summary post](https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026),
both read 2026-09-15.

---

## 8. Risks and alternatives

### The biggest risk, and it is not the paywall

**Everything is on one device.** SwiftData in the app group, photos in the app's own
container, one manual zip in Settings, no sync and nothing automatic. A person who logs
a year of wins and loses their phone loses the year.

Free, that is a disappointment. Paid, it is a grievance, a refund and a one-star review
that says "I paid for this". This is the single thing I would insist on fixing or
disclosing before charging:

- **Best:** make the backup automatic. A scheduled write of the same export into
  iCloud Drive or the Documents directory, plus a restore path. No server needed, no
  privacy manifest change (iCloud Drive is the user's own storage).
- **Minimum:** say it plainly, in onboarding and on the paywall. "Everything stays on
  this phone. Back it up in Settings so it survives a new one."

Full CloudKit sync would be the real answer, and it is also the one thing that would
genuinely justify a subscription. That is a large piece of work and a different
conversation.

### Refund exposure

Low in money terms for a $9.99 one-time purchase, and Apple reviews each request rather
than granting automatically. What matters is not the rate but the *theme*: refunds
cluster where people feel tricked. The two available tricks here are gating the record
and losing data, and the plan above removes the first and flags the second.

### Review-bombing over a paywall

Real, and a function of *where* the paywall appears rather than whether one exists.
Three chosen entry points, no launch modal and no tab-bar badge is the mitigation.

Given zero ratings today, there is a decent case for **shipping 1.0 completely free and
adding the unlock in 1.1**, once forty or fifty reviews exist to absorb the first angry
one. The cost is a few weeks of revenue you were not going to earn anyway. I would do
this.

### Apple's cut

30% standard, **15% under the Small Business Program**: "a reduced commission rate of
15% on paid apps and In-App Purchases", for developers with up to $1 million in
proceeds in the prior calendar year "as well as developers new to the App Store".
Proceeds adjust "fifteen (15) days after the end of the fiscal calendar month in which
your enrollment is approved", so enroll before you launch, not after
([Apple](https://developer.apple.com/app-store/small-business-program/), read
2026-09-15).

### Free forever with a tip jar

Costs you essentially all of the revenue in the table above, and does not save you any
work: a tip jar is the same StoreKit integration as a real unlock. What it buys is that
no review can ever be about money, and that the app stays a pure gift. If the portfolio
matters more than the income, this is a defensible choice and I would not argue against
it. I would just not pretend it earns anything. Tip take rates are a fraction of a
percent of users, which at 1,000 downloads is plausibly $0 to $30. **Estimate. I found
no credible primary benchmark.**

### The job-hunting angle

This is the argument that actually decides it, so here it is straight.

You are a product designer looking for work in the Bay Area. A free, beautiful, widely
installed app with two hundred five-star reviews is worth more to that goal than
$1,500. Portfolio value scales with installs and with visible evidence of craft.
Revenue at these volumes does not change your life.

**But the two are not opposed under the recommended model.** Free download, free core,
free record, free weekly replay, one honest $9.99 unlock for the keepsakes. Installs
stay uncapped. Nobody in an interview has ever held a modest one-time unlock against a
designer, and several will ask about the paywall copy, which is a very good question to
be asked.

The models that *would* hurt the job hunt are the other two: paid up front kills the
install count you want to point at, and a subscription on a local-only app invites the
one question you would rather not have to answer.

---

## Sources

All read 2026-09-15.

- App Store product pages, `https://apps.apple.com/us/app/id<id>`: Streaks (963034692),
  Way of Life (393159800), Bearable (1482581097), Gentler Streak (1576857102), Finch
  (1528595748), Flighty (1358823008), one sec (1532875441), Day One (1044867788),
  Reflectly (1241229134), Structured (1499198946), Daylio (1194023242), 1 Second
  Everyday (587823548), Halide Mark III (885697368), Dark Noise (1465439395), Drafts
  (1435957248), HabitKit (6443918070), Do Habits (1103961876), Polarsteps (947925763).
- `https://itunes.apple.com/search` and `/lookup` for prices, categories and rating
  counts.
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/),
  sections 3.1.1, 3.1.2(a), 3.1.3(b), 5.1.1(v).
- [App Store Small Business Program](https://developer.apple.com/app-store/small-business-program/).
- [Promoting your apps](https://developer.apple.com/app-store/promote/) and
  [App Store Connect Help: promo codes](https://developer.apple.com/help/app-store-connect/offer-promo-codes/request-and-manage-promo-codes).
- [App Store Connect Help: set a price](https://developer.apple.com/help/app-store-connect/manage-app-pricing/set-a-price/)
  and [Apple Newsroom, 2022-12-06](https://www.apple.com/newsroom/2022/12/apple-announces-biggest-upgrade-to-app-store-pricing-adding-700-new-price-points/).
- [RevenueCat, State of Subscription Apps 2026](https://www.revenuecat.com/state-of-subscription-apps/)
  and [summary](https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026).
  115,000+ apps, $16bn revenue, 1bn+ transactions.
- The code: `CLAUDE.md`, `docs/product-direction.md`, `tasks/app-store-readiness.md`,
  `Strata/PrivacyInfo.xcprivacy`, `Strata/Models/HeadStore.swift`,
  `Strata/Models/FilmLook.swift`, `Strata/Views/SettingsView.swift`,
  `Strata/Views/ProfileView.swift`, `Strata/Views/OnboardingView.swift`,
  `Strata/Views/ReplayView.swift`, `Strata/Services/ReplayVideoExporter.swift`,
  `StrataWidget/StrataWidget.swift`.

Skills used: `monetization`, `storekit`, `app-store`. The `legal` skill was not needed:
the recommendation has no subscription, so Apple's standard EULA covers the terms.
