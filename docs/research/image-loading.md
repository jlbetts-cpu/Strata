# A faster, calmer image system for Strata

Research and build-ready spec. 2026-09-15.

The owner, testing on his phone: *"loading times are kinda slow for images on
the maps and other areas… I don't want the app to feel slow or hard to find
things on the map because they won't load, or the Memories photos: I scroll and
the images can't keep up."*

**Read-only pass.** Nothing in any checkout was edited, nothing was built, no
simulator was run. Every claim about the code below is from reading the file
named beside it. Every claim about a *number on a device* is either quoted from
a measurement already recorded in the tree (cited), arithmetic from constants in
the tree (shown), or a published third-party benchmark (linked) — none of it is
a measurement I took, and the build plan starts by taking the real ones.

**What I could not enumerate.** `ls`, `find` and `grep` all fail on this machine
right now (`Resource temporarily unavailable` — the shell cannot fork while the
three build agents are running), so I could not list the tree. Files verified by
reading them in full: `Strata/Services/ImageManager.swift`,
`Strata/Services/ThumbnailStore.swift`, `Strata/Views/CachedImageView.swift`,
`Strata/Views/MemoriesMapView.swift`, `Strata/Views/PhotoGalleryGrid.swift`,
`Strata/Views/PhotoViewer.swift`, `Strata/Views/MonthTowerView.swift`,
`Strata/Views/FlippableBlockView.swift`, `Strata/Views/AlbumCoverView.swift`,
`Strata/Services/ReplayImages.swift`, `Strata/Services/PerfProbe.swift`,
`Strata/Services/DebugHarness.swift`, `Strata/Services/QuickWinService.swift`,
`Strata/Models/GridConstants.swift`, `CLAUDE.md`. **The widget
(`WidgetSnapshot` / `WidgetPreviewRenderer`) and the Spotlight indexer I could
not locate and have not read.** They are treated below as cold, low-traffic
consumers and every recommendation about them is marked as unverified.

---

## 0. The three changes that matter

Everything in this document reduces to three moves. The rest is detail,
sequencing and the measurements that prove each one.

1. **Bake a small JPEG derivative when a photo is saved, and read every hot
   path from that instead of from the 2560px HEIC original.** Today every
   thumbnail in the app — the map's eighty blocks, every gallery cell, every
   tower block, every filmstrip card — pays a full-resolution HEIC decode.
2. **Stop the map hiding a block until its photograph has decoded.** A block
   that is not drawn cannot be found, and "hard to find things on the map
   because they won't load" is that gate, exactly.
3. **Give visible work its own lane and prefetch ahead of the scroll.** One
   queue at one priority means the cell under the thumb waits behind eighty it
   is not looking at, and nothing is ever started before it is needed.

---

## 1. Where the time actually goes

### 1.1 The path, end to end

This is what happens between "a view wants this picture" and "pixels on screen",
for every thumbnail in the app. Line references are to the files as they stand.

| # | Step | Where | Thread | Cost |
|---|------|-------|--------|------|
| 1 | View body calls `ThumbnailStore.shared.state(for:width:)` | `CachedImageView.shown` | main | ~0 |
| 2 | `bucket(width)` rounds up to one of `[128,256,384,512,768,1024]` | `ThumbnailStore.bucket` | main | ~0 |
| 3 | `slot(key).generation` is read → this view now observes this photo | `ThumbnailStore.image` | main | ~0 |
| 4 | `ImageManager.cachedThumbnail` → `NSCache` hit, or `recoverLive` (weak table) | `ImageManager` | main | ~0; **warm path ends here** |
| 5 | Miss: in-flight cap checked; either `schedule(key)` or push to `deferred` | `ThumbnailStore.image` | main | ~0 |
| 6 | `Task { @MainActor }` → `await ImageManager.loadThumbnail` | `ThumbnailStore.schedule` | main | one task hop **per photograph** |
| 7 | `withCheckedContinuation` → `ioQueue.async` | `ImageManager.loadThumbnail` | main → io | queue hop |
| 8 | `CGImageSourceCreateWithURL(… kCGImageSourceShouldCache: false)` | `ImageManager.downsample` | io | mmap, header parse |
| 9 | `CGImageSourceCreateThumbnailAtIndex` with `CreateThumbnailFromImageAlways: true`, `ThumbnailMaxPixelSize: w`, `ShouldCacheImmediately: true`, `CreateThumbnailWithTransform: true` | `ImageManager.downsample` | io | **the whole cost: a full 2560px HEIC decode, then a resample to `w`** |
| 10 | `UIImage(cgImage:)` | io | ~0 |
| 11 | continuation resumes → back on the calling actor | main | hop |
| 12 | `thumbnailCache.setObject(cost:)`, `liveThumbnails.setObject` | `ImageManager.loadThumbnail` | main | ~0 |
| 13 | `loading.remove`, `missing` update, `slot(key).generation &+= 1`, `pump()` | `ThumbnailStore.schedule` | main | ~0 |
| 14 | Observation fires → **only the views that read this slot** re-evaluate | SwiftUI | main | one body per asking view |
| 15 | Body re-runs, step 4 now hits, `Image(uiImage:)` is built | main | ~0 |
| 16 | `.transition(.opacity.animation(GridConstants.imageFadeIn))` | `CachedImageView.body` | render | the fade's own duration before the picture is at full strength |

Steps 1–5 and 11–15 are already cheap and already correct. **Step 9 is the
whole problem, and steps 6/7 and the absence of any step before step 1 are what
turn one slow decode into a screen that cannot keep up.**

### 1.2 Every avoidable cost, named

**(A) Every thumbnail decodes a 2560px original. Avoidable.**
`ImageManager.storedMaxDimension = 2560`, and its doc comment records why: 1024
was upscaling in the viewer, and the measured file sizes were
`cap 1024 → 45 KB`, `cap 2048 → 115 KB`, `cap 2560 → ~160 KB`. That decision is
right for the *viewer*. But `downsample` points `CGImageSourceCreateThumbnailAtIndex`
at that same file for every thumbnail, with `kCGImageSourceCreateThumbnailFromImageAlways: true`,
which by definition decodes the full image and then scales it. A 2560×1177
frame is **3.0 megapixels decoded to produce a 384×177 thumbnail worth
0.068 megapixels** — 44× the pixels that reach the screen. Multiply by up to 80
blocks on the map.

