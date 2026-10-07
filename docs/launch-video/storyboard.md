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

## Storyboard v3 (46.5 s, 16:9, 1920x1080, 30 fps)

| # | Time | Camera | Picture | Words | Sound |
|---|---|---|---|---|---|
| 0 | 0.0 | inside the screen, pulling back | The app's launch: the logo draws itself full frame, then erases at full size (he likes the erase; keep it close, never under a camera move); we pull out of the screen and the phone forms round it; it turns to a 3D hero angle as the app opens | | pencil stroke, air, tap |
| 1 | 3.8 | type | The wins themselves (dog, breakfast, Yosemite, kayak, the doodle) burst out round the line in depth, then fall | "Every day has a few small wins." | pops, fall |
| 2 | 6.8 | type, drum | A 3D word drum rolls: "I drank some water / went outside / walked the dog…"; each one drops a block that lands in a row | | tick per roll, thud per block |
| 3 | 11.0 | hero 3D, slow orbit | A photo block flies out of the camera and lands on the real tower; the tower keeps building | "Every win is a block." | air, landing |
| 4 | 15.4 | extraction | Three blocks lift off the screen and hang in depth as the phone falls away | "Snap it. Doodle it. Or just tap it." | shutter, pencil, tap |
| 5 | 19.3 | macro, low | The crest fills and coloured blocks burst off the screen | "Hit your goal," | chime, pops |
| 6 | 21.9 | high, over the island | The island opens into a printer; the strip feeds out | "and your day prints." | printer ticks |
| 7 | 25.1 | the whole phone shakes in 3D | The strip develops | "Shake to develop." | rattle, shimmer |
| 8 | 28.5 | extraction | The real strip leaves the screen, turns over, and hangs beside the phone | "Share it anywhere." | lift, turn, paper |
| 9 | 32.3 | type, then rise | Friends' faces burst round the line in shallow focus, the phone rises, the faces fly into the crew bubble, heads pop out | "Better with friends." | pops |
| 10 | 37.1 | lying back, top-down | October's skeleton dances | "Every month, its own drawing." | bones |
| 11 | 40.3 | black | The full stop lands as a block | "Small wins. Stacked." | low tap, landing |
| 12 | 42.6 | the launch again | The logo draws, "Some Wins" in Zen Maru, the official App Store badge | | pencil, tap |

## Rules for the build

- Real app footage only, in the phone; pieces that leave the screen are crops of the same frame.
- Type: SF Pro, ink only (grey only while a word arrives); Zen Maru for the wordmark.
- No shadows, no glow. Hairline and depth of field separate things.
- The App Store badge is Apple's official artwork, unaltered.
- No em dashes, no surveillance language. Photos: his chosen set; friends' faces with their OK.
- Deterministic: every frame drawn from the clock, so a change re-renders exactly.
