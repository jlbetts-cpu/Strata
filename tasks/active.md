# Apollo — Active Work

Rewritten 2026-09-22. Everything the previous version described (five tabs,
light-only, SF Pro Rounded, the tower grid) is gone; it is in `history.md`.

## Where the app is

Three tabs, glyphs only: **Home · Camera · Memories**.

**Home** replaced the tower. A warm white sheet over the camera's black, a
"Recents" shelf of one folder per day, every folder open, newest first. Read
`## Home` in `CLAUDE.md` before touching it — most of what is settled there was
settled by being wrong first.

578 tests green, Release builds for a device, branch `apollo-rename`.

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

## Next, in the order it should happen

**The social feed is the big one and it has its own document:
`docs/social-and-backend.md`.** Read that before starting any of it. Short
version: the backend already exists, complete, in `~/Desktop/apollo-app`, and
the daily-unlock ritual is already written (`SunsetClock`).

1. [ ] **The polaroid.** Figma `13258-6988` in the Apollo file, 342x452, thin
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
