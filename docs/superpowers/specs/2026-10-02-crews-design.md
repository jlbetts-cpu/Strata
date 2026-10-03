# Crews

**Status:** built 2026-10-02, behind `CrewsFlag` (off). Two departures from
the design below, both deliberate:

- **Inviting** (2.3) is the system share sheet registered as a CloudKit
  collaboration (`CrewSharing`), not a contact picker plus a message composer.
  It puts the people you message most first, and Messages carries the
  invitation as a bubble that joins in one tap. Members are administrators on
  iOS 26 (`allowsParticipantsToInviteOthers`), so anyone can invite.
- **Notifications** (5) are a silent CloudKit push that wakes the app, which
  writes the notification itself (`CrewNotifications`). A service extension
  would need a second app ID with the iCloud container assigned in the
  developer portal. The cost: a phone where Sturdy was swiped away gets its
  crew notifications when it next opens. Hide Alerts drops them entirely,
  which the extension design could not.

Before the flag can be on: the Push Notifications, Sensitive Content Analysis
and Declared Age Range capabilities on the app ID, their entitlements, and a
new App Store profile; the `Report` record type's permissions in the CloudKit
dashboard; the App Store Connect answers in `docs/crews-app-store-privacy.md`.

**Supersedes** the sharing model of `2026-09-28-social-check-in-design.md`
(count only, no tower). Shown that spec, the owner said "i like our idea
better". What carries over from it is listed in section 4.

**The owner's calls, 2026-10-02, in his words and answers:**

- "a simple social button on the top left ... when you click into a group it
  shows the shared tower"
- "notifications work just the same as on imessages": every win, like Messages
- "up to 8 people": 8 including you
- "you can change the chat name the profile pic": anyone in the crew can rename
  it, change its photo and invite; only the person who started it removes people
- "use as many native elements as possible and feel native and easy to use"
- "invite people from your contacts"
- "all of the peoples heads should bounce around and you can individually put
  them into the top bubble ... it should actually look like they are cramped in
  there"
- Age: 13+ with limits. Friends' heads: fully alive.

Earlier in the day (the brief, `~/Downloads/crews-agent-prompt.md`), still in
force where the message above does not override it: your own tower never
changes; a crew tower is today's, closing at the crew owner's midnight;
checkboxes on posting, sticky; no category routing; no ownership marks on a
block's face; no feeds, likes, comments, leaderboards, streak comparisons,
discovery, usernames or place data.

---

## 1. What a crew is

A crew is up to **8 people, you included**, who share a tower for the day.
You can be in up to **5 crews**. A crew is standing: invite once, and a fresh
crew tower opens every day at the crew owner's midnight.

Your own tower is home. The Wins tab always opens on it, every win you log
lands in it, and nothing a crew does ever adds to it, takes from it or changes
its count, streaks, Memories, Replays, widget or backup.

---

## 2. Screens

Every screen is built from system parts first: `NavigationStack` pushes,
`List` with `.insetGrouped` where Messages and Contacts use it, the system
contact picker, the system share and message sheets, `.toolbar` items with
Liquid Glass. Strata's own type, ink and blocks dress them.

### 2.1 The button

A `GlassIconButton` with `person.2` in the **top left of the Wins header**.
This rewrites the LOCKED row that kept that corner empty for a logo
(`docs/design.md`, updated with this spec). With the flag off the corner stays
empty.

A small ink dot sits on its shoulder when a crew has a win you have not seen,
the way Messages marks an unread thread. No number.

### 2.2 Crews (the list)

Pushed, large title **Crews**, like the Messages list:

- A row: the crew's picture (its photo, or the members' faces clustered the
  way Messages clusters a group), the crew name in title weight, beneath it
  the latest win as "Sam: Gym" or "Sam added a photo", the time on the right,
  a chevron, and the unread dot on the left.
- Swipe a row for **Hide Alerts** and **Leave**.
- Bottom right, the compose button (`square.and.pencil`) in glass, as in
  Messages: **New Crew**.
- Empty: one line and the compose button. "Start a crew. Just the people you'd
  tell anyway."

