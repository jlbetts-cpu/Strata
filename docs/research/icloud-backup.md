# Automatic iCloud backup for Strata

A build-ready design. Research only: nothing in any checkout was edited, nothing
was built, no simulator was run.

Owner's words: *"add automatic iCloud backup to the app so people don't lose
their wins."*

Owner's binding constraint, given during this research:

> the photographs must back up too, not only the wins. A design where a restored
> phone shows the tower with blocks that have lost their pictures is not
> acceptable.

So photographs sync by default. "Photos optional" exists only as a fallback for
people who run out of iCloud room, never as the shipping default.

Every claim about the app below was read out of
`/Users/jaydenbetts/StrataWork/owner-head` on 2026-09-15. Claims about Apple APIs
carry a source and a date at the end.

---

## 0. The five things a builder should read first

1. **`SharedModelContainer` falls back to an IN-MEMORY store when the container
   fails to open.** Adding `cloudKitDatabase:` makes the container validate the
   schema at init, and this schema fails that validation today (31 properties,
   §3a). The result would not be an error dialog. It would be an app that opens
   empty and saves nothing. **Fix the fallback before anything else ships.**
   `Strata/Services/SharedModelContainer.swift:16-30`.

2. **"Back Up Everything" cannot be restored, and it is lossy.** It writes
   `wins.json` + a `photos/` folder, zipped. The JSON has no `imageFileName`,
   so nothing in the file says which photograph belongs to which win. It also
   drops `towerOrder`, `blockSize` per log, latitude/longitude,
   `spontaneousCategoryRaw`, `PlanItem`, `MoodLog`, the head and the profile.
   And there is **no import path anywhere in the app** (grepped: no
   `fileImporter`, no decodable export type, no restore function).
   `Strata/Views/SettingsView.swift:496-580, 643-672`.

3. **The widget does not read the SwiftData store.** It reads a JSON snapshot in
   the App Group, by deliberate design (`Shared/WidgetSnapshot.swift:5-17`).
   That means enabling CloudKit on the store touches the widget not at all. It
   also means the store is *not* in a group container today, so there is no
   store relocation to do.

4. **CLAUDE.md's "entitlements are empty on purpose" is stale.** Both app
   entitlement files already carry `com.apple.security.application-groups`
   (`group.JaydenBetts.Strata`). Signing is automatic, team `W34J6358L7`. The
   warning behind the rule still stands (HealthKit entitlements once broke
   provisioning) but the file is not empty and adding a second capability is
   not a first.

5. **Photographs are 99.7% of the sync payload.** The record itself is a few
   megabytes over five years. Everything hard about this project is the
   photographs (§5, §7).

---

## 1. What "don't lose their wins" must cover

Ranked by what a person would actually grieve, not by bytes.

| Rank | Thing | Where it lives now | Replaceable? | Grief |
|---|---|---|---|---|
| 1 | **The photographs** | `Documents/strata-images/*.heic` | **Never.** A photograph of a moment is the one thing in this app that cannot be recreated from memory. | Total. This is the loss people mean. |
| 2 | **The wins themselves** (date, name, size, colour, place, tower order) | SwiftData store | In theory, by retyping. In practice nobody retypes four years of days. | Severe. The tower IS the count, and the count is the product. |
| 3 | **The head** | `Application Support/Head/{happy,…}.png` + `head.json` | Yes, by walking the maker again with the front camera. | Annoying, not devastating. It is a ten-minute rebuild. It is also the single most personal artifact in the app. |
| 4 | **The profile** (name, profile photo, background colour) | UserDefaults + a 600px file | Yes, in ten seconds. | None. |
| 5 | **Plan items** | SwiftData store (`PlanItem`) | Yes. `PlanItem.sweep` already deletes completed one-offs overnight, so the list is ephemeral by design. | None. Sync them because they are free (they ride the same store), not because they matter. |
| 6 | **Preferences** (reminders, camera timer, guides, haptics, sound, Save to Photos, Remember places, replay reminders, onboarding flag, look choice) | UserDefaults | Yes, in a minute in Settings. | None. |

**The one-line version: photographs first, the record second, the head third,
and everything below that is a courtesy.**

A ranking that matters for the design: rank 1 is enormous and rank 2 is tiny.
That asymmetry is the reason the record and its pictures must be able to sync
*separately* (§5.3). A user whose iCloud is full should still get their tower
back.

### What is already protected, and what is not

Nothing in the app sets `isExcludedFromBackup` (grepped). So `Documents/`,
`Application Support/` and UserDefaults are already inside the **iOS device
backup**, and a user who has iCloud Backup switched on and restores a new phone
from it gets everything today.

What that does not cover, and what this project is actually for:

- A user with iCloud Backup off, or whose backup is weeks stale because the
  phone stopped backing up when iCloud filled.
- A phone lost, stolen or drowned between backups.
- Two devices in use at once (iPad, a second phone). A device backup is not sync.
- The device backup itself competes for the same 5GB. Photographs are what fills
  it. The thing meant to protect the wins is crowded out by the wins.

So the honest framing for the owner: this is not "there is no backup today", it
is "the backup today is silent, all-or-nothing, and the first thing to break
when iCloud fills".

---

## 2. What the app stores today (verified in code)

### 2.1 SwiftData

`Strata/Services/SharedModelContainer.swift`:

```swift
let schema = Schema([Habit.self, HabitLog.self, MoodLog.self,
                     Tower.self, PlanFolder.self, PlanItem.self])
let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
```

No `groupContainer:`. No `cloudKitDatabase:`. Default store location
(`Application Support/default.store`).

Relationships:

- `Habit.logs` cascade, inverse `\HabitLog.habit` (`Habit.swift:202`)
- `Tower.habits` nullify, inverse `\Habit.tower` (`Tower.swift:12`)
- `PlanFolder.habits` nullify, inverse `\Habit.planFolder` (`PlanFolder.swift:14`)

No `.deny` anywhere. No `@Attribute(.unique)` and no `#Unique` anywhere
(grepped). `#Index<HabitLog>([\.dateString])` on `HabitLog.swift:13`.

### 2.2 Photographs

`Strata/Services/ImageManager.swift`:

- Directory: `FileManager.urls(for: .documentDirectory)[0] / "strata-images"`.
  **The app's own Documents, not the App Group.**
- Written by `save(image:for:)`: resize to `storedMaxDimension = 2560`, HEIC at
  quality 0.85, file name `"<logID>_<suffix>.heic"`.
- Referenced by `HabitLog.imageFileName`.
- Written in production from four places: `AddWinSheet.swift:721`,
  `MainAppView.swift:1468`, `MainAppView.swift:1563` (a re-point, not a write),
  `ImageMigrationRunner.swift:30`. Cleared at `AddWinSheet.swift:639` and
  `PhotoViewer.swift:835`.
- Thumbnails are an in-memory `NSCache` only, plus a weak live table. **Nothing
  is cached to disk.** Nothing to sync, nothing to exclude.
- `pruneOrphans(referenced:)` deletes any file no log names. Its doc comment is
  explicit that the caller must hand over a set it *knows* is complete. **Under
  sync this function becomes dangerous in a new way (§11.7).**

### 2.3 The head

`Strata/Models/HeadStore.swift`:

