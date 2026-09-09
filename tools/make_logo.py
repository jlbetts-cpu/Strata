#!/usr/bin/env python3
"""Strata's blocky S: a rounded square with a slash cut through it.

    python3 tools/make_logo.py

Writes brand/strata-mark.svg (vector) and PNG previews.

WHAT THIS IS, AND HOW IT DIFFERS FROM ITS REFERENCE
---------------------------------------------------
The shape family — a heavy S made by cutting two wedges out of a rounded
square — is an old and widely-used lettering idea, but the specific drawing
the owner found on Pinterest is somebody's work and is not ours to copy. Four
things here are deliberately not it, and each is tied to something the app
already is rather than being an arbitrary nudge:

1. **The outer radius is the BLOCK's radius**, 14.7% of the side, the same
   ratio `BlockSurface` uses. The reference is visibly rounder. This is the
   change that makes the mark belong to this app: the logo is the same
   cornered object as everything in the tower.
2. **The wedge tips are cut flat, not pointed.** A knife point is the
   reference's signature; a block has no points. Each wedge ends in a short
   vertical face, so the slash reads as a gap between two blocks rather than
   as a blade.
3. **The slash rises one cell in four columns** — a 1:4 slope, taken from the
   tower's own grid, rather than the reference's shallower angle.
4. **The bars are not equal to the counters.** The reference is near enough to
   thirds; here the bars are 0.30 and the slash sits off-centre by design, so
   the S has a direction to it.

Everything is parameterised below, so the drawing can be argued with.
"""
import math
import os
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "brand")

# --- Geometry, in a unit square. y runs DOWN, as in SVG. -------------------
#
# The S is the UNION of three pieces: a bar across the top, a bar across the
# bottom, and a slash running from the top bar's left down to the bottom bar's
# right. Built this way rather than by cutting wedges out of a square — the
# first attempt did that and produced a Z, because a wedge that tapers to a
# point leaves the two bars joined by a hairline.
BAR = 0.300          # bar height, top and bottom
SLASH = 0.500        # the slash's HORIZONTAL thickness
                     # Chosen by rendering 0.36 / 0.43 / 0.50 / 0.57 side by
                     # side: below 0.43 the slash reads as a hairline joining
                     # two bars, above 0.50 the counters start closing and the
                     # letter turns into a solid lozenge.
RADIUS = 0.147       # the block's corner radius, as a fraction of the side


def mark_points():
    """The mark as one closed polygon, clockwise from the top-left.

    Returns the points and the indices of the four outer corners, which are
    the only ones that round.
    """
    pts = [
        (0.0, 0.0),                 # 0  outer
        (1.0, 0.0),                 # 1  outer
        (1.0, BAR),                 # 2  under the top bar, at the right
        (SLASH, BAR),               # 3  the slash's upper-right corner
        (1.0, 1.0 - BAR),           # 4  the slash meets the bottom bar
        (1.0, 1.0),                 # 5  outer
        (0.0, 1.0),                 # 6  outer
        (0.0, 1.0 - BAR),           # 7  above the bottom bar, at the left
        (1.0 - SLASH, 1.0 - BAR),   # 8  the slash's lower-left corner
        (0.0, BAR),                 # 9  the slash meets the top bar
    ]
    return pts, {0, 1, 5, 6}


def rounded_path(points, radius, round_only):
    """An SVG path, rounding only the vertices named in `round_only`."""
    n = len(points)
    out = []
    for i, p in enumerate(points):
        prev = points[(i - 1) % n]
        nxt = points[(i + 1) % n]
        if i not in round_only:
            out.append(("L", p))
            continue
        # Trim back along both edges by `radius`, then arc between.
        def unit(a, b):
            dx, dy = b[0] - a[0], b[1] - a[1]
            d = math.hypot(dx, dy) or 1.0
            return (dx / d, dy / d)
        ui = unit(p, prev)
        uo = unit(p, nxt)
        a = (p[0] + ui[0] * radius, p[1] + ui[1] * radius)
        b = (p[0] + uo[0] * radius, p[1] + uo[1] * radius)
        out.append(("L", a))
        out.append(("A", (radius, b)))
    # Emit.
    d = []
    first = out[0]
    d.append(f"M {first[1][0]:.5f} {first[1][1]:.5f}")
    for kind, val in out[1:]:
        if kind == "L":
            d.append(f"L {val[0]:.5f} {val[1]:.5f}")
        else:
            r, b = val
            d.append(f"A {r:.5f} {r:.5f} 0 0 1 {b[0]:.5f} {b[1]:.5f}")
    d.append("Z")
    return " ".join(d)