### 2.3 New Crew

A sheet. Name field (optional; an unnamed crew is called by its members' first
names, "Sam, Ana and Leo", as Messages does), then **Add People**:

- The system contact picker (`CNContactPickerViewController`), multi-select.
  No Contacts permission is asked for and nothing is uploaded: the picker hands
  back only the people chosen.
- **Invite** creates the crew and opens the system message composer
  (`MFMessageComposeViewController`) to those people with the invite link
  (the crew's `CKShare` URL) and one line: "Join my crew on Sturdy".
- Where Messages is unavailable, the system share sheet with the same link.

Caps are checked in the store before the link exists: 8 members, 5 crews.

### 2.4 The crew tower

Pushed from the list.

- **Top middle**, exactly where Messages puts a group: the members' faces
  clustered in one glass circle, the crew name below with a ›. Back on the
  left. Tap the faces or the name for Crew Info.
- **Below**, today's crew tower: every member's wins from the crew day, drawn
  by the same block, the same lattice and the same drop as your own tower.
  A friend's win falls in live while you watch. Every tenth win the tower
  dances, as yours does. Nothing else celebrates.
- **Heads**: section 3.
- Same-colour runs **do not merge** in a crew tower: two touching blocks are
  two people's wins. (The month tower's reasoning.)
- A block's face carries no owner mark. Its **back** names who logged it,
  "Sam's win", and holds **Report** and, for your own block, nothing new.
- A crew with no wins yet today: the empty lattice and the heads. No sentence.

### 2.5 Crew Info

A sheet, laid out like a Messages group's details:

- The crew photo, large, with **Edit** under it: choose a photo, or go back to
  the members' faces. Anyone can change it.
- The name, editable inline. Anyone can change it.
- Members, one row each: head (or initial in a circle), name. Swipe to remove,
  shown only to the person who started the crew. **Block** on any row but your
  own.
- **Add People** (anyone, while under 8).
- **Hide Alerts** toggle.
- **Leave Crew** in red, at the bottom, with a confirmation. For the person who
  started it the same row reads **End Crew** and ends it for everyone.

### 2.6 Posting

One checkbox per crew, preset to whatever you chose last time:

- In Add Win, a row under the title.
- On the camera's review screen beside Use Photo.
- On a block's Edit screen, so a win can be added to or pulled back from a
  crew later. Unchecking withdraws it.

A one-tap win uses the last choice with no step. All unchecked: yours alone.
No "share with?" prompt, ever. From 13 to 15 (section 9.1) the camera row reads
"Photos stay with you" and only the title and shape are sent.

---

## 3. Heads in a crew

Everyone in the crew who has a head has it in the crew tower, alive: blinking,
playing faces, bouncing on the blocks, carried by a finger, exactly as yours
does on the Wins tab. A member with no head appears only in the top cluster,
as an initial.

### 3.1 The cramped bubble

The top-middle cluster is the crew's bubble. Drag any head to it and the
cluster opens a little to catch it (the over-swell your bubble already has);
let go and the head flies in and **squeezes in beside whoever is already
there**: heads overlap, each squashed a touch toward the others, the cluster
growing only slightly, so four or five in there look crammed. Tap a face in
the cluster to pop that one out (the existing pop and droplets). Parking is
yours alone: it is how the tower looks on your phone, not anyone else's.

### 3.2 What changes in code

Today the head system is built for one head (`CompanionParking.shared`, one
sim, one rig from `HeadStore.shared.headForTower`). A crew needs:

- an arena that owns **N sims** with their own seeds, one frame clock for all
  of them, and soft head-to-head collision;
- parking keyed per member (a set of parked member ids, per crew), not one Bool;
- a cluster view that packs 1 to 8 faces into one circle with overlap and
  squash, the same glass and the same pop;
- the Wins tab keeping its one head and its one bubble, unchanged.

The single-head code is generalised, not forked: the Wins tab becomes the
arena with one member.

### 3.3 Sending a head

