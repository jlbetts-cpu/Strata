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

1. **One ink, one weight family.** Near-black line (the app tints it), a nib
   that swells slightly on downstrokes and thins at the ends. No fills except
   eyes and the occasional tiny solid (a crow, a shoe).
2. **Lines don't close.** Contours break, overshoot a little, or stop short.
   A shape is suggested, not traced shut.
3. **Hatching is shadow, and there is little of it.** Three to seven short
   parallel strokes on the side away from the light, and a small patch under
   whatever stands on the ground. Never a grey fill.
4. **No frame. A vignette.** The ground is two to four short horizontal strokes
   and a tuft or two of grass; the scene fades into white at the edges.
5. **White is most of the picture.** The subject takes about a third of the
   canvas, centred, with air on every side.
6. **Gesture over detail.** Round heads, dot eyes, at most a short mouth. Arms
   and posture say the feeling. No fingers (mittens or simple ends), no noses
   beyond a bump.
7. **One small moment, gently funny.** A win the size of a day: a walk, a
   tidied desk, a friend's call, a first coffee.
8. **No text inside the drawing.** The app sets any words.

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

## The prompt

Use Recraft (V3 or later) with the vector illustration style for a direct
SVG, or any image model and then vectorise (below).

```
A minimal pen-and-ink vignette of [SCENE].

Drawn like an old-timey storybook sketch with a modern, playful simplicity:
a single near-black ink line from a flexible dip pen, swelling slightly on
downstrokes and tapering at the ends. Loose, confident, slightly wobbly lines
that often don't close, overshoot a little or stop short. Simple round-headed
characters with dot eyes and no fingers; posture and gesture carry the
feeling. Shadow only as a few short, uneven cross-hatched strokes on one side
and a small hatched patch on the ground beneath. The ground is just two or
three short horizontal strokes and a couple of grass tufts that fade into
white. No frame and no background: a vignette on pure white, the subject
about a third of the canvas and centred, with lots of empty space. Gentle,
understated humour. Hand-drawn imperfections: uneven hatching spacing,
asymmetry, one line slightly re-traced. Black ink only, no colour, no grey,
no gradients, no text.
```

**Avoid (negative prompt, where the tool has one):**

```
colour, grey fill, gradient, shading, soft shadows, 3D, glossy, perfect
symmetry, uniform line weight, closed smooth outlines, clip art, flat
corporate vector, thick cartoon outlines, frame, border, background, pattern,
text, letters, logo, watermark, hands with fingers, detailed faces, photoreal
```

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
