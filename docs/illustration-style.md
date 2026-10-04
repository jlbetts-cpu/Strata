# Some Wins illustration style

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

## The prompt (v3)

**Why v2 failed** (first real result, 2026-10-03, a scarecrow): every contour
drawn with several hairy strokes, hatching on the hat, the coat and the
ground, a grey pencil smudge, six falling leaves, straw fingers. The owner:
"too many lines... doesnt have the hey tea style at all... too complicated".
The words did it: "pen-and-ink", "storybook sketch", "1920s" and "hatch
strokes" ask a model for exactly that rendering, and the Shepard reference
pages pull the same way. What it got right, and v3 keeps: the slumped
gesture, the dot eyes, one prop.

**v3 flips the weighting.** HeyTea leads: one clean line, each contour drawn
once, very few elements, lots of white. Shepard is reduced to three things:
a slight wobble, contours left open, and at most one tiny patch of shadow.

### References

Use **only your own drawings** (01 and 02 in `illustration-references/`)
for the custom style. Leave the Shepard pages out: they teach density, and
density is what went wrong. Add your best v3 results to the style as they
come.

### The recurring character

> a small round-headed person, slightly lopsided round head, two dot eyes,
> simple soft bean-shaped body, short stubby arms and legs, no fingers

### The prompt

```
A minimal doodle illustration of [SCENE, one small everyday moment, one
character, at most one prop].

Drawn like a modern tea-brand illustration: a few confident black lines, each
contour drawn once in a single smooth stroke, even medium weight with soft
round ends, slightly wobbly as if by hand, some contours left open. Simple
round shapes, dot eyes, no fingers. Lots of white space: the drawing is small
and centred. The ground is one short line. At most one tiny patch of three
short parallel strokes for shadow. About 15 to 25 lines in total. Quiet,
playful humour. Black line on white.
```

### Negative prompt

```
sketchy lines, multiple overlapping strokes, hairy lines, cross-hatching,
hatching, pencil shading, smudge, grey, texture, stippling, detailed
rendering, vintage engraving, scattered elements, falling leaves, confetti,
motion lines, background, frame, border, fingers, straw, text, letters,
signature, watermark, colour, gradient, 3D, realistic proportions
```

### Settings

Recraft: Vector illustration (or the custom style from your drawings only),
square, 4 variations. Elsewhere: square, 4 variations, then vectorise.

### Pick the one that passes

- **Can you count the lines?** If not, it's too busy.
- **Is every contour a single stroke,** never a bundle of hairy ones?
- **One character, at most one prop,** nothing scattered around them?
- **Is white most of the picture?**
- **At 60pt, can you still tell what's happening?**
- **No hatching beyond one tiny patch, no grey, no fingers, no text?**
- **Beside October and the crews drawing,** does it look like the same hand?

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