A **compact rig**: the head's expressions at 256px with their shut-eye frames
and the manifest, about 150 KB, uploaded once to the crew as a `CKAsset` on
your Member record and replaced when you change heads. Friends cache it under
`Application Support/CrewHeads/<crew>/<member>/` and load it with the existing
`HeadStore.read(from:)` / `rig(from:)`. Under 13 there are no crews; 13 to 15
heads are sent (a head is a drawing of your face you chose to make; the
research doc's 4.1 call).

### 3.4 Performance

Eight `LivingHeadView`s is the risk. Budget: no hitch over 2 frames at 60 Hz
with 8 heads on an iPhone 12-class device, measured with `-strataPerfProbe`.
If it is over: heads off screen and heads at rest pause their timelines, and
parked heads draw a still frame.

---

## 4. Data

### 4.1 Where it lives

**Not in SwiftData.** The spike (2026-10-02, iOS 26.5 SDK) found no sharing API
in SwiftData: `ModelConfiguration.CloudKitDatabase` is only `.automatic`,
`.none` or `.private(_:)`; the sharing calls exist only on Core Data's
`NSPersistentCloudKitContainer` and take `NSManagedObject`. So:

**`SocialStore`**, a separate layer beside SwiftData, talking to CloudKit
directly (`CKContainer("iCloud.JaydenBetts.Strata")`). Friends' wins are
NEVER `Habit`/`HabitLog` rows. `SocialStore` has no `ModelContext` in its
interface.

- **One custom zone per crew** in the creator's private database, one `CKShare`
  per zone, `publicPermission = .none`. Every member joins as a participant with
  read-write; to let anyone invite (the owner's call) members are made
  administrators where the SDK allows it (verify `CKShare.ParticipantRole`
  `.administrator` in phase 1 of the build; if absent, Add People shows only
  for the creator and the spec is amended).
- Members read the zone through their `sharedCloudDatabase`.
- Ending a crew deletes the zone, for everyone.

### 4.2 Records

**`Crew`** (one per zone): `name`, `photo` (`CKAsset`, 600px, no metadata),
`ownerProfileID`, `timeZoneIdentifier` (the creator's), `createdAt`.

**`Member`** (one per person): `profileID`, `firstName` (what they typed in
Profile; nothing from contacts), `head` (`CKAsset`, the compact rig, optional),
`joinedAt`. Identity is the iCloud account, mapped to `ProfileStore.profileID`.

**`SharedWin`** (one per win per crew):

| Field | Source |
|---|---|
| `winID` | `HabitLog.id` |
| `senderProfileID` | `ProfileStore.profileID` |
| `crewDay` | the crew day, `yyyy-MM-dd`, in the crew's time zone |
| `title` | `Habit.title` (empty stays empty) |
| `colour` | `habit.displayCategory` raw value |
| `icon` | `habit.category` raw value |
| `blockSize` | `Habit.blockSize` |
| `photo` | `CKAsset`, share derivative: 1080px long edge, re-encoded, no EXIF, no GPS |
| `cropX`, `cropY` | `HabitLog.cropPositionX/Y` |
| `createdAt`, `updatedAt` | `HabitLog.createdAt/updatedAt` |

Never in a record: note, caption, place, coordinates, accuracy, habit id, plan
item, mood. A test asserts the key set is exactly this table.

### 4.3 Lifecycle

- **Post** writes one `SharedWin` per checked crew. **Edit** updates every copy
  by `winID`. **Uncheck** deletes that copy. **Delete a win** deletes every
  copy. **Remove a photo** removes the asset from every copy and keeps the win.
- **Leave** deletes your copies and your Member record from that zone.
- **Never `try?`** a CloudKit write or delete. Failures are logged, retried, and
  shown quietly on the block's back: "Not sent to Roommates yet".
- **Offline**: an on-disk outbox (JSON in Application Support, not SwiftData),
  flushed on foreground and on reconnect.
- **Fetching**: on foreground, on opening the list, and every 15 s while a
  crew tower is on screen (`CKFetchRecordZoneChangesOperation` with change
  tokens), plus whenever a push arrives.
- **Retention**: `SharedWin`s older than the crew's previous day plus 2 days
  are pruned by whoever opens the crew next. A crew is a window on now.
- **Sticky choice**: the last set of crew ids, in `UserDefaults`. A crew you
  leave drops out.
- **Caps**: 8 members and 5 crews, enforced in `SocialStore` when an invite is
  made and again when one is accepted, from either side.

### 4.4 Accepting an invite

Strata has no app or scene delegate today. One is added
(`UIApplicationDelegateAdaptor` plus a scene delegate) to receive
`windowScene(_:userDidAcceptCloudKitShareWith:)` and the cold-launch
`cloudKitShareMetadata`, then run `CKAcceptSharesOperation` and push the crew
tower. `CKSharingSupported = YES` goes in Info.plist.

---

## 5. Notifications

Like Messages: a banner for every win, grouped by crew, silenced per crew by
Hide Alerts.

- **Subscriptions**: a `CKDatabaseSubscription` on the shared database (crews
  you joined) and one on the private database (crews you started). Query and
  zone subscriptions do not work on the shared database (SDK headers).
- **Text**: CloudKit cannot fill a database notification with record fields, so
  the push carries `shouldSendMutableContent` and a plain fallback ("New win in
  your crew"), and a **Notification Service Extension** fetches the change and
  rewrites it: title the crew name, body "Sam: Gym" or "Sam added a photo", the
  thread identifier the crew id (that is what groups them), the sender's head
  as the attachment.
- **Hide Alerts**: the extension marks a hidden crew's notification `.passive`
  with no sound, so it lands silently in Notification Center. Fully dropping it
  needs Apple's notification filtering entitlement, which is requested; until it
  is granted, passive is the behaviour.
- **Your own wins** never notify you.
- **Setup**: Push Notifications turned on for the app ID, `aps-environment` in
  the entitlements, the `remote-notification` background mode, a new extension
  target with its own bundle id and App Store profile. All of it is done
  through the App Store Connect API key (`tools/asc_profiles.py`). Permission
  is asked the first time you join or start a crew, never at launch.

---

## 6. Rendering a crew tower

- `TowerViewModel.buildTower` takes `[HabitLog]` and `PlacedBlock` holds
  `habit`/`log` models. The packer only reads id, size, day, order and date.
  The seam: a value type (`TowerEntry`) the packer takes, built from either a
  `HabitLog` or a `SharedWin`; `PlacedBlock` carries `Look` plus optional
  models. `Look` gets a value initialiser. `FlippableBlockView` reads its face
  from `Look` and its back from a small `BlockBack` value, so a friend's block
  needs no model.
- **A separate `TowerViewModel` and `TowerAnimationCoordinator` per crew
  screen.** Running `buildTower` on the live instance for anything else breaks
  the Wins tab (DayAlbumDetailView.swift:12).
- The drop queue, the drop physics, the dance and `AnimatedBlockView` are
  reused unchanged. Any new value a block reacts to (the sender on its back)
  goes into `AnimatedBlockView.==`.
- `MainAppView.body` is at the type-checker's ceiling. The crews button and
  its navigation go in as a `ViewModifier` and the crew screens live in their
  own files.
- Motion through `GridConstants` tokens; haptics through `HapticsEngine`.

---

## 7. Words

No long dash in anything a person reads. Nothing that sounds like watching:
not "see what your friends are doing", "active now", "tracking". The lines:

- "Crews" · "New Crew" · "Start a crew. Just the people you'd tell anyway."
- "Join my crew on Sturdy"
- "Sam: Gym" · "Sam added a photo" · "Sam's win"
- "Not sent to Roommates yet"
- "Hide Alerts" · "Add People" · "Leave Crew" · "End Crew" · "Block" · "Report"
- "Photos stay with you" (13 to 15)

---

## 8. The flag

`CrewsFlag`, off by default, a `UserDefaults` bool with a `-strataCrews 1`
launch argument. Off means: no button, no checkboxes, no subscription, no
network call, no zone. A test fails if the fake container is touched with the
flag off.

---

## 9. Safety, privacy, App Store

Sharing titles and photographs makes Sturdy an app with user-generated content;
guideline 1.2 applies in full. None of this is optional and all of it lands
before the flag can be turned on.

### 9.1 Age (the owner's call: 13+ with limits)

- The app is rated **13+**.
- **Declared Age Range** is asked when you first open Crews. Under 13: Crews
  does not open ("Crews are for 13 and up"). 13 to 15: crews work, photos are
  never sent (the camera row says so), titles and shapes are.
- If the person declines to share an age range, Crews treats them as 13 to 15.

### 9.2 The four 1.2 requirements

- **Filter**: invite only, plus `SensitiveContentAnalysis` on every photo before
  it is posted. Flagged: not uploaded, and the sender is told plainly, "This
  photo stays with you". The win itself still posts.
- **Report**: on the back of any friend's block and on a member row. A
  `Report` record in the public database (crew id, win id, reason; no photo),
  record type permissions set in the CloudKit dashboard so only the developer
  can read them. Owner to set the permissions once (manual step).
- **Block**: one tap on a member row. Their wins, head and name disappear from
  every crew on your phone; they are not told; if you started the crew they are
  also removed.
- **Contact**: a support address in Profile and on the product page.

### 9.3 What the app claims

In one pass before the flag is on: `PrivacyInfo.xcprivacy` declares what now
reaches other people (Name, Photos, Other User Content, User ID, each linked,
not tracking, purpose App Functionality; reports as collected),
`PrivacyPolicyView` and `docs/privacy.html` say what a crew sees, how to
withdraw a win, how to leave, that there is no Sturdy server, and the age
rules; a note for the owner lists the App Store Connect privacy answers that
change. The built Info.plist is checked in both configurations.

---

## 10. Verification

Unit tests, against a fake CloudKit container, no real iCloud:

- `SharedWin` key set is exactly 4.2's table; no place, note or habit id reaches
  a record whatever the win holds.
- The share derivative has no `{GPS}` and no `{Exif}` (read back with
  `CGImageSource`).
- Uncheck withdraws; delete removes every copy; photo removal keeps the win.
- A 9th member and a 6th crew are refused at the store, from either side.
- Crew day uses the crew's time zone across midnight and a DST change.
- Sticky choice persists and drops a crew you left.
- Flag off: the fake container fails the test if touched.
- Your tower's blocks, count, streaks, Memories and widget are unchanged by any
  crew activity.
- 13 to 15: no photo asset in any record.
- Parking: per-member, per-crew; the Wins tab's one head is unchanged
  (existing `CompanionParkingTests` keep passing).
- Notification text built from a record: "Sam: Gym", thread id = crew id,
  passive when hidden.

Simulator, through `DebugHarness` flags in the existing style:
`-strataSeedCrew <n>` (a crew of n with seeded wins and heads),
`-strataCrewDropEvery <s>` (a fake friend posts every s seconds). Every screen
is captured and every motion filmed (`tools/film.sh`) and graded in
`docs/motion-audit.md` until each is a 10.

Manual only, listed as unverified until done on two phones: the invite round
trip between two iCloud accounts, a win crossing devices, a real notification,
`SensitiveContentAnalysis` on device, Declared Age Range on device.

---

## 11. Build order

1. `SocialStore` on a fake container, no UI: crews, invites, caps, post / edit /
   withdraw / delete, outbox, pruning, sticky choice. Tests.
2. The real CloudKit adapter, the app and scene delegate, invite acceptance.
3. The button, Crews list, New Crew, Crew Info.
4. The `TowerEntry` seam and the crew tower with live drops and the dance.
5. N heads, head-to-head collision, the cramped cluster.
6. Posting checkboxes, sticky.
7. Push, the notification extension, signing.
8. Safety, age, privacy, words.
9. Film and grade every screen and motion to 10.

## 12. Risks

- **Push signing** failed once before (the 2026-09-28 spec left it out for
  that). Mitigation: the API key path that fixed build 35's export.
- **Administrator role** may not exist on the SDK (4.1).
- **Filtering entitlement** is at Apple's discretion (5).
- **Eight live heads** may cost too much (3.4).
- Two-account testing needs a second iCloud account on a second device.
