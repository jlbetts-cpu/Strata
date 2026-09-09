#!/usr/bin/env python3
"""The Strata wordmark, drawn in the mark's own geometry.

    python3 tools/make_wordmark.py

Writes brand/strata-wordmark*.svg and PNG previews.

WHAT THIS IS — AND WHAT IT IS NOT
---------------------------------
This is a WORDMARK: the six letters of "Strata", constructed. It is **not a
typeface**. A face is 26 letters twice over, ten figures, punctuation, spacing
pairs and hinting, and the honest estimate for one that survives being set at
arbitrary sizes is weeks of drawing rather than an afternoon of geometry. What
the camera screen actually needs is one word, and one word is a thing that can
be drawn exactly rather than approximated.

Every glyph is built from the same three rules the mark uses:

- **One stem weight** (`STEM`), everywhere, because the mark has one.
- **Flat terminals.** No curves anywhere. The mark is cut from straight edges
  and so is this.
- **The block's corner radius** on the OUTER corners of the letter's overall
  silhouette only, never on interior angles — the same rule as the mark.

Coordinates are in a unit em: x right, y DOWN, cap height 1.0.
"""
import os
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "brand")

STEM = 0.235         # one stem weight
                     # Lighter than the mark's 0.30 bar. At 0.30 the counters
                     # of `a` and `r` closed to slivers and the word set as a
                     # solid black bar — the mark can be that heavy because it
                     # is one letter at 200pt; six letters at 60 cannot.
XH = 0.72            # x-height, as a fraction of the cap height
RADIUS = 0.147 * 0.62   # the block's ratio, on a stem rather than a full square
TRACK = 0.150        # space between letters
                     # Wide, because the letterforms are square and their
                     # sidebearings are nearly zero: at 0.085 the `a` touched
                     # whatever followed it.


def rect(x, y, w, h):
    return [(x, y), (x + w, y), (x + w, y + h), (x, y + h)]


def glyph_S():
    """The mark, at cap height: two bars and a slash."""
    bar = STEM
    slash = 0.50
    w = 0.86
    return [[
        (0.0, 0.0), (w, 0.0),
        (w, bar), (slash * w, bar),
        (w, 1.0 - bar), (w, 1.0),
        (0.0, 1.0), (0.0, 1.0 - bar),
        (w - slash * w, 1.0 - bar), (0.0, bar),
    ]], w


def glyph_t():
    """A stem with a crossbar, and a foot that turns right.

    The first version had the crossbar sitting on the x-height and no foot,
    so the letter read as a plus sign with a tail. The stem now rises well
    clear of the crossbar and the foot steps right, which is what tells a `t`
    from an `l` at a glance.
    """
    w = 0.56
    stem_x = 0.15
    bar = STEM * 0.70
    top = 1.0 - XH - 0.26      # the ascender, clear above the x-height
    return [
        rect(stem_x, top, STEM, 1.0 - top - bar),     # stem
        rect(0.0, 1.0 - XH, w * 0.86, bar),           # crossbar
        rect(stem_x, 1.0 - bar, w - stem_x, bar),     # foot, stepping right
    ], w


def glyph_r():
    """A stem, a shoulder, and the short drop that ends it.

    The shoulder alone was a flat tab and read as an `f` with no crossbar.
    The drop at its right end is what a roman `r` actually has, cut square.
    """
    w = 0.62
    bar = STEM * 0.80
    return [
        rect(0.0, 1.0 - XH, STEM, XH),                # stem
        rect(STEM, 1.0 - XH, w - STEM, bar),          # shoulder
        rect(w - bar, 1.0 - XH, bar, bar * 1.85),     # the drop
    ], w


