# Strata's design language: a bright room in 2088

Written 2026-09-23 from the owner's brief, so that four people working on four
screens at once produce one app rather than four.

> "We kinda have that Tokyo neo aesthetic... like that vibe that you are in a
> bright room in 2088 on an app. Like it's the 1990s future aesthetic... every
> element, every shadow, every animation needs to feel a part of that goal and
> that system, on every screen, popup, every element."

And the constraint that keeps it from becoming a costume:

> "I think we already did a lot of typography throughout. I don't want
> everything to be the special font."

---

## 1. What the reference actually is

1990s Japanese futurism is **optimistic, bright and precise**. It is white and
light grey, not black and neon. Its future is a well-made object: a Braun radio,
a Muji shelf, a train timetable, a games console manual. The type is technical
and set with air. The colour is carried by the CONTENT, never by the chrome.

Cyberpunk in the Blade Runner sense is the opposite of this and is the trap:
dark screens, glows, scan lines, magenta on cyan. **None of that.** If a change
would look at home on a gaming laptop, it is wrong here.

The single sentence to design against: **it should look like a beautifully made
instrument that happens to be full of your photographs.**

---

## 2. Type

Two faces, and the split is the whole rule.

- **Jaro** (`StrataFont`, `Typography.screenTitleDrawn`, `.tally`) is for the
  app's own **nouns and numbers**: a screen's name, a count, a day number, an
  index. It is a display face; it is what makes the app look like itself.
- **SF Rounded** is for everything a person **reads as language**: body,
  labels, buttons, captions, empty states, settings rows.

**Never** set a sentence in Jaro. Never set a button in Jaro. If you are about
to use it for a third thing on one screen, you are decorating.

**The technical register comes from setting, not from a third face.** A label
that wants to feel like an instrument gets: SF Rounded, footnote size, medium
weight, ALL CAPS, `Typography.sectionKerning` (0.8). That is
`Typography.sectionLabel` and it already exists. Use it for section headings and
index labels; do not invent another.

**Numbers are readouts.** Counts and indices are Jaro, tabular, and never
abbreviated when they fit. A count that ticks should tick, not cross-fade.

---

## 3. The surface

The app has one ground truth for structure: **the tower's cell grid**
(`GridConstants`, 4 columns, 4pt gutter). `TowerLattice` draws the empty cells
of that grid behind the tower at 34% of `AppColors.quietFill`, fading out three
rows above the top block.

Any screen that lays out a grid of things uses **the same cell language**: the
same gutter, the same corner radius for its size class, cards that sit in slots
rather than floating in a list. A screen that needs structure behind it uses
the lattice rather than inventing a pattern.

**Never** a decorative pattern, a scan line, a dot grid, or a gradient laid over
a page. Structure is always the real geometry of the content.

---

## 4. Colour

- The **blocks and the photographs carry every saturated colour in the app.**
- Chrome is ink and grey: `AppColors.inkPrimary` / `inkSecondary` /
  `inkTertiary` / `inkQuiet` / `quietFill`, over `WarmBackground`.
- A tint is only ever **borrowed from content**: a block's category colour, a
  day's colour, the photograph. Never a brand accent painted onto chrome.
- No glow. No neon. No colour used to mean "futuristic".

---

## 5. Motion

**Reaction, not decoration.** The rule the owner gave us by rejecting the first
attempt: nothing animates because a screen appeared. Things animate because a
person did something, and they animate **where it happened**.

The ladder, in seconds:

| what | duration | curve |
|---|---|---|
| press | 0.06 – 0.10 | `GridConstants.tapSquashSpring` |
| state change | 0.16 – 0.22 | `snapBack` |
| move / reorder | 0.28 | `naturalSettle` |
| reveal / arrive | 0.34 – 0.50 | `naturalSettle` |
| a landing's ripple | 0.42 (1x1) · 0.52 (2x1) · 0.66 (2x2) | out fast, slowing |

Nothing loops. Nothing idles. Nothing over 0.7s. Every animation must be
interruptible by the next touch.

**Speed is the motto.** If an animation makes the person wait for it, it is
wrong however good it looks.

---

## 6. Chrome, shadow and edges

- **Shadows are for objects that stand on the ground**: a block, a card you can
  pick up, the drawer. Chrome separates with a **hairline** and with
  translucency, never with elevation.
- One corner radius per size class, from `GridConstants`. A photograph gets the
  photo corner, a block gets the block corner, a surface gets
  `radiusSurface`.
- Hairlines are `1 / displayScale`, in ink at low alpha, never a grey line.

---

## 7. What a screen must be able to say

Every screen should answer, without a word of explanation:

1. **Where am I** — a name, in Jaro, top left.
2. **How much is here** — a count, in Jaro, beside the name.
3. **What is this made of** — the structure visible, not implied.

If a screen cannot answer all three, that is the thing to fix before styling it.

---

## 8. The refusals

Do not, on any screen:

- set body text, buttons or long labels in Jaro
- add a glow, a neon, a scan line, a dot grid or a decorative gradient
- add a shadow to anything that is not standing on something
- animate anything on appearance, or loop an animation
- invent a colour that is not in `AppColors` or taken from content
- introduce a third typeface, a third radius ladder or a second grid

---

## 9. How to check

Screenshot it. `CLAUDE.md`: counting is not looking. A claim about how a screen
looks needs a screenshot somebody opened, and a claim about how it moves needs
frames, not a duration in a diff.