**(B) The originals are HEIC, and HEIC decodes about twice as slowly as JPEG.
Avoidable.** `ImageManager.save` chooses `public.heic` whenever
`CGImageDestinationCopyTypeIdentifiers()` offers it, which is every modern
device. PSPDFKit's device benchmark measured **HEIC decode at 2.1× JPEG**, and
found it *slower on newer silicon* despite hardware support
([PSPDFKit/Nutrient, "iOS HEIC Performance", 2018](https://www.nutrient.io/blog/ios-heic-performance/)).
HEIC is the right choice for the stored original — it is a third the bytes at
the same quality. It is the wrong choice for a file that exists to be decoded
sixty times a second.

**(C) Nothing survives a relaunch. Avoidable.** `thumbnailCache` is an
`NSCache` and `liveThumbnails` is an `NSMapTable` with weak values. Both are
process memory. Every cold launch re-decodes the map, the gallery and the tower
from scratch. There is no disk cache of decoded-ready derivatives anywhere in
the app.

**(D) The width buckets overshoot by roughly 2× in pixels, on all four hot
surfaces. Avoidable.** `ThumbnailStore.widthBuckets = [128, 256, 384, 512, 768, 1024]`
and `bucket()` rounds **up**. Working the real widths out from the constants in
the tree (`GridConstants.blockReferenceCell = 86.5`,
`GridConstants.horizontalPadding = 16`, `GridConstants.spacing = 4`,
`PlaceBlock.cell = 44`, `PhotoGalleryGrid.gutter = 2`, `Filmstrip.side = 74`) at
`displayScale = 3`:

| surface | drawn width | asked (px) | bucket | linear overshoot | **pixel overshoot** |
|---|---|---|---|---|---|
| tower 1×1 block | 86.5pt | 260 | 384 | 1.48× | **2.18×** |
| tower 2×2 block | 177pt | 531 | 768 | 1.45× | **2.09×** |
| map block (`PlaceBlock.decodeWidth`) | ~90pt | 271 | 384 | 1.42× | **2.01×** |
| gallery cell (402pt screen) | 132.7pt | 398 | 512 | 1.29× | **1.65×** |
| gallery cell (440pt screen) | 145.3pt | 436 | 512 | 1.17× | **1.38×** |
| gallery cell (375pt SE) | 123.7pt | 371 | 384 | 1.03× | **1.07×** |
| filmstrip card | 74pt | 222 | 256 | 1.15× | **1.33×** |
| month 1-cell block | ~85pt | 255 | 256 | 1.00× | **1.00×** |

The ladder was chosen so that nearby sizes share a decode — the comment on
`widthBuckets` says so, and cites the filmstrip and the month block landing
together on 256, which they do. But the three biggest consumers by volume
(tower, map, gallery) each land just past a rung and pay roughly double the
pixels, in both decode time and cache cost. Note the gallery straddles the
384/512 boundary depending on phone width, so the same code decodes 1.07× on an
SE and 1.65× on a 16 Pro.

**(E) The in-flight cap is sized for slow decodes and throttles hard under a
fling. Avoidable, but only after (A).** `ThumbnailStore.maxInFlight = 48`; asks
past it go to `deferred`. A freed place is handed back by `pump()`, which bumps
the deferred key's slot so its view asks again and holds the place for
`reaskGrace = 250ms`; `pump()` reschedules itself on that same 250 ms. So the
drain rate for deferred work is bounded at roughly 48 per 250 ms, and each
re-ask costs a full main-actor body evaluation. On a fling past a hundred cells
this is the mechanism by which "the images can't keep up" — but 250 ms is
exactly the right number when a decode takes 80 ms and exactly the wrong one
when it takes 3 ms.

**(F) There is no prefetch anywhere except one beat on the map. Avoidable.**
The only lookahead in the app is `PlaceBlock`'s
`.task(id: upcoming) { if let upcoming { _ = isDecoded(upcoming) } }` — the map
reads the *next* slideshow frame a beat early. The gallery, the filmstrip, the
tower and the month tower all ask only when a view is being drawn. A
`LazyVGrid` builds a cell when it is at or just past the viewport edge, so the
decode starts with roughly zero rows of lead. A fling crosses a screen in
~150 ms; a cold decode today does not fit in that.

**(G) Two main-actor hops and one `Task` per photograph. Partly avoidable.**
`ThumbnailStore.schedule` creates a `Task { @MainActor }` per key. Eighty map
blocks is eighty main-actor tasks whose only job is to `await` and then write
three dictionaries. The decode itself is correctly off-main on
`ImageManager.ioQueue` and must stay there.

**(H) The viewer decodes full-resolution, uncached, three at a time.
Avoidable.** `PhotoViewer.loadWindow` keeps `[index, index+1, index-1]` and
calls `ImageManager.loadFullImage`, which is documented "Not cached". A
2560×1177 decode is 3.0 MP = **12 MB of RGBA**, so the window is ~36 MB, and
every page turn drops one and decodes another. Paging back to a picture you saw
four swipes ago decodes it again from scratch. Worth noting the window ordering
was already fixed once — `loadWindow`'s comment records the owner's "the photo
loading is slow" being caused by the visible picture queueing behind its
neighbour — so the *ordering* is right and the *cost per item* is what is left.

**(I) One delete flushes the whole thumbnail cache. Avoidable.**
`ImageManager.deleteImage` calls `forgetAllThumbnails()`, which empties both the
`NSCache` and the weak live table, "because NSCache can't enumerate by prefix".
So removing one photograph in the viewer costs the gallery underneath every
thumbnail it had. `pruneOrphans` does the same on any non-zero result.

**(J) The fade adds its own duration to every cold arrival. Not avoidable, and
should not be.** `CachedImageView` fades in on `GridConstants.imageFadeIn` and
holds the shimmer placeholder underneath for `imageFadeInDuration` after. This
is correct and load-bearing (CLAUDE.md: *a crossfade must never reveal what is
under it*), and it does **not** fire on a warm hit — `.animation(…, value: image != nil)`
needs the value to *change*, and on a cache hit the first body already has the
image. Leave it alone. It is only worth naming because it means the target for
a cold cell has to include it.

**(K) The map will not draw a block until its photograph is in memory.
Avoidable, and it is the specific complaint.** `PlaceBlock` gates `arrive()` on
`pictureReady`, which is `ThumbnailStore.state(…).image != nil`. `waitForPicture()`
gives up after 600 ms and arrives anyway — showing `waitingFill` grey, which is
the outcome the gate exists to prevent. So during a pan the map is *genuinely
empty* for up to 600 ms per block, and when the 48-place queue is full it is
empty for longer and then shows grey regardless.

**(L) The map's ask order is declaration order, not screen order. Avoidable.**
`MemoriesMapView` already maintains `drawn.ids` — exactly "which blocks MapKit
is drawing right now" — and uses it only inside `apply()`. Nothing orders the
decode queue by it. The block under the thumb can be sixtieth in line behind
blocks scrolled past the screen edge (MapKit keeps annotation views for those;
`apply()`'s doc comment records this).

**(M) The map's slideshow doubles the working set. Partly avoidable.** Every
block asks for `upcoming` on every `tick`, so a map of forty places holds forty
pictures nobody is looking at yet, at the same 384px bucket. Correct in intent
(it is what stops a handover fading in grey — the owner's *"find a way that the
photo always can stay and casually change"*), wrong in priority: it should be
prefetch-lane work, not visible-lane work.

### 1.3 Per surface, shortest version

- **Map** — (A)+(B)+(D) make each decode expensive, (L) puts them in the wrong
  order, (E) throttles them, (K) hides the block while it waits, and (M) doubles
  the count. Five compounding causes on one screen. This is why the map is the
  loudest complaint.
- **Gallery scroll** — (A)+(B)+(D: 1.65× on the owner's phone) make each cell
  expensive, (F) means nothing starts until the cell is already on screen, and
  (E) throttles the drain. Nothing else.
- **Tower** — (A)+(B)+(D: 2.18×). No prefetch, but a tower scroll is slower than
  a gallery fling and the block has its own colour to show, so it reads as calm
  even when it is slow. Note `FlippableBlockView` passes no `decodeWidth`, so a
  block's bucket follows its drawn size — fine, because a tower block does not
  change size.
- **Month tower** — same as the tower, plus `DayPhotoSlideshow` holding two
  slots per block. `CachedImageView(showsPlaceholder: false)` is correct here.
  The drawer's `\.memoriesDrawerVisible` gate already stops it running under the
  map; keep that.
- **Viewer** — (H). Three 12 MB decodes, uncached, re-run on every return.
- **Replay** — already the best-behaved path in the app. `ReplayImages.load`
  sizes each decode to its largest block (`decodeSide`), runs a task group, and
  bypasses the buckets deliberately. It still pays (A) and (B) per photograph,
  and it runs at default priority, so a replay warming up competes with a
  gallery the user is actually scrolling.
- **Album covers** — `AlbumCoverView` asks at `side`, `showsPlaceholder` default
  (on). Low volume; inherits (A)/(B)/(D).
- **Widget / Spotlight** — *not read; unverified.* Both are cold, out-of-process
  or one-shot, and both would benefit from a pre-baked small derivative simply
  by being able to read a 20 KB file instead of decoding a 2560px HEIC inside a
  memory-limited extension. Treat this as a hypothesis until someone reads
  `WidgetSnapshot`.

### 1.4 Measurements already in the tree

Quote these rather than re-deriving them; they were expensive.

- **The decode queue.** `ImageManager.ioQueue`'s comment, at 80 cold
  thumbnails: serial `3.0× slower`; concurrent with a blocking semaphore
  `stalls under load`; `Task.detached` on the cooperative pool `545 ms (1.53×)`;
  concurrent with nothing blocking `215 ms (5.12×)` — which is what ships.
  **Do not re-open this.** Any new lane must be a non-blocking concurrent GCD
  queue.
- **Per-key observation.** `ThumbnailStore`'s comment, 2026-09-15, over a
  365-day seed with `-strataPerfProbe`: with one global version the photo viewer
  ran **~4,000 image-view bodies a second** and the idle map **~1,000**, and
  neither settled. **Do not re-open this either.**
- **Eviction of on-screen pictures.** `ImageManager.liveThumbnails`' comment:
  the filmstrip dimming and re-fading after a switch to dark mode, because
  replay posters for the new scheme pushed the strip's thumbnails out of a
  100-entry cache. The weak table is the fix and must survive any rewrite.
- **Cache sizing.** `ImageManager.init`: `countLimit = 300`,
  `totalCostLimit = 150 MB`, with the comment that 100 was "four screens of the
  gallery, or the map's eighty blocks and not much else".
- **Storage.** `pruneOrphans`' comment: **3,127 photographs, 522 MB** on a real
  phone before any cleanup existed — ~167 KB each. That is the number the disk
  budget below is built on.
- **Stored size.** `storedMaxDimension`'s comment: `1024 → 45 KB`,
  `2048 → 115 KB`, `2560 → ~160 KB` on a synthetic full-screen frame, with the
  note that a real camera photograph is "a few hundred KB".
- **Replay decode sizing.** `ReplayImages.decodeSide`'s comment: sizing a 1×1's
  decode to its own block rather than two cells took it to **44% of the pixels**.

---

## 2. The system

Six mechanisms. Each is independently shippable; the order is in §5.

### 2.1 Pre-baked derivatives at save time

**The rule: no hot path ever opens the 2560px original.**

Two derivative tiers, written as **JPEG** (not HEIC — see (B)), in a
**subdirectory** of the image directory:

    strata-images/
      <uuid>_<suffix>.heic          the original, unchanged
      derived/
        <uuid>_<suffix>@320.jpg     tier S — baked eagerly at save
        <uuid>_<suffix>@640.jpg     tier M — baked lazily on first ask, evictable

**Why 320 and 640.** From the table in (D): tier S at 320px covers the
filmstrip (222), the month 1-cell (255), the tower 1×1 (260) and the map (271)
with at most 1.55× pixel overshoot and no upscaling. Tier M at 640 covers the
gallery on every phone width (371–436), the tower 2×2 (531) and album covers.
Anything above 640 falls through to the original, which is the viewer, share,
and the replay's largest blocks.

**Disk cost, honestly.** JPEG q0.80 at 320px longest side is roughly 18–25 KB
for a photographic frame; at 640px roughly 60–90 KB. Against the measured
~167 KB average original:

| | per photo | 1,000 photos | 3,127 photos (the measured library) |
|---|---|---|---|
| originals today | 167 KB | 167 MB | 522 MB |
| + tier S always | +22 KB (**+13%**) | +22 MB | +69 MB |
| + tier M for all | +75 KB (+45%) | +75 MB | +234 MB |
| + tier M under a 96 MB LRU cap | ≤ +96 MB | +75 MB | **+96 MB** |

So: **bake S eagerly for everything** (13% is a fair price and it is the tier
the map and tower live on), and **bake M lazily with a byte cap**, evicted LRU.
Settings' storage figure must include `derived/`.

**Two traps that must be handled in the same change:**

1. **`pruneOrphans` will delete the derivatives — and then the whole folder.**
   It lists `imageDirectory` non-recursively and calls
   `FileManager.removeItem(at:)` on anything whose `lastPathComponent` is not in
   `referenced`. `derived` is a directory URL, its name is not a referenced file
   name, and `removeItem` on a directory is recursive. So the first prune after
   this ships would delete every derivative in the app. `pruneOrphans` must skip
   it explicitly, and gain its own pass that removes a derivative whose original
   is gone. Its doc comment already calls it "the most dangerous function in the
   app"; this is why.
2. **`storageUsed()` must walk `derived/` too**, or Settings reports a number
   that is no longer true. Its comment insists the number people check has to be
   true; that is a promise this change can break.

**The baker.**

```
actor DerivativeBaker {
    static let shared = DerivativeBaker()
    // Idempotent by construction: the work item is "originals with no @320.jpg".
    // There is no cursor to persist and nothing to corrupt if the app is killed.
    func bakeIfNeeded(_ fileName: String, tier: Tier) async -> URL?
    func migrate() async     // walks the directory, yields between each
}
```

- **Background, idempotent, resumable.** Resumability is a property of the work,
  not of saved state: the set of un-baked originals is recomputed by a directory
  listing each time. Killing the app mid-migration loses at most one file's
  work.
- **Priority.** `.background` QoS, and additionally suspended while
  `ThumbnailStore` has anything in `loading` — visible work outranks it
  absolutely. One file per iteration with a `Task.yield()` between.
- **Driven by** a foreground trickle while the app is idle plus a
  `BGProcessingTask` for a real library. 3,127 photos at ~60 ms each (one HEIC
  decode + one small JPEG encode) is roughly 3 minutes of CPU — not something
  to do in a foreground burst.
- **Safety.** It only ever *creates new files under `derived/`*. It never
  reads-then-writes an original, never deletes one, and never touches
  `HabitLog.imageFileName`. CLAUDE.md's rule — *never delete or rewrite image
  files on a code path that only meant to read them* — is satisfied by
  construction, and should be stated in the file's doc comment so the next
  person does not "optimise" it into an in-place rewrite.
- **Colour space.** Write the derivative explicitly as 8-bit sRGB (or 8-bit
  Display P3 if the original is wide-gamut and the loss matters on a block). A
  16-bit wide-gamut original produces a 16-bit `CGImage`, which doubles both
  decode time and `ImageManager.cost(of:)` — and `cost(of:)` assumes 4 bytes per
  pixel, so a 16-bit image is *silently charged half what it uses*. Forcing
  8-bit at the derivative makes that assumption true again.

**The save hook.** `ImageManager.save(image:for:maxDimension:quality:)` is the
single writer of originals in the app (`DebugHarness.seedPhoto` deliberately
bypasses it and writes straight to the directory, for the documented deadlock
reason — the seeder must therefore *also* call the baker, or every fixture will
exercise the fallback path and the derivative path will never be tested).
Bake tier S inside `save`, on the same `ioQueue.async` block, from the already
resized `UIImage` — so it costs one extra small encode and **no extra decode**.

### 2.2 A two-level cache

**L1 — memory. Keep exactly what is there; change only the sizing.**

`NSCache<NSString, UIImage>` plus the `NSMapTable` weak live table. Both are
right and both were paid for. The cost model
(`w × h × scale² × 4`) stays, and becomes accurate once derivatives are 8-bit.

Change the ceiling from a constant to a fraction of the device:

```
let physical = ProcessInfo.processInfo.physicalMemory
thumbnailCache.totalCostLimit = Int(min(192 << 20, physical / 32))
thumbnailCache.countLimit     = 600
```

On a 6 GB phone that is **192 MB** (6 GB / 32 = 192 MB); on a 3 GB phone 96 MB.
`NSCache` still empties itself under memory pressure, which is the real
backstop. **Raise `countLimit` only after §2.1 ships** — the point of 600 is
that a tier-S entry at 320×240 is ~300 KB against a 384×288 original-sourced one
at ~440 KB, so more entries fit in the same bytes. Raising the count first would
just hold more expensive things (see §6).

**L2 — disk. The derivatives *are* the disk cache.**

There is no second cache to keep coherent, which is the point: a derivative is a
pure function of an original, named after it, and invalidated by its deletion.

- Tier S: not evictable. Tied to the original's lifetime.
- Tier M: LRU under a byte cap (start at 96 MB), swept at launch and on a low
  disk-space notification, ordered by `.contentAccessDateKey`.
- **What survives a relaunch:** everything on disk. The memory cache never
  survives, and that is correct — reconstituting it costs a 3 ms JPEG decode
  per visible cell instead of an 80 ms HEIC one.

**Interaction with the width buckets.** The buckets now choose a *file*, not a
downsample target:

```
bucket(px) ≤ 320  →  derived/@320.jpg
bucket(px) ≤ 640  →  derived/@640.jpg   (bake on demand)
otherwise         →  the original
```

Inside a tier, `downsample` runs exactly as it does today, on a file 1/50th the
pixels. When the bucket equals the tier's own size, skip the resample entirely
and call `CGImageSourceCreateImageAtIndex` with `kCGImageSourceShouldCacheImmediately: true`.

**The `decodeWidth` escape hatch is untouched.** `PlaceBlock.decodeWidth` — one
width for every block on the map whatever size it draws at — is a settled
decision (CLAUDE.md) and still stands on top of the buckets, exactly as its
comment says. With tiers it gets *stronger*: every map block at every zoom now
resolves to the same file as well as the same key.

### 2.3 Prefetching

**Knowing the scroll, on iOS 18 and iOS 26.** The deployment target is 18.0, and
all of these are iOS 18+, so no availability gate is needed:

- `onScrollGeometryChange(for:of:action:)` — transforms `ScrollGeometry`
  (`contentOffset`, `containerSize`, `contentSize`, `visibleRect`) into an
  `Equatable` value and calls the action when it changes. This is the offset,
  every frame. `PhotoViewer.deck` **already uses it** to publish the deck's
  fractional page — so the pattern is in the codebase and proven.
- `onScrollPhaseChange(_:)` — `ScrollPhase` is
  `.idle / .tracking / .interacting / .decelerating / .animating`, with
  `isScrolling`, plus a context carrying the scroll velocity on the change.
  This is what distinguishes a fling from a drag from a settle.
- `onScrollTargetVisibilityChange(idType:threshold:_:)` — hands back the ids
  currently considered visible. Requires `.scrollTargetLayout()` on the content
  container and an explicit `.id` on each child. This is the cleanest source of
  "which cells are on screen" and avoids computing index ranges from offsets.
- `ScrollPosition` — for driving position, not reading velocity. Not needed
  here.

Caveat worth knowing: `onScrollGeometryChange` and `onScrollPhaseChange` only
respond to the **outermost** scroll view in the hierarchy, so they go on the
Memories scroll view, not on `PhotoGalleryGrid`'s `LazyVStack`.

Sources: [Swift with Majid, "Mastering ScrollView in SwiftUI: Scroll Geometry", 25 Jun 2024](https://swiftwithmajid.com/2024/06/25/mastering-scrollview-in-swiftui-scroll-geometry/) ·
[Swift with Majid, "Scroll Visibility", 16 Jul 2024](https://swiftwithmajid.com/2024/07/16/mastering-scrollview-in-swiftui-scroll-visibility/) ·
[Augmented Code, "ScrollView phase changes on iOS 18", 15 Jul 2024](https://augmentedcode.io/2024/07/15/scrollview-phase-changes-on-ios-18/) ·
[Fatbobman, "The Evolution of SwiftUI Scroll Control APIs", 2024](https://fatbobman.com/en/posts/the-evolution-of-swiftui-scroll-control-apis/) ·
[Apple, `onScrollTargetVisibilityChange(idType:threshold:_:)`](https://developer.apple.com/documentation/swiftui/view/onscrolltargetvisibilitychange(idtype:threshold:_:))

**The gallery grid.**

```
@State private var lead: Int = 0          // signed rows of lookahead
@State private var flinging = false

.onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { old, new in
    direction = new > old ? .down : .up
}
.onScrollPhaseChange { _, phase, context in
    flinging = abs(context.velocity.dy) > 2000        // pt/s
}
.onScrollTargetVisibilityChange(idType: GalleryPhoto.ID.self) { visible in
    store.prefetch(rowsAhead: flinging ? 0 : 3, from: visible, direction: direction)
}
```

- **Ahead only.** Three rows (nine cells) in the direction of travel. Behind the
  scroll, nothing is asked for and nothing is kept warm beyond the cache's own
  LRU.
- **Cancel behind.** `ThumbnailStore` already has most of this: a deferred key
  whose view stopped asking simply never asks again and its reserved place
  expires after `reaskGrace`. Make it explicit — `cancel(keys:)` removes from
  `deferred` and marks a `cancelled` set that the queue block checks before
  decoding.
- **When the user flings past a hundred cells:** at `|velocity| > 2000 pt/s`,
  **stop prefetching and stop scheduling** — a decode that lands after its cell
  has left the screen is pure waste and it is also the thing that starves the
  cells that stop. During a fling the grid shows its shimmer, which is the
  correct and honest thing for an edge-to-edge camera roll. On `.decelerating`,
  resume prefetch at reduced lead; on `.idle`, full lead. This is the standard
  answer (UIKit's `prefetchDataSource` does effectively the same via
  `cancelPrefetchingForRowsAt`) and it is what turns a fling from "a queue
  draining behind me" into "a blur that resolves the moment I stop".

**The filmstrip.** `Filmstrip` already draws `reach = 8` cards either side of
the middle, and draws them through `CachedImageView`, so the ask is already ±8.
No new prefetch is needed; what it needs is **priority** — the card under the
finger and its two neighbours are visible-lane, the rest are prefetch-lane.

**The map.** `MemoriesMapView.DrawnBlocks` already holds exactly the right set.
Use it:

1. Visible lane, ordered by `cluster.winCount` descending (the biggest block is
   the largest thing on screen and the first thing the eye lands on), tie-broken
   by distance from screen centre.
2. Prefetch lane: clusters in `displayed` but not in `drawn` — the ring MapKit
   is holding just past the edge.
3. Prefetch lane: `PlaceBlock.upcoming`, the next slideshow frame. It is
   currently asked at the same priority as the picture on screen; it should not
   be.

**Replays.** `ReplayImages.load` is already a task group and already sizes each
decode correctly. Move it to the prefetch lane so warming a replay cannot
outrank a gallery the user is scrolling, and keep the up-front load — the
comment explaining why (`ImageRenderer` does not wait for an async decode, so
the video would come out with coloured blanks) is load-bearing.

### 2.4 Priority

Three lanes. Each is a **non-blocking concurrent `DispatchQueue`** — the
measured shape in `ImageManager.ioQueue`. **Never a semaphore** (measured:
stalls under load) and not the cooperative pool (measured: 1.53× vs 5.12×).

| lane | QoS | in-flight cap | what |
|---|---|---|---|
| `visible` | `.userInitiated` | 32 | a view that is drawing asked for it |
| `prefetch` | `.utility` | 8 | ahead-of-scroll, the map's ring, `upcoming`, replay warm-up |
| `bake` | `.background` | 2, and gated on `loading.isEmpty` | the migration |

QoS does the arbitration; the caps stop any one lane monopolising the pool.
`maxInFlight` becomes per-lane, and `reaskGrace` drops from **250 ms to ~32 ms**
once a decode is single-digit milliseconds — 250 ms was correctly sized for an
80 ms HEIC decode and becomes the dominant latency once the decode is 3 ms.

**Cancellation.** `CGImageSourceCreateThumbnailAtIndex` cannot be interrupted,
so cancellation has to happen before dispatch: a `cancelled: Set<Key>` checked
at the top of the queue block. With tier-S derivatives a decode is a few
milliseconds, so an uncancellable decode stops being a problem worth solving —
which is itself an argument for doing §2.1 before §2.4.

**A decode gets cancelled when its cell scrolls away** by three mechanisms in
order of cheapness: (1) the view stops asking, so a deferred key is never
re-asked and its reserved place expires; (2) an explicit `cancel(keys:)` from
the prefetcher on direction change; (3) the `cancelled` set for work already
queued.

### 2.5 Decode ergonomics

**`CGImageSourceCreateThumbnailAtIndex`** with
`kCGImageSourceCreateThumbnailFromImageAlways: true`,
`kCGImageSourceThumbnailMaxPixelSize`, `kCGImageSourceShouldCacheImmediately: true`
and `kCGImageSourceCreateThumbnailWithTransform: true` is **right** for reading
a file at a chosen pixel size, and is exactly what `ImageManager.downsample`
does. Two notes:

- `...FromImageAlways` forces a full decode of the source. That is required
  today because our HEIC files carry no useful embedded preview —
  `encodeHEIC` adds one image via `CGImageDestinationAddImage` and no thumbnail.
  Once we read from a 320px derivative the flag costs nothing, because the
  source *is* the target size.
- `ShouldCacheImmediately` moves the decode to the moment of the call rather
  than to first draw, which is the entire point of doing it on a background
  queue. Setting `kCGImageSourceShouldCache: false` when *creating the source*
  and `ShouldCacheImmediately: true` when creating the thumbnail — which the
  code does — is the documented pairing that gives you full control of when the
  CPU hit lands. ([Swift Senpai, "Reducing Memory Footprint When Using UIImage"](https://swiftsenpai.com/development/reduce-uiimage-memory-footprint/) ·
  [Swiftjective-C, "Optimizing Images"](https://www.swiftjectivec.com/optimizing-images/) ·
  originally [WWDC18 "Image and Graphics Best Practices"](https://nonstrict.eu/wwdcindex/wwdc2018/219/))
- Always pass `ThumbnailMaxPixelSize`. Without it you get a thumbnail the size
  of the full image.

**`UIImage.byPreparingForDisplay()` / `byPreparingThumbnail(ofSize:)`** (iOS 15+,
async, run off the main thread) are right when you **already hold a `UIImage`**
and cannot go back to the file — an asset-catalogue image, a `UIImage` handed to
you by a picker, a `UIImage` you just rendered. `ReplayImages.decodeBundled`
uses `byPreparingThumbnail` for precisely that case and is correct. They are the
wrong tool for a file on disk, because they require the full image decoded into
memory first, which is the cost we are trying to avoid.
([PSPDFKit, "Loading Images on iOS 15", 2021](https://pspdfkit.com/blog/2021/ios-15-image-api/))

**Why decoding on the main actor is the thing to avoid.** At 60 Hz the frame
budget is 16.67 ms and at 120 Hz it is 8.33 ms. A 2560px HEIC decode is an order
of magnitude over both. One on the main thread is a visible hitch; nine (a
gallery row) is a freeze. The current code is already off-main and the risk in
any rewrite is re-introducing it accidentally — the classic way is calling
`UIImage(contentsOfFile:)` or touching `.cgImage` inside a `body`. `PerfProbe`'s
`[PERF-HITCH]` line (any display-link gap over 50 ms) is the alarm for this and
should be in the acceptance criteria of every task in §5.

### 2.6 What the user sees while waiting

**The rule stays: a block is a coloured block that becomes a photograph.**

| surface | while waiting | how it arrives |
|---|---|---|
| **Tower** | the block's own category colour (`showsPlaceholder: false` — already right) | fade on `imageFadeIn`, over the opaque colour |
| **Month tower** | the day's category colour, day numeral on top (already right) | two-slot crossfade, outgoing held opaque underneath (already right) |
| **Map** | the block, **drawn immediately**, on `PlaceBlock.waitingFill` | picture fades in on top of the opaque fill |
| **Gallery** | the shimmer placeholder, held at full strength *under* the arriving picture | already right; target is that it is rarely seen |
| **Album cover** | the 4%-black slot, then the picture | already right |
| **Viewer** | black, then the **tier-M derivative**, then the full-resolution swap | fade to M; the M→full swap is invisible at fit scale |
| **Filmstrip** | shimmer card | already right |

The only change is the map, and it is change (2) from §0 — see §3.

**Tiny blurred placeholder (BlurHash / ThumbHash) versus the block's colour:
use the colour. Do not add a blur hash.** Four reasons, in the app's own terms:

1. **The colour is information; a blur is a guess.** A tower block's colour is
   its category — CLAUDE.md is explicit that colour and category are two facts
   and that getting them confused claims something untrue. Replacing a fact with
   a smeared approximation of the photograph is a downgrade.
2. **It is a third state.** Colour → blur → photograph is two handovers where
   there is currently one, on a screen that can hold eighty of them. *Premium is
   subtraction.*
3. **It costs a schema field and a migration** on `HabitLog` for every
   photograph ever taken, for a benefit that only exists during the wait.
4. **After §2.1 the wait is 10–40 ms.** A placeholder that flashes for two
   frames is worse than no placeholder. Blur hashes earn their place when the
   wait is a network round trip; here it is a local JPEG decode.

The one honest exception is the **widget**, which cannot decode on demand inside
its memory budget — but the widget already renders from a snapshot, so a
pre-baked tier-S file solves it more simply than a hash would. *(Unverified — I
have not read `WidgetSnapshot`.)*

**And the rule that must not break:** at every instant of a handover, something
opaque covers what must not show through. The block's colour, `waitingFill`, or
the outgoing picture held at full opacity underneath. `BlockSurface`,
`PlaceBlock` and `DayPhotoSlideshow` each document this the hard way; nothing
here changes it.

---

## 3. The map specifically

### Why finding things on the map feels slow

Five causes compounding, all identified in §1.2:

1. **A block is invisible until its photograph decodes** (`PlaceBlock.pictureReady`
   gating `arrive()`), for up to 600 ms, and longer when the queue is full — at
   which point `waitForPicture()` shows it grey anyway, which is the outcome the
   gate was written to prevent. **This is the literal text of the complaint.**
2. **Each decode is a 2560px HEIC at a 384px bucket** — 2.01× the pixels drawn,
   at 2.1× the per-pixel cost of JPEG.
3. **The ask order is `displayed` order**, not screen order, though `drawn.ids`
   already knows the screen order.
4. **`apply()` runs on every quarter-zoom step**, re-clustering and re-keying
   `justArrived` / `carry` — correct, but it means a pinch produces several full
   rounds of asks.
5. **`upcoming` doubles the working set** at the same priority as what is on
   screen.

### What to load first

In strict order, all through the visible lane:

1. **The user's own area on a cold open.** `frameOnYourPlaces()` decides the
   opening region before any block exists, and `goToMe()` decides it on the
   recentre press. Both are the earliest possible moment to start decoding —
   hand the clusters inside that region to the store as soon as the camera is
   set, not when MapKit gets round to making the annotation views.
2. **The largest block in view.** `cluster.winCount` descending. A 2×2 is four
   times the area of a 1×1 and is where the eye goes; it is also the block whose
   grey square is most visible.
3. **Then by distance from screen centre** — the same ordering
   `arrivalDelay(for:)` already uses for the stagger, so the decode order and
   the arrival order agree instead of fighting.
4. **Then the ring**, prefetch lane: `displayed` minus `drawn`.
5. **Then `upcoming`**, prefetch lane.

### What to hold in memory as the camera moves

Everything in `drawn`, plus one ring. Two things already guarantee this and must
not be undone:

- `liveThumbnails` (weak values) means a picture something still holds cannot be
  evicted from under it. This was the filmstrip-dimming fix.
- `PlaceBlock.decodeWidth` — **one width for every block on the map** — means a
  block's key does not change with zoom, so its picture stays in the cache
  across every camera move. CLAUDE.md lists this as settled.

### Keeping a picture on a block while zooming

**This was already fixed and must not be undone.** `MemoriesMapView.apply()`
implements `carry`: a new cluster that holds a photograph an on-screen block was
just showing **opens on that photograph**, already decoded, so zooming out the
picture you were looking at becomes the joined block's picture. Its doc comment
records the owner's own words and three filmed failure modes. Combined with
`decodeWidth`, that is the existing answer to "the photo always can stay and
casually change", and nothing in this spec touches either. Tiering makes both
stronger: every zoom level now resolves to the same *file* as well as the same
cache key.

### The one change

**Remove the `pictureReady` gate on `arrive()`.** The block arrives on its own
`mapFade`, on `waitingFill`, and its photograph fades in on top when it lands.

This is a **documented decision and needs the owner's yes**: the comment reads
*"A block arrives with its photograph, not before it… Filmed on a zoom out: two
grey squares for a sixth of a second each."* The case for changing it:

- The rule was written to stop **two arrivals** (a grey square appearing, then
  becoming a photograph). The right fix for two arrivals is to make the second
  one imperceptible, not to delay the first one by up to 600 ms.
- After §2.1, a warm block's picture is present on the first body and a cold
  one lands in tens of milliseconds — below the threshold at which the second
  arrival reads as a separate event at all.
- The gate does not actually hold: `waitForPicture()` gives up at 600 ms and
  shows the grey square regardless. So today the app pays the delay **and**
  shows the thing the delay was meant to prevent.
- A block that is not drawn cannot be tapped, cannot be counted and cannot be
  found. "Hard to find things on the map because they won't load" is a
  description of this gate.

**Measure it before and after**, with a burst capture (CLAUDE.md's method: start
the capture *before* the event, count classified frames, never an aggregate):
blocks drawn per frame across a `-strataMapSweep`, and the number of
block-frames showing `waitingFill` with no picture. If the second number goes up
by more than a couple of frames per block, the change is wrong and should be
reverted.

---

## 4. Budgets and targets

Build against these. Every one is measurable with instruments that already exist.

### Latency

| what | cold (not in memory) | warm (in memory) | how measured |
|---|---|---|---|
| gallery cell appears → picture on screen | **p50 ≤ 40 ms, p95 ≤ 90 ms** | ≤ 16 ms (same frame) | `PerfProbe.sample("ThumbAskToShown")` — **already wired**, in `ThumbnailStore.image`; read via `PerfProbe.window`, which prints `n / p50 / p95 / max` |
| map block appears → picture | **p50 ≤ 60 ms, p95 ≤ 150 ms** | ≤ 16 ms | same sample, windowed over `-strataOpenMap -strataMapSweep` |
| map: block drawn at all | **≤ 1 frame** after MapKit makes the view | — | burst capture, count block-frames |
| viewer open → a picture | **≤ 120 ms** (tier M) | — | `PerfProbe.window("PhotoViewer open", seconds: 2)` — already wired |
| viewer open → full resolution | ≤ 400 ms | — | same |
| viewer page turn → picture | ≤ 100 ms | ≤ 16 ms | `PerfProbe.window("PhotoViewer page-turn n")` — already wired, driven by `-strataPhotoAutoPage` |
| tower block appears → picture | p50 ≤ 40 ms | ≤ 16 ms | `ThumbAskToShown` |

### Throughput

| what | target | how |
|---|---|---|
| one tier-S decode (320px JPEG) | **≤ 4 ms** | `-strataBenchImages`, extended to report per tier |
| one tier-M decode (640px JPEG) | ≤ 12 ms | same |
| one full decode (2560px HEIC) | today's `oneFullDecode=` figure; must not regress | same |
| sustained decodes | **≥ 120 tier-S decodes/second** across the visible lane | `-strataBenchImages 200`, concurrent figure |
| concurrent-vs-serial speedup | **≥ 4×** (it is 5.12× today at n=80) | `-strataBenchImages 200` — and pass 80+, per the harness's own warning that a 30-image run reported 8× for a pipeline that stalled |

### Memory, 6 GB phone

| what | ceiling | how |
|---|---|---|
| L1 thumbnail cache cost | **192 MB** (`min(192 MB, physicalMemory/32)`) | assert `totalCostLimit`; Instruments allocations |
| viewer full-resolution window | **≤ 40 MB** (3 × ~12 MB) | Instruments |
| app footprint, map full + drawer open | ≤ 420 MB | Instruments |
| memory warnings during a 2-minute mixed session | **0** | `didReceiveMemoryWarning` counter in DEBUG |

### Frame budget during a fling

| what | target | how |
|---|---|---|
| display-link gaps > 50 ms | **0** | `[PERF-HITCH]` lines — any is a failure |
| gaps > 25 ms | **≤ 2%** of frames in the window | `PerfProbe.window` prints `frames= gaps>25ms= maxGap=` |
| `CachedImageView` bodies/s, gallery fling | ≤ 400 | `[PERF] bodies` |
| `CachedImageView` bodies/s, idle map | ≤ 60 | `[PERF] bodies` — the pre-2026-09-15 figure was ~1,000 and must not come back |
| `PhotoViewer` + `Filmstrip` bodies/s, swiping | ≤ 300 combined | `[PERF] bodies` — was ~4,000 with the global version |

### The baseline run

Take this **before task 1 ships**, on the owner's phone, release build:

```
-strataSeedHistory 365 -strataSeedHistoryPerDay 5 -strataSeedTodayPhotos 1 \
-strataSeedPlaces -strataPerfProbe
```

then, separately: `-strataOpenMap -strataMapSweep` · `-strataOpenPhoto 0
-strataPhotoAutoPage 8` · `-strataScrollMemories` · `-strataBenchImages 200`.

Read `Documents/perf.log` back with `simctl get_app_container … data`, not the
unified log — `PerfProbe`'s own comment records that the log store persisted
lines tens of seconds late under load and a `log show` straight after a run came
back short.

**Two things this baseline cannot tell you**, and they must not be claimed:
frame pacing on the device differs from the simulator, and nothing on this
machine can pinch a map or fling a grid with a finger. `-strataMapSweep` and
`-strataPhotoAutoPage` drive the camera and the select path, not the gesture.
`StrataUITests` can do the real gestures and is the only thing that can.

---

## 5. Build plan

Ordered. Each task ships and is testable alone.

---

**1 — Baseline the pipeline. (S)**

Add `PerfProbe.window` calls around the gallery scroll and the map sweep (the
`ThumbAskToShown` *sample* already exists in `ThumbnailStore.image`; it has no
window reporting it outside the viewer). Extend `DebugHarness.runImageBench` to
report per-tier decode times so the same command answers the before and the
after.

*Ship nothing else.* Measure: everything in §4. This is the number every later
claim is checked against.
*Risk to documented decisions:* none.

---

**2 — Bake tier S at save. (M)**

`DerivativeBaker`, written from inside `ImageManager.save`'s existing
`ioQueue.async` block, from the already-resized `UIImage` — one extra small
encode, no extra decode. `DebugHarness.seedPhoto` calls it too, or the fixture
never exercises the new path.

Also in this task, or it is a data-loss bug: **`pruneOrphans` must skip
`derived/`** (today it would `removeItem` the whole directory on its first run),
gain a pass that removes orphaned derivatives, and **`storageUsed()` must walk
`derived/`**.

Measure: a new photo produces both files · `pruneOrphans` leaves them · deleting
an original removes them · Settings' storage figure matches `du`.
*Risk:* `pruneOrphans` is the most dangerous function in the app and this change
touches it. Unit-test it against a real temp directory (it already has
`imageDirectoryForTesting` for exactly this).

---

**3 — Read from derivatives. (M)**

`ImageManager.downsample` picks the smallest derivative ≥ the requested bucket,
falls back to the original when there is none. Tier M baked on demand. **No view
changes at all** — every call site is untouched.

Measure: `ThumbAskToShown` p50/p95 on the gallery and the map, against task 1's
baseline. `-strataBenchImages 200` `oneThumbnail=` before and after.
*Expected:* this is the single biggest move in the document.
*Risk to documented decisions:* none. `decodeWidth`, the per-key `Slot`, the
weak live table and the decode-while-drawing contract are all untouched.

---

**4 — Migrate the existing library. (L)**

`DerivativeBaker.migrate()` at `.background`, suspended whenever
`ThumbnailStore.loading` is non-empty, one file per iteration with a yield,
resumable by directory listing (no persisted cursor), driven by a foreground
trickle plus a `BGProcessingTask`.

Measure: wall-clock to bake 1,000 · **zero `[PERF-HITCH]` lines while it runs** ·
disk delta matches the §2.1 table · killing the app mid-run and relaunching
resumes without duplicate work.
*Risk:* it writes files. Its doc comment must state that it only ever creates
new files under `derived/` and never touches an original.

---

**5 — The map stops hiding blocks. (S)**

Remove the `pictureReady` gate on `PlaceBlock.arrive()`. Keep `carry`, keep
`decodeWidth`, keep the two-slot crossfade, keep `waitForPicture` deleted along
with the gate it served.

Measure: burst capture over `-strataMapSweep` — blocks drawn per frame, and
block-frames showing `waitingFill` with no picture. Start the capture *before*
the sweep (CLAUDE.md: a burst aimed at the map's merge returned 46
byte-identical frames because the sweep finished during the preceding `sleep`).
**Touches a documented decision — needs the owner's yes.** The argument is in
§3; do not ship it silently.

---

**6 — Priority lanes. (M)**

Split `ioQueue` into `visible` / `prefetch` / `bake`, each a non-blocking
concurrent queue. Per-lane in-flight caps (32 / 8 / 2). Drop `reaskGrace` from
250 ms to ~32 ms. Add `cancel(keys:)` and a `cancelled` set.

Measure: `ThumbAskToShown` p95 during a scripted fling · hitch count · that the
concurrent/serial speedup in `-strataBenchImages 200` has not fallen below 4×.
*Risk:* this is the file whose queue shape was measured four ways. **Do not
introduce a semaphore and do not move to `Task.detached`** — both were measured
and both lost. Re-run the bench as part of the acceptance.

---

**7 — Gallery and filmstrip prefetch. (M)**

`onScrollPhaseChange` + `onScrollGeometryChange` + `onScrollTargetVisibilityChange`
on the **outermost** Memories scroll view. Three rows of lead in the direction
of travel; suspend entirely above 2,000 pt/s; resume on `.decelerating`.
Filmstrip: centre card + 2 neighbours in the visible lane, the rest in prefetch.

Measure: p95 ask-to-shown during a scripted fling · hitch count · that the
prefetch is actually ahead (count decodes that land before their cell's first
body). `onScrollTargetVisibilityChange` needs `.scrollTargetLayout()` and an
explicit `.id` on each cell — `PhotoGalleryGrid.cell` has `.matchedTransitionSource`
but I did not see an `.id`, so check that first.
*Risk:* `PhotoViewer.deck` already uses `onScrollGeometryChange`; adding another
on an ancestor is fine, but only the outermost scroll view reports.

---

**8 — Viewer: preview then full. (S)**

`PhotoViewer.loadWindow` shows the tier-M derivative first and swaps to
full-resolution when it lands. Cap the full decode at
`screenLongSide × displayScale × 1.5` rather than the stored 2560 — on a 402×874
phone at 3× that is ~2,620px for a portrait, so in practice this is a no-op on
the biggest phones and a saving on smaller ones. Keep the visible-first ordering
and the `Task.yield()` between decodes; both were paid for.

Measure: `PerfProbe.window("PhotoViewer open")` and the page-turn windows.
*Risk:* the swap must not be visible. `PhotoPage` fades on
`value: image != nil`, which will not fire for an M→full swap of the same
identity — check it does not flicker, by burst capture.

---

**9 — Cache hygiene. (S)**

- `totalCostLimit = min(192 MB, physicalMemory/32)`, `countLimit = 600`.
- Stop `deleteImage` and `pruneOrphans` flushing everything: keep a
  `name → [key]` index so a single file's entries can be evicted by prefix.

Measure: thumbnails re-decoded after deleting one photo in the viewer — should
be **0**, is currently *all of them*.
*Risk:* the index must not keep `UIImage`s alive; store keys only.

---

**10 — Bucket ladder, only if still needed. (S)**

Add 288 and 448, or round up to the next multiple of 32. Do this **after** task
3, and only if the measurement still shows overshoot mattering — once the source
is a 320px JPEG, the overshoot is a resample of a small image rather than a
decode of a large one, and it may be below the noise.

Measure: distinct decodes per photograph before and after (more buckets means
fewer shared decodes — that is the trade), plus `ThumbAskToShown`.
*Risk:* `widthBuckets`' comment names the filmstrip/month-block sharing at 256
as deliberate. Do not break that pair.

---

### What each task risks, at a glance

| documented decision | tasks that go near it |
|---|---|
| **One thumbnail width for every block on the map** (`PlaceBlock.decodeWidth`) | none — 3 and 10 sit underneath it and strengthen it |
| **Per-key observation, one `Slot` per photograph** | 6 (caps and grace only; the `Slot` mechanism is untouched) |
| **A view asks while drawing, never on appear** | 7 must not move the ask into `.task`/`.onAppear` — prefetch is an *extra* ask, never a replacement |
| **A crossfade must never reveal what is under it** | 5 and 8 |
| **A block arrives with its photograph, not before it** | **5 changes this** — owner's call required |
| **The concurrent non-blocking decode queue** (measured 5.12×) | 6 |
| **Image files are never rewritten by a path that meant to read them** | 2 and 4 |
| **Memories does not use `@Query`** | none |

---

## 6. What not to do

**Do not adopt a third-party image library** (Kingfisher, Nuke, SDWebImage).
They exist to solve *network* image loading: HTTP caching semantics, request
coalescing, retries, cancellation across a connection. None of that exists here
— every byte is already on the device. What this app actually needs is
local-file decode at a chosen pixel size, per-key SwiftUI observation, and a
weak live table so a picture on screen cannot be evicted from under itself.
All three are already built, and two of them were built *in response to
measured bugs* that a generic library would not know about. Three further costs:
it would replace measured code (5.12× on `ioQueue`) with unmeasured code; it
would add a package to an app whose `PrivacyInfo.xcprivacy` currently declares
nothing collected *partly because it has no third-party dependencies*
(CLAUDE.md is explicit that the manifest, the policy and the usage strings are
part of any change that touches user data); and its global cache-invalidation
model is exactly the one-global-version design that was measured at ~4,000
bodies a second and removed on 2026-09-15.

**Do not preload everything.** 3,127 photographs at tier S is roughly 1.3 GB of
decoded pixels, which no phone will hold, so it becomes a cache thrash rather
than a preload. Worse, it inverts the priority the whole design rests on: the
picture you are looking at ends up queued behind pictures you are not. The map
already learned this in miniature — `upcoming` is a *one-beat* lookahead, not a
preload of every frame of every slideshow.

**Do not raise the cache limits as a first move.** The cache is already 300
entries and 150 MB, and the complaint is *cold* latency, not eviction thrash —
a bigger cache makes the first scroll exactly as slow and the memory warning
more likely. There is one documented case of eviction thrash (the filmstrip
dimming), and it was fixed properly, by the weak live table, not by a bigger
number. Size the cache *after* the decodes get cheap, and size it off
`physicalMemory` rather than a constant, so a 3 GB phone is not carrying a 6 GB
phone's ceiling.

**Do not let a photograph appear before its block.** A picture floating where no
block has arrived, or a block that resizes when its picture lands, breaks the
one rule the app is built on. Concretely: never fade a photograph in over a
transparent ground. The block's colour, or `waitingFill`, is opaque underneath
from the first frame and the picture comes up on top of it — the two-slot
structure `PlaceBlock` and `DayPhotoSlideshow` already use, for the reason
`BlockSurface` documents (two masked layers at 50% composite to 75% alpha and
the substrate shows through the middle of the handover). Task 5 makes the block
arrive *earlier*, never the picture.

**Three more, each already paid for:**

- **Do not put a semaphore on the decode queue.** Measured: it stalls under
  load, because a blocked GCD worker is answered by spawning another until the
  pool is exhausted. The comment on `ioQueue` is the receipt.
- **Do not go back to one global observed version.** Measured 2026-09-15: ~4,000
  image-view bodies a second in the viewer, ~1,000 on an idle map, neither ever
  settling.
- **Do not give the map more than one decode width.** Settled in CLAUDE.md and
  in `PlaceBlock.decodeWidth`: asking for 88 at one zoom and 176 at the next
  decodes the same photograph twice and re-decodes on every zoom step.

---

## Sources

API behaviour and benchmarks cited above, with dates.

- Apple, [`onScrollTargetVisibilityChange(idType:threshold:_:)`](https://developer.apple.com/documentation/swiftui/view/onscrolltargetvisibilitychange(idtype:threshold:_:)) — iOS 18+.
- Swift with Majid, [Mastering ScrollView in SwiftUI: Scroll Geometry](https://swiftwithmajid.com/2024/06/25/mastering-scrollview-in-swiftui-scroll-geometry/), 25 Jun 2024 — `onScrollGeometryChange`, `ScrollGeometry` fields.
- Swift with Majid, [Mastering ScrollView in SwiftUI: Scroll Visibility](https://swiftwithmajid.com/2024/07/16/mastering-scrollview-in-swiftui-scroll-visibility/), 16 Jul 2024 — `onScrollTargetVisibilityChange`, its `scrollTargetLayout` + `.id` requirements.
- Augmented Code, [ScrollView phase changes on iOS 18](https://augmentedcode.io/2024/07/15/scrollview-phase-changes-on-ios-18/), 15 Jul 2024 — `ScrollPhase` cases, `isScrolling`, the change context.
- Augmented Code, [Scroll geometry and position view modifiers in SwiftUI on iOS 18](https://augmentedcode.io/2024/07/01/scroll-geometry-and-position-view-modifiers-in-swiftui-on-ios-18/), 1 Jul 2024.
- Fatbobman, [The Evolution of SwiftUI Scroll Control APIs](https://fatbobman.com/en/posts/the-evolution-of-swiftui-scroll-control-apis/), 2024 — including the outermost-scroll-view caveat.
- PSPDFKit / Nutrient, [iOS HEIC Performance](https://www.nutrient.io/blog/ios-heic-performance/), 2018 — HEIC decode measured at **2.1× JPEG** on device, and slower on newer silicon despite hardware support.
- PSPDFKit, [Loading Images on iOS 15](https://pspdfkit.com/blog/2021/ios-15-image-api/), 2021 — `byPreparingForDisplay()` / `byPreparingThumbnail(ofSize:)`, async, off-main.
- Swift Senpai, [Reducing Memory Footprint When Using UIImage](https://swiftsenpai.com/development/reduce-uiimage-memory-footprint/) — `kCGImageSourceShouldCache` + `kCGImageSourceShouldCacheImmediately` pairing.
- Swiftjective-C, [Optimizing Images](https://www.swiftjectivec.com/optimizing-images/) — the `CGImageSourceCreateThumbnailAtIndex` option set; always pass `ThumbnailMaxPixelSize`.
- Apple, WWDC18 [Image and Graphics Best Practices](https://nonstrict.eu/wwdcindex/wwdc2018/219/) — the downsampling pattern this codebase already follows.

In-tree measurements are cited inline in §1.4 with the file and symbol that
records them.