- Directory: `Application Support/Head/`
- Contents: one `<expression>.png` per `HeadRig.Expression`, optional `shut.png`,
  and `head.json` (a `Manifest`: version, contentHeight, chin, eye positions per
  expression).
- Canvas `side = 600` px.
- Switches in `UserDefaults.standard`: `headIsProfilePicture`, `headOnMap`,
  `headCameraSticker`, `headOnTower`, `headLook`.

### 2.4 UserDefaults, complete list

`profileName`, `profileBackground`, `headIsProfilePicture`, `headOnMap`,
`headCameraSticker`, `headOnTower`, `headLook`, `activeTowerID`,
`cameraShowsGuides`, `cameraTimerSeconds`, `hapticsEnabled`, `hasOnboarded`,
`notificationsEnabled`, `reminderHour`, `reminderMinute`, `replayRemindersOn`,
`savesToCameraRoll` (`PhotoLibrarySaver.defaultsKey`), `remembersPlaces`
(`LocationService.defaultsKey`), `soundEngineMuted`, `towerFilterMode`,
`profileChartUnit`, `milestoneStore`, `imageMigrationComplete`,
`pendingWelcomeWin`, `lastCelebrationDate`, `lastCompletionDateString`,
`lastDayBoundaryCheck`, `hasSeenFirstDrop`, `lastAuroraWeek`,
`towerShowParallax`, `sectionExpanded`, `smartViewOverrides`, `planSortMode`.

Profile photo: a 600px file written by `ProfileStore` (see `ProfileStore.photoURL`).

### 2.5 App Group

`group.JaydenBetts.Strata`, holding `widget-snapshot.json` and
`widget-photos/` (today's photographs re-encoded at 600px for the widget,
`WidgetSnapshot.photoPixels`). **Derived data. Never sync it.**

---

## 3. Approach comparison

Judged on: correctness, cost, review risk, offline behaviour, storage limits,
restore experience, work to build.

### (a) SwiftData + CloudKit, photographs carried in the model

`ModelConfiguration(schema:, cloudKitDatabase: .private("iCloud.JaydenBetts.Strata"))`,
which mirrors the local store into the user's CloudKit private database via
`NSPersistentCloudKitContainer` underneath.

**The constraint audit against the real models.** CloudKit mirroring requires
every attribute to be optional or to carry a default, forbids unique
constraints, and requires relationships to be optional with an inverse and no
`.deny` rule ([fatbobman, Designing Models for CloudKit Sync][f1];
[Hacking with Swift][hws1]).

Relationships and delete rules **pass today**: all four are optional or to-many,
all have inverses, none is `.deny`, none is ordered. No unique constraints
exist. `#Index` is a local SQLite index and is unrelated to CloudKit's own
indexes, so it is not a blocker ([fatbobman, Fixing Invisible Records][f2]).

Optionality is where it fails. **31 properties break the rule today:**

| Model | Properties that are non-optional with no default |
|---|---|
| `Habit` (10) | `id`, `title`, `category`, `blockSize`, `frequencyRawValues`, `createdAt`, `reminderEnabled`, `isTodo`, `creationXP`, `graceDays` |
| `HabitLog` (6) | `dateString`, `completed`, `caption`, `surgeMode`, `xpCollected`, `isBonusBlock` |
| `MoodLog` (4) | `id`, `dateString`, `mood`, `motivation` |
| `Tower` (5) | `id`, `name`, `emoji`, `createdAt`, `order` |
| `PlanFolder` (6) | `id`, `name`, `icon`, `colorHex`, `sortOrder`, `createdAt` |
| `PlanItem` | **none. Already compliant.** |

Every one is fixed by writing a default in the declaration
(`var title: String = ""`, `var completed: Bool = false`,
`var frequencyRawValues: [String] = []`, `var createdAt: Date = Date()`,
`var id: UUID = UUID()`). The initialisers already assign all of these, so no
behaviour changes and SwiftData migrates the store in place. This is exactly the
shape `PlanItem`, `towerOrder` and `latitude` already use, and the codebase
already documents it as the shape that migrates without a plan
(`HabitLog.swift:52-57`).

Two more to check by building, not by reading:

- `HabitLog.subtasks: [SubTask] = []` is a `Codable` struct array. SwiftData
  stores it as a composite blob. It should mirror as a Bytes field, but this is
  the one property in the schema I cannot certify from documentation. **Verify
  by opening a CloudKit-enabled container and reading the error, which is
  Apple's own recommended validation method** ([Apple Frameworks Engineer,
  forums thread 751617][af1]).
- `HabitLog.imageData` is `@Attribute(.externalStorage) Data?`. It is optional,
  so it passes. `.externalStorage` works with CloudKit and is the correct
  shape for large binary: the bytes travel as a CKAsset rather than inline in
  the record ([forums 751617][af1]; assets do not count toward the 1 MB record
  limit, [Apple, Data Size Limits][ap1]).

**Migration of the existing store:** none needed for location. The mirroring
container adopts the store where it is and uploads the whole of it on first run.
The store does not move into the App Group, because the widget does not read it.

**App Group + widget:** unaffected. This is the single biggest thing this
architecture has going for it.

| | |
|---|---|
| Correctness | High. Apple's own mirroring, tombstoned deletes, change tokens, retry and backoff all handled. |
| Cost | Zero infrastructure. Storage is the user's own iCloud. |
| Review risk | Low. No new usage strings. Privacy answers stay "not collected" (§9). |
| Offline | Writes land locally and queue. The app is unchanged offline. |
| Storage | The user's 5GB free tier. **This is the binding constraint.** §7. |
| Restore | Install, sign in, open. Rows arrive first, pictures follow. |
| Work | Medium. 31 one-line defaults, one new model for the photo bytes, one materialiser, the container fallback fix, the Settings switch, and the copy. |

### (b) SwiftData local + a hand-written `CKSyncEngine` layer

Keep the store as it is; write records by hand into a custom zone.

Correctness: you own three-way merge, change tokens, state serialization,
backoff, `.changeTokenExpired`, `.userDeletedZone`. All of that is real code and
every one of it is a way to lose a win. Cost: high. Review risk: same as (a).
Offline: you build the queue. Storage: same 5GB. Restore: you build it. Work:
**Large, and the largest by a wide margin.**

The honest case for (b): it is the only option that lets you decide *what* to
upload and *when*, per record, which matters when the account is full. But (a)
plus a separate photo model (§5.3) buys most of that control for a fraction of
the work.

**Rejected.** `CKSyncEngine` is the right tool for an app that cannot express its
schema in Core Data. This one can, after 31 defaults.

### (c) A periodic backup FILE to the app's iCloud Drive container

Extend `exportData()` to write its zip into
`FileManager.url(forUbiquityContainerIdentifier:)/Documents/` on a schedule, and
build an importer.

What the existing export produces, verified: a zip named
`Strata Backup <yyyy-MM-dd>.zip` containing `wins.json` and `photos/`. Zipping is
done by `NSFileCoordinator(readingItemAt:options:[.forUploading])`, with no
archiver dependency, which is genuinely clever and worth keeping.

