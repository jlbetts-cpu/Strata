"""The owner's drawn icons, cut from his Procreate sheet (2026-10-06).

Run from docs/icons: reads source.png (his contact sheet, 1920 x 6750, black
ink on white, stored greyscale so it is a third of the size and the same
pixels) and writes Doodle*.imageset into Strata/Assets.xcassets as template
images at @2x and @3x. `python3 slice_icons.py --preview out.png` also writes a
contact sheet of every icon at its real size, light and dark, to look at.

The split he approved (2026-10-06, "less is so much more to me"): his hand
where you DRAW (the ink tools, the day's sticker) and on the category chips;
SF Symbols for everything whose job is to be recognised at a glance (back,
close, share, trash). Then (2026-10-07): "make sure the icons still look clean
and premium, I don't want the app to lose value from this update." So every
icon here goes through three steps, and none of them redraws him:

1. ONE STROKE WEIGHT ON SCREEN. He draws at one pen, about 9.8px on a ~170px
   icon, which is 0.058 of the icon; an SF Symbol at Medium is 0.10 (a 17pt
   `circle` measures 1.72pt of ring). Shown at an SF size his line read as a
   hairline beside the type. Each outline icon is thickened to `STROKE_PT` at
   the size it is shown, measured per icon, so the eraser and the undo match
   even though he drew them at different sizes on the sheet.
2. SMOOTHED, NOT TRACED. At 4x, a light blur and a re-cut at half: the pen's
   ragged edge goes, his wobble in the line stays.
3. SIZED BY EYE AGAINST THE SYMBOL IT REPLACES. A drawn icon reads smaller
   than a geometric one of the same box (round ends, no hard corners), so each
   is drawn `OPTICAL` larger than the SF Symbol's own ink box, measured off
   SF Symbols rendered at the same point size and weight.
"""
import os
import sys
import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, '../../Strata/Assets.xcassets')
UP = 4              # supersampling for the thicken and smooth
SPECK = 30          # source px: smaller pieces of ink are stray marks
STROKE_PT = 1.6     # the line on screen, at the size it is shown
OPTICAL = 1.12      # drawn this much larger than the SF ink box it replaces
SMOOTH = 1.2        # source px of blur before the re-cut
CAL = 0.815         # erosion-depth estimate -> true width, from his smiley's
                    # ring (9.7px measured across, 11.9px estimated)

# The sheet's cells: a row band (16 of them, top to bottom) and a column
# (six, 300px apart from x = 60). See the module note in the commit for the
# sheet's full order; only what ships is listed.
#
# name: (band, column, filled, SF ink box it replaces in pt (w, h) at the
#        canvas's own point size, canvas pt)
# The tools are shown at `GridConstants.iconToolbar` (17) on a 26pt canvas;
# the category chips at `iconCategory` (13) on a 20pt canvas.
ICONS = {
    'DoodleSticker':    (4, 4, False, (17.3, 17.3), 26),
    'DoodleHealth':     (15, 0, True, (12.7, 12.0), 20),
    'DoodleWork':       (15, 1, True, (15.0, 12.7), 20),
    'DoodleCreativity': (15, 2, True, (13.0, 15.7), 20),
    'DoodleFocus':      (15, 3, True, (17.3, 11.3), 20),
    'DoodleSocial':     (15, 4, True, (17.3, 12.0), 20),
    'DoodleMindfulness': (15, 5, True, (14.0, 12.0), 20),
    # The tips' marks (2026-10-08, the owner: "i made like 100 icons... make
    # sure the grid is good on the tips"). All outline, one stroke, shown in
    # the tip's round well on the tools' 26pt canvas: his plus in a circle
    # (the slot), his sparkle star, his pencil, his person with a plus.
    'TipPlus':          (0, 4, False, (17.3, 17.3), 26),
    'TipSparkle':       (2, 3, False, (17.3, 17.3), 26),
    'TipPencil':        (4, 0, False, (16.6, 16.6), 26),
    'TipPersonPlus':    (10, 1, False, (18.6, 17.0), 26),
}
# Optical corrections by eye, after looking at the built rows: his eraser
# stands on a line, which makes its box taller than the eraser itself reads;
# his people are two small shapes and a sliver, and read a size under the
# heart and the bag beside them on the chips.
TWEAK = {'DoodleSocial': 1.1}
# The white inside a filled glyph (the bag's clasp, the eye's ring, the leaf's
# veins) opened by this much each side: at 13pt his gaps were half a point and
# the clasp read as a smudge. The outside edge is not touched.
COUNTER_PT = 0.22

