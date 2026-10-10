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

---

## 2. Memories as the hub: the month's albums

**Where they live.** Your Memories first screen is exactly as you left it
(drawing, calendar, the photo count peeking under the tab bar). The albums
sit one scroll down, between the photo count and the photographs, in one
row: albums are made of photographs, so they belong to that section. Like
everything on the page, they are for the month the picker names.

**What the app makes, by itself:**

- **With [crew]**: your own photographed wins you sent to that crew that
  month (three or more). Your own only: a friend's photo leaves the crew
  after two weeks and is not kept on your phone either.
- **What you kept doing**: a title photographed on two or more days that
  month (three or more photos), e.g. "Gym".
- **Moments** ("A year ago today", "This week last year"), on the current
  month only.
- At most five cards; no row at all when nothing qualifies.

**Left out on purpose.** "Last month" as a moment card: the picker one step
back is already that, and it is the duplication you cut from the old shelf.
A "Yesterday" card: the hand-off (section 3) already carries yesterday into
the calendar. Recaps already have their play button.

**REVIEW**: whether a lone card (one crew album) earns the row, or the row
should wait for two.

---

## 3. Wins flows into Memories

**What you see.** The first time you open Wins on a new day, if yesterday
had wins, yesterday's tower is standing where you left it when the logo
lifts. It holds for a breath, then shrinks and glides into the Memories tab
(a light tap as it lands), and today's empty ground fades in behind it. The
next time you open Memories, yesterday's day grows into its calendar square,
once. No words, no badge, no count: the motion is the message.

- Never after a day with no wins. Nothing is said about a quiet day.
- Not if you already logged today (from the widget, say): it would land on
  top of today's blocks.
- Reduce Motion: a plain fade, and the calendar square is simply there.
- Real blocks, drawn by the same code as Memories, so what leaves is exactly
  what you built.

**Fixed on the way.**

- **A tower left open across midnight kept showing yesterday as today.**
  Nothing watched the date. It now refreshes at midnight and on every
  return to the app, and the hand-off plays then.
- **"Tap the slot to log your first win."** was said every morning to
  people with months of wins. Now "Tap the slot to log today's first win."
  **REVIEW**: one word of copy.

**Looked at, not counted.** Recorded on the simulator frame by frame. The
first version showed today's empty slot for a second and then dropped
yesterday's tower on top of it; it is now decided under the launch logo, so
there is no flash.

---

## 4a. The confetti on the first win