Correctness: **the file as it stands is not restorable** (no `imageFileName` in
the JSON, no importer, and half the schema missing). Fixing that is real work in
itself. Cost: it rewrites the whole archive every time, so a user with 1.9 GB of
photographs writes 1.9 GB to iCloud on every backup, and iCloud Drive keeps
versions. That is the worst storage profile of any option here. Review risk: low.
Offline: fine. Restore: a file the user must find and choose, which is a step
most people will not take at the moment they are setting up a new phone. Work:
Medium to Large, and most of it is an importer that (a) does not need at all.

**Rejected as the primary.** Keep it, improve it (§12 task 9), and let it be the
thing a person uses to hand their wins to themselves outside Apple.

### (d) iCloud Documents with `NSFileCoordinator` for the photographs, plus (a) for the database

Photographs move to the ubiquity container; the record syncs by (a).

The genuine advantage: iCloud Drive files can be **evicted locally and
re-downloaded on demand**, so a user with 4 GB of photographs does not have to
keep 4 GB on the phone. Option (a) has no eviction: the bytes are in the store
and they stay.

The genuine disadvantage, and it is decisive: **two mechanisms means two
half-synced states that can disagree.** A win whose row arrived but whose file
did not, a file that arrived for a row that never did, a file deleted by
coordination while the row still points at it. Each of those is a bug class that
(a) does not have, because in (a) a photo record either exists or it does not,
and CloudKit saves a record atomically. `ImageManager` would also have to learn
"not downloaded yet" as a third state alongside "present" and "missing", and
every read site would have to handle it.

Also: `NSMetadataQuery` is a live query you have to own, start, stop and reason
about. The app already has a documented scar from a MapKit view silently
stopping a whole page from re-evaluating (CLAUDE.md). This is the same family of
risk.

**Rejected for v1.** It is the right answer to local disk pressure and belongs
in a later version if disk becomes the complaint. §5.6 keeps the door open with
a cheaper mechanism.

### (e) Do nothing automatic; make the manual export unmissable

A banner, a nag, a monthly reminder to press Back Up Everything.

Correctness: it is not restorable, so it is not a backup (see (c)). Even fixed,
it is a thing the user must remember at exactly the moment they are least likely
to (before the phone is lost). Cost: near zero. Review risk: none. Work: Small.

**Rejected as the answer to the owner's request**, which was explicitly for
*automatic*. Worth a line in §12 anyway: the export should be fixed regardless,
because it is the only path that survives a person leaving Apple.

---

## 4. Recommendation

**SwiftData + CloudKit private database (option a), with each photograph carried
in the model as `@Attribute(.externalStorage)` bytes on its own small model,
materialised back onto disk under its existing `imageFileName` when it arrives.**

**Second choice: (d)**, the same database sync with the photographs in an iCloud
Drive container coordinated by `NSFileCoordinator`. It is strictly better on
local disk and strictly worse on everything else.

The reason, in one paragraph: the record half of this problem is already solved
by Apple, and the only thing standing between Strata and that solution is 31
missing default values on properties whose initialisers already assign them.
Everything genuinely hard here is the photographs, and the hard part of the
photographs is not the transport, it is that they will not fit in a free 5GB
account for a heavy user, which is equally true of every option on the list. Given
that, the deciding question is how many mechanisms can fail: (a) has one sync
engine, one account check, one conflict model and one error surface, and the
picture arrives in the same atomic record save as the fact that the win has a
picture, which is precisely the invariant a restored phone needs. (d) is two
mechanisms with two partial states that can disagree with each other, and it buys
one real thing, local eviction, which is a disk problem and not the loss problem
the owner asked about. (b) is (a) with Apple's half rewritten by hand, and every
line of that is a new way to lose a win. (c) and (e) both produce a file that
cannot currently be restored at all, which disqualifies them as backups whatever
else they are.

**What syncs by default: the wins, their photographs, plan items, mood logs,
towers and folders, and the head with its face images and switches. Nothing
else.** Preferences stay on the phone, and the app says so.

---

## 5. The photographs, in detail

This is the part the owner made non-negotiable, so it gets its own section.

### 5.1 How they travel

A new model, **`WinPhoto`**, holding the bytes:

```swift
@Model
final class WinPhoto {
    var id: UUID = UUID()
    /// The file name this picture belongs under, byte for byte the same string
    /// `HabitLog.imageFileName` carries. The key that reconnects the two.
    var fileName: String = ""
    /// The picture itself. External storage keeps it out of the row, and
    /// CloudKit carries it as a CKAsset rather than inline in the record.
    @Attribute(.externalStorage) var data: Data?
    /// When these bytes were written, for the de-dupe rule in §11.6.
    var createdAt: Date = Date()
    @Relationship(deleteRule: .nullify, inverse: \HabitLog.photo)
    var log: HabitLog?
}
```

and on `HabitLog`:

```swift
var photo: WinPhoto?
```

**Why a separate model rather than a `Data?` on `HabitLog`.** Three reasons, and
the first is the important one.

1. **A photo that cannot be saved must not block the win.** An
   `.externalStorage` attribute on `HabitLog` becomes a CKAsset field on the
   *same* CKRecord as the win. A record save that fails on quota fails the whole
   record, so a full iCloud account would stop the rows syncing as well as the
   pictures. With `WinPhoto` separate, the win's record is a few hundred bytes
   and goes up regardless; only the picture's record fails. This is what makes
   §7's "the tower always comes back, even when the pictures cannot" true rather
   than aspirational.
2. `HabitLog` is fetched constantly. `MemoriesViewModel` pages the whole record
   eight weeks at a time; `MainAppView` walks every log it holds on
   `refreshData()`. Keeping the bytes on a different object keeps them out of
   every one of those fetches.
3. It gives the uploader, the materialiser and the "am I finished" count a
   single obvious home.

### 5.2 How a restore reconnects each picture to its win

`imageFileName` stays the key. It is already the key everywhere in the app, and
it must keep resolving.

On a new phone:

1. The `HabitLog` rows arrive. `imageFileName` is set. `ImageManager` finds no
   file, so every block draws its colour. **This is already how blocks behave**
   while a thumbnail is decoding, so nothing new appears on screen.
2. The `WinPhoto` records arrive, each one carrying `fileName` and `data`.
3. A **materialiser** runs: for each `WinPhoto` whose `fileName` has no file on
   disk, write `data` to `imageDirectory/fileName` with
   `Data.write(to:options:.atomic)`, then tell `ImageManager` to forget nothing
   and let the next thumbnail request pick it up. The block's picture fades in.

**The materialiser only ever creates files. It never deletes and never
overwrites an existing file.** That is the whole of its contract, and it is
written that way deliberately because of CLAUDE.md's rule: *"Never delete or
rewrite image files on a code path that only meant to read them."* A path that
only meant to fill in a gap has no business touching a file that is already
there.

Where it runs: a `@ModelActor`, kicked on (i) app launch after the container
opens, (ii) `NSPersistentCloudKitContainer`'s remote-change notification, and
(iii) return to the foreground. It fetches `WinPhoto` where `data != nil`,
batches through with `modelContext.enumerate(_:batchSize:)` so a thousand
pictures do not materialise into memory at once, and writes.

### 5.3 The other direction: getting existing photographs into the model

For every `HabitLog` with an `imageFileName` and no `photo`, read the file and
create a `WinPhoto`. Same actor, same batching, runs after the materialiser.

This is the **backfill**, and it is the expensive moment in this project: a user
with 3,127 photographs uploads all of them the first time. It must be:

