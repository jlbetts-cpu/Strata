# Unification pass: decision log

Started 2026-10-09. The running record of what changed, why, and what you
should look at. Newest decisions at the bottom of each section. Anything
marked **REVIEW** is a call I made that you may want to undo.

---

## 1. Crew data out of personal iCloud

### What I found (the audit)

Every crew lived in the **crew starter's own iCloud**. When you start a
crew, the app makes a private "zone" (a folder) in *your* iCloud and shares
it with friends through Apple's iCloud sharing. Everything anyone posts in
that crew, wins, photos, chat lines, drawings, reactions, heads, is written
into that folder, so **it all counts against the starter's iCloud storage**.

- Your phone: iCloud is full, so CloudKit refuses the share itself
  ("Quota exceeded") and no crew can start. That is the error you saw.
- Worse, a friend joining your crew writes *their* member record into
  *your* storage, and so does every photo they post. One full iCloud can
  silently stop a whole crew.
- Your own tower (your wins, your journal, your photos) is separate: it is
  SwiftData mirrored to your private iCloud. That stays exactly as it is.

What already lived in the **public** database (the app's own storage, not
anyone's iCloud): pings for notifications, reports, bans.

### Why the public database, explained plainly

CloudKit gives every app three databases:

- **Private**: yours alone, counts against your iCloud storage.
- **Shared**: a view of someone else's private folder they shared with you.
  Still counts against *their* storage. This is what crews used.
- **Public**: the app's own storage, paid by Apple's allowance to the app
  (it grows with the number of users), counting against **nobody's**
  iCloud. Anyone signed in to iCloud can write to it through the app.

Moving shared crew data to public means a full iCloud can never break a
crew again, for the starter or for anyone in it.

### The catch, and how I handled it: privacy

The public database has no "only these people may read" setting. Its
permission model is three fixed roles:

| Role | Who | What they may do |
|---|---|---|
| `_world` | anyone using the app | read |
| `_icloud` | anyone signed in to iCloud | create records |
| `_creator` | the person who made a record | change or delete it |

There is no per-crew access list (custom roles exist but are assigned by
hand in the CloudKit Console, one person at a time, so they cannot model
"the 6 people in Ana's crew"). So if crew posts sat there in plain text,
any app user who learned a crew's ID could read them. Your crews screen
promises "Private. Only people you invite can see it.", and the privacy
policy says the same.

**So every crew is end-to-end encrypted.** When a crew starts, the phone
makes a secret key (AES-256, Apple's CryptoKit). Everything people post,
names, win titles, chat lines, photos, heads, drawings, is locked with that
key *on the phone* before it is uploaded. The key travels only inside the
invite link, after the `#`, the part of a web address that browsers never
send to a server. The public database only ever holds sealed boxes and the
crew's random ID. Even someone reading the raw database sees nothing.

### How it is stored (schema)

One record type, `CrewItem`, in the public database's default zone:

| Field | Type | Index | What it holds |
|---|---|---|---|
| `crew` | String | queryable | the crew's random ID (`crew-<uuid>`) |
| `kind` | String | queryable | crew, member, win, reaction, message, removal |
| `box` | Bytes | | every other field, sealed with the crew key |
| `a`, `b` | Asset | | photos, heads, drawings, each sealed |
| (system) modified time | | queryable, sortable | for "what changed since" |

Permissions: read `_world`, create `_icloud`, write `_creator`. That last
one matters: **only the person who posted something can change or delete
it**, enforced by Apple's servers, not by the app.

### Record zones, and what changes because of them

The public database has one zone and no change feed, so:

- **Syncing** asks "every crew item for my crews changed since I last
  looked" (one query covers all your crews), plus an occasional full list
  to notice deletions. The crew on screen asks for just its own changes
  every few seconds, as before.
- **Ending a crew**: the starter marks the crew record ended; every phone
  sees it, forgets the crew and deletes its own posts. (Before, deleting
  the starter's zone deleted everything at once.)
- **Removing someone**: the starter posts a removal; every phone hides that
  person, and their phone forgets the crew.
- **Renaming / changing the crew photo**: still anyone in the crew (your
  2026-10-02 call). The crew record is the starter's and only they can
  change it, so a member's rename is saved as their own small "edit"
  record and every phone shows the newest edit. Nothing changes for you.
- **Invites** are now a link the app makes itself
  (`https://jlbetts-cpu.github.io/Strata/join.html#...`), not Apple's
  iCloud share sheet. The page opens the app (`somewins://`), or points to
  the App Store if it is not installed. **REVIEW**: needs `docs/join.html`
  pushed to GitHub Pages; a proper universal link needs a domain you own.
- **A second phone of yours** gets your crew keys through a tiny private
  record (a few hundred bytes each). If that iCloud is full, the keys stay
  on the first phone and the second phone re-joins by the link.

### What you have to do (I cannot)

1. **CloudKit Console → Deploy Schema Changes.** `CrewItem` (and the tiny
   private `CrewKeys`) are already in Development (imported with `cktool`,
   validated first; the file is `tools/cloudkit/full-schema.ckdb`). Until you
   deploy, TestFlight and App Store builds cannot save a crew. The same
   click also deploys the win-sync types once you have run the schema step
   on your phone.
2. **Push** (it also publishes `docs/join.html`).

### Old crews

Test crews made before this live in the old shared zones. The new build
starts crews fresh and, once, **deletes the old crew zones from the
starter's iCloud** so the space they used comes back. **REVIEW**: test
crews from builds up to 113 do not carry over; everyone re-creates them.

### Done (2026-10-09)

- `PublicCrewCloud` replaces the zone-and-share cloud behind the same
  `CrewCloud` protocol, so no screen and none of `SocialStore`'s rules
  changed. The old class is deleted.
- `CrewKey` / `CrewKeyRing` / `CrewItemRecord` live in `NotifyShared` so the
  notification extension opens a friend's win to name it on the lock screen.
- Invites are rich links (crew name and your tower as the preview) through
  the system share sheet; `docs/join.html` opens the app.
- One silent-push subscription for your crews' items replaces the old pair
  on the private and shared databases (which also fired on every change to
  your own wins).
- Tests: sealing (wrong key, wrong record and tampering all refuse), links
  (round trip; junk refused), boxes with photos, the extension's reader.
  1,304 unit tests pass.
- Not testable here: real CloudKit traffic (the simulator has no iCloud
  account). Verified by the fake cloud for every `SocialStore` rule, and by
  reading. **REVIEW on device**: start a crew, invite, join, post, end.
