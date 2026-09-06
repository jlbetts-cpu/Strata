# Strata — Active Work

> Check `coordination.md` for bot assignments before modifying shared files.
> When a task is done, move it to `history.md` under the right category.

## In Progress

(none)

## Open Question — needs Jayden

- [ ] **Typeface.** The Apollo Figma (248:14) specifies **Familjen Grotesk Medium**
      for block title/time. The app ships SF Pro Rounded, brand.md pins it, and
      the standing instruction is "as native Apple as possible". Blocks were
      restyled with SF Pro Rounded kept. Adding Familjen Grotesk means bundling a
      custom font — global, and it walks away from the native-type ideology.
      Decide before any further type work.

## Next Up

- [ ] Observation isolation — extract TimelineTabView/TowerTabView from MainAppView to break cross-VM body re-evaluation (needs coordination between all bots)
- [ ] Reverse-fill for skip — hold + drag left to fill grey R→L (bidirectional intention gesture)
- [ ] Week summary skipped rings — weekSummaryView doesn't show grey skipped segments (day circles do)
- [ ] Chip V2 (Picture Superiority) — vertical pill layout, icon 20pt dominant, title below (Paivio 1971)
- [ ] Positional drop v2 — DropDelegate with Y coordinates for precise time assignment during chip drag
- [ ] Tower integration — show unscheduled habits as incomplete/matte blocks on tower screen (tap → schedule)
- [x] Accessibility review (dynamic type, VoiceOver, reduce motion) — Tower screen done; other screens still needed
- [ ] F-10: Time label column width for Dynamic Type (deferred)
- [ ] Add Task Claude: "Smart Rebalance" — deterministic day rescheduling button using existing findNextOpenSlot
- [ ] Add Task Claude: "Effort Heat Map" — ambient effort density indicator in Today section header
