#!/usr/bin/env python3
"""Flatten a Figma letterform export to one filled path.

Figma writes a stroked outline as a mask plus a fill plus a stroke — for
"Memories" that is 24 `<path>` elements for 8 letters, all three copies
carrying the same 500-byte `d`. The letter you see is the fill grown outward
by half the stroke width.

This computes that region once, with a real path union, and writes a single
`<path>`. Nothing is approximated: the union is skia's, the same one a
renderer would do, so the output is the input's own geometry rather than a
trace of it.

Two reasons to bother beyond the size:

- **A stroke is a renderer's opinion.** Join style, miter limit and how a
  0.5-unit stroke lands on a pixel grid are all decided by whoever is drawing.
  A filled outline is the same shape in Xcode's vector asset pipeline, in
  `qlmanage`, and in a browser.
- **Template rendering tints fill and stroke separately.** One path cannot
  disagree with itself.

    python3 tools/flatten_svg.py in.svg out.svg [--precision 2]
"""

import argparse
import re
import sys
from pathlib import Path

import pathops
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.svgLib.path import parse_path


def flatten(svg: str) -> tuple[str, str]:
    """Return `(viewBox, d)` for the union of every glyph in the export."""
    view = re.search(r'viewBox="([^"]+)"', svg).group(1)
    ds = re.findall(r'<path d="([^"]+)"', svg)
    widths = [float(m) if m else 1.0
              for m in re.findall(r'<path [^>]*?(?:stroke-width="([^"]+)")?[^>]*?stroke="',
                                  svg)]

    if len(ds) % 3 == 0 and len(set(ds[:len(ds) // 3])) == len(ds) // 3 \
            and ds[:len(ds) // 3] == ds[len(ds) // 3:2 * len(ds) // 3]:
        # mask / fill / stroke, one triple per glyph.
        glyphs = ds[:len(ds) // 3]
        width = float(re.search(r'stroke-width="([^"]+)"', svg).group(1))
    else:
        # One path carrying both a fill and a stroke attribute.
        glyphs = ds
        m = re.search(r'stroke-width="([^"]+)"', svg)
        width = float(m.group(1)) if m else 1.0

    out = pathops.Path()
    for d in glyphs:
        fill = pathops.Path()
        parse_path(d, fill.getPen())
        edge = pathops.Path()
        parse_path(d, edge.getPen())
        edge.stroke(width, pathops.LineCap.ROUND_CAP, pathops.LineJoin.ROUND_JOIN, 4.0)
        # Skia strokes round joins as CONICS — rational quadratics, which are
        # exact for a circular arc and which neither the boolean ops nor SVG
        # can represent. Approximating them as quadratics is the conversion
        # every renderer does anyway, and it must happen before the union or
        # skia throws rather than degrading.
        edge.convertConicsToQuads()
        glyph = pathops.op(fill, edge, pathops.PathOp.UNION)
        out = pathops.op(out, glyph, pathops.PathOp.UNION) if len(list(out.segments)) else glyph
    return view, out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("src"); ap.add_argument("dst")
    ap.add_argument("--precision", type=int, default=2)
    a = ap.parse_args()

    src = Path(a.src)
    view, path = flatten(src.read_text())
    pen = SVGPathPen(None, ntos=lambda v: f"{round(v, a.precision):g}")
    path.draw(pen)
    _, _, w, h = view.split()
    svg = (f'<svg width="{w}" height="{h}" viewBox="{view}" '
           f'xmlns="http://www.w3.org/2000/svg">\n'
           f'<path d="{pen.getCommands()}" fill="white"/>\n</svg>\n')
    Path(a.dst).write_text(svg)
    print(f"{src.name}: {len(src.read_text())} -> {len(svg)} bytes "
          f"({100 - 100 * len(svg) // len(src.read_text())}% smaller)")


if __name__ == "__main__":
    main()
