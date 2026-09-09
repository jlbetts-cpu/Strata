#!/usr/bin/env python3
"""Builds the Strata app icon: the Jaro S, cut into five stacked blocks.

    python3 tools/make_app_icon.py

Writes AppIcon-light/dark/tinted.png into the asset catalogue.

WHY THE S IS CUT WHERE IT IS
----------------------------
Jaro's S is not a curve. It is an angular ribbon whose outline has four
INNER corners, at y = 367, 545, 815 and 1000 in font units. Cutting the
glyph on those four lines splits it into exactly the five strokes the
letterform is built from — a bottom arm, a riser, the middle diagonal, a
riser, a top arm — with no seam landing anywhere arbitrary. The cuts are
horizontal because that is how the tower stacks; a block never sits on a
slope.

So the icon is not an S with decoration applied. It is the same S, taken
apart at its own joints, with each piece drawn as one of the app's blocks.

WHY THE GENERATOR LIVES HERE
----------------------------
The chrome constants below are COPIES of `GridConstants`. They are
duplicated rather than imported because this runs outside the app, and the
duplication is the reason this file exists in the repo instead of being a
one-off: if the block's rim, wash or band ever changes, re-run this and the
icon follows. Keep the two in sync.
"""
import math
import re
import os
import sys

from fontTools.pens.recordingPen import RecordingPen
from fontTools.ttLib import TTFont
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_logo as logo
FONT = os.path.join(ROOT, "Strata/Resources/Jaro.ttf")
OUT = os.path.join(ROOT, "Strata/Assets.xcassets/AppIcon.appiconset")

# --- GridConstants, mirrored. Keep in sync. -------------------------------
RIM_W_RATIO = 1.4 / 86.5      # blockRimWidth / blockReferenceCell
RIM_FALLOFF = 0.45            # blockRimFalloff
SCRIM = 0.10                  # blockScrimOpacity
BAND_START = 0.74             # blockBandFeatherEnd
BAND_FEATHER = 0.66           # blockBandFeatherStart
BLUR_OF_WIDTH = 0.0178        # blur is 1.78% of block width — NOT of the rim

# --- CategoryColors, mirrored. --------------------------------------------
GREEN = (0x0E, 0xAD, 0x74)    # health
BLUE = (0x40, 0xA9, 0xFF)     # work
PURPLE = (0xAF, 0x9C, 0xFA)   # creativity
ORANGE = (0xFD, 0xB5, 0x4F)   # focus
PINK = (0xEC, 0x85, 0xB4)     # mindfulness — the app's own colour
WARM_BLACK = (0x1C, 0x1A, 0x18)

# The mark is ONE colour, knocked out of a field.
#
# It was five, one per band, ordered by measured CIELAB separation. On a
# 1024px render that is lovely. At 50pt on a home screen it is mush: the two
# riser bands are four pixels tall, the colours average together, and what
# survives is a vague colourful blob rather than a letter. Rendered side by
# side at 210/110/70/50 the single-colour version reads instantly at every
# size and the five-colour one stops being legible below about 100.
#
# So the blocks are still there — you can see all five, because the field
# shows through the seams between them — but the thing you recognise from
# across a home screen is one confident shape in the app's own pink.
KNOCKOUT_GROUND = PINK
KNOCKOUT_INK = (255, 255, 255)
KNOCKOUT_GROUND_DARK = (0xC8, 0x6B, 0x98)   # mindfulness `darkShade`

# The gap between bands, in font units.
#
# The tower's gutter is 4pt on an 86.5pt cell — 4.6%. Held to that here, a
# band is ~267 units tall, so the seam is 12 units, which at 50pt on a home
# screen is a third of a pixel and disappears. 26 is what survives the
# smallest size the icon is ever drawn at, which is the size that decides
# whether anyone recognises it.
KNOCKOUT_GAP = 26.0

