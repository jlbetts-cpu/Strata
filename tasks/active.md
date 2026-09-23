# Apollo — Active Work

## PARKED, 2026-09-23 — Strata ships first

The owner: "I think what we had with Strata was releasable and all we have to
do is update the camera, fix the App Store Connect problem, I want to add
these live emulations and release the app, and then come back to Apollo right
after for another release... this is looking like a couple more months of
development when we already built a stunning minimal app that works."

So Apollo stops here, at a build that runs and looks right, rather than
mid-feature. **The social feed was not started** — it is the next thing, and
`docs/social-and-backend.md` is ready for whoever picks it up.

**Carry back to Strata**, his own note: the performance work from this session
applies to both apps. The jitter and lag findings are in `CLAUDE.md` under
`## Measuring smoothness` — the short version is that the scroll was never
the problem, the cost is at launch, and `drawingGroup` per card rather than
per stack is what fixed the folder.

Rewritten 2026-09-22. Everything the previous version described (five tabs,
light-only, SF Pro Rounded, the tower grid) is gone; it is in `history.md`.

## Where the app is

Three tabs, glyphs only: **Home · Camera · Memories**.

**Home** replaced the tower. A warm white sheet over the camera's black, a
"Recents" shelf of one folder per day, every folder open, newest first. Read
`## Home` in `CLAUDE.md` before touching it — most of what is settled there was
settled by being wrong first.

Release builds for a device, branch `apollo-rename`. **Not "578 tests
green" any more** — see the section below on the suite: individual suites
pass, the full run cannot finish on this machine, and nobody should quote a
total until it does.

## Not verified on a device — the honest list

- [ ] **The day sticker's cut-out.** `VNGenerateForegroundInstanceMaskRequest`
      cannot run in a simulator at all. The picking, scoring, caching and
      placement are all tested; the lift is a device check. Run with a real
      day of photographs and see what it picks.
- [ ] **The shutter blink** — the geometry has tests and a lab, but it fires
      on a real capture, and a simulator has no camera.
- [ ] **Launch smoothness.** Two or three gaps over 50ms in the first twenty
      seconds on a Debug simulator build, worst about 115ms. Much of it is app
      startup rather than Home. Needs his phone's numbers before anyone
      optimises further.
- [ ] The lens code, RAW, and front-flash brightness (carried over, still
      true).

## The test suite cannot be trusted on this machine right now

Found 2026-09-23 and NOT diagnosed to a conclusion. The full run aborts and
restarts repeatedly with `RPC timeout. Apparently deadlocked` out of the
simulator's capture and audio stacks — `FigCaptureSourceSimulator`,
`HALC_ProxyIOContext ... skipping cycle due to overload`. It survived a
simulator reboot AND an erase. Individual suites pass: 54 tests across the
seven that cover the folder, the print, the grid and the shutter ran green
in 0.3s immediately after a full run had failed.

One genuine-looking failure inside it is almost certainly not one: "Building
and encoding a frame barely touches the CPU" measured 10.8ms against an 8ms
budget, on a machine that had been building and running simulators for
twelve hours. CLAUDE.md's own rule applies — timing gates read CPU load.
Check it against `origin/main` on a quiet machine before touching the code it
points at.

`SoundEngineRestartTests` had its audio probe moved out of the suite trait as
part of the diagnosis. That change stands on its own (a probe evaluated while
the runner is preparing can abort every test; one inside a test cannot) but
it did NOT fix this.

## Landed on 2026-09-23, after the list above was written

- **A size looks like a size again.** The organised grid took its height from
  the PHOTOGRAPH, so a small holding a portrait came out taller than a hard
  holding a landscape. The height is the size's now
  (`ScatterLayout.tidyHeight`), the two columns he asked for are untouched,
  and a hard is 2.25x the area of a small. The same ladder reaches the shelf:
  `PeekSize` orders how deep into its folder a card stands.
- **The sheet stopped 84pt too low.** `ApolloSheet` ignored the safe area on
  every edge, so the 20pt strip was 20pt from the bottom of the GLASS, under
  the floating tab bar. The camera's viewfinder stops 20pt above the BAR.
  Both now measure 103 to 104pt off the bottom, photographed.
- **The pull has a handle.** iOS's grabber, 36x5, on the lip of the sheet.
- **Content is clipped to the paper** (`clippedToSheet`), because a
  `ScrollView` takes the safe area and gives its content an inset, so cards
  used to carry on past the lip and float on the black.
- **The selected tab glyph was black on near-black** once the bar started
  floating over the strip. `.tint` follows the strip now, not the window.

## Next, in the order it should happen

**The social feed is the big one and it has its own document:
`docs/social-and-backend.md`.** Read that before starting any of it. Short
version: the backend already exists, complete, in `~/Desktop/apollo-app`, and
the daily-unlock ritual is already written (`SunsetClock`).

1. [x] **The polaroid.** Done 2026-09-22. `WinPrint` / `WinPrintView`.
       Original note: Figma `13258-6988` in the Apollo file, 342x452, thin
       border with a deep bottom edge and the mark in the corner. It is what a
       win becomes when you TAP it, not how it looks while scrolling. Smallest
       piece, no backend, and the feed will reuse it.
2. [ ] **The locked feed, on mock data.** Port `SunsetClock` and the feed view
       under Recents, running entirely on `MockFeedRepository`. No network, no
       auth, nothing that can break the app.
3. [ ] **Auth and real reads.** Supabase session, real repositories.
4. [ ] **Publishing.** A local win to `publish_photo`.

## Smaller, unclaimed

- [ ] Sort inside a folder (by time, size, colour). Asked for, never built.
      The inside is a clean masonry now, and this adds chrome to a screen he
      asked to keep bare — worth checking he still wants it.
- [ ] Tower features never carried over: outlined blocks for habits planned
      but not done, and long-press to edit.
- [ ] App Store Connect still says "Strata Wins". The 4.1(a) rejection is
      unanswered.
- [ ] `docs/design-system.md` and `docs/product-direction.md` both predate
      Home and still describe the tower and four tabs.

## Settled — do not reopen

- **SF Pro, not SF Pro Rounded.** 2026-09-22.
- **Titles are New York at Medium.** Medium because the mark's stems are
  heavier than New York Regular's; Semibold overtakes them. `-strataTypeLab`
  sets every weight against the mark.
- **Home is light, the strip under it is the camera's black.** Both pinned,
  whatever the phone is set to.
- **The tab bar's background cannot be changed.** Four approaches, all
  recorded in `MainAppView`.
- **Every folder on the shelf is open.** Closed folders were my reading of an
  earlier note, not his.