- Batched and cancellable.
- Off the main actor.
- Ordered **newest first**. If it stops halfway, the half that made it is the
  half the person looked at most recently.
- Reported honestly while it runs (§8).
- Stoppable on `CKError.quotaExceeded` (§7.3).

New photographs taken after this ships are written to `WinPhoto` at the moment
they are attached, in the same save as `imageFileName`, from the four write
sites listed in §2.2. Centralise that into one helper so a fifth site cannot
forget:

```swift
enum WinPhotoStore {
    /// Attach a freshly saved photograph to a win: the file name the app
    /// reads by, and the bytes iCloud carries.
    static func attach(fileName: String, data: Data,
                       to log: HabitLog, context: ModelContext)
}
```

### 5.4 Local disk, and the honest cost

**The bytes exist twice on the device:** the HEIC in `strata-images/`, and
SwiftData's external-storage copy. A user with 1.9 GB of photographs will use
3.8 GB on the phone.

That is a real cost and it should be said out loud rather than discovered. Two
things make it acceptable for v1:

- The file on disk is the read path the entire app already depends on. Removing
  it means rewriting `ImageManager`, `ThumbnailStore`, the map, the month tower,
  the gallery, the viewer, the replay exporter and the widget copier. That is a
  larger change than the sync itself, and it is the kind of change CLAUDE.md
  warns about.
- The duplication is reclaimable later without changing the architecture (§5.6).

### 5.5 What the app must never do with the duplicate

`ImageManager.pruneOrphans(referenced:)` deletes any file no log names. Under
sync there is a window where rows have not arrived yet, so "no log names it" is
temporarily false for photographs that are perfectly fine.

**Rule: `pruneOrphans` must not run until the store reports its first sync
complete, and must never run while the materialiser has work queued.** Gate it
on both. The function's own doc comment already says the caller must hand over a
set it knows is complete; under sync, "complete" acquires a second meaning and
the caller must honour it.

### 5.6 The eviction door, left open (not v1)

Once the bytes are durable in the model, the on-disk file is a cache and can be
deleted and re-materialised on demand. That reclaims the duplication in §5.4.

It is deliberately **not** in v1, because it is a path that deletes real user
photographs, and CLAUDE.md is explicit about those. If it is ever built, it may
delete a file only when all three hold: the matching `WinPhoto.data` is non-nil,
the store reports that record as uploaded, and the device is under real storage
pressure. Anything less and it is the "read path that wrote" bug from the
portfolio's own history, with photographs instead of heads.

### 5.7 The head travels the same way

Same mechanism, one more model:

```swift
@Model
final class Identity {
    /// A fixed name so two devices converge instead of making two rows. There
    /// are no unique constraints under CloudKit, so §11.6's de-dupe is what
    /// actually enforces this.
    var key: String = "me"
    var updatedAt: Date = Date()

    // The head, as HeadStore writes it today.
    @Attribute(.externalStorage) var headManifest: Data?   // head.json
    @Attribute(.externalStorage) var faceHappy: Data?
    @Attribute(.externalStorage) var faceNeutral: Data?
    // ... one per HeadRig.Expression, plus:
    @Attribute(.externalStorage) var faceShut: Data?

    // The head's switches, which are part of the head, not of the phone.
    var headIsProfilePicture: Bool = false
    var headOnMap: Bool = false
    var headCameraSticker: Bool = false
    var headOnTower: Bool = false
    var headLook: String = "none"

    // The profile, which is two settings and costs nothing to carry.
    var profileName: String = ""
    var profileBackground: String?
    @Attribute(.externalStorage) var profilePhoto: Data?
}
```

`HeadStore.save(_:)` writes the files as it does now **and** the row.
`HeadStore.load()` gains a second step: if there are no files on disk but there
is an `Identity` row with faces, write the files out first, then load exactly as
today. `delete()` clears both, and clearing the row is what propagates the
deletion.

The head's face set is small (six 600px PNGs with alpha, on the order of 1.5 MB
to 3 MB once) so it is free against the photograph budget. It is also the
artifact people would most hate to rebuild, which is why it does not get a
different, cheaper mechanism.

The switches move into the row because a head that arrives switched off looks
like a head that did not arrive. `NSUbiquitousKeyValueStore` would also carry
them, but that is a second sync surface with its own notification and its own
conflict rules for five booleans, and the head is already coming through this
one.

**Everything else in UserDefaults stays on the phone** (§8 copy says so).

---

## 6. What changes in the schema, in full

| Change | Model | Size |
|---|---|---|
| Add `= <default>` to 31 properties | `Habit` 10, `HabitLog` 6, `MoodLog` 4, `Tower` 5, `PlanFolder` 6 | S |
| New `WinPhoto` + `HabitLog.photo` | new | M |
| New `Identity` | new | M |
| `SharedModelContainer`: add `cloudKitDatabase:`, and replace the in-memory fallback with a local-only retry | service | M |

No property is renamed. No property is removed. No type changes. That matters:
once a CloudKit-mirrored schema is live, the rule is **add only, never delete,
never rename, never change a type**, because a rename is read as a delete plus a
create and takes the data with it ([fatbobman][f1]).

Which means: **`HabitLog.imageData` and `imageURL`, `videoURL`, `imageFlipped`
must stay exactly where they are, forever.** They are already marked "retained
for migration" and "deprecated, retained for schema compatibility". Under
CloudKit that retention stops being politeness and becomes a rule.

---

## 7. Storage maths

### 7.1 Per photograph

Two measurements already in the codebase, combined:

- `ImageManager.storedMaxDimension` doc comment, measured on a fixture:
  cap 1024 gives 45 KB, cap 2560 gives about 160 KB. Ratio **3.56x**.
- `pruneOrphans` doc comment, measured on a real phone in the cap-1024 era:
  **3,127 photographs, 522 MB**, which is **167 KB average for real camera
  photographs**.

167 KB x 3.56 = **about 600 KB per photograph at today's 2560 cap**. The code's
own estimate agrees in shape: *"expect a few hundred KB each rather than 160."*
Plan with 600 KB; treat 300 KB as the optimistic end.

### 7.2 What that adds up to

At 600 KB per photograph:

| Photos a day | Per year | 3 years | 5 years |
|---|---|---|---|
| 1 | 219 MB | 657 MB | 1.1 GB |
| 2 | 438 MB | 1.3 GB | 2.2 GB |
| 4 | 876 MB | 2.6 GB | 4.4 GB |

The one real user visible in the code, 3,127 photographs, re-encoded at today's
cap: **1.9 GB**.

The record itself, by contrast: a `HabitLog` row is on the order of half a
kilobyte, so three wins a day for five years is roughly 5,500 rows, **a few
megabytes with CloudKit's metadata on top**. The head is 3 MB once. The profile
is 100 KB.

**Photographs are about 99.7% of everything this feature will ever upload.**

### 7.3 Against the free 5 GB tier

CloudKit private-database storage is charged to the **user's** iCloud quota, not
the developer's, and the free tier is 5 GB shared with device backup, Photos,
Mail and everything else ([Apple Developer Forums, CloudKit private database
usage][ck1]). CloudKit returns `CKError.quotaExceeded` when it is full and
expects the app to tell the user in its own UI.