# The glyph's own inner corners.
CUTS = [0, 367, 545, 815, 1000, 1333]
BBOX = (90.0, 705.0, 0.0, 1333.0)   # minx, maxx, miny, maxy

# The S gets 72% of the icon's height. The old icon set it at 64%, which on a
# white ground read as timid — a knockout mark on a colour field can afford
# more air than a coloured mark on white. Compared at 180/110/64pt against the
# real squircle mask: below ~0.13 the slanted top and bottom arms start
# crowding the mask's corners, above ~0.16 the mark loses presence next to
# other icons.
MARGIN = 0.14
SS = 4           # supersample


def outline(ch="S", steps=16):
    """The glyph, flattened to a polygon."""
    font = TTFont(FONT)
    pen = RecordingPen()
    font.getGlyphSet()[font.getBestCmap()[ord(ch)]].draw(pen)
    poly, cur = [], None
    for op, args in pen.value:
        if op in ("moveTo", "lineTo"):
            cur = args[0]
            poly.append(cur)
        elif op == "qCurveTo":
            *ctrls, end = args
            for i, c in enumerate(ctrls):
                # TrueType implies an on-curve point midway between controls.
                e = end if i + 1 == len(ctrls) else (
                    (c[0] + ctrls[i + 1][0]) / 2, (c[1] + ctrls[i + 1][1]) / 2)
                for j in range(1, steps + 1):
                    t = j / steps
                    poly.append((
                        (1 - t) ** 2 * cur[0] + 2 * (1 - t) * t * c[0] + t * t * e[0],
                        (1 - t) ** 2 * cur[1] + 2 * (1 - t) * t * c[1] + t * t * e[1]))
                cur = e
    return poly


def band(poly, ylo, yhi):
    """The polygon clipped to a horizontal strip (Sutherland–Hodgman)."""
    def half(pts, inside, level):
        out = []
        for i, a in enumerate(pts):
            b = pts[(i + 1) % len(pts)]
            ain, bin_ = inside(a[1], level), inside(b[1], level)
            if ain:
                out.append(a)
            if ain != bin_:
                t = (level - a[1]) / (b[1] - a[1])
                out.append((a[0] + t * (b[0] - a[0]), level))
        return out
    p = half(poly, lambda y, l: y >= l, ylo)
    return half(p, lambda y, l: y <= l, yhi) if p else []