**Root cause, not the symptom.** The goal check itself was right (it waits
for today's blocks to reach the goal you set). A second celebration sat in
the same landing code: a leftover "perfect day" dance and confetti from the
old scheduled-habits model. A day counted as perfect when its completed
wins matched the wins *scheduled* for it, and under today's model every win
you log is its own one-off scheduled for today, so any day with one win was
"perfect". Your first win fired it.

Removed entirely, with the dead "patina" it also fed (it only ever applied to
week and month tower views that no longer exist). A test now holds the dance
and the confetti to exactly one trigger, the goal. 1,305 tests pass.

---

## 4b. The goal strip, into your crew and out to Instagram

**Out** already worked: the strip's Share opens the system share sheet,
which is where Instagram, Messages and the rest live.

**Into a crew**, without a new button: each crew you are in now appears
in that same share sheet, next to the apps, with the crew's photo. Tap
"Roommates" and the strip lands in that crew's chat as the picture itself
(no speech bubble), under your name. Like every chat line it is gone at the
crew's midnight, and it passes the same photo check a doodle does.

- Only your own strip offers your crews; a crew's strip is already theirs.
- No CloudKit schema change: it rides the chat's existing record with an
  invisible marker, as tosses do, so nothing extra to deploy.
- **REVIEW**: a direct "Instagram Stories" button would need a Meta app ID
  you do not have; the share sheet's Instagram entry covers it.

---

## 5. Retention, minimal and warm

**(b) The crew streak is forgiving now.** A day counted only when
*everyone* posted, so one person's quiet day was the whole crew's loss, and
bigger crews almost never kept a day. Now **half the crew keeps the day**
(at least two; a crew of two still needs both). The two free days a week
the crew already had stay, and a break is silent: the Best number is kept.
The line under the streak says "Today counts. Nice work, crew." when
enough are in, and still never names who has not posted.

**(c) The flame.** Each crew in the list shows a small flame and its
streak after the name, quiet ink, only from 3 days on. **REVIEW**: on
2026-10-02 you had the win count removed from the end of these rows; this
is different (the crew's streak, tiny, beside the name), but it is a number
back on the row.

**(a) The crew's evening.** The app's rule is one cue a day, so this is not
an extra notification: for someone in a crew, the existing evening
check-in ("Anything else today?", only on days with a win but under your
goal) now fires at **the same minute on every phone in the crew**, worked
out from the crew and the day (somewhere between 7:00 and 8:55pm, a
different moment each evening), with "Roommates is sharing tonight's wins."
under it. No server: every phone computes the same time. A friend abroad,
where that lands outside 5 to 10pm, keeps their own 7pm.

**REVIEW**: days with no win at all still get only the morning reminder,
not a crew nudge, to keep one cue a day. If you would rather the crew
evening be the cue on empty days too, that is a one-line change.

### Added 2026-10-10

- **Milestones and fresh starts.** On a 7, 14, 21, 30, 50, 75, 100...
  day the line under the crew streak reads "Look what your crew is
  building. 14 days." After a run ends it reads "Starting fresh. Your best
  is still 21." (only once the best was a week or more). Nothing is sent as
  a notification; it is there when you open the crew.

---

## 2b. The crew's sheet points at Memories

The crew's top-middle pill opens its sheet, where "Recent Days" says wins
stay for two weeks. Nothing there said what is kept. A last row in that
list now reads **"Kept in Memories, 5 of your photos"** and opens the same
crew album Memories shows, all months. The crew forgets; Memories keeps;
one row says so. Your own photos only, as you chose on 2026-10-09.

---

## 4c. Doodles and stickers stay on their photo

You asked: "where you draw or paste is where it should go." A strip's
doodles were one picture laid over the paper from the top, and the paper
moves: a photo logged later joins, a second Quick pairs with a lone one
and turns a wide row into two squares, a frame is taken off in the editor.
The doodle stayed put and ended up over a different photo.

Now every stroke and sticker belongs to what it was drawn on. On a photo,
it moves and scales with that photo. On the wordmark's foot, it moves with
the foot. Take a photo off and its doodles go with it, and come back if
you put it back.

- Checked by drawing a ring on a wide photo, adding a photo so it became
  half of a pair, and looking at both renders: the ring followed its photo.
- **REVIEW**: strips doodled before this build only start following from
  their next save, because the old files never recorded what was under
  each mark. I have not seen it in the live editor with a finger, only in
  renders and tests; worth one try on your phone.

---

## 6. Bugs and code health (first round)

### The onboarding face screen crash

No crash log was available here, so this was found by reading the code
(**REVIEW**: if you can, pull the tester's crash from Xcode Organizer >
Crashes to confirm). The likeliest cause, now fixed:

- **The camera raced itself.** Starting the camera ran on its own thread
  while the head maker, at the same instant, switched to the front lens and
  added its face-frame output on the main thread. If "start" landed in the
  middle of that switch, AVFoundation throws and the app dies. Only a real
  phone gets there (the simulator has no camera), which is why it showed up
  with a tester. Now: configure first, start last, and every later change
  waits for the camera to finish starting or stopping.
- **A data race on the frame callback** when closing the maker while frames
  still arrived. Set once now, never cleared.
- **A memory spike** making six faces at full resolution, each with its own
  image engine, while the camera ran (iOS ends apps for this, and a tester
  sees it as a crash). One shared engine, memory released per face.
- **Not a crash, but looks like one:** turning the camera on in Settings
  makes iOS end the app, and onboarding restarted at the film. It now
  resumes on the page you were on.

### The map

All fixed at the cause, with tests:

1. Replacing a photo with one that has no location kept the old photo's
   place, so the new photo stood where the old one was taken.
2. Camera pins came from a 100m fix up to two minutes old: now 10m while the
   camera is open, and no older than 30 seconds.
3. A normal Wi-Fi fix (65m) vanished from its block as you zoomed in.
4. Editing a win's photo or place did not refresh the map.
5. The map assumed every phone is 393pt wide and allowed tilting, which
   skewed the scale and merged blocks across town. Measured now; pan and
   zoom only.
6. A walk of photos chained into one spot drifting along the route.

### Removed (dead code)

- The "perfect day" celebration and patina (see 4a).
- The zone-and-share crew cloud and its push routing (see 1).
- The two onboarding pages you asked out (yesterday).
