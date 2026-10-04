# Some Wins illustration style

> **Decision, 2026-10-03: the owner draws them; Claude cleans and fits them.**
> Two AI rounds read as AI. His own drawings already have the naive, deadpan
> charm; what held them back was mechanics (a thick uneven marker line, big
> filled blacks, extra strokes), not skill. The prompts below stay for
> composition ideas only.

## Drawing one in Procreate

1. **Canvas:** 2048 x 2048 px. Hide the background layer before exporting,
   so it comes out transparent.
2. **Brush:** Inking > Technical Pen, black, about 18 to 22 px (roughly 1% of
   the canvas width). Streamline low (10 to 20%) so your wobble stays. No
   QuickShape: let circles be a bit lopsided.
3. **Draw less:** one subject, 12 to 20 strokes. Stop when it reads.
4. **No big black fills.** A crow or a bat is an outline with one dot eye.
   Keep solid black to eyes and tiny details.
5. **Leave it imperfect:** let strokes overshoot or not quite meet, and don't
   redraw a line that wobbles. That's the charm.
6. **Deadpan:** dot eyes, no smiles, no fingers.
7. **Export:** Share > PNG, named for its place (`MonthNovember`,
   `CrewsTogether`, `PlanEmpty`; see "Prompts by screen" for every name), and
   send it. Claude crops it, removes specks, sizes it to 3x and fits it on the
   page in the app's ink, so it works in dark mode.

The owner, 2026-10-03: HeyTea's charm plus E.H. Shepard's old-timey pen
sketches, simple and minimal, SVG, made for digital, and reading as human,
imperfections and all.

## What each brings