def svg(size=512, ink="#EC85B4", ground="#FFFFFF", padding=0.16):
    pts, outer = mark_points()
    # Only the four OUTER corners round. Every inner vertex is a cut face,
    # and a block has no rounded interior angles.
    path = rounded_path(pts, RADIUS, outer)
    scale = size * (1 - 2 * padding)
    off = size * padding
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}">
  <rect width="{size}" height="{size}" fill="{ground}"/>
  <g transform="translate({off:.3f} {off:.3f}) scale({scale:.5f})">
    <path d="{path}" fill="{ink}" fill-rule="nonzero"/>
  </g>
</svg>
'''


def rounded_polygon(points, radius, round_only, steps=24):
    """The outline as a flat point list, arcs sampled.

    One polygon, so a rasteriser needs nothing but `polygon()`. The first
    attempt at this painted the ground back into each corner and laid a disc
    over the inside, which put four pink circles OUTSIDE the letter — a
    reminder that "cheaper than deriving the arc" usually is not.
    """
    n = len(points)
    out = []
    for i, p in enumerate(points):
        prev, nxt = points[(i - 1) % n], points[(i + 1) % n]
        if i not in round_only:
            out.append(p)
            continue

        def unit(a, b):
            dx, dy = b[0] - a[0], b[1] - a[1]
            d = math.hypot(dx, dy) or 1.0
            return (dx / d, dy / d)

        ui, uo = unit(p, prev), unit(p, nxt)
        a_pt = (p[0] + ui[0] * radius, p[1] + ui[1] * radius)
        b_pt = (p[0] + uo[0] * radius, p[1] + uo[1] * radius)
        # Quadratic through the corner — the same curve `addQuadCurve` draws
        # on the Swift side, so the two renderings agree.
        for k in range(steps + 1):
            t = k / steps
            out.append((
                (1 - t) ** 2 * a_pt[0] + 2 * (1 - t) * t * p[0] + t * t * b_pt[0],
                (1 - t) ** 2 * a_pt[1] + 2 * (1 - t) * t * p[1] + t * t * b_pt[1],
            ))
    return out


def render(ink=(0xEC, 0x85, 0xB4), ground=(255, 255, 255), size=1024, padding=0.175):
    """The mark, rasterised. Same polygon as the SVG, so they cannot drift."""
    from PIL import Image, ImageDraw
    SS = 4
    W = size * SS
    img = Image.new("RGB", (W, W), ground)
    pts, outer = mark_points()
    flat = rounded_polygon(pts, RADIUS, outer)
    scale = W * (1 - 2 * padding)
    off = W * padding
    ImageDraw.Draw(img).polygon(
        [(off + x * scale, off + y * scale) for x, y in flat], fill=ink)
    return img.resize((size, size), Image.LANCZOS)


def emit_swift():
    """The mark as a SwiftUI `Shape`, so the app draws the vector rather than
    shipping a bitmap of it."""
    pts, outer = mark_points()
    print("    // Generated by tools/make_logo.py --swift. Do not hand-edit.")
    print("    /// The mark's outline in a unit square, y DOWN.")
    print("    static let outline: [CGPoint] = [")
    rows = [f"CGPoint(x: {x:.4f}, y: {y:.4f})" for x, y in pts]
    for i in range(0, len(rows), 3):
        print("        " + ", ".join(rows[i:i + 3]) + ("," if i + 3 < len(rows) else ""))
    print("    ]")
    print(f"    /// Which vertices round — the four outer corners only.")
    print(f"    static let roundedCorners: Set<Int> = {sorted(outer)}".replace("[", "[").replace("]", "]"))
    print(f"    /// The block's corner radius, as a fraction of the side.")
    print(f"    static let cornerRatio: CGFloat = {RADIUS}")


def main():
    import sys as _sys
    if "--swift" in _sys.argv:
        return emit_swift()
    os.makedirs(OUT, exist_ok=True)
    variants = {
        "strata-mark":            ("#EC85B4", "#FFFFFF"),   # pink on white
        "strata-mark-knockout":   ("#FFFFFF", "#EC85B4"),   # white on pink
        "strata-mark-black":      ("#111111", "#FFFFFF"),
    }
    for name, (ink, ground) in variants.items():
        p = os.path.join(OUT, f"{name}.svg")
        open(p, "w").write(svg(ink=ink, ground=ground))
        print("wrote", p)
        png = p.replace(".svg", ".png")
        subprocess.run(["qlmanage", "-t", "-s", "1024", "-o", OUT, p],
                       capture_output=True)
        made = p + ".png"
        if os.path.exists(made):
            os.replace(made, png)
            print("wrote", png)


if __name__ == "__main__":
    main()
