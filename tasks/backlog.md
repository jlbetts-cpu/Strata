# Strata — Backlog

Future ideas, tech debt, and parking lot items. Not actively being worked on.

## Tech Debt

- Remove `imageData` from HabitLog schema (migration soak period ongoing)
- **Dead after the light-only switch:** `AppColors.ghostBaseDark`, `CategoryStyle.glow`,
  `CategoryStyle.darkShade` (and its `gradientBottom` accessor) have zero callers.
  Left in place because coordination.md marks `CategoryColors.swift` read-only —
  needs a Tower Claude pass to remove.
- **Insights `@Query` is unscoped.** `InsightsView` fetches all `HabitLog`s. Bounding
  it needs a verified string-comparison `#Predicate` on `dateString`, or a real
  `Date` column on HabitLog. Same gap as PlanPageView's `allLogs`.
- Figma palette deltas, not applied (CategoryColors is read-only): social ships
  `#14D4C1` vs Figma `#00DCC6`; mindfulness ships `#EC85B4` vs Figma `#EF8EB5`.
  Both differences are near-imperceptible.
- ~~`IncompleteBlockView`~~ — DONE (deleted in brand sync)

## Features

- **Tower incomplete blocks** — Show unscheduled habits as matte/incomplete blocks at bottom of tower. Tap → "+" overlay to schedule (like camera overlay on completed blocks). Creates motivating loop: see gap → schedule → complete → tower grows.
- **Drag-to-schedule** — Long-press unscheduled chip to drag into scheduled section. Assign time based on drop position between existing habits. (NNGroup: tap-first primary, drag secondary.)
- **Replan flow** — Triage missed past habits: swipe to reschedule, complete, delete, or push to unscheduled. (Structured's Replan pattern.)
- Settings tab implementation (profile, preferences, data export)
- Habit stacking (`anchorHabitID` field exists but unused)
- Drag-to-reorder habits within unscheduled section


## Polish

- **Watch the block rim blur in Instruments.** BlockRim's blurred layer no longer
  carries `.drawingGroup()` — rasterising to view bounds re-clipped the smear and
  reinstated the hard edge the blur exists to remove. Blur is 4pt on a 0.8pt ring,
  ~12 blocks visible after culling. Cheap in theory, unmeasured on device.

- ~~Tower: category icon size 11→13pt~~ — DONE (shipped in cross-audit, icon sizes now tokenized in GridConstants)
- Tower: culling threshold 40→30 blocks with 200→150pt buffer (cross-audit, low priority)
- Tower: micro-sway ADHD user testing — flag ±0.12° sway for participant feedback (cross-audit)

- Novelty sustainment — evolve tower aesthetics at milestones, seasonal themes, new block materials (research: 67% abandon at week 4 without novelty)
- Behavioral insights — weekly pattern analysis ("Morning habits: 80%, Evening: 40%")
