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

---

## 10. Confidence

Written 2026-09-23 from the owner's brief:

> "I genuinely want to make the UI great and the UX great and fast and smooth
> and premium, and keep researching what makes an app look and feel premium. I
> think it's confidence, and we need to add it to every page."

> "Every single state should look like a screenshot moment. Nothing should look
> out of place or broken UI. We are building the future, and the future is
> minimal, intentional, but we still have that character."

He is right, and the useful part is that confidence is checkable where "premium"
is not. **Almost every cheap-looking detail in an app is a decision somebody did
not make.** Two sizes because neither was chosen. A 12pt inset because the edge
felt scary. Type at 15 because 17 did not fit and nobody moved anything. A faint
grey control because a real one felt loud. Hedging is the tell, and hedging is
visible, so a reviewer can find it.

**What confidence is not.** It is not sparseness, and it is not minimalism.
Apple's *Principles of Great Design* separates the two: "burying everything in
one place looks minimal but isn't simple", and "sometimes adding context
simplifies". Rams is the same the other way round: "as little design as
possible... not for reasons of economy or convenience", and "nothing must be
arbitrary or left to chance". Kenya Hara's word for Muji is emptiness rather
than minimalism: a state left open for the user to fill, not a subtraction for
its own sake. And Teenage Engineering is the proof that reduction is a
discipline rather than a look: the OP-1 has four knobs because four was decided,
and what remains is argued for. **Reduction is not the goal; what remains, and
why, is.**

That is exactly this app's shape. The blocks and the photographs are the
content, and they are saturated, warm and full of a person's life. The chrome's
confidence is what lets them be loud.

### The ten rules

Each has a check a reviewer can run against one screenshot, and a live example.

**1. One size, not three near sizes.** If two things on a screen differ by less
than about 15% in size, weight or opacity, the difference is not a decision, it
is a wobble. Pick one, or make them properly different.
*Check:* list every type size, glyph size and corner radius on the screen. Two
values within 15% of each other is a finding.
*Was:* `AllClearCelebration` mixed three particle shapes at 4 to 8pt, where all
three read as the same speck. One shape now.

**2. Full bleed or a real margin, never a timid inset.** An element either goes
edge to edge or it sits on `pageMargin`. Nothing sits 6pt in from the edge
because the edge felt close.
*Check:* measure every left edge on the screen. They should be exactly two
numbers: 0 and the page margin.
*Live:* the camera roll is deliberately edge to edge with a 2pt gutter and every
other band is on the margin. `docs/research/screen-control.md` section 1c found
Profile and Settings sitting 4pt further in than the rest of the app, which is
the failure this rule names.

**3. Type is set at the size it should be, not shrunk to fit.** If a string does
not fit, change the layout, cut the words, or let it wrap. Do not scale it down
until it does.
*Check:* grep the screen for `minimumScaleFactor` and `lineLimit`, then ask of
each one whether it is Dynamic Type headroom or a default size that never fitted.
*Carve-out, and it matters:* a `minimumScaleFactor` that only ever fires at the
accessibility text sizes is not hedging, it is the app honouring a setting. The
hedge is type shrunk at the DEFAULT size. `ViewThatFits` with two real layouts
(the Wins pill, `DynamicScreenTitle`) is the confident answer and is already the
pattern here.

**4. Empty space is left empty.** Space is the material, not a gap to be filled.
A band of nothing under the tower is the tower standing up.
*Check:* for every element, name what it tells the person that nothing else on
the screen already tells them. If it repeats a fact, it goes.
*Live:* "nothing sits under the tower" and the three frosted capsules that were
removed from between the tower and the tab bar. Also `MemoriesView`, where three
of us applied section 7's "how much is here" to our own band on the same day and
the page ended up saying it six times on one scroll.

**5. One accent, used once.** The colour comes from the content. Chrome does not
get a brand colour, and a screen has at most one thing shouting on it.
*Check:* count the saturated areas on the screen. Every one should be a
photograph, a block or a category colour.
*Live:* the Memories title is ink and not pink, "because a page title in the same
pink would put two shouts on a screen whose subject is photographs".

