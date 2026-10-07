# Some Wins launch video: breakdown and storyboard (v3)

Level 1 of the workflow he shared: the film is built in code, frame by frame,
around real recordings of the app. **Sound effects only** (the phone's own
taps, drops, the print, the shake); music goes on after, by him.

v3 (2026-10-07) answers his notes on v2: monotone type that fits the brand,
the logo booting up at the start, the real App Store badge at the end, true
3D device angles, UI that leaves the screen and lands on it, more life, and
the "clever adds" outside the product that make it feel premium.

## Why the renderer changed

Higgsedit (Higgsfield's editor) only rotates flat in 2D. A phone with
thickness, a camera that orbits it, and a block that flies out of the screen
need real perspective, so the film is a page with CSS 3D (a phone built from
stacked slices of its aluminium band, glass inset inside the rim) rendered
frame by frame at 2x and encoded natively. Higgsfield stays for what only it
can do: generated profile pictures for the social burst (his call, later,
on credits he approves).

## The four references, frame by frame (10 fps on every type moment)

| | Rene | Wabi 2.0 | Okara Dots |
|---|---|---|---|
| Open | macro on real bubbles, pull back to the phone | sunset orb, typed line with a cursor | pixel logo morphs into the name |
| Phone | white phone on white, nearly front-on, often cropped by the frame | phone huge and cropped; widgets fly out to a curved 3D carousel | no phone; UI windows floating in depth |
| UI ↔ screen | a notification lifts off the lock screen, floats alone, then a phone rises under it and it lands in the chat | a bubble stands alone, the phone forms round it; cards leave the phone into an arc | panels tilted in 3D, cursor presses |
| Clever adds | ⚽ bounces through "l⚽ve"; a cloud of faces in shallow focus; real people in a park with UI over them | 3D objects (plane, camera, suitcase) burst round a bubble; hearts burst off the screen; avatars burst round "friends" | soft-focus windows drifting behind the logo |
| Close | logo draws, line, URL | "iOS. Android." | logo, pill CTA |

**Type, exactly:** words never slide; each blurs in (about 0.4 s, 0.1 s
apart) and arrives grey, then darkens to ink. Leaving, words blur out while an
anchor word stays and the line re-centres round it. A held line pushes in by
a few percent. Wabi is fully monotone: ink, with grey only for words still
arriving. That is the Some Wins brand (one face, ink), so the film is
monotone; the only colour is the product's own (blocks, photos).

**Camera, exactly:** nothing sits still. Slow pushes on long eases, a few
degrees of orbit, macro on one element, and depth of field on anything behind.

## What a stranger can't get from a screenshot

1. Wins are blocks that fall. 2. The goal prints your day; the Dynamic Island
is the printer; shake to develop. 3. Friends, as heads. 4. It's yours, by hand
(doodles, the month's drawing). 5. Small on purpose.

Psychology in order: curiosity → recognition → reward → belonging → identity → ask.

## Storyboard v5 (45.6 s, cut to the music)

v5 answers his notes on v4: TikTok pace (57.7 s down to 45.6 s, every shot
played 1.2x to 1.7x of its authored timing), show the camera, the journal and
doodling, the strip's real back, all three block sizes, no glitches on
camera, more varied animation per shot (Muse, the fifth reference), and his
music: Monume, "Product Launch" (Pixabay, 110 BPM). The track's drop
(8.70 s) lands on the pull-out from the screen, and **every cut falls on a
beat**: each shot lasts a whole number of beats.

**Muse (Meta), frame by frame:** objects sitting inline in the sentence; a
middle line that swaps with an icon; a full-screen grid of tiny objects
rippling in; a macro into one calendar day as it changes; a typed field with
a cursor; badges on the close. Taken: inline photos in line 1, the typed
journal line, the photo grid behind "Small wins. Stacked.", the dive into a
calendar day, and the shutter freezing the frame.

| # | Beats | Picture | Words |
|---|---|---|---|
| 0 | (to the drop) | Logo draws, erases at full size; out of the screen as the app opens | |
| 1 | 4 | His photos pop inline into the sentence | "Every day has a few small wins." |
| 2 | 8 | Word drum; photo blocks fall in order, Quick, Regular and a Deep 2x2 | "I kayaked the bay / ... / played with the team" |
| 3 | 10 | The real camera with his night-market clip as the lens (debug `-strataFakeLens`): compose, draw a wide block out of the shutter, the frame freezes and pops off the screen, pick a look, name it | "Snap it." "Pick a look." "Name it." |
| 4 | 4 | That photo falls into the next free slot of his real tower | "Every win is a block." |
| 4b | 6 | The journal: the line writes in, the doodle (moon, sparkle, taco) draws on in the app's ink | "Write it down." (typed) "Doodle on it." |
| 5 | 4 | Crest fills, colour bursts off the screen | "Hit your goal," |
| 6 | 4 | Island prints the strip | "and your day prints." |
| 7 | 6 | Shake; the strip develops at real speed | "Shake to develop." |
| 8 | 6 | The strip leaves the screen, turns to its real back (Some Wins, the date), turns back | "Share it anywhere." |
| 9 | 6 | His photos with friends on a 3D arc; faces fly into the crew bubble | "Better with friends." |
| 9b | 6 | The crew chat; a reply lifts off the screen | "Cheer each other on." |
| 10 | 4 | October's skeleton, then a dive into the calendar's days | "Every month, its own drawing." |
| 11 | 4 | Grid of all his photos ripples in; the full stop lands as a block | "Small wins. Stacked." |
| 12 | 6 | Logo draws, "Some Wins", App Store badge | |

**Never on camera:** the dark tab bar that lingers after leaving the camera
(a known Liquid Glass cost, written down in `MainAppView`), and the purple
placeholder before a new block's photo loads. Both are cut around.

## Rules for the build

- Real app footage only, in the phone; pieces that leave the screen are crops of the same frame.
- Photos only in blocks (no doodle or plain blocks); blocks only fall, with gravity, in order.
- Type: SF Pro, ink only (grey only while a word arrives); Zen Maru for the wordmark.
- No shadows, no glow. Hairline and depth of field separate things.
- The App Store badge is Apple's official artwork, unaltered.
- No em dashes, no surveillance language. Photos: his chosen set; friends' faces with their OK.
- Deterministic: every frame drawn from the clock, so a change re-renders exactly.
