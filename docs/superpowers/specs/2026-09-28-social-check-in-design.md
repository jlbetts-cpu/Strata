# Checking in on friends

**Status:** design, approved in chat 2026-09-28. Not built. **Superseded 2026-10-02** by [Crews](2026-10-02-crews-design.md): friends now share a tower, titles and photos, by the owner's choice. Kept for its reasoning.
**Owner's calls, in his words:** "a simple number would actually be better, I
don't know if we really need the tower to be shown", shapes only and no photos,
invite link only, build it now and ship it behind a flag.

---

## 1. What this is

You can see, at a glance, whether the people you care about had a day that went
well. That is the whole feature.

A friend appears on the Wins page as their head with a number beside it. The
number is how many wins they logged today. Tapping the head nudges them. There
is no feed, no stream, no scroll, and nothing to catch up on.

**What it is not.** Not a social network. Not a feed. No likes, no comments, no
replies, no follower counts, no discovery, no strangers. Every one of those was
considered and cut: they are the features that turn a private record into a
performance, and this app's whole claim is that it is the place where the things
you did count, not the things you showed people.

## 2. The one number, and why it is only a number

**A date and an integer. That is the entire payload.** (There is a third field,
`updatedAt`, which is a timestamp on the record rather than anything about you;
see 3.4.)

Not the blocks, not their sizes, not the category colours, not a title, not a
photograph, not a place, not a habit name, not a time of day.

This started as the tower's shapes and colours and the owner cut it down
himself. He was right twice over:

- **Nothing private can leak through a payload that never carried it.** There is
  no code path where a title or a photograph could reach a friend by accident,
  because neither is ever copied into the record. Privacy by construction beats
  privacy by a flag somebody has to remember to check.
- **Nothing objectionable can be in an integer.** App Review guideline 1.2 puts
  real obligations on apps that carry user generated content: a method for
  filtering objectionable material, a mechanism to report it, the ability to
  block abusive users, and published contact information. A count has nothing to
  filter and nothing to report. The blocking obligation is still met, and
  trivially: see section 7.

The one piece of free text anywhere near this is a person's display NAME, and
that does not come from a text field either. It is the name CloudKit gives for
the share participant, which comes from their Apple ID. Nobody types anything.

## 3. Architecture

### 3.1 It is not SwiftData, and that is deliberate

**SwiftData has no sharing API.** `CKShare` belongs to
`NSPersistentCloudKitContainer`; `ModelConfiguration` exposes
`cloudKitDatabase` and nothing about sharing. So the shared data cannot be
`Habit` and `HabitLog` rows without replacing the store — which is the store
that was stabilised the same week its owner lost everything on a reinstall, and
is not something to rewrite for a friend counter.

**FIRST TASK OF THE BUILD IS TO VERIFY THIS.** It is the assumption the whole
design rests on. A one-afternoon spike: try to obtain a `CKShare` for a SwiftData
backed store on the current SDK. If it turns out to be possible, come back to
this document before using it, because section 3.2 is still probably the better
design and would need to lose an argument, not a fact.

### 3.2 A separate, derived layer

`SocialStore` is a new service beside SwiftData, not inside it. It talks to
CloudKit directly through `CKContainer`, `CKRecord` and `CKShare`.

Its contract is narrow enough to state in one line: **it reads a count and
writes a count.** It has no reference to `ModelContext`, cannot fetch a `Habit`
or a `HabitLog`, and cannot be made to by a later edit without that edit being
obvious in review.

```
SwiftData (private, on device + private CloudKit DB)
    Habit, HabitLog, MoodLog, Tower ........... untouched by any of this
            |
            | countOfWinsToday() -> Int          (the only thing read)
            v
SocialStore (CloudKit, custom zones)
    DayCount  { day: Date, count: Int }
    Nudge     { sentAt: Date }
```

### 3.3 One zone per friendship, not one zone for everyone

Each friendship gets its own custom `CKRecordZone`, shared with exactly one
person by one `CKShare`.

The obvious design is one zone shared with everybody, and it has a leak: a
`Nudge` addressed to friend B sits in a zone friend C can also read, so C learns
that you nudged B. Per friendship zones have no cross visibility at all, and
they make removal trivial — deleting the zone ends the friendship completely, on
both sides, with no server to ask.

The cost is that your count is written once per friend rather than once. At the
size this is for, which is a circle and not an audience, that is a handful of
small writes a day. **The friend cap is 12**, which is the same number the
Apollo notes settled on for private circles and is a product decision, not a
technical limit: past a dozen people a glance stops being a glance. It is
enforced in `SocialStore` at the point an invitation is created, not in the view,
so it cannot be walked around by accepting a link from the other side.

### 3.4 Records

**`DayCount`** — one per day, in each friendship zone.
`day` (Date, midnight local), `count` (Int64), `updatedAt` (Date).
Written when a win is logged and when the app comes to the foreground on a new
day. Records older than 30 days are deleted on write, so the zone stays small
and there is no history to mine.

**`Nudge`** — written into the sender's own share of the friendship zone.
`sentAt` (Date). Nothing else. There is no recipient field because the zone has
exactly one other person in it.

### 3.5 Invitation

A `CKShare` with `publicPermission = .none`, handed to the system share sheet as
a URL. The recipient taps it, iOS opens the app with the share metadata, and the
app accepts it.

**There is no directory, no search, no username and no contacts access.** Nobody
can find you. A link is the only way in, and it is a link you sent.

### 3.6 Nudges arrive on next open, not as a push

