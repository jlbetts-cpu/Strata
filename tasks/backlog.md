# Strata — Backlog

Future ideas, tech debt, and parking lot items. Not actively being worked on.

## Tech Debt

- Remove `imageData` from HabitLog schema (migration soak period ongoing)
- ~~`IncompleteBlockView`~~ — DONE (deleted in brand sync)

## Features

- **Tower incomplete blocks** — Show unscheduled habits as matte/incomplete blocks at bottom of tower. Tap → "+" overlay to schedule (like camera overlay on completed blocks). Creates motivating loop: see gap → schedule → complete → tower grows.
- **Drag-to-schedule** — Long-press unscheduled chip to drag into scheduled section. Assign time based on drop position between existing habits. (NNGroup: tap-first primary, drag secondary.)
- **Replan flow** — Triage missed past habits: swipe to reschedule, complete, delete, or push to unscheduled. (Structured's Replan pattern.)
- Insights tab implementation
- Settings tab implementation (profile, preferences, data export)
- Habit stacking (`anchorHabitID` field exists but unused)
- Drag-to-reorder habits within unscheduled section


## Polish

- ~~Tower: category icon size 11→13pt~~ — DONE (shipped in cross-audit, icon sizes now tokenized in GridConstants)
- Tower: culling threshold 40→30 blocks with 200→150pt buffer (cross-audit, low priority)
- Tower: micro-sway ADHD user testing — flag ±0.12° sway for participant feedback (cross-audit)
- Dark mode audit across all opacity values

- Novelty sustainment — evolve tower aesthetics at milestones, seasonal themes, new block materials (research: 67% abandon at week 4 without novelty)
- Behavioral insights — weekly pattern analysis ("Morning habits: 80%, Evening: 40%")
