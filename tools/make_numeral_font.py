#!/usr/bin/env python3
"""Build `StrataNumerals.otf` from the owner's drawn digits.

The digits arrive as one Figma export — a 362x28 strip holding `1234567890`.
Using it as a strip would mean writing a layout engine: measuring advances,
positioning ten `Image`s, and hand-rolling the roll-up animation that
`Text` gets for free. So it is turned into a real font instead, which is
what the owner asked for: "treat it like you would any other font".

Two things about the export matter.

**Figma writes an outside stroke as three copies of the same path** — one
inside a mask, one filled, one stroked at 2 with `mask=url(...)`. The letter
you see is the fill grown outward by 1. Taking the fill alone would halve
every stem. So each glyph is the fill UNIONED with a round-joined 2-wide
centred stroke, which is the same region.

**The strip is cropped flush**, so there are no sidebearings to read at the
ends. The inter-digit gaps run 5.6-7.0; half of the median is used as a
uniform sidebearing.

Digits are **tabular** — one advance for all ten, each centred in it. A
count that changes must not reflow, and a tally that animates its digits
must not jitter the ones beside it.

Metrics are SF Pro Rounded's exactly (upem 2048, ascent 1980, descent -432,
cap 1443), so the font is metrically compatible: a `Text` in it has the same
layout box as a `Text` in the system face at the same point size, and the two
can be mixed on a line without either being nudged.
"""

import re
import sys
from pathlib import Path

import pathops
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.svgLib.path import parse_path

SRC = Path.home() / "Desktop/Developmental Improv/1234567890.svg"
OUT = Path(__file__).resolve().parent.parent / "Strata/Resources/StrataNumerals.ttf"

# The strip spells 1234567890 — zero last, not first.
ORDER = "1234567890"

UPEM = 2048
CAP_UNITS = 28.0        # the drawing's own height IS its cap height
ASCENT, DESCENT, CAP = 1980, -432, 1443
SCALE = CAP / CAP_UNITS
# Cubic-to-quadratic tolerance, in font units. A fifth of a unit at 2048 upem
# is a fiftieth of a pixel at 100pt: below anything a screen can show, and
# small enough that the outlines are the drawing rather than a trace of it.
MAX_ERR = 0.2


def glyph_paths(svg: str) -> list[str]:
    """The ten outlines, each fill unioned with its outside stroke."""
    ds = re.findall(r'<path d="([^"]+)"', svg)
    if len(ds) != 30:
        sys.exit(f"expected 30 paths (10 glyphs x mask/fill/stroke), got {len(ds)}")
    fills = ds[10:20]
    out = []
    for d in fills:
        base = pathops.Path()
        parse_path(d, base.getPen())
        edge = pathops.Path()
        parse_path(d, edge.getPen())
        edge.stroke(2.0, pathops.LineCap.ROUND_CAP, pathops.LineJoin.ROUND_JOIN, 4.0)
        out.append(pathops.op(base, edge, pathops.PathOp.UNION))
    return out


def main() -> None:
    paths = glyph_paths(SRC.read_text())
    boxes = [p.bounds for p in paths]

    gaps = [boxes[i + 1][0] - boxes[i][2] for i in range(len(boxes) - 1)]
    side = sorted(gaps)[len(gaps) // 2] / 2
    widest = max(b[2] - b[0] for b in boxes)
    advance = round((widest + 2 * side) * SCALE)

    fb = FontBuilder(UPEM, isTTF=True)
    names = [".notdef", "space"] + [f"{c}.glyph" for c in ORDER]
    fb.setupGlyphOrder(names)
    fb.setupCharacterMap({ord(c): f"{c}.glyph" for c in ORDER} | {0x20: "space"})

    glyphs = {".notdef": TTGlyphPen(None).glyph(), "space": TTGlyphPen(None).glyph()}
    metrics = {".notdef": (advance, 0), "space": (advance, 0)}
    for char, path, box in zip(ORDER, paths, boxes):
        name = f"{char}.glyph"
        # Centre the ink in the tabular advance, and put the baseline on the
        # drawing's bottom edge (SVG y grows down, the font's grows up).
        dx = (advance / SCALE - (box[2] - box[0])) / 2 - box[0]
        pen = TTGlyphPen(None)
        path.draw(TransformPen(Cu2QuPen(pen, MAX_ERR),
                               (SCALE, 0, 0, -SCALE, dx * SCALE, CAP_UNITS * SCALE)))
        glyphs[name] = pen.glyph()
        metrics[name] = (advance, round((box[0] + dx) * SCALE))

    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=ASCENT, descent=DESCENT, lineGap=0)
    fb.setupNameTable({
        "familyName": "Strata Numerals", "styleName": "Regular",
        "psName": "StrataNumerals-Regular", "version": "Version 1.000",
        "copyright": "Drawn by Jayden Betts.",
    })
    fb.setupOS2(sTypoAscender=ASCENT, sTypoDescender=DESCENT, sTypoLineGap=0,
                usWinAscent=ASCENT, usWinDescent=-DESCENT, sCapHeight=CAP,
                sxHeight=CAP, achVendID="STRT", fsType=0)
    fb.setupPost(isFixedPitch=1)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    fb.save(OUT)

    print(f"sidebearing {side:.2f}  widest {widest:.2f}  advance {advance} "
          f"({advance / UPEM:.3f} em)")
    print(f"wrote {OUT.relative_to(Path.cwd())} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
