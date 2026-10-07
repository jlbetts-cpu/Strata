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

## Storyboard v4 (53.5 s, 16:9, 1920x1080, 30 fps)

v4 answers his notes on v3: it is **a photo app with friends**, so his own
photos (the zip) and friends' faces lead every shot; no doodle or plain
colour blocks; blocks only ever fall, with gravity, in the order they were
said; reveals are slower and calmer; the sound is quiet and tactile; the
crew chat is shown.

| # | Time | Camera | Picture | Words |
|---|---|---|---|---|
| 0 | 0.0 | inside the screen, then out | The launch: the logo draws, then erases at full size; we pull out of the screen as the app opens | |
| 1 | 3.8 | type | His photos (the dog, breakfast, the beach, Yosemite, the kayak) drift forward out of depth round the line, then fall | "Every day has a few small wins." |
| 2 | 7.2 | type, drum | "I kayaked the bay / had a real breakfast / walked the dog / hiked Yosemite / won the game / went to the beach / had a bonfire / graduated": each photo block falls onto a tower in that order, bottom row first | |
| 3 | 12.6 | hero 3D, slow orbit | A photo block falls from above the phone into the real tower's next place | "Every win is a block." |
| 4 | 17.0 | extraction | Three photo blocks lift off the screen and hang in depth | "Snap it. Stack it. Keep it." |
| 5 | 20.9 | macro, low | The crest fills; colour bursts off the screen | "Hit your goal," |
| 6 | 23.5 | high, over the island | The island prints the strip | "and your day prints." |
| 7 | 26.7 | the phone shakes in 3D | The strip develops | "Shake to develop." |
| 8 | 30.1 | extraction | The real strip leaves the screen, turns over, hangs beside the phone | "Share it anywhere." |
| 9 | 33.9 | 3D arc, then rise | His photos with friends turn on a curved wall; the phone rises; friends' faces fly into the crew bubble; heads pop out | "Better with friends." |
| 9b | 38.9 | close, then extraction | The crew chat: today's lines arrive one by one (friends' faces in their circles); "so proud of you 🔥", a reply to his win, lifts off the screen | "Cheer each other on." |
| 10 | 44.1 | lying back | October's skeleton dances | "Every month, its own drawing." |
| 11 | 47.3 | black | The full stop lands as a block | "Small wins. Stacked." |
| 12 | 49.6 | the launch again | The logo draws, "Some Wins", the official App Store badge | |

**Sound (v4):** effects only and quiet (peak -14 dBFS, average about -41):
modal fingertip taps, felt landings for blocks, soft air for moves, a warm
bloom for the goal and the develop, pencil and eraser grain for the logo, a
small printer motor, paper flutter for the shake. Everything goes through
real rooms (GarageBand's impulse responses). No pitch sweeps, no cartoon.

## Rules for the build

- Real app footage only, in the phone; pieces that leave the screen are crops of the same frame.
- Photos only in blocks (no doodle or plain blocks); blocks only fall, with gravity, in order.
- Type: SF Pro, ink only (grey only while a word arrives); Zen Maru for the wordmark.
- No shadows, no glow. Hairline and depth of field separate things.
- The App Store badge is Apple's official artwork, unaltered.
- No em dashes, no surveillance language. Photos: his chosen set; friends' faces with their OK.
- Deterministic: every frame drawn from the clock, so a change re-renders exactly.