def _mask(pts, W):
    m = Image.new("L", (W, W), 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return m


def _vgrad(W, top, bot, fn):
    g = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(g)
    for y in range(max(0, int(top)), min(W, int(bot) + 1)):
        t = (y - top) / max(1.0, bot - top)
        d.line([(0, y), (W, y)], fill=max(0, min(255, int(255 * fn(t)))))
    if bot < W:
        d.rectangle([0, int(bot) + 1, W, W], fill=max(0, min(255, int(255 * fn(1.0)))))
    return g


def render(colours, size=1024, ground=(255, 255, 255), out=None):
    poly = outline()
    W = size * SS
    minx, maxx, miny, maxy = BBOX
    gw, gh = maxx - minx, maxy - miny
    sc = (W * (1 - 2 * MARGIN)) / gh
    ox = (W - gw * sc) / 2 - minx * sc
    oy = (W + gh * sc) / 2 + miny * sc

    def tf(p):
        return (ox + p[0] * sc, oy - p[1] * sc)

    cell = gh * sc / 5            # one band stands in for one tower cell
    rim_px = RIM_W_RATIO * cell

    # Everything is clipped to the S's own silhouette, so the frosted band
    # softens the SEAMS BETWEEN blocks and never the outline of the letter.
    silhouette = _mask([tf(p) for p in poly], W)

    def flat(i, colour):
        pts = [tf(p) for p in band(poly, CUTS[i], CUTS[i + 1])]
        if not pts:
            return None, None
        m = _mask(pts, W)
        s = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        ImageDraw.Draw(s).polygon(pts, fill=tuple(colour) + (255,))
        wash = Image.new("RGBA", (W, W), (255, 255, 255, int(255 * SCRIM)))
        s = Image.alpha_composite(s, Image.composite(
            wash, Image.new("RGBA", (W, W), (0, 0, 0, 0)), m))
        s.putalpha(m)
        return s, (pts, m)

    # A crisp backing of flat colour, under the chromed copy. Where the band's
    # blur thins the surface the colour beneath still shows, so the letter's
    # outline stays sharp — a blurry edge reads as a bad export at 60pt.
    backing = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    for i, colour in enumerate(colours):
        s, _ = flat(i, colour)
        if s:
            backing = Image.alpha_composite(backing, s)

    mark = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    for i, colour in enumerate(colours):
        surf, geo = flat(i, colour)
        if not surf:
            continue
        pts, m = geo
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        left, right, top, bot = min(xs), max(xs), min(ys), max(ys)

        # The rim: an inner border, brightest along the top edge, because a
        # block is lit from above rather than outlined.
        k = max(3, int(rim_px) | 1)
        edge = ImageChops.subtract(m, m.filter(ImageFilter.MinFilter(k)))
        falloff = _vgrad(W, top, bot, lambda t: 1.0 if t < 0.03 else
                         1.0 - (1 - RIM_FALLOFF) * min(1.0, (t - 0.03) / 0.5))
        rim = Image.new("RGBA", (W, W), (255, 255, 255, 0))
        rim.putalpha(ImageChops.multiply(edge, falloff))
        surf = Image.alpha_composite(surf, rim)

        # The frosted band: the same surface out of focus over the bottom 26%.
        # The blur eats the rim, so the seam below each block IS that rim
        # defocused — not a strip, and not a gradient.
        # Blur the COLOUR over a field of the same colour, not over
        # transparency. PIL blurs RGBA channels without premultiplying, so a
        # naive blur averages in the black behind the transparent pixels and
        # the block's bottom edge comes out dark — measured at (196,145,75)
        # against a body of (253,188,96). Extending the colour past the edge
        # first is what a premultiplied blur would have given.
        radius = BLUR_OF_WIDTH * (right - left)
        field = Image.new("RGB", (W, W), tuple(colour))
        field.paste(surf.convert("RGB"), (0, 0), surf.split()[3])
        blurred = field.filter(ImageFilter.GaussianBlur(radius)).convert("RGBA")
        blurred.putalpha(surf.split()[3].filter(ImageFilter.GaussianBlur(radius)))
        bandmask = _vgrad(W, top, bot, lambda t: 0.0 if t < BAND_FEATHER else
                          min(1.0, (t - BAND_FEATHER) / (BAND_START - BAND_FEATHER)))
        surf = Image.composite(blurred, surf, bandmask)
        # Clipped back to this block. `BlockSurface` does NOT do this — it lets
        # the blur spill past the bottom edge, which is right on the tower
        # because a 4pt gutter catches it. There is no gutter here, so the
        # spill lands on the block below and mixes two colours into a dirty
        # line. Measured at the orange/purple seam: (198,147,77) fading through
        # grey before the purple, where it should be light.
        surf.putalpha(ImageChops.multiply(surf.split()[3], m))
        mark = Image.alpha_composite(mark, surf)

    mark = Image.alpha_composite(backing, mark)
    mark.putalpha(silhouette)

    img = Image.new("RGB", (W, W), ground)
    img.paste(mark, (0, 0), mark.split()[3])
    img = img.resize((size, size), Image.LANCZOS)
    if out:
        img.save(out)
    return img


def _rdp(pts, eps):
    """Douglas-Peucker. Keeps the letterform's corners, drops the many points
    the quadratic flattening left along what are essentially straight runs."""
    if len(pts) < 3:
        return pts
    def dist(p, a, b):
        (x0, y0), (x1, y1), (x2, y2) = p, a, b
        dx, dy = x2 - x1, y2 - y1
        if dx == 0 and dy == 0:
            return math.hypot(x0 - x1, y0 - y1)
        t = max(0.0, min(1.0, ((x0 - x1) * dx + (y0 - y1) * dy) / (dx * dx + dy * dy)))
        return math.hypot(x0 - (x1 + t * dx), y0 - (y1 + t * dy))
    imax, dmax = 0, 0.0
    for i in range(1, len(pts) - 1):
        d = dist(pts[i], pts[0], pts[-1])
        if d > dmax:
            imax, dmax = i, d
    if dmax > eps:
        return _rdp(pts[:imax + 1], eps)[:-1] + _rdp(pts[imax:], eps)
    return [pts[0], pts[-1]]


def emit_swift(eps=2.0):
    """Prints the five bands as normalised Swift literals, for `StrataMark`.

    Normalised into a unit box: x across the glyph's width, y DOWN from its
    top, which is SwiftUI's convention and not the font's. The in-app mark is
    drawn from these rather than from a PNG so it stays the same object as the
    tower's blocks; it is generated rather than hand-typed so it stays the same
    object as the icon.
    """
    poly = outline()
    minx, maxx, miny, maxy = BBOX
    gw, gh = maxx - minx, maxy - miny
    print("    // Generated by tools/make_app_icon.py --swift. Do not hand-edit.")
    print("    static let bands: [[CGPoint]] = [")
    for i in range(5):
        pts = band(poly, CUTS[i], CUTS[i + 1])
        pts = _rdp(pts + [pts[0]], eps)[:-1]
        print(f"        [   // band {i}: y {CUTS[i]}\u2013{CUTS[i+1]}")
        row = []
        for x, y in pts:
            row.append(f"CGPoint(x: {(x - minx) / gw:.4f}, y: {(maxy - y) / gh:.4f})")
        for j in range(0, len(row), 3):
            print("            " + ", ".join(row[j:j + 3]) + ("," if j + 3 < len(row) else ""))
        print("        ]" + ("," if i < 4 else ""))
    print("    ]")
    print(f"    /// The glyph's own proportions: {gw:.0f} \u00d7 {gh:.0f} font units.")
    print(f"    static let aspect: CGFloat = {gw / gh:.4f}")


def render_knockout(ground, ink, size=1024, gap=KNOCKOUT_GAP):
    """The S in one colour, with the field showing through its seams."""
    poly = outline()
    W = size * SS
    minx, maxx, miny, maxy = BBOX
    gw, gh = maxx - minx, maxy - miny
    sc = (W * (1 - 2 * MARGIN)) / gh
    ox = (W - gw * sc) / 2 - minx * sc
    oy = (W + gh * sc) / 2 + miny * sc

    img = Image.new("RGB", (W, W), ground)
    draw = ImageDraw.Draw(img)
    for i in range(5):
        lo = CUTS[i] + (gap / 2 if i else 0)
        hi = CUTS[i + 1] - (gap / 2 if i < 4 else 0)
        pts = band(poly, lo, hi)
        if not pts:
            continue
        draw.polygon([(ox + p[0] * sc, oy - p[1] * sc) for p in pts], fill=ink)
    return img.resize((size, size), Image.LANCZOS)


def render_letter(ground, ink, size=1024, margin=0.175):
    """The S as a LETTER, set in Jaro, knocked out of a field.

    The icon has been three things. A flat pink field with a white Jaro S; the
    glyph taken apart into five coloured blocks; the same silhouette knocked
    out of pink in one colour. The owner's call (2026-09-09) is the first, and
    the reason holds up: the mark inside the app is one pink block with a
    letter on it, and an icon that is a different construction of the same
    letter is a second logo.

    Set with Core Text rather than reproduced from the outline data, so the
    letterform is exactly the font's.
    """
    from PIL import ImageFont
    SSx = 4
    W = size * SSx
    img = Image.new("RGB", (W, W), ground)
    draw = ImageDraw.Draw(img)

    # Binary-search the point size that puts the cap height at the margin.
    target = W * (1 - 2 * margin)
    lo, hi = 10, W * 2
    for _ in range(40):
        mid = (lo + hi) / 2
        font = ImageFont.truetype(FONT, int(mid))
        box = draw.textbbox((0, 0), "S", font=font)
        if (box[3] - box[1]) < target:
            lo = mid
        else:
            hi = mid
    font = ImageFont.truetype(FONT, int(lo))
    box = draw.textbbox((0, 0), "S", font=font)
    x = (W - (box[2] - box[0])) / 2 - box[0]
    y = (W - (box[3] - box[1])) / 2 - box[1]
    draw.text((x, y), "S", font=font, fill=ink)
    return img.resize((size, size), Image.LANCZOS)


MARK_SVG = os.path.join(ROOT, "brand", "strata-S-owner.svg")


def render_svg_mark(ink, ground, size=1024, margin=0.20):
    """The owner's `S`, rasterised from its SVG.

    `qlmanage` is the only SVG rasteriser on a stock Mac, and it flattens onto
    an opaque white canvas — so the letter is recovered as a MASK by
    thresholding the render, then painted. Reading the alpha channel does not
    work; it comes back fully opaque everywhere, which is what made the first
    two attempts at this produce a full-canvas bounding box.
    """
    import subprocess
    import tempfile
    from PIL import Image, ImageDraw

    tmp = tempfile.mkdtemp()
    src = open(MARK_SVG).read()
    # Force a dark letter on white, whatever the file says.
    src = src.replace('fill="white"', 'fill="#000000"')
    if 'fill="#000000"' not in src:
        src = src.replace("<path ", '<path fill="#000000" ', 1)
    src = src.replace("<svg", '<svg style="background:#FFFFFF"', 1)
    p = os.path.join(tmp, "mark.svg")
    open(p, "w").write(src)
    subprocess.run(["qlmanage", "-t", "-s", "4000", "-o", tmp, p], capture_output=True)
    rendered = p + ".png"
    if not os.path.exists(rendered):
        raise RuntimeError("qlmanage did not rasterise " + MARK_SVG)

    # INVERT the greyscale rather than thresholding it. A hard threshold
    # throws away the rasteriser's antialiasing, and the result was a letter
    # with visibly stepped edges at 1024px. Inverting keeps every intermediate
    # value, so the mask carries the soft edge straight through.
    grey = Image.open(rendered).convert("L")
    mask = grey.point(lambda v: 255 - v)
    box = mask.point(lambda v: 255 if v > 20 else 0).getbbox()
    if box is None:
        raise RuntimeError("no letter found in the rasterised mark")
    mask = mask.crop(box)

    SSx = 4
    W = size * SSx
    avail = W * (1 - 2 * margin)
    scale = min(avail / mask.width, avail / mask.height)
    m = mask.resize((max(1, int(mask.width * scale)), max(1, int(mask.height * scale))),
                    Image.LANCZOS)
    img = Image.new("RGB", (W, W), ground)
    img.paste(Image.new("RGB", m.size, ink), ((W - m.width) // 2, (W - m.height) // 2), m)
    return img.resize((size, size), Image.LANCZOS)


def svg_polygon(path, steps=18):
    """The S's outline as one flat polygon, in its own SVG units.

    `brand/strata-S-owner.svg` is a single closed contour — the flattened
    union of the drawing's fill and its outside stroke, written by
    `tools/flatten_svg.py`. One contour means the chrome pipeline below can
    treat the letter as a block: `_mask` fills it, `MinFilter` erodes it into
    a rim, and the band clips to it.

    Flattened here rather than rasterised by `qlmanage`, which is what this
    used to do. The rasteriser flattens onto opaque white, so the letter had
    to be recovered from luminance and resampled — two lossy steps, and the
    first version of it had visibly stepped edges. Sampling the curves gives
    the geometry exactly.
    """
    from fontTools.pens.recordingPen import RecordingPen
    from fontTools.svgLib.path import parse_path

    d = re.findall(r'<path d="([^"]+)"', open(path).read())[0]
    rec = RecordingPen()
    parse_path(d, rec)

    pts, cur = [], None

    def sample(p0, ctrl):
        out = []
        for i in range(1, steps + 1):
            t = i / steps
            if len(ctrl) == 2:
                (x1, y1), (x2, y2) = ctrl
                out.append(((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * x1 + t * t * x2,
                            (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * y1 + t * t * y2))
            else:
                (x1, y1), (x2, y2), (x3, y3) = ctrl
                out.append((
                    (1 - t) ** 3 * p0[0] + 3 * (1 - t) ** 2 * t * x1
                    + 3 * (1 - t) * t * t * x2 + t ** 3 * x3,
                    (1 - t) ** 3 * p0[1] + 3 * (1 - t) ** 2 * t * y1
                    + 3 * (1 - t) * t * t * y2 + t ** 3 * y3))
        return out

    for op, args in rec.value:
        if op == "moveTo":
            cur = args[0]
            pts.append(cur)
        elif op == "lineTo":
            cur = args[0]
            pts.append(cur)
        elif op in ("curveTo", "qCurveTo"):
            seg = sample(cur, list(args))
            pts += seg
            cur = seg[-1]
    return pts


def chromed(mask, outline_pts, colour, W, top, bot, left, right):
    """One block's surface, with the rim and the frosted band on it.

    The same three moves `render` makes, lifted out so the letter and the tile
    can both take them. See `BlockChrome.swift` for why each is built this way
    — in particular, the blur has to happen over a field of the block's own
    colour or PIL averages in the black behind the transparent pixels and the
    bottom edge comes out dirty.
    """
    surf = Image.new("RGBA", (W, W), tuple(colour) + (255,))
    wash = Image.new("RGBA", (W, W), (255, 255, 255, int(255 * SCRIM)))
    surf = Image.alpha_composite(surf, wash)
    surf.putalpha(mask)

    # The rim, as a stroke clipped back inside the mask.
    #
    # `render` erodes with a `MinFilter` instead, which is exact but is
    # O(pixels x kernel^2): the letter is one block rather than a fifth of
    # one, so its rim kernel is five times wider, and at 4096px that took
    # minutes rather than seconds. Stroking the outline and intersecting is
    # the same region and is linear in the path.
    rim_px = max(3, int(RIM_W_RATIO * (bot - top) * 1.15))
    stroke = Image.new("L", (W, W), 0)
    ImageDraw.Draw(stroke).line(list(outline_pts) + [outline_pts[0]],
                                fill=255, width=rim_px * 2, joint="curve")
    edge = ImageChops.multiply(stroke, mask)
    falloff = _vgrad(W, top, bot, lambda t: 1.0 if t < 0.03 else
                     1.0 - (1 - RIM_FALLOFF) * min(1.0, (t - 0.03) / 0.5))
    rim = Image.new("RGBA", (W, W), (255, 255, 255, 0))
    rim.putalpha(ImageChops.multiply(edge, falloff))
    surf = Image.alpha_composite(surf, rim)

    radius = BLUR_OF_WIDTH * (right - left)
    field = Image.new("RGB", (W, W), tuple(colour))
    field.paste(surf.convert("RGB"), (0, 0), surf.split()[3])
    blurred = field.filter(ImageFilter.GaussianBlur(radius)).convert("RGBA")
    blurred.putalpha(surf.split()[3].filter(ImageFilter.GaussianBlur(radius)))
    bandmask = _vgrad(W, top, bot, lambda t: 0.0 if t < BAND_FEATHER else
                      min(1.0, (t - BAND_FEATHER) / (BAND_START - BAND_FEATHER)))
    surf = Image.composite(blurred, surf, bandmask)
    surf.putalpha(ImageChops.multiply(surf.split()[3], mask))
    return surf


def render_letter_block(ground, surface, size=1024, margin=0.19):
    """The icon: the owner's `S` as one of the app's blocks, on a pink field.

    The mark used to be a flat pink `S` on white, and before that the Jaro `S`
    cut into five stacked blocks. The five-block version is what "that pretty
    gradient" refers to: the rim catching light along each block's top edge
    and the frosted band softening the seam below it. A single flat letter has
    neither, which is why it read as a sticker.

    So the chrome goes on the letter. The `S` is a block — one flat colour,
    a white rim brightest along its top edge, the bottom 26% of it out of
    focus — standing on the app's own pink. It is the same construction as
    every block in the tower, applied to a shape that happens to be a letter.
    """
    W = size * SS
    poly = svg_polygon(MARK_SVG)
    xs = [p[0] for p in poly]
    ys = [p[1] for p in poly]
    gw, gh = max(xs) - min(xs), max(ys) - min(ys)
    sc = W * (1 - 2 * margin) / max(gw, gh)
    ox = (W - gw * sc) / 2 - min(xs) * sc
    oy = (W - gh * sc) / 2 - min(ys) * sc
    pts = [(ox + x * sc, oy + y * sc) for x, y in poly]
    left, right = min(p[0] for p in pts), max(p[0] for p in pts)
    top, bot = min(p[1] for p in pts), max(p[1] for p in pts)

    mask = _mask(pts, W)
    # A crisp backing under the chromed copy, for the reason `render` gives:
    # where the band's blur thins the surface the flat colour still shows, so
    # the letter's silhouette stays sharp at 60pt.
    backing = Image.new("RGBA", (W, W), tuple(surface) + (255,))
    backing.putalpha(mask)
    letter = Image.alpha_composite(
        backing, chromed(mask, pts, surface, W, top, bot, left, right))

    img = Image.new("RGB", (W, W), ground)
    img.paste(letter, (0, 0), letter.split()[3])
    return img.resize((size, size), Image.LANCZOS)


def main():
    if "--swift" in sys.argv:
        return emit_swift()
    os.makedirs(OUT, exist_ok=True)
    # The owner's own `S`, as one of the app's blocks: white, on the app's
    # warm black.
    #
    # Four combinations were rendered and compared at 1024 and at 60pt. A pink
    # field fills the tile with the app's loudest colour and leaves the letter
    # nothing to catch; pink on pink is the prettiest large and turns to mush
    # small. Black won the ground, and then white won the letter — both the
    # owner's calls, and the pair is also the highest contrast of the four,
    # which is what an icon is judged on at 60pt.
    #
    # The chrome still does its work on a white letter here, which it could
    # not do on a white letter on pink: against black the rim along the top
    # edge and the frosted band across the bottom 26% both read, and that is
    # the whole reason the S is a block and not a shape.
    render_letter_block(ground=WARM_BLACK, surface=(255, 255, 255)).save(
        os.path.join(OUT, "AppIcon-light.png"))
    # Dark is the same drawing. The light one is already dark, and an icon
    # that changes identity between appearances is two icons.
    render_letter_block(ground=WARM_BLACK, surface=(255, 255, 255)).save(
        os.path.join(OUT, "AppIcon-dark.png"))
    # Tinted is recoloured by iOS off luminance, so it has to be monochrome
    # going in — colour here would only be thrown away.
    render_letter_block(ground=(0, 0, 0), surface=(250, 250, 250)).save(
        os.path.join(OUT, "AppIcon-tinted.png"))
    for name in ("light", "dark", "tinted"):
        p = os.path.join(OUT, f"AppIcon-{name}.png")
        print(f"{name:7} {Image.open(p).size}  {p}")


if __name__ == "__main__":
    sys.exit(main())
