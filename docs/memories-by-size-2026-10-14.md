# Memories, split by size

Written 2026-10-14. Research and a code audit only: no Swift was changed.

The owner, the same day: "during the app you take a lot of big, medium, and
large wins and in the memories there is no real separator other than the
individual days. I feel like id love it if we keep the apple photos look while
splitting it into sizes."

**Recommendation: design B, a section per size inside the month's photographs
(Deep, then Regular, then Quick), drawn by the `PhotoGalleryGrid` and
`SectionHeading` already on the page.** About 40 lines across two files and one
test, no new component, no new stored field. Two things for him to look at
before it ships are listed at the end.

---

## 1. What is on the page now

Read from `Strata/Views/MemoriesView.swift`, `PhotoGalleryGrid.swift`,
`MonthCalendarView.swift`, `SectionHeading.swift` and `Strata/Models/Album.swift`.

Top to bottom, inside one `LazyVStack` in a `ScrollView`:

1. **The pinned header** (`pageHeader`, in `.pinnedBar`): map, recap play
   button and Profile in one `GlassGroup`, then `MonthPicker` (a `Menu` once
   there is more than one month).
2. **The calendar** (`monthTower` wrapping `MonthCalendarView`): seven
   columns, one block per day, swipe for the next month.
3. **The count line** (`photosCaption`): "12 Photos" in `Typography.screenSubtitle`,
   `inkSecondary`, 44pt tall.
4. **The month's albums** (`MemoriesShelf`), when there are any.
5. **The camera roll** (`PhotoGalleryGrid(sections: shown, ...)`): three
   across, square, 2pt gutter, edge to edge, no corner, no caption. `shown` is
   `monthPhotos`, ONE `GallerySection` for the month, newest first. Its heading
   ("October") is dropped by `headingRepeatsTitle` because it repeats the month
   picker. So today the month's photos are one undivided wall.
6. **The month's drawing** (`monthArt`) at the end.

**The size is already in hand at every step, so nothing new is stored.**

- `Habit.blockSize: BlockSize` is stored. Every win is its own `Habit`
  (`QuickWinService` creates one per log), so the size is per win.
