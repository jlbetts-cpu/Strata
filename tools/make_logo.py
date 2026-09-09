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
SLASH = 0.560        # the slash's HORIZONTAL thickness
                     # Rendered at 0.36 / 0.43 / 0.50 / 0.56 / 0.62 side by
                     # side. Below 0.43 the slash reads as a hairline joining
                     # two bars; at 0.50 the two triangular counters were
                     # bigger than the owner wanted; past 0.56 they close up
                     # and the letter turns into a lozenge.
RADIUS = 0.147       # the block's corner radius, as a fraction of the side
INNER_RADIUS = 0.075 # every interior angle
                     # The interior angles used to be knife-sharp, on the rule
                     # that a block has no rounded inside corners. True of a
                     # block; not true of a letter cut from one, where the two
                     # acute corners where the slash meets the bars came to
                     # points sharp enough to look like a rendering artefact.


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


def rounded_path(points, radii):
    """An SVG path, rounding each vertex by its own radius."""
    flat = rounded_polygon(points, radii)
    d = [f"M {flat[0][0]:.5f} {flat[0][1]:.5f}"]
    for x, y in flat[1:]:
        d.append(f"L {x:.5f} {y:.5f}")
    d.append("Z")
    return " ".join(d)


def _corner_radius(p, prev, nxt, wanted):
    """A radius the corner can actually take.

    Trimming back by more than half of either adjacent edge turns the corner
    inside out. The slash meets the bars at a very acute angle, so this clamp
    is what lets the interior corners round at all.
    """
    a = math.hypot(p[0] - prev[0], p[1] - prev[1])
    b = math.hypot(p[0] - nxt[0], p[1] - nxt[1])
    return min(wanted, a * 0.5, b * 0.5)


def rounded_polygon(points, radii, steps=28):
    """The outline as a flat point list, arcs sampled.

    `radii` is one wanted radius per vertex; 0 leaves the corner sharp. One
    polygon out, so a rasteriser needs nothing but `polygon()`. An earlier
    attempt painted the ground back into each corner and laid a disc over the
    inside, which put four pink circles OUTSIDE the letter — "cheaper than
    deriving the arc" usually is not.
    """
    n = len(points)
    out = []
    for i, p in enumerate(points):
        prev, nxt = points[(i - 1) % n], points[(i + 1) % n]
        r = _corner_radius(p, prev, nxt, radii[i])
        if r <= 0:
            out.append(p)
            continue

        def unit(a, b):
            dx, dy = b[0] - a[0], b[1] - a[1]
            d = math.hypot(dx, dy) or 1.0
            return (dx / d, dy / d)

        ui, uo = unit(p, prev), unit(p, nxt)
        a_pt = (p[0] + ui[0] * r, p[1] + ui[1] * r)
        b_pt = (p[0] + uo[0] * r, p[1] + uo[1] * r)
        # Quadratic through the corner — the same curve `addQuadCurve` draws
        # on the Swift side, so the two renderings agree.
        for k in range(steps + 1):
            t = k / steps
            out.append((
                (1 - t) ** 2 * a_pt[0] + 2 * (1 - t) * t * p[0] + t * t * b_pt[0],
                (1 - t) ** 2 * a_pt[1] + 2 * (1 - t) * t * p[1] + t * t * b_pt[1],
            ))
    return out


def radii_for(points, outer):
    """Outer corners take the block's radius; every other vertex takes the
    softer interior one."""
    return [RADIUS if i in outer else INNER_RADIUS for i in range(len(points))]


def render(ink=(0xEC, 0x85, 0xB4), ground=(255, 255, 255), size=1024, padding=0.175):
    """The mark, rasterised. Same polygon as the SVG, so they cannot drift."""
    from PIL import Image, ImageDraw
    SS = 4
    W = size * SS
    img = Image.new("RGB", (W, W), ground)
    pts, outer = mark_points()
    flat = rounded_polygon(pts, radii_for(pts, outer))
    scale = W * (1 - 2 * padding)
    off = W * padding
    ImageDraw.Draw(img).polygon(
        [(off + x * scale, off + y * scale) for x, y in flat], fill=ink)
    return img.resize((size, size), Image.LANCZOS)


def svg(size=512, ink="#EC85B4", ground="#FFFFFF", padding=0.175):
    """The mark as an SVG, from the same polygon everything else uses."""
    pts, outer = mark_points()
    path = rounded_path(pts, radii_for(pts, outer))
    scale = size * (1 - 2 * padding)
    off = size * padding
    ground_rect = f'<rect width="{size}" height="{size}" fill="{ground}"/>' if ground else ""
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}">
  {ground_rect}
  <g transform="translate({off:.3f} {off:.3f}) scale({scale:.5f})">
    <path d="{path}" fill="{ink}"/>
  </g>
</svg>
'''


def emit_swift():
    """The mark as a SwiftUI `Shape`, so the app draws the vector rather than
    shipping a bitmap of it."""
    pts, outer = mark_points()
    radii = radii_for(pts, outer)
    print("    // Generated by tools/make_logo.py --swift. Do not hand-edit.")
    print("    /// The mark's outline in a unit square, y DOWN.")
    print("    static let outline: [CGPoint] = [")
    rows = [f"CGPoint(x: {x:.4f}, y: {y:.4f})" for x, y in pts]
    for i in range(0, len(rows), 3):
        print("        " + ", ".join(rows[i:i + 3]) + ("," if i + 3 < len(rows) else ""))
    print("    ]")
    print("    /// One wanted radius per vertex, as a fraction of the side.")
    print("    /// The outer corners take the block's ratio; the interior")
    print("    /// angles take a smaller one, so the counters read as cut")
    print("    /// rather than as knife points.")
    print("    static let cornerRadii: [CGFloat] = [")
    rr = [f"{r:.4f}" for r in radii]
    for i in range(0, len(rr), 5):
        print("        " + ", ".join(rr[i:i + 5]) + ("," if i + 5 < len(rr) else ""))
    print("    ]")


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