**6. A control is clearly there or clearly not.** No faint hints. If it is
pressable it looks pressable at arm's length, and it answers the finger on
touch down. If it is unavailable it is visibly disabled, never removed.
*Check:* 44pt minimum, measured; 3:1 contrast for a control and 4.5:1 for text,
computed from the real tokens over the real ground, never eyeballed (CLAUDE.md,
*An ink is not a surface*); and a press response that exists below iOS 26 as well
as on it.
*Live:* the month chevrons were "disabled and dimmed at the edges, never hidden:
a control that vanishes reads as a bug". The counter-example is the pre-26 glass
fallback, which has no press response at all, so the same button is two buttons
depending on the phone (`docs/research/motion-and-layering.md` section 1.1C).

**7. Glass only over content.** Liquid Glass is for a control floating over
something the person is looking at: a viewfinder, a map, a photograph, a tower.
On a plain warm-white page it has nothing to refract and renders as a grey box
pretending to be a material, which is cheaper-looking than a clean flat control.
Apple: glass "is best reserved for the navigation layer that floats above the
content of your app", not for content, and not stacked on more glass.
*Check:* for each glass element, name what is underneath it. If the answer is
"the page", it does not get glass. At most three glass elements on a screen
(`docs/research/visual-cohesion.md` section 4.2), and never two translucent
layers on top of each other.
*The one carve-out, and it is the owner's.* On 2026-09-23 he asked for the
tower's empty slot in glass: "I think the + square doesn't match the aesthetic of
things. I feel like that should be updated, maybe more liquid glass feel." The
slot is on the page, so it is an exception to this rule and not a precedent for
more of them. It earns the exception because what is behind it is the lattice,
which is real structure rather than blank ground, and because it is built on
`.clear` with no tint precisely so the lattice reads through: see `SlotGlass.swift`.
**Do not use this rule to revert it.**

**8. Never two solutions to the same problem on one screen.** One control per
job, one style per rank, one token per value. Two answers means nobody chose.
*Check:* for any value you can see twice (a hairline, a heading ink, a glass
recipe, a glyph state), find the one place it is defined. If there are two, that
is the finding, whatever the values are.
*Was:* `StrataTab` had an `icon` and a `selectedIcon` while `MainAppView` typed
the strings inline, so nothing read `selectedIcon` and the Memories tab never
filled. `ProfileAvatar` drew a 0.5pt hairline while the rest of the app draws
`1 / displayScale`. `SectionHeading` carried a `pinned` flag nothing passed.

**9. A comment that is not true is a hedge.** A claim in a doc comment stops
anybody looking, which is why every trap in `CLAUDE.md` about stale comments cost
hours. Documentation for a deleted control reads exactly like a control you
cannot find.
*Check:* for any sentence in a comment that asserts two things are the same, or
that a value was measured, either find the measurement or delete the sentence.
*Was:* `StrataMark` said the mark and the app icon are "the same drawing on the
same ground". Measured, the grounds are `0x403D39` and `0x1C1A18`: 4.5x apart in
relative luminance. `MonthTowerView` carried three paragraphs about chevrons that
had been removed. `MemoriesView` still says the month picker "sits OUTSIDE the
scroll view" while it is a pinned section header inside it.

**10. Every state is a finished state.** A loading state, an empty state, an
error, a mid-animation frame and a full accessibility text size are all states
somebody will see, so each is designed rather than allowed to happen.
*Check:* photograph every state the screen has, including the empty one and the
one at AccessibilityXXXL. A state that only exists for 300ms still has to look
like the app.
*Was:* the perfect-day confetti rebuilt its particles inside the draw closure, so
it rendered as random noise instead of a burst, every frame, in the one moment
the app is congratulating you.

### Where to apply it first

Confidence is a property of a SCREEN, so review a screen, not a component. Hold
the ten rules against one screenshot at a time and write down what you find
before changing anything, because half of these findings are decisions the owner
has already made deliberately and the other half are hedges.

