# Strata — Backlog

Future ideas, tech debt, and parking lot items. Not actively being worked on.

## Tech Debt

- Remove `imageData` from HabitLog schema (migration soak period ongoing)

### Schema Migration (HIGH — before first App Store update that removes fields)
- 14 dead fields across Habit (3), HabitLog (9), MoodLog (2) — 18.4% of all model properties
- Zero migration infrastructure (no VersionedSchema, no SchemaMigrationPlan)
- `imageData` uses `@Attribute(.externalStorage)` — needs special cleanup
- Recommendation: implement VersionedSchema v1→v2 before first App Store update that removes fields
- Current convention: "kept for migration" — safe for v1.0 launch

### @Query Performance Bug (HIGH — Tower Claude's file, coordinate before fixing)
- `MainAppView.swift:8` — `@Query private var habits: [Habit]` fetches ALL habits regardless of active tower
- Should add tower predicate to avoid O(n) scan across multiple towers

### Code Health Items (MEDIUM)
- `import Combine` unused in MainAppView.swift and OnboardingState.swift
- `ContentView.swift` is legacy wrapper ("all UI is in MainAppView") — evaluate for removal
- 161 `try?` silent save failures vs 26 `do/catch` — add logging on critical persistence paths

## Features

- **Tower incomplete blocks** — Show unscheduled habits as matte/incomplete blocks at bottom of tower. Tap → "+" overlay to schedule (like camera overlay on completed blocks). Creates motivating loop: see gap → schedule → complete → tower grows.
- **Drag-to-schedule** — Long-press unscheduled chip to drag into scheduled section. Assign time based on drop position between existing habits. (NNGroup: tap-first primary, drag secondary.)
- **Replan flow** — Triage missed past habits: swipe to reschedule, complete, delete, or push to unscheduled. (Structured's Replan pattern.)
- Insights tab completion — shipped: photo calendar, streaks, drill-down. Missing: trends, weekly patterns, data export, sharing
- Habit stacking (`anchorHabitID` field exists but unused)
- Drag-to-reorder habits within unscheduled section
- **Session timer** — After 3+ completions: "You've been focused for 45 min" (Nairne 2013, Bandura 1997). Requires @State lastCompletionTime tracking.
- **Smart scheduling suggestions** — "You skip Exercise 3x at 7 AM. Try 2 PM?" Pattern analysis from completion history (Reclaim.ai pattern).
- **Values integration** — Optional "Why this matters" tag on habits (ACT therapy, UMAAP 2023).
- **Energy/capacity check** — Morning prompt: "How's your energy?" Reorder habits by effort level (Brown 2005, Miranda 2006).
- **Effort Heat Map** — Ambient effort density indicator in Today section header.
- **Duration Picker** — Native Slider with category tint + 4 preset chips (15m/30m/1h/2h). Schema: `customDurationMinutes` on Habit. Needs coordination.

## Polish

- Tower: culling threshold 40→30 blocks with 200→150pt buffer (cross-audit, low priority)
- Tower: micro-sway ADHD user testing — flag ±0.12° sway for participant feedback (cross-audit)
- **Tower header scroll-aware date range** — Extend towerScrollOffset to compute visible block date range from viewport position. Current fix shows data range; this would show viewport range. Requires onScrollGeometryChange + binary search through placed blocks. Phase 2. (Pirolli & Card 1999)

- Novelty sustainment — evolve tower aesthetics at milestones, seasonal themes, new block materials (research: 67% abandon at week 4 without novelty)
- Behavioral insights — weekly pattern analysis ("Morning habits: 80%, Evening: 40%")

## Research-Backed Future Features (March 2026)

### Apple Native Integrations (Ranked by Impact × Effort)

Already shipped: HealthKit (auto-verify), EventKit (calendar ghost blocks), UserNotifications (daily reminders).

| Priority | Framework | Impact | Effort | Cost | What It Does for Strata |
|----------|-----------|--------|--------|------|------------------------|
| **1 — CRITICAL** | **CloudKit sync** | 8/10 | **~5 lines, 1-2 hrs** | FREE | SwiftData has built-in CloudKit sync. Just add iCloud capability + change ModelContainer config. Fixes "device loss = total data loss." |
| **2 — CRITICAL** | **App Intents + Shortcuts** | 8/10 | **30-50 lines, 1-2 hrs** | FREE | "Hey Siri, complete my morning run." One struct per action. Also unlocks Spotlight + Focus Filters. |
| **3 — CRITICAL** | **Spotlight indexing** | 6/10 | **2-10 lines, 1-2 hrs** | FREE | Nearly free if App Intents done. Conform to `IndexedEntity`. Search habits from home screen. |
| **4 — CRITICAL** | **Focus Filters** | 7/10 | **50-100 lines, 4-8 hrs** | FREE | Show only Work habits during Work Focus. One struct conforming to `SetFocusFilterIntent`. System generates Settings UI. |
| **5 — HIGH** | **WidgetKit** | 9/10 | **200-800 lines, 1-5 days** | FREE | Progress ring + habit list on home/lock screen. Interactive tap-to-complete (iOS 17+). Streaks' #1 differentiator. Requires separate target + App Groups for SwiftData sharing. |
| **6 — HIGH** | **Live Activities + Dynamic Island** | 8/10 | **100-200 lines, 1-3 days** | FREE | Lock screen timer for duration habits. Define ActivityAttributes struct + SwiftUI views. |
| **7 — MEDIUM** | **Apple Watch** | 8/10 | **300-500 lines, 2-3 days** | FREE | Complications for progress rings. WatchConnectivity for data sync. ~40-50% of premium segment. |
| **8 — LOW** | StoreKit 2 | 7/10 | Medium | FREE | Modern subscription/IAP. Only when monetizing. |
| SKIP | Screen Time API | 3/10 | — | — | Niche. Privacy-sandboxed. |
| SKIP | CoreLocation | 4/10 | — | — | Battery drain + "Always" permission. |
| SKIP | CoreMotion | 2/10 | — | — | Redundant with HealthKit. |
| SKIP | HandOff | 2/10 | — | — | No mid-habit device switching needed. |

**All integrations cost $0** beyond the existing $99/year Apple Developer Program. CloudKit free tier: 10GB assets, 100MB database, 2GB transfer — more than enough for a habit tracker.

**Recommended roadmap:**
- **Weekend sprint:** CloudKit sync (1-2 hrs) + App Intents (1-2 hrs) + Spotlight (1 hr) + Focus Filters (4-8 hrs) — all 4 in one weekend
- **Week sprint:** WidgetKit (progress ring + today's habits + interactive complete)
- **Second week:** Live Activities (duration habit timer on lock screen)
- **Month sprint:** Apple Watch app + complications

### Tier 1: Competitive Parity (catch up to Tiimo/Reclaim)
- **AI Schedule Suggestion** — Auto-suggest optimal time slots based on existing schedule. Reclaim.ai: "AI finds the best time for each habit based on your meetings, tasks, work hours." This is our biggest competitive gap. ([Source](https://reclaim.ai/blog/habit-tracker-apps))
- ~~**Calendar Integration**~~ — ✅ SHIPPED: ghost event blocks inline on timeline, calendar-aware gap-finding, all-day event banner, per-date fetching, busy range exposure for scheduling
- **Adaptive Rescheduling** — "If a meeting runs long, automatically reschedule habits so you never lose momentum." Smart Rebalance feature is the first step toward this. ([Source](https://reclaim.ai/blog/habit-tracker-apps))

### Tier 2: Differentiation (beat competitors)
- **Mood-Adaptive Planning** — Tiimo has mood tracking. We can go further: mood check-in adjusts suggested effort levels. "Future systems should integrate mood-adaptive mechanisms that adapt to emotional state." ([Source](https://arxiv.org/html/2603.17258))
- **Predictive At-Risk Habits** — "2026 evolution includes predictive AI that flags at-risk habits using calendar data." Flag habits likely to be skipped + suggest schedule adjustments. ([Source](https://reclaim.ai/blog/habit-tracker-apps))
- **Streak-Free Momentum** — 7-day positive-only heatmap. "A strong habit app should treat missed days as recoverable data, not failure states." No other app does shame-free visual progress. ([Source](https://fhynix.com/best-habit-tracking-apps/))
- **Goal-Connected Habits** — "Describe a goal, AI recommends specific habits proven to support it." Beyond Time, Rocky.ai do this. We could connect habits to goals with progress tracking. ([Source](https://beedone.co/en/blog/best-ai-habit-tracking-apps-2026/))

### Tier 2.5: Brand & Personality
- **Ponorca Mascot (Penguin × Orca)** — Research-backed mascot initiative for ADHD engagement and brand recall. Nielsen: 37% higher brand recall, 23% higher retention with mascots. Finch (bird companion app) gets 8-24 month ADHD retention via character attachment. **Strategy: GitHub model, not Duolingo model.** Ponorca appears ONLY at celebration moments (milestones, perfect days, onboarding, empty states) — never in the tower grid, daily timeline, or failure states. Symbolism: penguin = formal/professional, orca = apex intelligence. Hybrid = "resilient excellence." Requires: illustration/design work first, then strategic integration points. Keep premium aesthetic sacred — the mascot is a personality layer on top, not a replacement for the tool's seriousness. Sources: Okabe-Ito B2B mascot study, Finch ADHD retention data, GitHub brand toolkit mascot guidelines.

### Tier 3: Apple Design Award Quality (delight + innovation)
- **Liquid Glass UI** — iOS 26 .glassEffect() on dashboard cards + edit card. "The most significant design evolution since iOS 7." ([Source](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views))
- **Block Evolution** — Tower blocks visually evolve over time (material changes, glow intensity, particle effects). Research: "Novelty sustainment prevents 67% abandon at week 4."
- **Haptic Storytelling** — Progressive haptic narrative during habit completion. "Haptic storytelling is making iOS apps more intuitive than ever." ([Source](https://medium.com/@bhumibhuva18/ux-trends-for-ios-in-2025-micro-interactions-neumorphism-more-f45f9e227d49))
- **Focus Timer Integration** — TickTick has Pomodoro, Tiimo has focus timer. Embed a focus session timer into the "In Progress" state. When you start a task, optional countdown timer appears.

### Competitor Feature Gaps We Can Exploit
| Competitor | Missing | Our Opportunity |
|-----------|---------|----------------|
| Tiimo | No gamification, no tower metaphor | Our blocks ARE the reward |
| TickTick | Generic UI, streak-shame, slow sync | Premium ADHD-first design + native EventKit |
| Structured | No custom folders, limited personalization | Full section customization + Smart View overrides |
| Things 3 | No habits, no gamification, no ADHD focus | We combine task management + habit tracking + gamification |
| Habitica | Web-based, childish aesthetic | Premium iOS-native ceramic block metaphor |

## Dead Code Cleanup

All previously identified dead code has been resolved (Strong v1.0 + Meridian hygiene session, 2026-03-26).
