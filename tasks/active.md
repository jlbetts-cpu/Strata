# Strata — Active Work

## Done overnight (unverified — none of it has been compiled)

- [x] **Wins button page, set as the home tab.** Tab order is now Wins, Tower,
      Today, Plan, Insights. One button, a counter, a neutral grey block, naming
      optional and available on every win chip.
- [x] **Apollo block rim** ported onto the current block views — uniform white
      border, crisp above the frosted band and blurred inside it, replacing the
      flat 5pt bottom strip. `blockCornerRadius` 16 → 12.
- [x] **Single light appearance.** `UIUserInterfaceStyle = Light` on both build
      configs; 25 dark ternaries and 2 if/else blocks collapsed to their light
      branch; 11 unused `colorScheme` declarations removed.

## First thing when you wake

- [ ] **Build it.** Nothing above has been through a compiler — there is no Xcode
      on the machine the agent runs on. If it fails, the whole night's work backs
      out with `git revert -m 1 <merge sha>` and nothing else is affected.

## The tower grid — needs a screenshot before anyone touches it

Jayden reported blocks sitting too high and ghost blocks off screen. That was
never diagnosed, because the screenshot showing it came from a build that
predated `b189dae` — a different tower implementation entirely.

Prime suspect, from reading `MainAppView` around the tower ScrollView:

- The ZStack's height is set by `Color.clear.frame(height: max(gridH, 1))`, but
  the tier badge sits at `.offset(y: gridH + 16)` and "Your first block." at
  `gridH + 40`. Both are drawn OUTSIDE the measured bounds, so the container
  reserves no space for them and they cannot participate in layout.
- `.padding(.bottom, max(safeAreaBottom, 8))` may be double-counting the bottom
  inset that the tab bar already contributes.

Do NOT change either without a screenshot from a current build. Two rounds were
already lost this session to fixing things that were not there.

## Next up

- [ ] Icon Dynamic Type — icons are sized with fixed `.font(.system(size:))`, so
      they do not grow with the user's text size while the labels beside them do.
      A `.iconSize()` modifier wrapping `@ScaledMetric` exists on
      `claude/strata-xcode-dh6gp6` and can be ported.
- [ ] Decide whether Today and Plan become one tab. Jayden has said twice that
      the tabs should feel connected; Today's unscheduled Sandbox already does
      Plan's job, so there are two places to schedule the same habit. Structural,
      so it wants him awake.
- [ ] Ghost tier redesign (white card, category rim, colour previewed where the
      filled block's band sits) — on `claude/strata-xcode-dh6gp6`, not yet ported.

## Settled — do not reopen

- **Typeface: SF Pro Rounded.** The Apollo Figma specifies Familjen Grotesk;
  Jayden chose to keep the native face on 2026-09-06. The block's identity is
  carried by shape, colour and the rim, not the letterforms.
- **Light only.** Chosen 2026-09-06.
- **Insights is Jayden's implementation.** A parallel one was written against an
  old snapshot and has been dropped; do not reintroduce it.