A nudge that arrives while the app is closed needs a CloudKit subscription
delivering a background push, which needs the Push Notifications capability.
That capability is deliberately absent: these entitlements have failed
provisioning before, and the account is under extended review.

So v1 fetches on foreground. A nudge waits until you open the app. This is a
real cost and it is accepted rather than hidden: a nudge is an affectionate
prod, not an alert, and one that waits is still one. Push is roughly two lines
plus a capability when the account is calm.

## 4. Where it lives on screen

**Wins.** A quiet row under the header, above the tower: each friend's head, a
number beside it. Heads are already built, the roster already holds more than
one, and the owner asked for friends' heads by name in September. A friend who
has not made a head gets their initial in the same circle.

**Memories.** The same row, reading the week instead of the day, beside the map
and the replays where a week already is the subject.

**Camera.** Nothing. This is worth stating because the owner originally asked
for a per-win privacy control there, and a count makes it unnecessary: there is
no per-win decision to make when no win is ever shared. One fewer control on the
screen that has to stay fastest.

## 5. Behind a flag

Everything ships switched off, behind a single boolean, until the account is
clear of 4.1(a) and 1.0 is on the store. With the flag off there is no row, no
network call, no zone, and no entitlement in use beyond the iCloud one already
there.

## 6. Do we need a signup?

**No, and adding one would make the app worse.**

CloudKit gives identity from the Apple ID already signed in on the phone. That
means no password, no email verification, no password reset, no session tokens,
no server to hold any of it, and no breach to have.

It also avoids obligations that arrive with an account and never leave:

- Offering any third party login makes **Sign in with Apple** mandatory.
- An account means guideline **5.1.1(v)**: account deletion from inside the app,
  not by email, not by a web form.
- An account means storing credentials, which means a breach is possible, which
  means breach notification duties under state law.

A friendship here is a CloudKit share. Leaving is deleting a zone.

## 7. Legal, and what has to change before this ships

### 7.1 Blocking and removal — guideline 1.2

Met by the design rather than bolted on. Removing a friend deletes the
friendship zone: they stop seeing your number immediately, you stop seeing
theirs, and they cannot re-add you without a new link from you. That is
blocking, un-invitation and data deletion in one action, with no server to trust
and no request to process.

Reporting has nothing to point at, because the only content is an integer and a
name from an Apple ID. The Contact section of the privacy policy is the
published contact address guideline 1.2 asks for; confirm it is current.

### 7.2 The privacy policy — `docs/privacy.html`

Today the policy says data stays on the device, and its Sharing section is about
the iOS share sheet. Both become untrue the moment this ships. It needs:

- A new section saying plainly **what a friend can see: the number of wins you
  logged that day, and nothing else.** Naming the things they cannot see is
  worth the words: not your photographs, not what any win was, not where you
  were, not when.
- That a friendship is created by a link you send and ended by either person.
- That the data travels through **your own iCloud account**, under Apple's
  terms, and that there is no Strata server.
- That deleting the friendship deletes the shared data.

### 7.3 The privacy manifest — `Strata/PrivacyInfo.xcprivacy`

It currently declares `NSPrivacyTracking: false` and **no collected data types
at all**, which is accurate today and will not be. Adding, as Linked to the user
and Not used for tracking:

- **User ID** — the CloudKit participant identity.
- **Other Usage Data** — the daily count.

`NSPrivacyTracking` stays `false`. Nothing here is tracking.

### 7.4 App Store privacy answers

The App Privacy section in App Store Connect has to match the manifest. **Its
current state was not verified while writing this** — the App Store Connect API
exposes no endpoint for it, so it has to be read in the web UI. Read it, then
make it agree with 7.3. A manifest and an App Privacy answer that disagree is
its own rejection.

### 7.5 Children

The policy has a Children section already. A feature where people connect to
each other should be read against it before shipping, even one this narrow.

## 8. Testing

`SocialStore` is the unit, and it is testable because it is isolated.

- **The payload cannot widen.** A test that asserts a `DayCount` record's keys
  are exactly `day`, `count`, `updatedAt`. It fails the day somebody adds a
  title "just for the tooltip", which is the failure this whole design exists to
  prevent.
- **The count is the count.** Logging n wins produces n, across a day boundary,
  across time zones (`timeZoneIdentifier` is already on the model for this).
- **Pruning.** Records older than 30 days go, and nothing newer does.
- **Removal is complete.** After removing a friend, the zone is gone and a fetch
  returns nothing rather than stale numbers.
- **Nudge rate limiting.** One per friend per day; the second is refused
  locally, without a round trip.
- **The flag.** With social off, no CloudKit call is made at all. Asserted by a
  fake container that fails the test if it is touched.
- **No SwiftData reach.** `SocialStore` has no `ModelContext` in its interface.
  Pinned by a test that constructs it with nothing else.

Anything needing two real iCloud accounts is manual, and listed as such: the
invite round trip, and a nudge crossing between devices.

## 9. Explicitly out of scope

Photographs. Titles. Block shapes and colours. A feed. Likes, comments and
replies. Reactions. Group chat. Streaks between friends. Leaderboards. Public
profiles. Usernames. Contacts matching. Discovery of any kind. Push delivery
(v2). Anything that makes the number into a competition.

## 10. Order of work

1. Spike: confirm SwiftData cannot share, so section 3.1 rests on a fact.
2. `SocialStore` with a fake CloudKit container, and its tests. No UI.
3. The zone and share lifecycle: create, invite, accept, remove.
4. The Wins row, behind the flag.
5. Nudges.
6. The Memories row.
7. Privacy policy, privacy manifest and App Store privacy answers together, in
   one pass, before the flag is ever turned on.
