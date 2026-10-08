# Overnight, 2026-10-07 to 10-08

## Yours to do (nothing below works for users until these are done)

1. **Push.** `cd ~/Desktop/Strata && git push origin main`. Pushing is blocked
   for me.
2. **Analytics:** make a TelemetryDeck account (free tier), create an app, and
   put its app ID in `Info.plist` (repo root) under the key
   `SomeWinsTelemetryAppID`. Until then the app sends nothing at all.
3. **App Store Connect:**
   - accept the Paid Apps Agreement (tips can't go live without it);
   - create three consumable IAPs: `somewins.tip.small` $1.99 "Small Tip",
     `somewins.tip.medium` $4.99 "Kind Tip", `somewins.tip.large` $9.99
     "Generous Tip";
   - privacy label: Device ID, Product Interaction and Purchase History, each
     "used for analytics, not linked to you, not tracking" (rows are in
     `tasks/app-store-metadata.md`).
4. **Crews ON in 1.0, your call.** The code keeps App Store builds dark until
   `active.md`'s list is done: the Push, Sensitive Content Analysis and
   Declared Age Range capabilities, the CloudKit `Report` permissions, the
   privacy answers, and a test across two phones. Once that's done, ask and I
   flip `CrewsFlag` (one line). Flipping it before then ships a feature that
   can't reach the server.
5. **Friend photos** for the trailer grid, when you have them.
6. **Open question:** do Profile, the widget and Your day still say "Streak"
   anywhere you want changed?

## What landed (15 commits)

- **Data safety:**
  - an unreadable head list or crew outbox is set aside and rebuilt, never
    read as empty and saved over;
  - backups now carry stickers, strip doodles and which strips you developed,
    and a restore only adds.
- **Crashes closed:**
  - a damaged backup zip;
  - a huge picked photo (now decoded at 2560, off the main thread);
  - a double tap on the map's back button;
  - a failed tower fetch that made a second tower.
- **VoiceOver:** your own wins can be reached one by one, the strip develops,
  and escape closes reaction bars.
- **Onboarding rebuilt:**
  - the film first, with a quiet "Skip";
  - then try it, your head, thank you, your goal;
  - centred titles, a hairline progress bar, and real photos on the try-it
    page;
  - Your three and the first-win pages are gone, as you asked;
  - the head copy no longer says "stays on this phone".
- **Day strip:**
  - it prints in one continuous motion and lands with no seam (measured from
    a recording: brightness 113 to 116, no flash);
  - the paper follows light and dark mode until you pick one;
  - Edit removes stickers;
  - doodles keep their shape;
  - Cancel really cancels;
  - the pen shows on white paper;
  - the Story export fits at any turn.
- **Money:** a tip jar in Settings, and one gentle ask after your third strip,
  never again once you've tipped or said no.
- **Analytics:** anonymous counts only (wins logged, strips developed, which
  screens get used, where onboarding loses people). There is an off switch in
  Settings, and the privacy policy is rewritten to match.
- **Stray ink dot:** a dot left beside a sticker you pinch is now dropped.
- **Tests:** all green.
  - Unit tests: 1,214 pass. UI tests: 41 pass, 4 skipped, 0 fail.
  - Nine UI tests had gone stale against screens that have since changed:
    - the first run now walks the new onboarding;
    - the map tests open the map;
    - the tally is read off the goal crest;
    - the calendar replaced the month tower;
    - the grid test runs with a camera.
  - Two tests target the album shelf and month picker, which no screen builds
    any more. They are skipped with the reason written in, not deleted.

## Left alone, on purpose

- **Check with VoiceOver on your phone:** turn the camera off for Some Wins,
  open the Camera tab and swipe through it. Visually only the sentence and
  "Open Settings" show, which is right. But the UI test tool still lists the
  grid, flash, flip, timer and shutter there, and I couldn't prove from the
  simulator whether VoiceOver reads them out.
- **Strip decor decode:** it decodes on the first open of Your day, then comes
  from cache. Low cost, and not worth the risk tonight.

## Docs

`docs/launch-plan.md` (virality), and specs in `docs/superpowers/specs/`:
`2026-10-08-analytics-design.md`, `2026-10-08-tip-jar-design.md` and
`2026-10-08-onboarding-rebuild-design.md`.
