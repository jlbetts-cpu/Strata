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

---

## 7. The independent review (2026-10-10, overnight)

I had a second reviewer read every change in this pass, read-only, looking
for crashes, data loss, privacy leaks and logic bugs. It found 15 things.
None were caught by tests, because the simulator has no iCloud account and
the crew cloud code had only ever run against a stand-in. All but the
last group below are fixed; **none of the CloudKit fixes could be run
against real iCloud here either. REVIEW on two phones before friends get
the build**: start a crew, invite, join, post a photo, remove the photo,
leave, end.

### Would have broken crews for real people

- **A starter could not end their own crew, and leaving deleted nothing.**
  iCloud calls the writer of your own records by a placeholder name, not
  your account, and the app compared the two. Fixed: the placeholder is
  read as you.
- **A bad invite link could wipe a crew off your phone.** A link for a crew
  you were already in, with a wrong key after the `#`, replaced your good
  key and emptied the crew. A link never replaces a key that works now.
- **Leaving did not stick with two phones** (or after a failed backup): the
  other phone put the key back and re-joined you. Leaving is written down
  now and beats any older key on any of your phones.
- **A photo you took off a win stayed on the server**, sealed but there.
  Its slot is cleared on the save now.
- **Someone could block being removed** by creating the removal record's
  name first. Removals and renames are written under names nobody can take
  ahead of time.
- **A post could be missed for good** when a phone's clock ran fast or a
  first read was slow: "what changed since" used the phone's clock. It uses
  the server's own time now.
- **A crew or win you had just made could flicker away** for a moment: a
  listing run straight after a save could come back without it. What this
  phone wrote in the last 90 seconds is never dropped.
- **Junk aimed at a crew** (anyone signed in can write under a crew's id,
  though never read it) would have had its files downloaded by everyone.
  Photos are fetched only for records that open with the crew's key.

### The promise "sealed end to end" had a hole

Your crew keys were backed up to your private iCloud **in plain text**,
which Apple can read, next to the sealed posts. The backup is now sealed
with a key that lives only in your iCloud Keychain. A second phone without
iCloud Keychain joins by the invite link instead.

### Elsewhere

- **A photo taken after standing still for 30 seconds lost its place.** My
  own map fix caused it: fixes only arrive when you move 10 metres. A fix
  measured while the camera has been open is current however old it is.
- **Logging a win after 7pm cancelled the crew's later evening moment.**
  The crew's time is decided first now.
- **Two doodle bugs in last night's fix**: a neighbour's doodle could
  vanish when a photo came off, and a strip's very first doodles did not
  follow. Marks parked with a removed photo are kept under that photo's own
  id, never matched back by position.
- **A strip that failed to send into a crew said nothing.** It says why.
- Three places did real work on every redraw (the strip's doodles, the
  crew list's flame, the crew sheet's photo count). Cached or run once.

### Not fixed. REVIEW, your call

- **A removed person keeps the crew's key.** The app stops them, but
  someone technical with the old link could still read the crew, or rejoin
  under a second Apple ID. Closing it means giving the crew a new key when
  anyone is removed and re-sealing what is there: a real piece of work, and
  the usual answer in sealed group chat. I would do it before a public
  launch, not before a friends test.
- **The 8-person limit is only enforced by the app**, for the same reason.
- **Crew keys on the phone sit in the app's shared settings, not the
  Keychain**, so they travel in a device backup. Moving them needs a
  signing change shared with the notification extension.
- **Push did not land.** GitHub was 204 commits behind when I checked at
  00:15, so `docs/join.html` is not published and invite links open a
  missing page until `git push origin main` succeeds.

### The fixes, checked again (same night)

A second reviewer read only the fix commit, assuming each fix was wrong. It
confirmed six of ten and found the other four incomplete, plus one new bug
of mine. All fixed:

- **Leaving, properly this time.** The first fix only worked between
  phones sharing an iCloud Keychain. Leaving now also leaves one small
  sealed note in the crew itself ("this account left, at this time"), which
  your other phone reads and obeys; joining again by a link removes it.
  And a rejoin on one phone now reaches the other, instead of the two
  undoing each other for ever.
- **The crew's "ended" mark could be deleted** by the starter's own second
  phone while tidying up, so members who had not looked yet never saw the
  end. Tidying never deletes the crew's own record now.
- **A photo could be pinned to where the phone was hours ago**, after the
  app sat in the background. That was my standing-still fix from an hour
  earlier. A place is only "current" for fixes since the app last came
  forward, and coming forward asks for a fresh one.
- **A post whose photo failed to download could be skipped for good.**
  "Since" never moves past one that did not arrive.
- **A sealed backup could lock itself** if a phone made its own sealing key
  before the real one arrived. Reading never makes a key now, and a backup
  nobody has been able to open for a week is replaced.
- A dev phone's cache from before these fixes is read again whole, so the
  starter of an existing test crew can end it.
- A quiet crew no longer makes every refresh re-read a busy one.
- A removed photo is certain to leave the server: the record is deleted and
  written again, rather than trusting a blank to clear it.

### A test that failed on weekends

`testAPlanLineOpensTheAddSheetPrefilled` pressed a seeded plan line that
repeats on weekdays only, so it failed every Saturday and Sunday with "the
plan did not open" about a plan that had opened. It presses a plain line
now. Nothing to do with this pass; found because the suite ran after
midnight on a Saturday.

### A third read, and a simpler rule (01:40)

The third reviewer found the leave-and-rejoin fixes still had gaps: each
compared a time kept on one phone with a time written by another, and every
moment in between (a join still in flight, a clean-up that failed, a phone
that had not looked yet) let one phone undo the other. Three rounds of
patches on one mechanism is a sign the mechanism is wrong, so I changed the
rule instead of patching it again:

**You have left a crew when your note that you left is newer than your
member record, by the server's own clock, or you have no member record.**
Joining again writes a new member record, so an old note means nothing on
any phone, and no phone's clock is involved. A join also marks the notes
it found as answered, so the seconds before the member record is written
are safe.

Also from that read:

- **Opening a link at the five-crew cap could empty you out of that crew
  on your other phone**, and delete the crew if you started it, because
  "turn this join away" used the same code as "leave". It has its own,
  which touches nothing.
- **Taking a crew's picture off could delete the crew for everyone** if
  the save right after failed (my "delete it first" fix from the round
  before). The record is fetched and its file blanked instead; nothing is
  ever deleted first.
- A join by link no longer fails the first time with "this crew has
  ended" when a key sync happens to run during it.
- One evening cue a day is counted, so a crew moment before 7pm is never
  followed by a second cue at 7.
- A member record is never written into a crew you have left.