### Sources

- Apple, *Get to know the new design system*, WWDC25 (session 356), and *Meet
  Liquid Glass* (219): glass belongs to the navigation layer above content, not to
  content, and is not stacked.
  <https://developer.apple.com/videos/play/wwdc2025/356/>
- Apple, *Principles of Great Design*, distilled in `docs/apple-design.md`
  section 16: simplicity is not minimalism; craft is "every spacing, timing, and
  alignment value a deliberate choice you can defend"; delight is the result of
  the other seven principles, "not confetti tacked on top".
- Apple, *The Details of UI Typography*, WWDC 2020, in `docs/apple-design.md`
  section 15: tracking and leading are size-specific, and hierarchy is built from
  weight, size and leading as a set.
- Dieter Rams, the ten principles: good design is unobtrusive, and thorough down
  to the last detail, where "nothing must be arbitrary or left to chance".
  <https://www.vitsoe.com/us/about/good-design>
- Kenya Hara on Muji: emptiness rather than minimalism, a form left open for the
  user to fill. <https://en.wikipedia.org/wiki/Kenya_Hara>
- Teenage Engineering: constraints chosen up front (simple geometry, RAL colours,
  four knobs), reduction as rigour rather than as a style.
  <https://www.sfmoma.org/read/stay-curious-stay-naive-an-interview-with-teenage-engineering-jesper-kouthoofd/>
- In this repo, already measured: `docs/research/visual-cohesion.md` section 4.2
  (glass over an image, a hairline on the page; three glass elements a screen)
  and 4.3 (filled means selected, everywhere);
  `docs/research/screen-control.md` section 2.2 (one title line, three bottoms,
  boxes as large as they can be); `docs/research/motion-and-layering.md` section
  1.1 (one press behaviour) and 3.1 (six layers, and translucency does not
  stack).

---

## 11. Effortlessness

Added 2026-09-23. The owner named a second reference, alongside the 1990s
Japanese future:

> "There is this app Craft, the way it just is effortless in its design
> approach. A real stunning tool that feels and looks very modern."

**An honest note on sourcing:** the link he sent is behind a sign-in I cannot
open, so this is written from what that app is known for rather than from its
screens. If a specific screen matters, he should send the picture. And the
same rule as the Cal AI note applies, for the same reason: **principles, never
pixels.** This app is under a 4.1(a) copycat rejection and copying another
app's interface is named in that guideline.

**What effortless actually means, as rules.**

1. **The content is the interface.** Chrome appears when it is needed and is
   otherwise not there. A screen at rest should look like the thing itself,
   not like a frame around the thing.
2. **Direct manipulation over controls.** You move the thing, not a slider
   that moves the thing. This app already does its best work this way: the
   block is drawn by dragging, the shutter is held, the drawer is pulled.
   Prefer that over adding a button.
3. **Depth is spatial, not decorative.** A surface sits over another surface
   because it came from somewhere, and it goes back there. Every panel should
   grow out of the thing that opened it, which is why the film looks tray is
   the button.
4. **The transition carries the meaning.** Where something came from is the
   explanation. If a screen needs a label to say what just happened, the
   motion was wrong.
5. **Nothing asks twice.** No confirmation for a reversible act, no "are you
   sure" where an undo would do, no setup before the first use.
6. **Weight and inertia rather than timing curves.** Things that move should
   feel like they have mass. A tween reads as software; momentum reads as an
   object.
7. **It is finished at every size.** The same screen on an SE and at
   AccessibilityXXXL. Section 10, rule 10.

**How this sits beside section 1.** The 1990s future gives the app its
character: precise, technical, bright, an instrument. Effortlessness is how it
behaves: nothing in the way, everything where your hand expects. They pull in
opposite directions exactly once, on ornament. **When they do, behaviour
wins.** A detail that makes the app look like an instrument but costs a person
a step is decoration, and this doc's first rule is that premium is
subtraction.
