# Strata — Active Work

> Check `coordination.md` for bot assignments before modifying shared files.
> When a task is done, move it to `history.md` under the right category.

## In Progress

- [x] **Harmonious Dance Phase 2** — SHIPPED: momentum escalation, settle bounce, streak milestones, block flyaway, all-clear celebration, confetti, tower badge, counter flash
- [x] **Harmonious Dance Phase 3** — SHIPPED: device parallax, depth shadows, mass-aware tap, ghost block, press highlight, drop sounds, post-cascade settle
- [x] **Harmonious Dance Phase 4** — SHIPPED: staggered row reveal, week cascade, directional date, next-up glow, completed row polish
- [x] **Harmonious Dance Phase 5** — SHIPPED: first block magic, tower aurora

## For Add Task Claude (Plan Screen)

- [ ] **Routines tab: add "Done" card** — show completed routines for today (Zeigarnik 1927)
- [ ] **To-Dos tab: "Tomorrow" card missing** — was visible before, may be hidden by smart visibility. User wants it back.
- [ ] **"Saved" section: no discoverable UI** — swipe-to-save is hidden. Needs visible affordance.

## Next Up

- [ ] Reverse-fill for skip — hold + drag left to fill grey R→L (bidirectional intention gesture)
- [ ] Chip V2 (Picture Superiority) — vertical pill layout, icon 20pt dominant, title below (Paivio 1971)
- [ ] Positional drop v2 — DropDelegate with Y coordinates for precise time assignment during chip drag
- [ ] Tower integration — show unscheduled habits as incomplete/matte blocks on tower screen
- [ ] Dark mode audit — verify all screens look correct in dark mode
- [ ] F-10: Time label column width for Dynamic Type (deferred)
- [ ] Insights tab — partially shipped (photo calendar, streaks, drill-down, empty state). Missing: trends, weekly analytics, export, sharing.
- [x] Settings screen — SHIPPED: notifications, data export, reset, replay tutorial, rate/feedback, legal, debug
- [ ] Widgets — lock screen progress ring + tower height
- [ ] Add Task Claude: "Streak-Free Momentum" — 7-day positive-only heatmap per habit in expanded card (no streaks, no shame)
- [ ] Add Task Claude: "Smart Rebalance" — deterministic day rescheduling button using findNextOpenSlot when >2 habits skipped
- [ ] Add Task Claude: "Effort Heat Map" — ambient effort density indicator in Today section header
- [ ] Add Task Claude: Duration Picker — native Slider with category tint + 4 preset chips (15m/30m/1h/2h). Schema: customDurationMinutes on Habit. Needs coordination.
- [ ] Add Task Claude: AI Schedule Suggestion — research Reclaim.ai pattern. Auto-suggest optimal time slots based on existing schedule + energy patterns. Biggest competitive gap vs Tiimo.
- [ ] Add Task Claude: Calendar Integration — sync with Apple Calendar / Google Calendar. Show external events in Timeline Glimpse. Research: Reclaim.ai, TickTick calendar sync.
- [ ] Add Task Claude: Mood-Adaptive Planning — Tiimo's mood tracker pattern. Check-in before planning adjusts suggested effort levels. Research: "Future systems should integrate mood-adaptive mechanisms" (arxiv 2025).
- [ ] Add Task Claude: Predictive At-Risk Habits — flag habits likely to be skipped based on completion patterns. "2026 evolution includes predictive AI that flags at-risk habits" (Reclaim.ai).
- [ ] Add Task Claude: Liquid Glass Cards — upgrade dashboard grid cards to .glassEffect() on iOS 26. GlassEffectContainer for unified material. .interactive() for tap response.
