# Working on Strata

Read this first. It carries decisions and traps that have already cost real
hours, so that a new session does not repeat them.

## What this is

A SwiftUI + SwiftData iOS habit tracker. You complete habits; completed habits
become 2.5D blocks that stack into a tower. Tabs, in order:

**Wins** (one-tap logging, the home tab) · **Tower** (the record) ·
**Today** (the timeline) · **Plan** (capture and scheduling) · **Insights**

## Rule zero: build it

**You are running on the owner's Mac, so you can compile and run this app. Do
it before claiming anything works.**

Most of the design work in `BlockChrome.swift`, `WinsView.swift` and the
light-only conversion was written by an agent in a Linux container that could
not compile, could not run a simulator, and could not render SwiftUI. It was
reviewed line by line and pushed unverified. If something looks broken, suspect
that first — it has never been through a compiler.

"It renders correctly", "it compiles" and "I ran it" are three different claims.
Only make the one you actually earned.

## Traps that have each cost hours

**Verify the local checkout matches the remote before diagnosing anything.** A
whole session was lost to "nothing looks updated": the owner's Mac had 84
uncommitted changes and a dozen files that had never been pushed, so the running
app was newer than GitHub, not older. The giveaway was a string on screen
(`Seedling`) that existed in no committed file.

**`main` and a feature branch can share an ancestor and still be unmergeable in
practice.** In September 2026 two versions grew from `b189dae` in parallel — the
owner's real app (Siri Intents, sound engine, milestones, onboarding) and an
agent's design work. `MainAppView` differed by 1,000 lines. The design work was
re-applied by hand rather than merged, and the parallel Insights implementation
was dropped outright because the owner's was already wired in.

**The blocks are the identity; chrome is not.** Do not give cards, sheets or
form wells a white rim, a frosted band or a blurred edge. Those say "you built
this and it is standing on something", which is a block's claim.

## The block, and why it is built the way it is

From Figma "Apollo" (`248:14`). The effect is LAYERED, not styled: a block with
a solid white border on all four sides, and a separate rect over the bottom 26%
applying `backdrop-blur(10px)` to it. The blur eats the border, so the bottom
edge is that same border out of focus — not a strip, not a gradient.

`BlockSurface` reproduces this by drawing the surface twice and masking. Four
things were got wrong on the way there; do not redo any of them:

- **Do not composite a blurred ring on top of a sharp block.** That adds a white
  highlight inside the colour field and leaves the silhouette crisp. The source
  has neither. The sharp surface must be replaced, not decorated.
- **Do not crossfade the two copies symmetrically.** Two masked opaque layers at
  50% each composite to 75% alpha, so the block goes translucent through the
  handover and the page shows through as a milky cast. The blurred copy reaches
  full opacity BEFORE the sharp one starts to fade.
- **Do not add `.drawingGroup()` to a block view.** It rasterises to the view's
  bounds, which re-clips the soft edge and puts the hard silhouette back.
- **Do not scale the blur off the rim width.** In the source these are two
  separate elements (a 5px border, a 10px blur). Blur is 1.78% of block width;
  at 4pt the bottom half hazes over.

Proportions come from the source: radius 14.7% of the side, rim 0.89%, blur
1.78%, band the bottom 26%, wash 20% white.

## Settled — do not reopen

- **SF Pro Rounded, two weights.** The Figma specifies Familjen Grotesk; the
  owner chose the native face on 2026-09-06. Shape, colour and the rim carry the
  block's identity, not the letterforms.
- **Light appearance only** (`UIUserInterfaceStyle = Light`), chosen 2026-09-06.
- **SF Symbols only.** No second icon pack, no custom assets.
- **Insights is the owner's implementation.** A parallel one was written against
  an old snapshot and dropped. Do not reintroduce it.

## Deliberate pairs — do not "fix" these

- `checkmark.circle.fill` (green, "All done!") vs `checkmark.circle` (grey, "All
  cleared"). Fill means fully completed; outline means closed with skips.
- `WeekProgressStrip`'s 0.05 vs 0.08 ring track encodes future vs past.
- The mini-block preview is intentionally smaller-scaled chrome, not a bug.

## Conventions

- Task state lives in `tasks/`: `active.md` first, then `coordination.md` before
  touching shared files. `history.md` is append-only.
- Motion uses `GridConstants` spring tokens. No inline `.spring(...)`.
- Haptics via `HapticsEngine`. Never instantiate a feedback generator inline.
- Icon sizes come from `GridConstants.icon*` tokens.
- Stage your own paths: `git commit -- <paths>`. Never `-a`, never `add -A` —
  that is how two simulator recording folders ended up committed.
- The owner builds from `main`. Work parked on a branch is invisible to him.

## Safety

- `HabitLog.imageFileName` points at real user photos. Never delete or rewrite
  image files on a code path that only meant to read them.
- Adding a case to `HabitCategory` is safe for SwiftData, but it must be kept out
  of pickers — use `HabitCategory.selectable`, not `allCases`.