- `Album.records(from:)` flattens it to `WinRecord.size`.
- `Album.gallery(from:)` copies it to `GalleryPhoto.size` (added earlier on the
  owner's word: "on the photos it should say the size, dont see the point of
  not").
- `PhotoViewer.caption` already leads with `current.size.effortLabel`
  (the size, then the day and the time).

`BlockSize` cases are `.small`, `.medium`, `.hard`; `effortLabel` gives
**Quick, Regular, Deep**. Those three words are what the camera's size picker
and the add sheet already say, so they are the only words a split may use
(`docs/ten.md` rule 4, one word per thing).

**Where a split could live**, from the code:

| Place | What it would mean | Verdict |
|---|---|---|
| The calendar | Days are sized by win COUNT (`MonthTower.size(forWinCount:)`, 1-2 / 3-6 / 7+), not by any win's size. "A Deep day" and "a Deep win" would be two meanings of one word. | Leave it alone. |
| The count line | A control on "12 Photos". | Design A. |
| `PhotoGalleryGrid`'s sections | It already renders several `GallerySection`s, each under a `SectionHeading`. Only the month is fed to it. | Design B. |
| `PhotoGalleryGrid`'s cells | Tile size by win size. | Design C. |

---

## 2. How others separate a library and keep it clean

Tags: **(a)** the vendor's own documentation, **(b)** press or secondhand,
**(c)** my inference.

### Apple Photos

- **Library and Collections are two places** in iOS 26, and the Library is the
  one grid. Collections holds Recent Days, Media Types, People, Pinned and so
  on (a: Apple, "Find photos and videos by date", iOS 26 guide; b: AppleInsider
  on the iOS 26 split into Library and Collections).
- **The Library's filter lives in a menu, not on the grid.** iOS 26: tap the
  menu button, then Filter, then a choice such as Videos, Favorites or Not in
  an Album; several can stack; **All Items** clears them (a: Apple, "Sort and
  filter the photo library on iPhone", iOS 26). Nothing is added to the grid
  itself. The current guide (iOS 27) folds Photos, Videos and Screenshots into
  one **Media Types** filter (a).
- **Media Types is a list of collections, one per kind**: Videos, Selfies,
  Portrait, Panoramas and so on, each its own grid, and any of them can be
  pinned (a: Apple, "Locate photos and videos by media type", iOS 18; Apple
  support 121870 on pinning in the new layout).
- **Years and Months are curated and All is everything** (a: Apple, iOS 26
  guide). Months groups by significant events with a heading over each.
- **The old Days view varied tile size**: "your best images displayed as large
  squares surrounded by smaller related photos" (b: MacRumors' Photos guide;
  a: Apple's Photos Tech Brief, Sept 2019, "a visually rich layout"). The
  mosaic was driven by a quality score, and it is gone from the iPhone Library
  today; Days became Recent Days in Collections (a).

What Photos teaches (c): **it separates kinds of picture by putting a heading
over a plain grid, or by moving them into their own collection, never by
decorating the grid.** The tiles stay square and identical; the heading is the
separator. The one time it varied tile size, size meant "best", and Apple has
since retreated from it on the main grid.

### Google Photos

- Filters are **chips under the search bar** (Favorites, Videos, Screenshots,
  Motion photos and more) and they stack (b: Android Authority; 9to5Google).
  A chip row is a search result's tool; the main grid stays plain (c).

### Day One

- Four views across the top: List, Calendar, Media, Map. **Media is a grid of
  attachments with filters above it** for Photos, Video, Audio and PDF (a: Day
  One's "Journal views in Day One for iOS"). A calendar and a media grid side
  by side is this page's shape, and Day One keeps them as separate views
  rather than splitting the calendar (c).

### BeReal

- Memories is a private calendar of every post, opened from the profile; a
  tap opens the day (a: BeReal help centre). No grouping by kind; there is
  only one kind (a). I could not find a source that describes the grid in
  detail, so nothing here leans on it.

### What carries over

1. **Headings over plain grids** separate without changing the look (Photos'
   Months and Media Types, this app's own `GallerySection` headings).
2. **A filter is a menu or a chip row** and it hides rather than separates
   (Photos, Google Photos, Day One).
3. **Varied tiles** mean something only when the size is the meaning, and the
   reference app no longer does it on its main grid.

---

## 3. Three designs, ranked

### B. A section per size, inside the month (recommended)

**What it looks like.** Under the calendar and "12 Photos", the roll becomes
up to three runs: a **Deep** heading and its photos, then **Regular**, then
**Quick**. Each run is the same camera roll as today: three across, square,
2pt gutter, edge to edge. Newest first inside each. A size with no photos has
no heading. A month whose photos are all one size has no headings at all and
looks exactly as it does now.

```
 October                         (month picker)
 [calendar]
 12 Photos
 [albums]

 Deep
 ▢▢▢
 ▢

 Regular
 ▢▢▢
 ▢▢

 Quick
 ▢▢▢
 ▢▢▢
```

**How it keeps the Photos look.** It is what Photos does in Months and in
Media Types: a heading in ink over a plain grid. No tile changes shape, no
chrome is added, and the headings are the same `SectionHeading` this page
already uses ("Which is what Photos does, and what this page is", its own
comment). Deep first, because the biggest wins are the ones worth finding,
the way Photos leads with its best.

**Effort.** Small. One pure function in `Album.swift`, a few lines in
`MemoriesView.swift`, one test. Half a day with renders.

**Files.**
- `Strata/Models/Album.swift`: `Album.sizeSections(_:)`.
- `Strata/Views/MemoriesView.swift`: feed the grid the split sections; decide
  the viewer's order (below).
- `StrataTests/`: a value test of `sizeSections`.
- `PhotoGalleryGrid.swift` and `SectionHeading.swift`: unchanged.

**Risks.**
- **Air.** `SectionHeading` carries `gapSection * 2` (64pt) above itself, the
  page's biggest break by design. Three of them in one month is a lot of
  white space between photos of one month, and the first one lands 64pt under
  "12 Photos". The ladder allows `gapSection` (32). Render both; he picks.
- **Order inside the viewer.** `PhotoViewer` is handed `vm.gallery.flatMap(\.photos)`,
  every photo ever, by date. Split, a swipe from the last Deep photo goes to
  whatever came next by date, not to the next tile. Photos swipes in grid
  order. Recommended: hand the viewer the month's split order
  (`bySize.flatMap(\.photos)`), at the cost of no longer swiping into last
  month. His call; it is one line either way.
- **Chronology across sizes is lost** inside the month. The calendar above
  already carries the days, which is the point of having both (c).
- **A size that changes after logging** moves its photo to another section on
  the next reload. That is correct, and it already happens to the block.

**Owner rules.** No SwiftData change. Two existing components. Nothing added
to the page but up to three words. Words are `effortLabel`'s, title case
through `SectionHeading`, no counts on the headings (the grid's headings lost
their counts deliberately; see the note on `PhotoGalleryGrid.heading`).

### A. A size filter on the count line

**What it looks like.** "12 Photos" becomes a menu, as `MonthPicker` is:
the same line with a chevron, opening **All, Deep, Regular, Quick**, a
checkmark on the chosen one. Chosen, the line reads "4 Deep" and the roll
shows only those. It goes back to All when the month changes.

**How it keeps the Photos look.** It is Photos' own move: the filter in a
menu, the grid untouched, All Items to clear. Nothing is drawn on the grid.

**Effort.** Small to medium. A `@State` for the chosen size, a `Menu` built
like `MonthPicker.menu`, the filter on `monthPhotos`, the caption's words.
`MemoriesView` only. A day with renders and VoiceOver.

**Risks.**
- **It hides; it does not separate.** He asked for a separator. With the menu
  closed, which is nearly always, the page looks exactly as it does now (c).
- **A control on a page he keeps subtracting from.** The page has lost its
  title, its search and a shelf of replays to "less is so much more". A
  filter is a cousin of the search he removed ("No search in Memories" is
  LOCKED in `docs/design.md`). Not the same thing, but close enough to ask.
- **Discoverability.** A chevron on a grey count line is easy to miss.

**Files.** `Strata/Views/MemoriesView.swift` only.

### C. Tile size by win size (a mosaic)

**What it looks like.** In one roll, a Deep photo takes 2x2 cells, a Regular
2x1, a Quick 1x1, packed in date order, the way the tower and the photo strip
(`StripLayout.rows`) are packed.

**How it keeps the Photos look.** Partly. It echoes the old Days view's large
and small squares, and it is the most "this app" of the three: the roll would
be shaped like the tower.

**Effort.** Large. A custom `Layout` with dense packing in three columns (a
2-wide tile in a 3-wide grid leaves holes that date order cannot always fill),
per-size thumbnail widths in `ThumbnailStore` and `GalleryPrefetcher` (which
assumes one row height today), and the crop window: a Regular tile should show
what the block shows, which is `HabitLog.cropPositionX/Y` and `cropZoom`, not
carried by `WinRecord` or `GalleryPhoto` now. Those are existing stored fields
so no schema change, but three value types and the loader grow. Several days.

**Risks.**
- **It undoes his camera roll call** of 2026-10-03: the grid was made "what
  Photos is" and "it reads as the photos, not as more blocks". LOCKED in
  `docs/design.md`: "open, the camera roll, edge to edge". A mosaic is the
  photos as blocks again.
- **Holes or reordering.** Dense packing either leaves gaps or moves photos
  out of date order, and neither reads as Photos.
- **Size reads as "best".** In Photos a big tile means the system liked it;
  here it would mean the win was big. Close, not the same (c).

**Files.** `PhotoGalleryGrid.swift` (new layout), `Album.swift` (`WinRecord`,
`GalleryPhoto`, `records`, `gallery`), `GalleryPrefetcher`, `ThumbnailStore`
call sites, `CachedImageView` crop path, `MemoriesView.swift`.

### Ranking

| | Separates | Keeps the Photos look | New things on the page | Effort | Against a LOCKED call |
|---|---|---|---|---|---|
| **B. Sections** | yes, always visible | yes, Months and Media Types | up to 3 words | small | no |
| A. Filter | only when chosen | yes, Photos' filter menu | 1 control | small to medium | close to "No search" |
| C. Mosaic | by shape | partly, the old Days view | none, but every tile changes | large | the camera roll |

---

## 4. The recommendation, in code

Real names throughout. Not compiled; this is a sketch for the session that
builds it.

### `Strata/Models/Album.swift`

Beside `gallerySections(_:calendar:now:)`, in the same `nonisolated extension
Album`, so it stays a value function testable with struct literals.

```swift
nonisolated extension Album {
    /// **The month's photographs, by how big the win was** (the owner,
    /// 2026-10-14: "keep the apple photos look while splitting it into
    /// sizes"). Deep, then Regular, then Quick, each newest first as the
    /// month already is. A size with no photographs has no section.
    ///
    /// The headings are `BlockSize.effortLabel`, the words the camera's size
    /// picker and the viewer's caption already use.
    static let sizeOrder: [BlockSize] = [.hard, .medium, .small]

    static func sizeSections(_ month: GallerySection) -> [GallerySection] {
        sizeOrder.compactMap { size in
            let photos = month.photos.filter { $0.size == size }
            guard photos.isEmpty == false else { return nil }
            return GallerySection(id: "\(month.id)-\(size.rawValue)",
                                  title: size.effortLabel,
                                  photos: photos)
        }
    }
}
```

The id carries the month and the size so `ForEach(sections)` in
`PhotoGalleryGrid` never sees two equal ids, and so a month swipe replaces
the sections rather than morphing one month's Deep into the next.

### `Strata/Views/MemoriesView.swift`

In `body`, where `shown` and `count` are computed today:

```swift
let shown = monthPhotos
let count = shown.reduce(0) { $0 + $1.photos.count }
// Split only when there is something to split: one size is the roll as it
// was, with no heading over it.
let bySize = shown.first.map(Album.sizeSections) ?? []
let roll = bySize.count > 1 ? bySize : shown
```

and the grid call:

```swift
if count > 0 {
    PhotoGalleryGrid(sections: roll,
                     transitionNamespace: photoTransition,
                     onSelect: { photo in
                         viewing = ViewedPhoto(id: photo.fileName, title: photo.title)
                     },
                     // Unsplit, the one section is the month and its heading
                     // repeats the picker, so it is dropped as before. Split,
                     // the size headings are the separators.
                     screenTitle: shown.first?.title)
        // Split, the first heading brings its own air (SectionHeading's
        // gapSection * 2), so the grid adds none.
        .padding(.top, bySize.count > 1 ? 0
                 : (vm.monthAlbums.isEmpty ? GridConstants.gapTight : GridConstants.gapSection))
}
```

`headingRepeatsTitle` needs no change: it only drops a heading when there is
exactly one section, which is the unsplit case.

The viewer, if he picks grid order:

```swift
.fullScreenCover(item: $viewing) { photo in
    PhotoViewer(photos: viewerPhotos, startAt: photo.id, ...)
}

/// The order the viewer swipes in: the roll's own, as Photos does.
private var viewerPhotos: [GalleryPhoto] {
    let month = monthPhotos
    let bySize = month.first.map(Album.sizeSections) ?? []
    guard bySize.count > 1 else { return vm.gallery.flatMap(\.photos) }
    return bySize.flatMap(\.photos)
}
```

Mind the type-checker ceiling noted in `CLAUDE.md`: `body` here is long, so
keep `bySize` and `roll` as plain `let`s, or move them into a computed
property, rather than inlining the expression into the grid call.

### `StrataTests`

A swift-testing value test, no store:

- photos of mixed sizes come back as Deep, Regular, Quick in that order;
- a size with no photos has no section;
- newest first is kept inside each section;
- ids are unique and carry the month;
- a month of one size returns one section (so the caller falls back to the
  unsplit roll).

### Accessibility

`SectionHeading` already adds `.isHeader`, so VoiceOver's headings rotor jumps
Deep, Regular, Quick for free. Each cell's `spokenName` is unchanged.

---

## 5. For him to look at before it ships

1. **The air between sizes**: `SectionHeading`'s 64pt, against 32pt
   (`gapSection`), rendered on a full month. If 32 wins, it is a parameter on
   `SectionHeading` (its other callers keep 64) and a note at the site.
2. **The viewer's swipe**: grid order inside the month (recommended, as
   Photos), or by date across every month (as now).

Not proposed, and why: splitting the calendar (its size means win count, not
win size), counts on the size headings (removed from these headings on
purpose), and a filter (A) on top of the sections, which would be two ways to
do one thing.

---

## Sources

- Apple, "Sort and filter the photo library on iPhone", iOS 26:
  https://support.apple.com/guide/iphone/sort-and-filter-the-photo-library-iph2e66e2f2c/26.0/ios/26.0
- Apple, the same page for the current release (Media Types filter):
  https://support.apple.com/guide/iphone/sort-and-filter-the-photo-library-iph2e66e2f2c/ios
- Apple, "Find photos and videos by date on iPhone" (Years, Months, All; Recent Days):
  https://support.apple.com/guide/iphone/find-photos-and-videos-by-date-iph0ea0234e0/ios
- Apple, "Locate photos and videos by media type on iPhone", iOS 18:
  https://support.apple.com/en-mn/guide/iphone/iph8530ff6a2/ios
- Apple, "Find your Favorites and albums in Photos on your iPhone or iPad" (pinning Media Types):
  https://support.apple.com/en-ca/121870
- Apple, Photos Tech Brief, September 2019 (the Days view):
  https://apple.com/ph/ios/photos/pdf/Photos_Tech_Brief_Sept_2019.pdf
- MacRumors, Photos guide (Days view tile sizes):
  https://www.macrumors.com/guide/photos/
- AppleInsider, Photos in iOS 26 (Library and Collections), read secondhand through a search summary; the page refused a direct fetch:
  https://appleinsider.com/inside/ios-26/tips/inside-photos-in-ios-26-macos-26----refinements-in-apples-image-and-video-management-tool
- Android Authority, Google Photos search filters:
  https://androidauthority.com/google-photos-search-filters-2-1226630
- 9to5Google, Google Photos filters:
  https://9to5google.com/2021/04/15/google-photos-could-soon-add-enhanced-image-search-filters/
- Day One, "Journal views in Day One for iOS":
  https://dayoneapp.com/guides/tips-and-tutorials/journal-views-in-day-one-for-ios/
- BeReal help centre, Memories:
  https://help.bereal.com/hc/en-us/articles/7531349180829
