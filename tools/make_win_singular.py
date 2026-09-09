"""The singular, cut from the plural.

`wins.svg` is five contours — w, the i's stem, the i's dot, n, s — so "win" is
the same drawing with the rightmost one dropped. Cutting it here rather than
asking for a second export keeps the two words literally the same letterforms,
and the sidebearing is the one the export already had (0.16 at the right edge
of the plural).
"""
import re
import pathops
from fontTools.svgLib.path import parse_path
from fontTools.pens.svgPathPen import SVGPathPen

src = open("brand/wins-owner.svg").read()
d = re.findall(r'<path d="([^"]+)"', src)[0]
whole = pathops.Path(); parse_path(d, whole.getPen())

parts = sorted(((pathops.Path(), c) for c in whole.contours),
               key=lambda t: (t[0].addPath(t[1]), t[0].bounds[0])[1])
keep = pathops.Path()
for p, _ in parts[:-1]:
    keep.addPath(p)

bearing = 132.0 - whole.bounds[2]
width = round(keep.bounds[2] + bearing, 2)
pen = SVGPathPen(None, ntos=lambda v: f"{round(v, 2):g}")
keep.draw(pen)
open("brand/win-owner.svg", "w").write(
    f'<svg width="{width}" height="28" viewBox="0 0 {width} 28" '
    f'xmlns="http://www.w3.org/2000/svg">\n'
    f'<path d="{pen.getCommands()}" fill="white"/>\n</svg>\n')
print(f"win: viewBox 0 0 {width} 28  (plural was 132)")
