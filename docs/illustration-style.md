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

## The prompt (v2)

v1 rated 7/10 against these criteria: it put "no colour, no text, no frame"
inside the prompt, where image models tend to draw the nouns; it was long
and loose for Recraft, which follows short structured prompts; nothing held
a series together from month to month; nothing kept it readable at 120 to
170pt; it asked for a re-traced line, which comes out as a doubled outline;
and it gave no way to judge results. v2 fixes each. It is rated on craft,
not on runs: test it on the tool and adjust the scene line first.

### 1. Make it one series (once)

In Recraft, create a **custom style** from 3 to 5 references: your October
and crews drawings plus the first outputs you love. Every month is then
generated in that saved style, so the series holds together even when the
scene changes. Re-save the style as better pieces come in.

### 2. The recurring character

Keep one figure across every drawing, so the series has a face:

> a small round-headed person with a slightly lopsided round head, two dot
> eyes, no mouth unless smiling, a simple rounded body like a soft bean, short
> stubby arms and legs, no fingers

### 3. The prompt

Two parts. The **style block** never changes; only the **scene** does.

```
A pen-and-ink spot illustration of [SCENE, one small everyday moment, with the
recurring character].

Style: 1920s storybook pen sketch meets modern minimalist brand illustration.
One black ink line, medium weight and loose, drawn quickly by hand, slightly
wobbly, with gentle pressure variation and tapered ends. Contours left open
in places. Light from the upper left: a few short diagonal hatch strokes on
the lower right of each form and a small hatched patch on the ground beneath.
The ground is two or three short horizontal strokes and a tuft of grass,
fading into the white page. Pure white page around a centred vignette that
fills about a third of the square canvas. Under 40 strokes in total, each
bold enough to read at icon size. Gentle, understated humour; posture tells
the feeling. Black ink on white only.
```

### 3b. A/B version: Shepard named, lightly

Why the names are left out of 3: HeyTea's illustration barely exists in
image models' training, so the name mostly yields tea cups and logos;
Shepard's name is strong enough to pull Pooh and Piglet into the frame,
which reads as pastiche (the most AI-looking result) and comes close to a
known character; some services refuse or rewrite named-style requests; and
two names average into two famous looks instead of one of yours. This
version names Shepard as a mood only and fences off his characters. Run it
beside 3 and keep whichever passes the checklist more often.

```
A pen-and-ink spot illustration of [SCENE, with the recurring character], in
the spirit of E. H. Shepard's loose storybook pen sketches, simplified into a
playful modern minimal brand illustration. One loose black ink line with
gentle pressure variation, contours left open in places, a few short diagonal
hatch strokes for shadow with light from the upper left, a hint of ground in
two or three strokes fading into a pure white page. Centred vignette about a
third of the square canvas, under 40 strokes, readable at icon size. Original
characters only. Black ink on white only.
```

Add to the negative prompt for this version: `Winnie-the-Pooh, Pooh bear,
Piglet, Eeyore, Christopher Robin, teddy bear, Hundred Acre Wood`.

### 4. Negative prompt

```
colour, grey, gradient, soft shading, solid black fills, 3D, glossy,
perfect symmetry, uniform line weight, smooth closed outlines, doubled
outlines, clip art, corporate flat vector, thick cartoon outline, frame,
border, background scenery, pattern, text, letters, signature, watermark,
hands with fingers, detailed faces, realistic proportions, tiny fine details
```

### 5. Settings

- Recraft: **Vector illustration** style (or your saved custom style), square
  1:1, 4 variations per run.
- Elsewhere (Midjourney, GPT image, Imagen): square, generate 4, then
  vectorise as below.

### 6. Pick the one that passes

Keep a drawing only if every answer is yes:

- **At 60pt (thumbnail size):** can you still tell what's happening?
- **Is white most of the picture?**
- **Do some lines stop short or overshoot?** (If every contour is sealed, it
  will read as machine-made.)
- **Is the hatching under 8 strokes per form, all one direction?**
- **No fingers, no text, no frame, no grey?**
- **Is something slightly off-balance?** (A tilt, a dropped stroke, a
  lopsided head.)
- **Beside October and the crews drawing,** does it look like the same hand?

Then do the human pass: trace it once in Procreate at your own speed. That
pass is what makes it yours.

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