**HeyTea:** few lines, lots of white, one small everyday moment, gentle humour.
A round, simple figure with dot eyes doing one ordinary thing (sipping,
waiting, carrying). Black line on white, colour rarely, and type set beside
the drawing rather than inside it. ([Icy Tan's HeyTea work](https://www.icytan.com/blog/heytea-logo-illustration))

**E.H. Shepard:** life in the pen line. Economy of line, the white page doing
the work of air and light, sparse cross-hatching that wraps a form to give it
weight, posture carrying emotion (Eeyore's mood is three slumping contours),
and scenes that fade out at the edges instead of sitting in a frame.
([Abduzeedo, Shepard at 100](https://abduzeedo.com/eh-shepard-100-craft-winnie-pooh-illustration),
[High Museum](https://high.org/exhibition/winnie-the-pooh-exploring-a-classic/),
[Creative Boom](https://www.creativeboom.com/inspiration/winnie-the-pooh/))

**Together:** HeyTea's simplicity and subject, drawn with Shepard's hand.

## The rules

1. **One clean line, drawn once.** Near-black (the app tints it), even medium
   weight, soft round ends, a slight hand wobble. Every contour is a single
   stroke, never a bundle of sketchy ones. No fills except eyes and the
   occasional tiny solid (a crow, a shoe).
2. **Lines don't close.** Contours break, overshoot a little, or stop short.
   A shape is suggested, not traced shut.
3. **Almost no shadow.** At most one tiny patch of three short parallel
   strokes, usually under whatever stands on the ground. Never a grey fill,
   never hatching across a form.
4. **No frame, no scenery.** The ground is one short line. Nothing scattered
   around the subject: no leaves, no confetti, no motion lines.
5. **Count the lines.** About 15 to 25 in the whole drawing. One character,
   at most one prop.
6. **White is most of the picture.** The subject takes about a third of the
   canvas, centred, with air on every side.
7. **Gesture over detail.** Round heads, dot eyes, at most a short mouth. Arms
   and posture say the feeling. No fingers (mittens or simple ends), no noses
   beyond a bump.
8. **One small moment, gently funny.** A win the size of a day: a walk, a
   tidied desk, a friend's call, a first coffee.
9. **No text inside the drawing.** The app sets any words.

## What gives AI away, avoided by design

- Perfect symmetry and evenly spaced strokes: ask for unevenness.
- Uniform line weight everywhere: ask for nib pressure.
- Fully closed, smooth outlines: ask for broken lines.
- Grey fills, gradients, soft shading: forbid them.
- Busy backgrounds and frames: forbid them.
- Hands and lettering: leave them out.
- Everything centred and polished at once: ask for one off-balance element.

**The most human result is a human pass.** Use the generated drawing as a
sketch, then trace it in Procreate with your own hand. You keep the
composition and gain the real wobble. Your own drawings already have the thing
AI can't fake; this gives them structure.

## The prompt (v4)

**Why v3 still read as AI** (second result, 2026-10-03, a pumpkin, a broom
and a crow): one perfectly even line weight, every curve smooth and closed,
a kawaii smile on the pumpkin, a symmetrical pumpkin and a neatly detailed
broom binding. Clean, polished and cute: the default look of an image model.
"Tea-brand illustration" means nothing to a model, and "playful" pulled it
toward kawaii.

**What HeyTea actually does, in a model's terms:** a thin, slightly shaky
fineliner line on paper; strokes that don't quite meet; naive, slightly
awkward proportions drawn that way on purpose by an adult; deadpan figures,
often in profile, with a dot eye or no face; dry humour in an ordinary
moment; lots of empty paper. Not cute. Shepard stays only as the occasional
open contour.

### References

Into the custom style: **5 to 8 HeyTea illustrations you save yourself**
(black line only, one figure, deadpan, mostly white; from HeyTea's own
Instagram or Weibo, Icy Tan's HeyTea project, or the HeyTea illustration
board on Pinterest), **plus your October drawing**. Imitating the style is
fair; the images stay private references and nothing of theirs is published.
Leave the Shepard pages out.

### The recurring character

> a deadpan little person drawn naively, a slightly too-big round head, a
> single dot eye, often seen in profile, a plain soft body, stick-like arms,
> no fingers

### The prompt

```
A naive fineliner doodle of [SCENE, one ordinary moment, one character or
object, at most one prop].

Thin black fineliner line on white paper, drawn quickly by hand by an adult
on purpose simply: slightly shaky, small gaps where strokes don't quite
meet, a few lines that overshoot, uneven pressure. Slightly awkward naive
proportions. Deadpan: a single dot eye or no face, figures often in profile,
no smiles. Dry, understated humour. Lots of empty paper; the doodle is small
and centred. One short ground line. About 12 to 20 lines in total. Black line
on white only.
```

### Negative prompt

```
cute, kawaii, smiling faces, chibi, cartoon mascot, clip art, vector art,
perfectly smooth curves, uniform line weight, closed outlines, symmetry,
polished, detailed, hatching, shading, grey, texture, colour, gradient,
scattered elements, background, frame, text, letters, signature, watermark,
fingers, 3D
```

### Settings

Recraft: your custom style (the HeyTea references and October), square, 4
variations. If the tool has a "raw" or low-stylisation setting, use it: the
model's own polish is what reads as AI. Vectorise after (below) keeping the
wobble; don't smooth.

### Pick the one that passes

- **Does it look slightly wrong in a charming way** (proportions, a gap, a
  wobble)? If it looks perfect, it reads as AI.
- **No smile, no kawaii face?**
- **Line thin and a little uneven, strokes not all closed?**
- **12 to 20 lines, one subject, mostly white?**
- **At 60pt, can you still tell what's happening?**
- **Beside your October drawing,** could it be the same hand?

### The surest route

Draw the composition yourself as a rough doodle (your October drawing is
exactly the right energy), then use the tool's image-to-image or sketch mode
with this prompt and low strength, so it only tidies your line. The
imperfection stays yours, and the result can't look generated because it
isn't, mostly.

**Scene ideas, one per month, each a small win:**

- January: a figure in a scarf walking a dog through two strokes of snow.
- February: two friends sharing one umbrella, a heart-shaped puddle.
- March: someone planting a seedling, a worm peeking out.
- April: a figure jumping a puddle, a frog unimpressed.
- May: a picnic blanket corner, a bee on a sandwich.
- June: a figure reading under a tree, feet up.
- July: friends on a hill watching a single firework.
- August: a figure on a bike, a kite caught behind.
- September: a figure carrying a stack of books, the top one tipping.
- October: a crow on a pumpkin, a broom leaning on it, a bat overhead.
- November: two figures with mugs, steam curling into one shape.
- December: a figure carrying a small tree home, snow on its hat.
- Crews: three friends on a hill, arms up, a few rays of light.


## Prompts by screen

Every prompt below is the v4 prompt with its scene filled in. Paste it as is,
with the negative prompt from above. One drawing per screen, where the screen
is waiting for you; the Wins tower itself stays empty, because it is the
space you fill. **Size** is the most the app draws it, in points; store it
at 3x. **Asset** is the name to save it as, so it drops straight in.

### Memories

**January**: asset `MonthJanuary`, up to 170pt tall

```
A naive fineliner doodle of a deadpan little person with a slightly too-big round head and a single dot eye in a long scarf walking a small dog through two strokes of snow.

Thin black fineliner line on white paper, drawn quickly by hand by an adult on purpose simply: slightly shaky, small gaps where strokes don't quite meet, a few lines that overshoot, uneven pressure. Slightly awkward naive proportions. Deadpan: a single dot eye or no face, figures often in profile, no smiles. Dry, understated humour. Lots of empty paper; the doodle is small and centred. One short ground line. About 12 to 20 lines in total. Black line on white only.
```

**February**: asset `MonthFebruary`, up to 170pt tall

```
A naive fineliner doodle of two deadpan little people with slightly too-big round heads and single dot eyes sharing one small umbrella, a heart-shaped puddle at their feet.

Thin black fineliner line on white paper, drawn quickly by hand by an adult on purpose simply: slightly shaky, small gaps where strokes don't quite meet, a few lines that overshoot, uneven pressure. Slightly awkward naive proportions. Deadpan: a single dot eye or no face, figures often in profile, no smiles. Dry, understated humour. Lots of empty paper; the doodle is small and centred. One short ground line. About 12 to 20 lines in total. Black line on white only.
```

**March**: asset `MonthMarch`, up to 170pt tall

```
A naive fineliner doodle of a deadpan little person with a slightly too-big round head and a single dot eye kneeling to pat the soil around one seedling, a worm peeking out.

Thin black fineliner line on white paper, drawn quickly by hand by an adult on purpose simply: slightly shaky, small gaps where strokes don't quite meet, a few lines that overshoot, uneven pressure. Slightly awkward naive proportions. Deadpan: a single dot eye or no face, figures often in profile, no smiles. Dry, understated humour. Lots of empty paper; the doodle is small and centred. One short ground line. About 12 to 20 lines in total. Black line on white only.
```

**April**: asset `MonthApril`, up to 170pt tall

```
A naive fineliner doodle of a deadpan little person with a slightly too-big round head and a single dot eye mid-jump over a puddle, a frog on the edge looking unimpressed.

Thin black fineliner line on white paper, drawn quickly by hand by an adult on purpose simply: slightly shaky, small gaps where strokes don't quite meet, a few lines that overshoot, uneven pressure. Slightly awkward naive proportions. Deadpan: a single dot eye or no face, figures often in profile, no smiles. Dry, understated humour. Lots of empty paper; the doodle is small and centred. One short ground line. About 12 to 20 lines in total. Black line on white only.
```

**May**: asset `MonthMay`, up to 170pt tall

```
A naive fineliner doodle of a deadpan little person with a slightly too-big round head and a single dot eye on the corner of a picnic blanket, a single bee on their sandwich.

Thin black fineliner line on white paper, drawn quickly by hand by an adult on purpose simply: slightly shaky, small gaps where strokes don't quite meet, a few lines that overshoot, uneven pressure. Slightly awkward naive proportions. Deadpan: a single dot eye or no face, figures often in profile, no smiles. Dry, understated humour. Lots of empty paper; the doodle is small and centred. One short ground line. About 12 to 20 lines in total. Black line on white only.
```

**June**: asset `MonthJune`, up to 170pt tall

```
A naive fineliner doodle of a deadpan little person with a slightly too-big round head and a single dot eye reading under a small round tree, feet crossed up on the trunk.

Thin black fineliner line on white paper, drawn quickly by hand by an adult on purpose simply: slightly shaky, small gaps where strokes don't quite meet, a few lines that overshoot, uneven pressure. Slightly awkward naive proportions. Deadpan: a single dot eye or no face, figures often in profile, no smiles. Dry, understated humour. Lots of empty paper; the doodle is small and centred. One short ground line. About 12 to 20 lines in total. Black line on white only.
```

**July**: asset `MonthJuly`, up to 170pt tall

```
A naive fineliner doodle of a deadpan little person with a slightly too-big round head and a single dot eye sitting on a hill looking up at one simple firework.

Thin black fineliner line on white paper, drawn quickly by hand by an adult on purpose simply: slightly shaky, small gaps where strokes don't quite meet, a few lines that overshoot, uneven pressure. Slightly awkward naive proportions. Deadpan: a single dot eye or no face, figures often in profile, no smiles. Dry, understated humour. Lots of empty paper; the doodle is small and centred. One short ground line. About 12 to 20 lines in total. Black line on white only.
```

**August**: asset `MonthAugust`, up to 170pt tall

```
A naive fineliner doodle of a deadpan little person with a slightly too-big round head and a single dot eye riding a bike with a little kite trailing behind.

Thin black fineliner line on white paper, drawn quickly by hand by an adult on purpose simply: slightly shaky, small gaps where strokes don't quite meet, a few lines that overshoot, uneven pressure. Slightly awkward naive proportions. Deadpan: a single dot eye or no face, figures often in profile, no smiles. Dry, understated humour. Lots of empty paper; the doodle is small and centred. One short ground line. About 12 to 20 lines in total. Black line on white only.
```

**September**: asset `MonthSeptember`, up to 170pt tall

```
A naive fineliner doodle of a deadpan little person with a slightly too-big round head and a single dot eye carrying a stack of three books, the top one tipping.

Thin black fineliner line on white paper, drawn quickly by hand by an adult on purpose simply: slightly shaky, small gaps where strokes don't quite meet, a few lines that overshoot, uneven pressure. Slightly awkward naive proportions. Deadpan: a single dot eye or no face, figures often in profile, no smiles. Dry, understated humour. Lots of empty paper; the doodle is small and centred. One short ground line. About 12 to 20 lines in total. Black line on white only.
```

**October**: asset `MonthOctober`, up to 170pt tall

```
A naive fineliner doodle of a crow perched on a round pumpkin with a broom leaning against it, one small bat above.

Thin black fineliner line on white paper, drawn quickly by hand by an adult on purpose simply: slightly shaky, small gaps where strokes don't quite meet, a few lines that overshoot, uneven pressure. Slightly awkward naive proportions. Deadpan: a single dot eye or no face, figures often in profile, no smiles. Dry, understated humour. Lots of empty paper; the doodle is small and centred. One short ground line. About 12 to 20 lines in total. Black line on white only.
```

**November**: asset `MonthNovember`, up to 170pt tall

```
A naive fineliner doodle of two deadpan little people with slightly too-big round heads and single dot eyes holding mugs side by side, their steam curling into one swirl.

Thin black fineliner line on white paper, drawn quickly by hand by an adult on purpose simply: slightly shaky, small gaps where strokes don't quite meet, a few lines that overshoot, uneven pressure. Slightly awkward naive proportions. Deadpan: a single dot eye or no face, figures often in profile, no smiles. Dry, understated humour. Lots of empty paper; the doodle is small and centred. One short ground line. About 12 to 20 lines in total. Black line on white only.
```

**December**: asset `MonthDecember`, up to 170pt tall

```
A naive fineliner doodle of a deadpan little person with a slightly too-big round head and a single dot eye carrying a small round tree home, a little snow on their hat.

Thin black fineliner line on white paper, drawn quickly by hand by an adult on purpose simply: slightly shaky, small gaps where strokes don't quite meet, a few lines that overshoot, uneven pressure. Slightly awkward naive proportions. Deadpan: a single dot eye or no face, figures often in profile, no smiles. Dry, understated humour. Lots of empty paper; the doodle is small and centred. One short ground line. About 12 to 20 lines in total. Black line on white only.
```

### Crews

**Under the crews list**: asset `CrewsTogether`, up to 120pt tall

```
A naive fineliner doodle of three deadpan little people with slightly too-big round heads and single dot eyes standing close on a small hill, arms up, a few short rays above them.

Thin black fineliner line on white paper, drawn quickly by hand by an adult on purpose simply: slightly shaky, small gaps where strokes don't quite meet, a few lines that overshoot, uneven pressure. Slightly awkward naive proportions. Deadpan: a single dot eye or no face, figures often in profile, no smiles. Dry, understated humour. Lots of empty paper; the doodle is small and centred. One short ground line. About 12 to 20 lines in total. Black line on white only.
```

**No crews yet**: asset `CrewsEmpty`, up to 140pt tall

```
A naive fineliner doodle of a deadpan little person with a slightly too-big round head and a single dot eye holding a door open and waving someone in.

Thin black fineliner line on white paper, drawn quickly by hand by an adult on purpose simply: slightly shaky, small gaps where strokes don't quite meet, a few lines that overshoot, uneven pressure. Slightly awkward naive proportions. Deadpan: a single dot eye or no face, figures often in profile, no smiles. Dry, understated humour. Lots of empty paper; the doodle is small and centred. One short ground line. About 12 to 20 lines in total. Black line on white only.
```

**Crews are for 13 and up**: asset `CrewsTooYoung`, up to 120pt tall

```
A naive fineliner doodle of a deadpan little person with a slightly too-big round head and a single dot eye happily stacking three small blocks into a little tower on their own.

Thin black fineliner line on white paper, drawn quickly by hand by an adult on purpose simply: slightly shaky, small gaps where strokes don't quite meet, a few lines that overshoot, uneven pressure. Slightly awkward naive proportions. Deadpan: a single dot eye or no face, figures often in profile, no smiles. Dry, understated humour. Lots of empty paper; the doodle is small and centred. One short ground line. About 12 to 20 lines in total. Black line on white only.
```

**Signed out of iCloud**: asset `CrewsNoICloud`, up to 120pt tall

```
A naive fineliner doodle of a deadpan little person with a slightly too-big round head and a single dot eye holding the string of a small cloud like a balloon.

Thin black fineliner line on white paper, drawn quickly by hand by an adult on purpose simply: slightly shaky, small gaps where strokes don't quite meet, a few lines that overshoot, uneven pressure. Slightly awkward naive proportions. Deadpan: a single dot eye or no face, figures often in profile, no smiles. Dry, understated humour. Lots of empty paper; the doodle is small and centred. One short ground line. About 12 to 20 lines in total. Black line on white only.
```

**Crew rules (before the first crew)**: asset `CrewRules`, up to 120pt tall

```
A naive fineliner doodle of two deadpan little people with slightly too-big round heads and single dot eyes giving each other a high five.

Thin black fineliner line on white paper, drawn quickly by hand by an adult on purpose simply: slightly shaky, small gaps where strokes don't quite meet, a few lines that overshoot, uneven pressure. Slightly awkward naive proportions. Deadpan: a single dot eye or no face, figures often in profile, no smiles. Dry, understated humour. Lots of empty paper; the doodle is small and centred. One short ground line. About 12 to 20 lines in total. Black line on white only.
```

**Report sent**: asset `ReportThanks`, up to 100pt tall

```
A naive fineliner doodle of a deadpan little person with a slightly too-big round head and a single dot eye dropping a small envelope into a round postbox.

Thin black fineliner line on white paper, drawn quickly by hand by an adult on purpose simply: slightly shaky, small gaps where strokes don't quite meet, a few lines that overshoot, uneven pressure. Slightly awkward naive proportions. Deadpan: a single dot eye or no face, figures often in profile, no smiles. Dry, understated humour. Lots of empty paper; the doodle is small and centred. One short ground line. About 12 to 20 lines in total. Black line on white only.
```

### Wins and Plan

**Empty plan**: asset `PlanEmpty`, up to 120pt tall

```
A naive fineliner doodle of a deadpan little person with a slightly too-big round head and a single dot eye with a pencil tucked behind the ear, looking at one short checklist.

Thin black fineliner line on white paper, drawn quickly by hand by an adult on purpose simply: slightly shaky, small gaps where strokes don't quite meet, a few lines that overshoot, uneven pressure. Slightly awkward naive proportions. Deadpan: a single dot eye or no face, figures often in profile, no smiles. Dry, understated humour. Lots of empty paper; the doodle is small and centred. One short ground line. About 12 to 20 lines in total. Black line on white only.
```

**First open, before the first win**: asset `WinsFirst`, up to 140pt tall

```
A naive fineliner doodle of a deadpan little person with a slightly too-big round head and a single dot eye placing one small square block on the ground, very proud.

Thin black fineliner line on white paper, drawn quickly by hand by an adult on purpose simply: slightly shaky, small gaps where strokes don't quite meet, a few lines that overshoot, uneven pressure. Slightly awkward naive proportions. Deadpan: a single dot eye or no face, figures often in profile, no smiles. Dry, understated humour. Lots of empty paper; the doodle is small and centred. One short ground line. About 12 to 20 lines in total. Black line on white only.
```

### Memories states

**A day with nothing logged**: asset `DayEmpty`, up to 120pt tall

```
A naive fineliner doodle of a deadpan little person with a slightly too-big round head and a single dot eye napping on a small bench, one 'z' above.

Thin black fineliner line on white paper, drawn quickly by hand by an adult on purpose simply: slightly shaky, small gaps where strokes don't quite meet, a few lines that overshoot, uneven pressure. Slightly awkward naive proportions. Deadpan: a single dot eye or no face, figures often in profile, no smiles. Dry, understated humour. Lots of empty paper; the doodle is small and centred. One short ground line. About 12 to 20 lines in total. Black line on white only.
```

**No photographs in a month**: asset `PhotosEmpty`, up to 120pt tall

```
A naive fineliner doodle of a simple camera sitting on a stool, a deadpan little person with a slightly too-big round head and a single dot eye peeking from behind it.

Thin black fineliner line on white paper, drawn quickly by hand by an adult on purpose simply: slightly shaky, small gaps where strokes don't quite meet, a few lines that overshoot, uneven pressure. Slightly awkward naive proportions. Deadpan: a single dot eye or no face, figures often in profile, no smiles. Dry, understated humour. Lots of empty paper; the doodle is small and centred. One short ground line. About 12 to 20 lines in total. Black line on white only.
```

**No recap yet**: asset `RecapEmpty`, up to 110pt tall

```
A naive fineliner doodle of a deadpan little person with a slightly too-big round head and a single dot eye holding a small film reel and waiting, tapping one foot.

Thin black fineliner line on white paper, drawn quickly by hand by an adult on purpose simply: slightly shaky, small gaps where strokes don't quite meet, a few lines that overshoot, uneven pressure. Slightly awkward naive proportions. Deadpan: a single dot eye or no face, figures often in profile, no smiles. Dry, understated humour. Lots of empty paper; the doodle is small and centred. One short ground line. About 12 to 20 lines in total. Black line on white only.
```

**Location off (map)**: asset `MapNoLocation`, up to 110pt tall

```
A naive fineliner doodle of a deadpan little person with a slightly too-big round head and a single dot eye holding a folded map upside down, puzzled.

Thin black fineliner line on white paper, drawn quickly by hand by an adult on purpose simply: slightly shaky, small gaps where strokes don't quite meet, a few lines that overshoot, uneven pressure. Slightly awkward naive proportions. Deadpan: a single dot eye or no face, figures often in profile, no smiles. Dry, understated humour. Lots of empty paper; the doodle is small and centred. One short ground line. About 12 to 20 lines in total. Black line on white only.
```

### Camera and settings

**Camera turned off**: asset `CameraOff`, up to 120pt tall

```
A naive fineliner doodle of a deadpan little person with a slightly too-big round head and a single dot eye holding a camera with the lens cap still on.

Thin black fineliner line on white paper, drawn quickly by hand by an adult on purpose simply: slightly shaky, small gaps where strokes don't quite meet, a few lines that overshoot, uneven pressure. Slightly awkward naive proportions. Deadpan: a single dot eye or no face, figures often in profile, no smiles. Dry, understated humour. Lots of empty paper; the doodle is small and centred. One short ground line. About 12 to 20 lines in total. Black line on white only.
```

**Notifications off**: asset `NotificationsOff`, up to 100pt tall

```
A naive fineliner doodle of a small round bell asleep, wearing a nightcap.

Thin black fineliner line on white paper, drawn quickly by hand by an adult on purpose simply: slightly shaky, small gaps where strokes don't quite meet, a few lines that overshoot, uneven pressure. Slightly awkward naive proportions. Deadpan: a single dot eye or no face, figures often in profile, no smiles. Dry, understated humour. Lots of empty paper; the doodle is small and centred. One short ground line. About 12 to 20 lines in total. Black line on white only.
```

**Privacy: everything stays on the phone**: asset `PrivacyLocal`, up to 110pt tall

```
A naive fineliner doodle of a deadpan little person with a slightly too-big round head and a single dot eye tucking a phone into a coat pocket with a little smile.

Thin black fineliner line on white paper, drawn quickly by hand by an adult on purpose simply: slightly shaky, small gaps where strokes don't quite meet, a few lines that overshoot, uneven pressure. Slightly awkward naive proportions. Deadpan: a single dot eye or no face, figures often in profile, no smiles. Dry, understated humour. Lots of empty paper; the doodle is small and centred. One short ground line. About 12 to 20 lines in total. Black line on white only.
```

## Making it ready for the app

The app shows drawings as a single-colour template (it inks them itself and
follows dark mode), up to 170pt tall, at 3x.

1. **Vectorise** if the tool gave a raster: [vtracer](https://github.com/visioncortex/vtracer)
   (`vtracer --input in.png --output out.svg --colormode binary --mode spline
   --filter_speckle 8`), Illustrator Image Trace (Black and White Logo), or
   Vectorizer.ai. Keep the line's natural edge; don't smooth it.
2. **Clean the SVG:** black only (`#000`, the app recolours it), transparent
   background, no text, no embedded images, no filters. Delete specks.
   Aim for under 60 paths and under 40 KB.
3. **Hand it over** as the SVG or a transparent PNG. The asset is stored at 3x
   its largest on-screen size as greyscale with alpha, the same way October's
   and the crews' drawings are.