# The eraser while it is on: his eraser, filled, as `eraser.fill` is the
# selected tool across iOS. Made from the outline, not drawn.
FILLED_FROM = {}  # the eraser went back to Apple's (2026-10-07)


def disk(m, r):
    """Grow a mask by a round pen of radius r px."""
    r = int(round(r))
    if r <= 0:
        return m
    out = m.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r:
                out |= np.roll(np.roll(m, dy, 0), dx, 1)
    return out


def stroke_width(m):
    """A line's width in px: 4x the mean octagonal erosion depth, calibrated."""
    m = np.pad(m, 2)
    depth = np.zeros(m.shape, float)
    cur, i = m.copy(), 0
    while cur.any():
        depth += cur
        n = cur & np.roll(cur, 1, 0) & np.roll(cur, -1, 0) & np.roll(cur, 1, 1) & np.roll(cur, -1, 1)
        if i % 2:
            n &= np.roll(np.roll(cur, 1, 0), 1, 1) & np.roll(np.roll(cur, 1, 0), -1, 1) \
                & np.roll(np.roll(cur, -1, 0), 1, 1) & np.roll(np.roll(cur, -1, 0), -1, 1)
        cur, i = n, i + 1
    return CAL * 4 * depth[m].mean()


def label(m):
    """Connected pieces (8-way), as an int array, and their sizes."""
    H, W = m.shape
    lab = np.zeros((H, W), int)
    sizes, n = {}, 0
    for y, x in zip(*np.nonzero(m)):
        if lab[y, x]:
            continue
        n += 1
        stack, lab[y, x], count = [(y, x)], n, 0
        while stack:
            cy, cx = stack.pop()
            count += 1
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = cy + dy, cx + dx
                    if 0 <= ny < H and 0 <= nx < W and m[ny, nx] and not lab[ny, nx]:
                        lab[ny, nx] = n
                        stack.append((ny, nx))
        sizes[n] = count
    return lab, sizes


def outside_of(solid):
    """Background reachable from the border."""
    h, w = solid.shape
    out = np.zeros_like(solid)
    stack = [(y, x) for y in (0, h - 1) for x in range(w)] + [(y, x) for x in (0, w - 1) for y in range(h)]
    while stack:
        y, x = stack.pop()
        if 0 <= y < h and 0 <= x < w and not out[y, x] and not solid[y, x]:
            out[y, x] = True
            stack += [(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)]
    return out


def bands(ink):
    rows = ink.any(axis=1)
    out, start = [], None
    for y, v in enumerate(rows):
        if v and start is None:
            start = y
        if not v and start is not None:
            out.append((start, y))
            start = None
    if start is not None:
        out.append((start, len(rows)))
    return out


def cut(ink, band, column):
    """The ink of one cell: every piece whose middle falls in the cell."""
    y0, y1 = band
    x0, x1 = 60 + 300 * column, 360 + 300 * column
    region = ink[y0 - 24:y1 + 24, max(0, x0 - 60):x1 + 60]
    lab, sizes = label(region > 0.5)
    keep = np.zeros(region.shape, bool)
    for k, size in sizes.items():
        if size < SPECK:
            continue
        ys, xs = np.nonzero(lab == k)
        mid = xs.mean() + max(0, x0 - 60)
        if x0 <= mid < x1:
            keep |= lab == k
    # His anti-aliased edge stays with the piece it belongs to.
    near = disk(keep, 2)
    return np.where(near, region, 0)


