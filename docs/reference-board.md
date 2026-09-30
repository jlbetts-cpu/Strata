# What the board actually says

Read from the owner's `pretty ui` board, 89 pins, 2026-09-30. Written down
because it corrects several things I built this week from a wrong reading.

---

## 1. The single biggest finding: soft-3D objects, not flat panes

The dominant motif on the board, by a wide margin, is **things that look
moulded**. Ceramic discs. A water ripple in a pale surface. Glass pills with a
real specular highlight along the top. An entire sheet of "WEB UI SET · control
elements" that is puffy skeuomorphic knobs and buttons. Soft-3D app icons with
volume.

Every one of them has the same three ingredients:

1. a **bright rim or highlight along the top edge**, where the light is,
2. a **soft interior shading** that makes the surface read as curved rather than
   printed,
3. a **wide, faint occlusion shadow** underneath, close to the object.

**This is what he meant by "a physical blob of liquid glass".** He was not
describing Apple's Liquid Glass and its refraction — he was describing THESE,
which are a different tradition entirely: moulded volume, lit from above.

That is why the custom lens shader missed and why `.regular` glass missed. Both
were chasing refraction. The board wants **volume**.

## 2. Blurred colour is an OBJECT, never a wash

There are a lot of aurora gradients on this board — magenta into orange into
blue, heavily blurred, beautiful. And in almost every case the gradient is
**contained**: a circle, a blob, a card, sitting on a plain neutral field.

Nowhere on the board is a soft gradient smeared behind an entire interface.

**This is the direct correction to what I built.** The `DayGround` work put the
light behind everything as an all-over wash, which is why it kept reading as
"too strong" and "just red" no matter how it was tuned. The board's answer is the
opposite shape: a calm ground, with the light concentrated into one contained
object on it.

## 3. The ground is grey, not white

Pin after pin sits on a light neutral grey rather than white, and lets white
elements float above it. That is what gives the white things somewhere to be
bright against — the exact headroom problem the lattice ran into when the page
was lightened to 240 and the panes disappeared.

A grey ground solves it structurally rather than by tuning an opacity.

## 4. Chrome is crisp; softness lives in imagery

The soft, blurred, glowing things on this board are almost always **content**.
The controls over them are sharp: dark pill navs, crisp capsule buttons, legible
type, hard edges. Nothing is softly blurred AND a control at the same time.

## 5. Shapes: pills and generous radii

Floating pill tab bars, capsule buttons, rounded rectangles with big corners.
Strata already agrees with this.

---

## What this means, component by component

**The ground.** Stop the all-over wash. A calm neutral light grey, slightly
darker than the panes, so the tower and the lattice float on it. The sky scene
becomes either nothing or one contained element, not a full-bleed backdrop.

**The empty slot.** This is the board's signature object and currently the thing
furthest from it. It should be moulded: a bright top rim, soft interior
shading, a wide faint shadow under it. Not a refraction effect — volume.

**The blocks.** They already have a rim (`BlockChrome`). The board suggests
pushing the top-edge highlight and keeping the shadow wide and faint, which is
the direction the shadows were just taken anyway.

**The tab bar.** Already a floating pill. Correct.

**Where the light goes.** If the day's colour is to appear at all, it belongs in
one contained object — a soft orb behind the tower's foot, or nothing — rather
than tinting the page.

---

## Where this contradicts what is in the app today

Recorded plainly so the next session does not re-litigate it:

- `DayGround`'s full-bleed scene is the wrong shape for this board. It was built
  across several rounds and each round was told it was "too strong"; the reason
  is structural, not a value.
- The lattice going to a white pane is RIGHT, but it needs a grey ground under
  it to be visible without a drawn line.
- `docs/design-system-future.md` §6 allows shadow only for things standing on
  something. The board's soft-3D objects all carry one. That rule and this board
  disagree, and the owner owns both — worth asking before shadows spread.