In practice a free-tier user with iCloud Backup switched on has a few hundred
megabytes spare, not five gigabytes. So:

- A new user at 2 photographs a day fills a *realistic* free allowance inside
  the first year.
- **The existing 3,127-photograph user cannot complete a first sync on a free
  account at all.** 1.9 GB will not fit.

This is not an argument against the feature. It is the reason the design
separates the row from the picture, and the reason §8's copy has to be honest.

### 7.4 What happens when iCloud is full

The rule: **the record keeps going, the pictures stop, and the app says which.**

On `CKError.quotaExceeded`:

1. Set a persisted flag, `photoSyncPaused`.
2. The backfill stops. New photographs still get a `WinPhoto` row created
   locally with `data` set, so nothing is lost on this device, but the uploader
   is not asked to try again until the flag clears. (`NSPersistentCloudKitContainer`
   will retry on its own schedule; the flag exists so the *UI* can be truthful
   and so the backfill does not keep hammering.)
3. Wins, dates, sizes, colours, places, plan items and the head keep syncing.
   They are kilobytes.
4. Settings shows the state and the number (§8).
5. The flag clears when a photo record saves successfully.

What still syncs when full: everything except photograph bytes. What stops:
photograph bytes. What it says: §8, "Your wins are backed up. Your photos need
more iCloud room."

### 7.5 Never sync

- Thumbnails. In-memory only, regenerated free.
- `widget-photos/` and `widget-snapshot.json`. Derived, App Group, rebuilt on
  every launch by `refreshData()`.
- Replay videos. Written to `temporaryDirectory` and removed.
- The export zip.

---

## 8. The user's experience, with exact copy

House rules from CLAUDE.md apply to every string here: **no long dash anywhere a
person reads**, and **nothing that sounds like watching**. No "monitors", no
"tracks", no "in the background". Checked: none of the strings below contain an
em dash or an en dash.

### 8.1 Where the switch lives

`SettingsView`, the **Data** section, above "Back Up Everything", which becomes
the manual sibling of the automatic thing.

```
Data
  [ iCloud Backup ..................... (•) ]
  Back Up Everything
  Reset All Data
```

### 8.2 The default: ON, with one condition

**On by default, for anyone signed in to iCloud.** The owner asked for automatic,
and a backup switch that ships off is a backup most people never get. Apple's
privacy answer does not change either way (§9), so there is no disclosure cost
to defaulting on.

The condition: **on an existing install with photographs already on disk, the
first backfill must be offered, not assumed.** A silent 1.9 GB upload on
somebody's cellular plan is not a good surprise. So: automatic for the record
immediately, and a one-time prompt for the pictures, worded in §8.6.

New installs have nothing to back up yet, so they get no prompt at all.

### 8.3 Settings row, every state

Row title: `iCloud Backup`

Footer, by state:

| State | Footer |
|---|---|
| Off | `Your wins and photos stay on this phone only. If you lose it, they go with it.` |
| On, up to date | `Your wins and photos are saved to your iCloud. Last saved just now.` (or `Last saved 12 minutes ago`, `Last saved yesterday`) |
| On, working | `Saving your photos. 240 of 1,880 done.` |
| On, waiting for wifi or a connection | `Waiting for a connection. Nothing is lost, it will finish when you are back online.` |
| On, iCloud is full | `Your wins are backed up. Your photos need more iCloud room.` with a second line: `Free up space in iCloud, or turn photos off below and your wins keep saving.` |
| On, no iCloud account | `Sign in to iCloud in the Settings app to turn this on.` (row disabled) |
| On, iCloud account changed | `You signed in to a different iCloud account. The wins on this phone stay here, and new ones save to the new account.` |

### 8.4 The photos sub-switch

Under the main row, only visible when backup is on:

```
  Include photos ..................... (•)
```

Footer: `On by default. Photos are most of what a backup takes up, so turning
this off keeps your wins saving when iCloud is short of room. Photos already
saved stay saved.`

This is the fallback the owner described, not the default.

### 8.5 On the tower, while pictures are still arriving

Nothing new. **A block shows its colour, then its picture**, which is already
exactly what a block does while a thumbnail decodes. No spinner on a block, no
badge, no placeholder glyph. The only place progress is stated is Settings.

One exception worth building: if a person opens the photo viewer on a win whose
picture has not arrived yet, the viewer must not show an empty black frame. Copy
for that one screen:

`This photo is still coming down from iCloud.`

### 8.6 The one-time prompt on an existing install

Title: `Save your photos to iCloud?`

Body: `Strata can keep a copy of your wins and their photos in your own iCloud,
so a new phone gets them back. You have 1,880 photos, about 1.1 GB. They upload
when you are on wifi.`

Buttons: `Save Them` / `Not Now`

`Not Now` leaves the record syncing and the pictures off, and the row in Settings
says so.

### 8.7 A new phone

1. Install Strata, open it.
2. Onboarding runs as it does today.
3. The wins arrive. The tower builds. Blocks are colours.
4. The pictures fill in, newest first, so the days the person looked at most
   recently come back first.
5. The head arrives and appears wherever its switches say.

There is no restore screen, no file to find, no button to press. That is the
whole argument for sync over a backup file.

While step 4 runs, Memories and the map show what has arrived. **It must never
claim a day has no photograph when the photograph is simply still coming.**
The empty state for a day that is waiting:

`Photos from this day are still coming down.`

### 8.8 A device with no iCloud account

Check `CKContainer.accountStatus()` before claiming anything. On `.noAccount`
the row is visible and disabled with the footer from §8.3. **The app must keep
working exactly as it does today**, because it does: the store is local and the
mirroring container simply has nowhere to mirror to. No error, no modal, no
nagging.

On `.restricted` (a managed or Screen Time restricted device):
`iCloud is turned off on this phone by its settings.`

### 8.9 What the app must say while it has not finished uploading

The honest sentence, and the one that should appear in the Reset All Data
confirmation and anywhere the app claims safety:

`Wins you have just added may not be in iCloud yet.`

And **"Back Up Everything" keeps its place and its meaning**, because it is the
only thing that produces a file the user holds. Its footer becomes:

`A file you can keep anywhere, not just iCloud.`

---

## 9. Truthfulness obligations

CLAUDE.md: *"when you add or remove anything that touches user data, the
manifest, the policy and the usage strings are part of the change."*

### 9.1 `PrivacyInfo.xcprivacy`: NSPrivacyCollectedDataTypes stays EMPTY

Apple's definition, verbatim from the App Privacy Details page
([Apple][ap2], read 2026-09-15):

> "Collect" refers to transmitting data off the device in a way that allows you
> and/or your third-party partners to access it for a period longer than what is
> necessary to service the transmitted request in real time.

Data in a **CloudKit private database is in the user's own iCloud account**. The
developer has no access to it: it is not readable in the CloudKit Console, it is
not queryable from a server-to-server key, and it is charged to the user's
quota, not the developer's. Nothing is transmitted in a way that allows the
developer or a partner to access it. **So the correct answer is still "Data Not
Collected", and the manifest's empty array stays empty.**

This is worth stating carefully in the file itself, because the current comment
says the opposite will be needed:

> If a server, an account, a backup or an analytics SDK is ever added, this is
> the first file to change