def glyph_a():
    """Double-storey, cut square: a lid, a waist, a floor and two stems.

    The floor was missing, which left a notch at the foot where the counter
    ran out of the letter — visible at 200px and worse at 60. A letter with a
    hole in its outline is not a letter.
    """
    w = 0.68
    bar = STEM * 0.78
    low = 1.0 - XH * 0.46          # where the waist sits
    return [
        rect(0.0, 1.0 - XH, w, bar),                  # lid
        rect(w - STEM, 1.0 - XH, STEM, XH),           # right stem, full height
        rect(0.0, low, w, bar),                       # waist
        rect(0.0, low, STEM, 1.0 - low),              # left stem, below the waist
        rect(0.0, 1.0 - bar, w, bar),                 # floor — closes the counter
    ], w


GLYPHS = {"S": glyph_S, "t": glyph_t, "r": glyph_r, "a": glyph_a}


def rounded(points, radius, outer):
    """Straight path with the named vertices rounded — same helper as the mark."""
    import math
    n = len(points)
    d = []
    parts = []
    for i, p in enumerate(points):
        prev, nxt = points[(i - 1) % n], points[(i + 1) % n]
        if i not in outer:
            parts.append(("L", p)); continue
        def unit(a, b):
            dx, dy = b[0] - a[0], b[1] - a[1]
            m = math.hypot(dx, dy) or 1.0
            return (dx / m, dy / m)
        ui, uo = unit(p, prev), unit(p, nxt)
        parts.append(("L", (p[0] + ui[0] * radius, p[1] + ui[1] * radius)))
        parts.append(("A", (radius, (p[0] + uo[0] * radius, p[1] + uo[1] * radius))))
    d.append(f"M {parts[0][1][0]:.5f} {parts[0][1][1]:.5f}")
    for kind, val in parts[1:]:
        if kind == "L":
            d.append(f"L {val[0]:.5f} {val[1]:.5f}")
        else:
            r, b = val
            d.append(f"A {r:.5f} {r:.5f} 0 0 1 {b[0]:.5f} {b[1]:.5f}")
    d.append("Z")
    return " ".join(d)


def wordmark_paths(text="Strata"):
    """Every glyph's subpaths, laid out, plus the total advance."""
    out, x = [], 0.0
    for ch in text:
        shapes, w = GLYPHS[ch]()
        for shape in shapes:
            out.append([(px + x, py) for px, py in shape])
        x += w + TRACK
    return out, x - TRACK


def svg(text="Strata", height=200, ink="#111111", ground=None, pad=0.18):
    shapes, adv = wordmark_paths(text)
    scale = height * (1 - 2 * pad)
    w = adv * scale + 2 * pad * height
    body = []
    if ground:
        body.append(f'<rect width="{w:.2f}" height="{height}" fill="{ground}"/>')
    body.append(f'<g transform="translate({pad*height:.3f} {pad*height:.3f}) scale({scale:.5f})">')
    for shape in shapes:
        # The S carries the mark's rounded outer corners; the plain rectangles
        # of the lower-case do not, because a stem is already a straight cut.
        outer = {0, 1, 5, 6} if len(shape) == 10 else set()
        r = RADIUS if outer else 0
        body.append(f'  <path d="{rounded(shape, r, outer)}" fill="{ink}"/>')
    body.append("</g>")
    inner = "\n  ".join(body)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w:.2f}" '
            f'height="{height}" viewBox="0 0 {w:.2f} {height}">\n  {inner}\n</svg>\n')


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, ink, ground in [
        ("strata-wordmark", "#111111", "#FFFFFF"),
        ("strata-wordmark-white", "#FFFFFF", "#111111"),
        ("strata-wordmark-pink", "#EC85B4", "#FFFFFF"),
    ]:
        p = os.path.join(OUT, f"{name}.svg")
        open(p, "w").write(svg(ink=ink, ground=ground))
        print("wrote", p)
        subprocess.run(["qlmanage", "-t", "-s", "1200", "-o", OUT, p], capture_output=True)
        made = p + ".png"
        if os.path.exists(made):
            os.replace(made, p.replace(".svg", ".png"))


if __name__ == "__main__":
    main()
