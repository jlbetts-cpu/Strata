# Strata — Backlog

Future ideas, tech debt, and parking lot items. Not actively being worked on.

## Tech Debt

- Remove `imageData` from HabitLog schema (migration soak period ongoing)
- `IncompleteBlockView` defined in HabitBlockView.swift but unused — delete when Tower Claude is available

## Features

- Insights tab implementation
- Settings tab implementation (profile, preferences, data export)
- Habit stacking (`anchorHabitID` field exists but unused)
- Drag-to-reorder habits in AllItemsView

## Polish

- Dark mode audit across all opacity values
- Accessibility pass (dynamic type, VoiceOver, reduce motion)
- `tabViewBottomAccessory()` for + button (places accessory above tab bar when expanded, inline when collapsed)