That sentence should change to say that a backup **into the user's own iCloud**
is specifically the case that does not change it, and why. The comment is the
only place this reasoning will survive.

### 9.2 What the manifest DOES need

- `NSPrivacyAccessedAPICategoryUserDefaults` stays, reason `CA92.1`. The current
  comment says *"there is no app group"*, which is **already false** (the
  widget's group exists). If UserDefaults is read from a shared suite the reason
  becomes `1C8F.1`; today the app only uses `UserDefaults.standard`, so `CA92.1`
  remains correct and only the comment is wrong.
- Nothing else. CloudKit is not a required-reason API, and no new API category
  is entered.

### 9.3 `PrivacyPolicyView`: six of nine sections become false

Read as it stands today (`Strata/Views/PrivacyPolicyView.swift`, "Last updated
14 September 2026"):

| Section | What it says now | Status after sync |
|---|---|---|
| Where it is stored | `"On your device. Strata has no account, no server, and no analytics. Nothing you log is sent anywhere, and nobody but you can read it."` | **False.** "Nothing you log is sent anywhere" stops being true. "Nobody but you can read it" stays true and is the sentence worth keeping. |
| What Strata stores | lists the data, ends `"That is the whole of it."` | Still true about *what*. Needs *where*. |
| Photos | `"copied into Strata's own storage on your device"` | **Incomplete.** A copy also goes to iCloud. |
| Your profile | `"stay on your device, like everything else, and are never sent anywhere"` | **False.** |
| Your head | `"never sends them anywhere"` | **False.** |
| Places | `"stored on your device beside the photo and nowhere else"` | **False.** |
| Deleting everything | `"removes ... from the device permanently. Deleting the app does the same."` | **False and the most dangerous one.** Deleting the app does *not* remove the CloudKit copy. |
| Sharing | unchanged | True. |
| Contact | unchanged | True. |

Replacement copy for the two sections that carry the weight (no long dashes):

**Where it is stored**

> On your device, and in your own iCloud if you turn on iCloud Backup. Strata
> has no account and no server of its own. What goes to iCloud goes to your
> private iCloud storage, under your Apple Account. It is not sent to us, we
> cannot read it, and there is no analytics anywhere in the app.

**Deleting everything**

> Profile › Settings › Data › Reset All Data removes every win, every photo,
> your name, profile photo and head, and your tower. If iCloud Backup is on, it
> removes them from iCloud too, on this phone and on any other phone signed in
> to the same Apple Account. Deleting the app removes what is on the phone. The
> iCloud copy stays until you reset, or until you remove Strata's data in the
> Settings app under your Apple Account.

That last sentence is the one most apps get wrong and it is the one a reviewer
will check.

### 9.4 App Store Connect privacy questionnaire

**No change.** Every data type stays "Not Collected", because none of it reaches
the developer. Keep the reasoning in a comment in the manifest so the next
person answering the questionnaire does not talk themselves into ticking a box.

### 9.5 Usage strings

**No new usage string.** CloudKit does not have one and does not ask for
permission: it uses the account already signed in.

The existing three (`NSCameraUsageDescription`,
`NSLocationWhenInUseUsageDescription`, `NSPhotoLibraryAddUsageDescription`) do
not change in meaning. But note the location one says `"It only checks while the
camera is open"`, which stays true, and the privacy policy's Places section says
the coordinates are stored `"nowhere else"`, which does not. Fix the policy, not
the usage string.

CLAUDE.md's rule about empty usage strings being a device crash applies to
nothing here, because nothing new is added. Do not add an empty one for CloudKit
"just in case": there is no such key.

---

## 10. Entitlements and signing

### 10.1 Exactly what goes in

`Strata/Strata.entitlements` and `Strata/StrataDebug.entitlements`, added
alongside the existing app group:

```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.JaydenBetts.Strata</string>
</array>
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>
<key>com.apple.developer.ubiquity-kvstore-identifier</key>
<string>$(TeamIdentifierPrefix)$(CFBundleIdentifier)</string>
<key>aps-environment</key>
<string>development</string>
```

The last two: `ubiquity-kvstore-identifier` only if
`NSUbiquitousKeyValueStore` is ever used, which this design does **not** need,
so leave it out. `aps-environment` is added by Xcode when the Push Notifications
capability is enabled, and the Debug file gets `development` while the release
file gets `production` (Xcode manages this).

**Container identifier: `iCloud.JaydenBetts.Strata`.** Create it in the Developer
portal or let Xcode create it from the capability editor. It must match the
string in `ModelConfiguration(cloudKitDatabase: .private(...))` exactly.

`StrataWidget/StrataWidget.entitlements`: **unchanged.** The widget reads a JSON
file in the App Group and must stay that way (`Shared/WidgetSnapshot.swift:5-17`
gives the reasoning). Giving the widget iCloud access would be a new way for a
home-screen redraw to fail.

### 10.2 Capabilities

Three, in Signing & Capabilities on the Strata target only:

1. **iCloud**, with CloudKit ticked and the container selected.
2. **Push Notifications.** Xcode adds this automatically when CloudKit is
   enabled.
3. **Background Modes**, with **Remote notifications** ticked. This is what lets
   CloudKit send a silent push when another device changes something, so the
   app can pull without being reopened
   ([Kodeco / andrewcbancroft, NSPersistentCloudKitContainer setup][ck2]).

No background fetch, no background processing. Nothing else.

### 10.3 The risk to automatic signing

CLAUDE.md's warning is real and specific: *"HealthKit's entitlements were the
first thing to fail provisioning."* The mechanism of that failure is that a
capability in the entitlements file has no matching capability on the App ID in
the portal, so automatic signing cannot build a profile that contains it.

So the order matters:

1. Enable iCloud + CloudKit on the App ID `JaydenBetts.Strata` in the Developer
   portal **first**, and create the container there.
2. Then add the capability in Xcode, which writes the entitlements.
3. Then build.

Doing it the other way round is the exact failure the CLAUDE.md warning
describes. The check that costs nothing:

```
xcodebuild -scheme Strata -destination 'generic/platform=iOS' \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

which compiles device-ready code without touching provisioning, and then a real
signed build to prove the profile.

App Store Connect: nothing to fill in beyond the existing app record. The
CloudKit **schema** is created automatically on first run in the development
environment, and must then be **deployed to production from the CloudKit
Console** before any App Store or TestFlight build can sync. That is a manual
step and it is the one most likely to be forgotten: a TestFlight build against
an undeployed schema syncs nothing and reports nothing.

### 10.4 Simulator versus device

| Can be tested in the simulator | Cannot |
|---|---|
| Container opens with `cloudKitDatabase:` set, or throws | Live sync between two running apps |
| Schema validation (the 31 defaults) | Anything that depends on a silent push arriving |
| Records reaching CloudKit, verified in the CloudKit Console | Realistic timing |
| Records arriving **on relaunch or foreground** | |
| The backfill, the materialiser, quota UI with a stubbed error | |
| Every string and every state in §8 | |

The constraint, from Apple's own sample:

> "CKSyncEngine relies on remote notifications in order to sync properly.
> Simulators cannot register for remote push notifications, so running this
> sample on a real device or Mac is required for this app to properly sync."
> ([apple/sample-cloudkit-sync-engine README][ck3])

The same is true of the mirroring container, which uses the same push
mechanism. **A simulator can push changes up and can pull them down when the app
is relaunched. It cannot receive them live.** Two simulators signed into the same
iCloud account, relaunched by hand, is a complete functional test of everything
except latency and the push path.

---

## 11. Failure modes

### 11.1 Two devices change the same win

`NSPersistentCloudKitContainer` merges at the **property** level with
last-writer-wins. Two devices editing different fields of the same win both
survive. Two devices editing the same field: the later write wins and the
earlier is gone with no record of it.

For Strata this is mild. A win is a date, a size, a colour and sometimes a
caption; simultaneous edits to the same caption on two phones is a corner nobody
will hit. **Do not build a merge UI.** Do make sure `towerOrder` is understood:
a drag rewrites the order for **every** block in the tower
(`HabitLog.towerOrder` doc comment), so two devices rearranging at once produces
a mix. That is acceptable and self-correcting on the next drag.

### 11.2 A phone offline for weeks

Everything written offline queues locally and uploads when the connection
returns. Nothing is lost and nothing is different on screen. The only visible
effect is Settings' footer (§8.3, "Waiting for a connection").

The real risk is the opposite direction: a phone that has been offline for
longer than CloudKit keeps its change token gets `.changeTokenExpired`. The
mirroring container handles this by resetting the token and refetching, which is
correct and invisible. Do not try to handle it.

### 11.3 A full iCloud account

§7.4. Record keeps going, pictures pause, Settings says which, and there is a
switch that turns pictures off so the person can choose it rather than have it
chosen for them.

### 11.4 The user signs out of iCloud

`CKAccountChanged` fires. The mirroring container stops and the store keeps
working entirely locally. **Nothing on the phone is deleted.** The app must not
delete anything either: the wins on this phone are this person's wins whatever
account they are signed into.

Settings' footer changes to the `.noAccount` string. If they sign in to a
*different* account, new changes go to the new account's database and the old
account's copy stays where it is. The copy for that is in §8.3 and it is the
truth: `"The wins on this phone stay here, and new ones save to the new
account."`

### 11.5 Deleted wins coming back

CloudKit deletions are tombstoned in the zone, so a delete on one device
propagates to the others and does not resurrect. The ways a win *can* come back
are:

1. **A batch delete.** See 11.7. This is the big one.
2. Restoring an old device backup over a synced phone, which re-imports an old
   local store. Not preventable and not worth code.
3. A delete on device A racing an edit on device B: the **delete wins**, and the
   edit is lost. Correct, and the only sane rule.

### 11.6 Duplicates after migration

Two sources:

- **`Identity`.** With no unique constraints available under CloudKit, two
  devices coming online for the first time will each create a `key == "me"` row.
  **Required:** on every sync completion, fetch all `Identity` rows, keep the
  one with the newest `updatedAt`, delete the rest object by object. The same
  de-dupe-on-import pattern CloudKit users have used since unique constraints
  were ruled out ([Apple forums 656380][ck4]).
- **`WinPhoto`.** Keyed on `fileName`. Two devices could create two rows for the
  same file name if the backfill runs on both before either syncs. Same rule:
  group by `fileName`, keep the oldest `createdAt` (the original), delete the
  rest. **Deleting a duplicate `WinPhoto` must never delete the file on disk**,
  and this is exactly the "read path that wrote" hazard CLAUDE.md names: the
  de-dupe means to tidy rows, not to touch photographs.

`Tower` is also at risk: `TowerManager.ensureDefaultTower` creates one if none
exists, so two devices each create "a default tower". De-dupe by `createdAt`,
re-point the orphaned `Habit.tower` relationships, delete the extra.

### 11.7 What "a batch delete that deletes nothing" implies for a synced store

CLAUDE.md, §"A batch delete that deletes nothing": `modelContext.delete(model:)`
bypasses the relationship rules, the store refuses it on `HabitLog` and `Habit`,
every call was `try?`, and **Reset All Data deleted the photo files and left
every win in place for months.** `resetTower` now deletes object by object
(`MainAppView.swift:3122-3136`).

Under CloudKit that fix stops being a nicety and becomes load-bearing, for a
second reason on top of the first. A batch delete writes straight to the
persistent store without going through a managed object context, so the context
never observes the deletions and **the mirroring layer never learns about them**.
It cannot write the tombstones. The rows stay in CloudKit, and the next sync
brings every one of them back.

So the failure mode a batch delete would produce after this ships is worse than
the one it already produced: not "Reset All Data deletes nothing" but **"Reset
All Data appears to work, and then every win returns a few seconds later."**

Three rules fall out:

1. **Never `delete(model:)` anywhere in this app, ever.** Consider a test that
   greps for it, in the spirit of the project's gates. A gate that can fail.
2. Reset All Data must keep its object-by-object loop and keep logging the error
   rather than `try?`ing it, and should keep the DEBUG remaining-count check
   (`[strata-reset] logs remaining after reset: 0`). Add a second line for
   `WinPhoto` and `Identity`.
3. Reset All Data now has a **second half that happens later**: the deletions
   have to reach iCloud. If the user resets and immediately deletes the app, the
   deletions may not have been pushed. The confirmation copy must not promise
   more than it can do:

   > `This permanently deletes every win and photo, your name and profile photo,
   > and your head, on this phone and in your iCloud. It cannot be undone.`

   and, on the screen afterwards if backup is on:

   > `Clearing your iCloud copy. Stay on this screen for a moment.`

   `PlanItem` is not deleted by `resetTower` today
   (`MainAppView.swift:3131-3135` deletes `HabitLog`, `Habit`, `PlanFolder`,
   `MoodLog`, `Tower` and not `PlanItem`). Under sync that is a row that
   survives a reset and comes back to a fresh install. **Add it**, and add
   `WinPhoto` and `Identity` while you are there.

### 11.8 The silent in-memory fallback

Restating it because it is the one that turns a good feature into data loss.
`SharedModelContainer.shared` catches a container failure and returns an
**in-memory** container, setting `isUsingInMemoryFallback`. `MainAppView:476`
shows a message about it. But an in-memory store means nothing the person does
from that moment is saved.

Adding `cloudKitDatabase:` adds a whole new class of init failure: schema
validation. **Change the fallback to a three-step ladder before enabling
CloudKit:**

1. Try the schema with CloudKit.
2. On failure, log loudly and try the **same schema without CloudKit**, local
   and on disk. The person keeps their app and keeps saving; only sync is off.
3. Only if that also fails, in-memory, with the existing warning.

Step 2 is the important one and it does not exist today.

---

## 12. Build plan

Ordered. Each task is independently shippable and independently testable.

| # | Task | Size | Ships alone? | How it is tested |
|---|---|---|---|---|
| 1 | **Container fallback ladder** (§11.8). CloudKit not enabled yet; add the local-on-disk middle rung and a unit test that a bad schema lands on it instead of in-memory. | S | Yes, and it is an improvement on its own | Force a schema failure in a test; assert the store is on disk |
| 2 | **31 defaults** (§3a table). No CloudKit yet. Pure schema hygiene; SwiftData migrates in place. | S | Yes | Launch with an existing store, assert every row survives and `StrataTests` stays green |
| 3 | **`WinPhoto` + `Identity` models, local only.** New rows written beside the existing files. No sync. Includes the `WinPhotoStore.attach` helper replacing the four write sites, and the `HeadStore` two-way write. | M | Yes | `WinPhotoAttachTests` extension; assert file and row agree after every attach path |
| 4 | **The backfill and the materialiser**, local only, both directions between disk and model. Batched, off main, newest first, cancellable. | M | Yes | Seed with `-strataSeedHistory`, delete the files, run the materialiser, assert every `imageFileName` resolves again |
| 5 | **Turn on CloudKit.** Portal first, then capability, then `cloudKitDatabase:`. Nothing else changes. | M | Yes | Two simulators, one iCloud account, relaunch to pull. CloudKit Console to see the records |
| 6 | **Settings row, the sub-switch, and every string in §8.** Reads account status and sync state. | M | Yes | Drive each state with a stubbed status; screenshot each |
| 7 | **Quota handling** (§7.4): the paused flag, the backfill stop, the copy. | S | Yes | Inject `CKError.quotaExceeded` |
| 8 | **De-dupe sweeps** (§11.6) for `Identity`, `WinPhoto` and `Tower`, plus the `pruneOrphans` gate (§5.5) and the `PlanItem`/`WinPhoto`/`Identity` additions to `resetTower` (§11.7). | M | Yes | Create duplicates by hand in a test container; assert one survives and no file is touched |
| 9 | **Truthfulness pass** (§9): manifest comment, privacy policy rewrite, Reset All Data copy. Ship **in the same build** as task 5, never after it. | S | No, pairs with 5 | Read it. Grep the strings for `—` and `–` |
| 10 | **Fix "Back Up Everything"** so the file is restorable: put `imageFileName` in the JSON, add the missing fields, add an importer behind `fileImporter`. Independent of everything above. | M | Yes | Export, reset, import, assert the tower matches |
| 11 | *(Later, optional)* **Local eviction** (§5.6). Only if disk becomes a complaint. | L | Yes | Three-condition gate, and a test that proves it refuses when any condition fails |

### 12.1 Testing sync without two physical devices

1. **Two simulators, one iCloud account.** Sign both into the same Apple Account
   in the simulator's Settings app. Write on A, relaunch B, assert. This covers
   every correctness question. It does **not** cover live arrival, because a
   simulator cannot register for remote push ([apple sample README][ck3]).
2. **One simulator plus the CloudKit Console.** Write on the simulator, read the
   records in the Console, which also proves the schema deployed and the field
   names are what you think.
3. **A test-only `-strataSyncProbe` launch argument** in the spirit of
   `DebugHarness`, printing the mirroring container's event stream
   (`NSPersistentCloudKitContainer.eventChangedNotification`) to the console.
   Read it with `--console-pty`, the way the batch-delete bug was found.
4. **One real device for the push path only**, once, at the end. That is the only
   thing the simulator genuinely cannot answer.

### 12.2 Rollback if sync goes wrong in the field

The design makes this cheap, and it should be built in task 5, not improvised:

- A **kill switch** that is a local check, not a remote one: a `UserDefaults`
  key `icloudBackupOff` read inside `SharedModelContainer` before choosing the
  configuration. Set it, relaunch, the store opens local-only with the same
  schema and the same file. Nothing is lost and nothing migrates.
- **The local store is always complete.** CloudKit mirrors it, it is not the
  source. So turning sync off is never a data event.
- **A ship that makes it worse can be un-shipped.** The schema is add-only, so
  a build without CloudKit still opens a store that a CloudKit build wrote.
- What **cannot** be rolled back: the CloudKit schema in production, once
  deployed. Field names are permanent. This is why §6's add-only rule is
  absolute, and why task 3 (the models) must be got right before task 5 turns
  sync on.

---

## 13. Sources

All read 2026-09-15 unless noted.

- [f1] fatbobman, *Designing Models for CloudKit Sync: Core Data & SwiftData Rules* — https://fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/ (optional-or-default, no unique constraints, relationships optional with inverse, no Deny, no ordered, add-only migration)
- [f2] fatbobman, *Fixing Invisible Core Data/SwiftData Records in CloudKit Dashboard* — https://fatbobman.com/en/snippet/show-records-in-cloudkit-dashboard/ (CloudKit does not inherit local index configuration; local `#Index` is unrelated)
- [hws1] Hacking with Swift, *How to sync SwiftData with iCloud* — https://www.hackingwithswift.com/quick-start/swiftdata/how-to-sync-swiftdata-with-icloud
- [af1] Apple Developer Forums thread 751617, *Can SwiftData @Model with .externalStorage be used with CloudKit?*, May 2024 — https://developer.apple.com/forums/thread/751617 (`.externalStorage` works with CloudKit; an Apple Frameworks Engineer: enable CloudKit temporarily to run the validator against your model, and if the `ModelContainer` initializes the model is compatible)
- [ck4] Apple Developer Forums thread 656380, *Why? "CloudKit integration does not support unique constraints"* — https://developer.apple.com/forums/thread/656380
- [ap1] Apple, *CloudKit Web Services Reference: Data Size Limits* — https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/CloudKitWebServicesReference/PropertyMetrics.html (1 MB per record; assets do not count toward it; 50 MB maximum asset field)
- [ap2] Apple, *App Privacy Details on the App Store* — https://developer.apple.com/app-store/app-privacy-details/ (the "Collect" definition quoted in §9.1, and "Data that is processed only on device is not 'collected' and does not need to be disclosed in your answers.")
- [ck1] Apple Developer Forums, *CloudKit private database usage* — https://developer.apple.com/forums/thread/80756 (private-database storage is charged to the user's iCloud quota; 5 GB free per iCloud user)
- [ck2] andrewcbancroft, *Getting Started With NSPersistentCloudKitContainer* — https://www.andrewcbancroft.com/blog/ios-development/data-persistence/getting-started-with-nspersistentcloudkitcontainer/ (the three capabilities: iCloud + CloudKit, Push Notifications, Background Modes with Remote notifications)
- [ck3] Apple, *sample-cloudkit-sync-engine* README — https://github.com/apple/sample-cloudkit-sync-engine ("Simulators cannot register for remote push notifications, so running this sample on a real device or Mac is required for this app to properly sync.")

### Code read for this spec

`Strata/Services/SharedModelContainer.swift`, `Strata/Services/ImageManager.swift`,
`Strata/Services/ImageMigrationRunner.swift`, `Strata/Models/Habit.swift`,
`Strata/Models/HabitLog.swift`, `Strata/Models/PlanItem.swift`,
`Strata/Models/PlanFolder.swift`, `Strata/Models/MoodLog.swift`,
`Strata/Models/Tower.swift`, `Strata/Models/HeadStore.swift`,
`Strata/Models/ProfileStore.swift`, `Shared/WidgetSnapshot.swift`,
`Strata/Views/SettingsView.swift`, `Strata/Views/PrivacyPolicyView.swift`,
`Strata/Views/PhotoViewer.swift`, `Strata/Views/MainAppView.swift`
(`resetTower`), `Strata/PrivacyInfo.xcprivacy`, `Info.plist`,
`Strata/Strata.entitlements`, `Strata/StrataDebug.entitlements`,
`StrataWidget/StrataWidget.entitlements`, `Strata.xcodeproj/project.pbxproj`,
`CLAUDE.md`.
