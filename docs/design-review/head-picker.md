## Design Review — Head picker (Profile, "Your head")
**Maturity level:** L2 (`docs/design.md`, the system in code, the atomic-kit table as the checklist).
**Sub-agents run:** Visual Quality Inspector (with the Imagery Review Checklist), UX Critic, A11y Auditor, DS Compliance Checker, Motion Reviewer
**Total findings, before:** 4 (P0: 0, P1: 1, P2: 1, P3: 2)
**After this pass:** 3 open (P0: 0, P1: 1, P2: 1, P3: 1), the P1 in a file that is not mine

Captured 2026-10-02 on Strata-E, light and dark: `-strataStartTab tower -strataSeedMadeHead 1 -strataOpenSheet profile -strataScrollProfile head`. **One head only.**

### "Several heads" is unreachable, and the fix is not mine

`HeadStore.init` (Models, read-only to me) seeds `-strataSeedHead` only `if undressed == nil`, so once `-strataSeedMadeHead` has written a head nothing adds a second, and no flag writes two. The picker's whole layout question (a row of tiles, the chosen ring, scrolling past three) has therefore never been photographed. The change to ask for, in `HeadStore.swift` after `roster = onDisk` (~233). A sketch against the file's own names (`Roster.heads`, `Entry`, `support`, `writeVersion2Fixture`), not compiled, and it must run before `persistRoster` could write the roster out:

```swift
#if DEBUG
if let n = DebugHarness.seedHeadCount, n > 1 {          // -strataSeedHeads <n>
    for i in roster.heads.count..<n {
        let folder = "debug-head-\(i)"
        if let base = Self.support?.appending(path: folder) {
            Self.writeVersion2Fixture(to: base)            // the same fixture, n times
            roster.heads.append(Entry(id: UUID(), name: "Head \(i + 1)", created: Date(), folder: folder))
        }
    }
}
#endif
```

plus `static var seedHeadCount: Int? { argument("-strataSeedHeads").flatMap(Int.init) }` in `DebugHarness`. Real folders rather than the creator's empty-folder entry, because `resolve` refuses an empty folder and the swatch row reads each head from disk.

---

### What's working (≥3)
- **The destructive row names its object**: "Delete This Head" in `destructiveInk`, where it once read "Delete Me".
- **Each switch says what it does to the head, not to a setting**: "Let My Head Onto the Tower", "Show My Head on the Map". Off by default, which is the owner's rule ("it is a companion somebody opts into").
- **Tiles carry `.isSelected`** and their head's name as the label; selection is a ring on the tile's own edge.
- **Imagery:** the tile is the cut-out on `quietFill`, one subject, no frame competing with it.

### P1 — Major
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 1 | Coverage, all states designed (governance) | DS | the several-heads state | Unreachable from the harness (above). A picker reviewed only with one item has not been reviewed. | S (in HeadStore) | **Reported**, change written above. Not mine to make. |

### P2 — Minor
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 2 | Balance | Visual | one tile in a full-width row | One 46pt tile at the left of a 340pt card row, then the switches: the row reads as unfinished when there is one head. It is where "Add Another Head" lands, but that is a row further down. | M | Not changed; judge it with several heads first (#1). |

### P3 — Cosmetic
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 3 | Footer | DS | head footer (several heads only) | Was a 13pt Form footer; now on `.formFooter()` with the rest (`profile.md` #1). Unseen until #1. | — | Fixed in passing. |
| 4 | 1.4.11 | A11y | switches off | Platform off track; see `settings.md` #4. | — | None. |

### Motion review
Selection is instant (`reduceMotion` read in `HeadPickerRow`); the head on the tile is `.calm`. **Overall:** Purposeful.

---
### Summary
The single-head state is right: plain switches that say what they do, and a delete that names its object. The picker itself, the reason this row exists, has never been seen with more than one head, because the fixture cannot make two. That is the one thing to do next, and it is a five-line change in a file I may not edit.
