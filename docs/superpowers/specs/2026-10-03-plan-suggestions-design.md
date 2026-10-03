# Plan suggestions (on-device AI) — design

Approved by the owner 2026-10-03 ("Yes, build it").

## What it is

A quiet way for someone who doesn't know what to do to fill their plan. It is
not a chat. It proposes a few plan lines; the person checks the ones they want.

## Research it rests on

- Apple, generative AI guidance and WWDC25 (Foundation Models, prompt design and
  safety): AI suggests, the person decides; suggestions are optional, editable,
  dismissible.
- Implementation intentions ("after X, I will Y") roughly double follow-through;
  tiny behaviours anchored to an existing routine form habits most reliably
  (Gollwitzer; Fogg, Tiny Habits; 2024 systematic review of digital habit
  interventions).
- Few options beat many: 3 to 5 suggestions, never a long list.

## Where it lives

In the Plan sheet, a small sparkle "Suggest" control. Shown only when
`SystemLanguageModel.default.availability == .available` (iOS 26, Apple
Intelligence on, iPhone 15 Pro or newer). Absent everywhere else; the plan is
unchanged without it.

## Flow

1. Tap Suggest. Three one-tap starters appear ("A balanced day", "Back on
   track", "Busy workday") and one optional text line.
2. The model returns 3 to 5 suggestions, shown as ghost plan rows: outline block
   bullet in the category colour, the title, size, and repeat summary.
3. Tapping a row's box adds it to the plan as a real `PlanItem` (text, category,
   size, repeat days). Unchecking before Done removes it again.
4. "Others" asks again, excluding what was just shown. "Done" closes the
   suggestions.

Nothing is added unless checked. No chat bubbles, no persona, at most one short
header line from the model.

## What the model knows (all on device)

- Weekday and part of day.
- The person's line or chosen starter.
- Existing plan lines (never duplicate them).
- How many wins per category in the last 14 days (fill the gaps).
- Titles of wins logged on 4+ of the last 14 days (suggest a repeat for them).

## Rules (in the instructions and enforced in code)

- 3 to 5 suggestions; at least 3 different categories.
- Titles: verb first, 1 to 4 words, no emoji, no punctuation at the end.
- Mostly small; at most one large (`hard`).
- A repeating suggestion carries repeat days and is anchored to a routine in
  its title only when short ("Stretch after coffee").
- Categories: health, work, creativity, focus, social, mindfulness.

Code clamps whatever the model returns: count, duplicates against the plan and
each other, title length, at most one large, valid weekdays.

## Model change

`PlanItem.sizeRaw: String = BlockSize.small.rawValue` (default keeps CloudKit
mirroring valid). A checked plan line opens the add sheet at its size.

## Units

- `PlanSuggestion` (value type) and `PlanSuggestionRules` (pure clamping, tested).
- `PlanSuggester` protocol; `OnDevicePlanSuggester` (Foundation Models,
  `@available(iOS 26, *)`), and a fake for tests and the simulator debug flag.
- `PlanSuggestionsView`, inside `PlanSheet`.

## Failure

Model unavailable: no control. Generation error or guardrail: one quiet line,
"Couldn't suggest right now." Nothing else changes.