def render(name, cov, filled, box_pt, canvas_pt, scale, fill_on=False):
    """One icon on its canvas at `scale` (2 or 3), as an alpha array."""
    m = cov > 0.5
    ys, xs = np.nonzero(m)
    w, h = xs.max() - xs.min() + 1, ys.max() - ys.min() + 1
    # Fit the SF box times OPTICAL, by whichever side binds.
    # Fit the SF box times OPTICAL. Bound by the tighter side alone, a
    # drawing whose shape is not the symbol's (his eye is rounder than
    # `eye.fill`, his people squarer than `person.2.fill`) came out a size
    # smaller than its neighbours on the chips. The mean of the two fits,
    # held to 8% past the tighter one, keeps the row one size.
    kw, kh = box_pt[0] * OPTICAL / w, box_pt[1] * OPTICAL / h
    k = min((kw * kh) ** 0.5, 1.08 * min(kw, kh)) * TWEAK.get(name, 1.0)    # pt per source px
    if filled:
        grow = 0.0
        if name in SIMPLER:
            cov = SIMPLER[name](cov, k)
        cov = open_counters(cov, COUNTER_PT / k)
    else:
        target = STROKE_PT / k                                  # source px
        grow = max(0.0, (target - stroke_width(m)) / 2)
    if fill_on:
        cov = fill(m, grow).astype(float)
        grow = 0.0
    big = Image.fromarray((cov * 255).astype(np.uint8))
    big = big.resize((big.width * UP, big.height * UP), Image.BICUBIC)
    g = np.array(big) >= 128
    g = np.pad(g, int(UP * (grow + 8)))
    g = disk(g, grow * UP)
    sm = Image.fromarray(g.astype(np.uint8) * 255).filter(ImageFilter.GaussianBlur(SMOOTH * UP))
    g = np.array(sm) >= 128
    ys, xs = np.nonzero(g)
    g = g[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    px_per_big = k * scale / UP
    gw, gh = max(1, round(g.shape[1] * px_per_big)), max(1, round(g.shape[0] * px_per_big))
    glyph = Image.fromarray(g.astype(np.uint8) * 255).resize((gw, gh), Image.LANCZOS)
    side = round(canvas_pt * scale)
    a = Image.new('L', (side, side), 0)
    a.paste(glyph, ((side - gw) // 2, (side - gh) // 2))
    return a, grow * 2 * k


def seam_only(cov, k):
    """His bag with its flap line kept and its clasp taken in: the ring
    round the clasp is what ran into a smudge at the chip's 13pt (the owner,
    2026-10-07: "simplify my two"), and the seam across is what says
    briefcase. Filling the whole inside was tried and read as a cloud.
    The clasp sits at the middle of the white inside, which is symmetric
    about it, so its centre is that white's centre of mass."""
    ink = cov > 0.5
    shut = disk(np.pad(ink, 12), max(2, int(round(1.2 / k))))
    inner = ~ink & ~outside_of(shut)[12:-12, 12:-12]
    ys, xs = np.nonzero(inner)
    if not len(xs):
        return cov
    cy, cx = ys.mean(), xs.mean()
    bx = np.nonzero(ink)[1]
    r = 0.2 * (bx.max() - bx.min())
    yy, xx = np.mgrid[:cov.shape[0], :cov.shape[1]]
    clasp = inner & ((yy - cy) ** 2 + (xx - cx) ** 2 <= r * r)
    return np.where(clasp, 1.0, cov)


def back_steps_back(cov, k):
    """His two people with the shoulder behind left out: at 13pt the sliver
    of it read as a speck beside the front figure (the owner, 2026-10-07:
    "simplify my two"). The head behind stays, so it is still two people,
    as `person.2.fill` shows the one behind by its head. Paring the back
    figure thinner instead was tried and read as slivers."""
    ink = cov > 0.5
    lab, sizes = label(ink)
    big = sorted((n for n in sizes if sizes[n] > 30), key=lambda n: np.nonzero(lab == n)[1].mean())
    if len(big) < 4:
        return cov
    back = big[2:]
    shoulder = max(back, key=lambda n: np.nonzero(lab == n)[0].mean())
    return np.where(lab == shoulder, 0.0, cov)


SIMPLER = {'DoodleWork': seam_only, 'DoodleSocial': back_steps_back}


def open_counters(cov, r):
    """Widen the white inside a filled shape by r source px, leaving its
    outside edge where he drew it. Inside means not reachable from the
    border once gaps narrower than ~2r are shut, so the leaf's open-ended
    veins count as inside and the space around the shape does not."""
    ink = cov > 0.5
    shut = disk(np.pad(ink, 8), max(1, r))
    outside = outside_of(shut)[8:-8, 8:-8]
    inner = ~ink & ~outside
    return np.where(disk(inner, r), 0, cov)


def fill(m, grow):
    """The outline filled solid, as `eraser.fill` is the selected tool across
    iOS, with the line he drew across its inside (the eraser's tip) kept as a
    cut. At source resolution, after the line is thickened.

    Only the shape's own insides fill: a pocket smaller than a fifth of the
    largest (the sliver between the eraser's corner and the line it stands
    on) is left open, or the corner turns into a blob."""
    g = disk(np.pad(m, 4), grow)
    line = stroke_width(g)
    outside = outside_of(g)
    lab, sizes = label(~g & ~outside)
    biggest = max(sizes.values())
    insides = np.isin(lab, [k for k, v in sizes.items() if v >= biggest / 5])
    # Ink more than a line from the outside is the line drawn across the
    # inside. It meets the outline at both ends, where distance alone cannot
    # tell it from the outline, so it is carried on along its own direction
    # out through the edge: `eraser.fill`'s cut runs right across, and a cut
    # that stops short floats in the middle like a highlight.
    solid = g | insides
    core = g & ~disk(outside, line * 1.1)
    cut = core.copy()
    ys, xs = np.nonzero(core)
    if len(xs) > 10:
        pts = np.stack([xs, ys], 1).astype(float)
        mid = pts.mean(0)
        axis = np.linalg.svd(pts - mid)[2][0]
        t = (pts - mid) @ axis
        for end in (t.min(), t.max()):
            near = pts[np.abs(t - end) < (t.max() - t.min()) * 0.3]
            d = np.linalg.svd(near - near.mean(0))[2][0]
            tip = pts[np.argmin(np.abs(t - end))]
            if np.dot(d, tip - mid) < 0:
                d = -d
            r = line * 0.5
            yy, xx = np.ogrid[:g.shape[0], :g.shape[1]]
            for step in np.arange(0, line * 3, 1.0):
                cx, cy = tip + d * step
                # Stop once it is through the edge: further on it would
                # nick the line the eraser stands on.
                if not solid[int(round(cy)), int(round(cx))]:
                    break
                cut |= (xx - cx) ** 2 + (yy - cy) ** 2 <= r * r
    return (solid & ~cut)[4:-4, 4:-4]


def save(name, alphas):
    folder = os.path.join(ASSETS, f'{name}.imageset')
    os.makedirs(folder, exist_ok=True)
    for scale, a in alphas.items():
        black = Image.new('L', a.size, 0)
        Image.merge('RGBA', [black, black, black, a]).save(os.path.join(folder, f'{name}@{scale}x.png'))
    with open(os.path.join(folder, 'Contents.json'), 'w') as f:
        f.write('{\n  "images" : [\n    { "idiom" : "universal", "scale" : "1x" },\n'
                f'    {{ "filename" : "{name}@2x.png", "idiom" : "universal", "scale" : "2x" }},\n'
                f'    {{ "filename" : "{name}@3x.png", "idiom" : "universal", "scale" : "3x" }}\n'
                '  ],\n  "info" : { "author" : "xcode", "version" : 1 },\n'
                '  "properties" : { "template-rendering-intent" : "template" }\n}\n')


def preview(made, path):
    """Every icon at 3x, black on the light page and white on the dark one."""
    tiles = [(n, a[3]) for n, a in made.items()]
    pad, side = 24, max(a.width for _, a in tiles)
    sheet = Image.new('RGB', ((side + pad) * len(tiles) + pad, (side + pad) * 2 + pad), (246, 244, 240))
    dark = Image.new('RGB', (sheet.width, (side + pad) + pad // 2), (31, 30, 29))
    sheet.paste(dark, (0, side + pad + pad // 2))
    for i, (_, a) in enumerate(tiles):
        x = pad + i * (side + pad)
        sheet.paste(Image.new('RGB', a.size, (20, 20, 20)), (x, pad), a)
        sheet.paste(Image.new('RGB', a.size, (240, 240, 240)), (x, side + 2 * pad), a)
    sheet.save(path)


if __name__ == '__main__':
    src = np.array(Image.open(os.path.join(HERE, 'source.png')).convert('L')).astype(float)
    ink = 1 - src / 255
    rows = bands(ink > 0.5)
    assert len(rows) == 16, f'the sheet has {len(rows)} rows, not 16'
    made = {}
    for name, (band, column, filled, box, canvas) in ICONS.items():
        cov = cut(ink, rows[band], column)
        made[name] = {}
        for scale in (2, 3):
            made[name][scale], line = render(name, cov, filled, box, canvas, scale)
        print(f'{name}: stroke {stroke_width(cov > 0.5):.1f}px drawn, '
              f'grown to {line + STROKE_PT * 0:.2f}pt extra' if not filled else f'{name}: filled')
    for name, base in FILLED_FROM.items():
        band, column, _, box, canvas = ICONS[base]
        cov = cut(ink, rows[band], column)
        made[name] = {s: render(base, cov, False, box, canvas, s, fill_on=True)[0] for s in (2, 3)}
        print(f'{name}: filled from {base}')
    if '--preview' in sys.argv:
        preview(made, sys.argv[sys.argv.index('--preview') + 1])
    else:
        # `--only A,B` writes just those, so adding an icon never rewrites
        # the ones already shipping.
        only = sys.argv[sys.argv.index('--only') + 1].split(',') if '--only' in sys.argv else None
        for name, alphas in made.items():
            if only is None or name in only:
                save(name, alphas)
