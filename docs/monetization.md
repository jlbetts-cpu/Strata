# Making money from Strata

The plan, agreed 2026-09-15. Paid comes later: the app ships free first, and the
unlock is added before launch. Full research, with sources and numbers, is in
`research-monetization.md` (kept outside the repo).

## The shape of it

**Free download, one payment to unlock, no subscription.** A subscription has to
keep earning its money, and Strata runs entirely on the phone with nothing to fund.
Apple's guideline 3.1.2(a) expects ongoing value for a recurring charge, so a
subscription here is both dishonest and a review risk.

**$9.99**, with **$5.99 for the first 60 days** as a launch price. Comparable
one-time unlocks: HabitKit $29.99, Dark Noise $49.99, Streaks $5.99 paid up front.
Enroll in the Small Business Program first, so Apple takes 15% rather than 30%.

## The line

**The record is free. The keepsakes are paid.**

Free forever:

- Logging a win, the tower, and your whole record however far back it goes
- The camera, photos, and the map
- Albums, the month tower, the gallery
- The widget, Siri, Spotlight, reminders, the backup export
- Your Week, playing on screen

Paid, as "Strata Everything":

- Saving a replay as a video
- Your Month
- Your head: the maker, and using it as your picture, your map marker and a sticker
- The film looks

Nothing in the core loop is ever gated. Logging a win stays the fastest thing in the
app, free, for everyone.

## Where it is asked for

At the end of your first week's replay, when you reach for Save video. Not at launch,
not after onboarding, not on a win. One more place: the Make Your Head row, and a
quiet row in Profile that says what the unlock is.

The sheet's words are written out in the research file, including restore, the
failure and Ask to Buy lines. The tone rule stands: plain, no long dashes, no
countdowns, no dark patterns, and no tip jar on the thank-you page.

## What it takes to build

About a week of small pieces, none of them risky:

- `StrataStore`, an `@Observable` singleton beside `HeadStore`, holding the
  entitlement, seeded from a cached flag so nothing flashes locked on the first frame
- `Transaction.currentEntitlements` to read it, `Transaction.updates` to catch
  refunds, Family Sharing and Ask to Buy
- Purchase and restore (`AppStore.sync()`)
- One hand-built unlock sheet in the app's own style, not Apple's store views
- Gates at four actions: Save video, Your Month, Make Your Head, the film looks
- A `.storekit` configuration for testing, then a sandbox pass on a real device
- App Store Connect: the non-consumable, the scheduled launch price, Family Sharing

The privacy manifest does not change, and must not: a purchase is data Apple handles,
not Strata. The privacy policy gains one paragraph saying exactly that.

## Before charging anybody

Two things are not about money and both block it:

1. **There is no automatic backup and no sync.** Everything lives on one phone.
   Charging turns "I lost my wins" into "I paid for this and lost my wins". Either
   ship an automatic backup (iCloud, or a scheduled export the person can restore
   from) or say plainly, in the app and on the product page, that the record lives on
   this phone only.
2. **`strataapp.co` is dead.** App Store review opens the privacy policy URL. Point it
   at a page that exists, or register the domain and host `docs/privacy.html`.

## What it might make

Solo launches are small. At a 3% conversion on 10,000 lifetime downloads, $9.99 and
Apple's 15%: about $2,500. At 1,000 downloads: about $250. The research file works
through the assumptions. The honest reason to charge is that a paid app is a finished
app, not that it will pay rent.
