# Strata — Active Work

Rewritten 2026-09-23. Everything the previous version described (five tabs,
Wins/Tower/Today/Plan/Insights, an overnight run that had never been compiled)
is long gone. It is in `history.md`.

## Where the app is

Three tabs: **Wins · Camera · Memories**. Wins is the tower of blocks.

`main` was restored on 2026-09-23 to the tree of the tag `strata-offline-v1`
(df23688, 17 September), the commit before "Strata becomes Apollo" turned this
into a different app. **The restore is a new commit, not a reset**: the Apollo
camera, the folder that replaced the tower, the stickers and the prints are all
still in this history and on the branch `apollo-rename`, and anything wanted
back is a cherry-pick away. That is how the live film emulation is coming back.

## The design language

`docs/design-system-future.md` is the brief every screen is being held to, and
it is not decoration: the owner asked for a 1990s Japanese future, bright and
precise rather than dark and neon. Read it before touching any screen. The two
rules it is easiest to break: **Jaro is for the app's own nouns and numbers
only**, and **nothing animates because a screen appeared.**

## Landed

- **The lattice.** `TowerLattice` draws the tower's own grid behind it: same
  cell, same 4pt gutter, same corner radius, anchored to the same bottom row.
  Not a pattern. `TowerLatticeTests` holds it to `GridConstants.blockFrame`.
- **The landing ripple**, in progress at the time of writing: the surface
  answers a block landing, from that block's cell, in its colour, scaled by its
  size. Nothing on arrival, which was the first version and was rejected.

## In flight, one agent each, partitioned by file

1. The lattice ripple (`TowerLattice.swift`, the ripple lines of `MainAppView`).
2. Memories (`MemoriesView`, `MemoriesDrawer`, `MemoriesMapView`, the albums).
3. The recap cards (`ReplayCard`, `ReplayShelf`, `ReplayFrame`, `ReplayView`).
4. The sheets and popups (nine files). **Done**: one `FormSectionLabel`, one
   spacing ladder, every `.primary.opacity(x)` removed, and two real bugs
   caught on the way (a plan row sitting 1pt inside the margin, and a ghost
   bullet drawn at 22 against the 24 that lands in it).
5. The camera: porting the live film emulation and the lens picker from
   `apollo-rename`. RAW is deliberately NOT in that port.

**Only one agent may build.** The owner's machine rule is one xcodebuild and
one simulator at a time, so four of the five write code and report what they
could not verify, and the whole tree is built and fixed in one pass afterwards.

## Not verified, honestly

- **Nothing from agents 2, 3, 4 or 5 has been compiled.** They were told not
  to, and their reports say what they could not check. The build and the
  screenshots are owed.
- **The camera cannot be checked in a simulator at all.** No camera, so the
  looks, the lens picker, the shutter path and the flash are all device work.
- **RAW** is the heaviest thing in the camera and changes the shutter path, the
  capture time and the memory profile. It goes in as its own piece with a test
  on a real phone, after the looks and the lenses land.

## App Store: the 4.1(a) rejection

Rejected under **4.1(a) Copycats**, "metadata contains third-party content
similar to a popular app", on an account already under extended review.
Apple did not say which part. What is known:

- The listing already says "Strata Wins" and was rejected with that name, so
  simply adding a word is not on its own the remedy.
- **There is another App Store app called Strata that captures everyday
  moments, and its own feature is called Strata Capture.** Same word, same
  category. That is a better candidate than Strava, which is at least a
  different category.
- The owner: the head maker is completely original and is not the problem.

**The name being adopted is Strata Neo**, subject to him saying it out loud a
few times. Clear on the App Store. Note for whoever writes the metadata:
NEOSTRATA is a 50-year-old registered skincare mark built from the same two
roots in the other order. Different class, different industry, but a lawyer
rather than an agent should confirm it.

Also: **the app ships as "Strata" on the home screen and the widget ships as
"Strata Wins"**, because only the widget target sets
`INFOPLIST_KEY_CFBundleDisplayName`. Both need to say the same thing.

## Settled — do not reopen

- **Typeface: SF Rounded for language, Jaro for the app's own nouns and
  numbers.** Settings, Line and Privacy keep SF Rounded Medium titles; that is
  in `CLAUDE.md` and it beats any later brief.
- **Light only.** Chosen 2026-09-06.
- **The tower's chaos is not the tower's problem.** Do not tidy the blocks.
- **Nothing loops and nothing animates on appearance.**
