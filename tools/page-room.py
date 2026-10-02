#!/usr/bin/env python3
"""How much of a screen is ground, and where the gaps are.

The owner has asked twice for "a lot of white space ... focus on hey tea
design system because thats kinda what we are going for", and
docs/illustrations.md records the HEYTEA rule it comes from: "Enormous
negative space. The figure sits small in a big empty field."

docs/screen-audit.md's check 7 can only see that a gap is ON the ladder. It
cannot see that every gap on a page is the SAME rung, which is exactly what a
page with no air looks like. This measures the thing check 7 is blind to.

A row is EMPTY when nothing is drawn across it: the ground is a smooth mesh, so
an empty row's spread from side to side is a couple of levels, while a row
crossing a block, a word or a rule is tens of them. Everything here is reported
in POINTS at the capture's own scale.

    tools/page-room.py shot.png [--scale 3] [--top 59] [--bottom 34]
    tools/page-room.py --signature shot.png [shot.png ...]
    tools/page-room.py --faint shot.png [shot.png ...]

    rows        the share of the usable band with nothing drawn on it
    break       the biggest run of empty rows: the page's own breath
    bands       every run of drawn rows, and the gap above each

**`--signature` is a check that a capture is of the screen you asked for.**
A launch flag whose value is missing reads as nil (`DebugHarness.argument`
returns the word AFTER the key, so a flag given last has none), and the app
then opens on whatever it would have opened on anyway. That capture looks
exactly like a capture. An md5 comparison does not catch it either: on
2026-10-01 seven of twenty-four captures were of the wrong screen and only two
pairs were byte-identical, because photographic noise differs between two runs
of the same screen. What does catch it is the band structure, which is the
layout and nothing else: print the signature for every capture in a set and
any two screens that agree to a tenth of a point are one screen photographed
twice.
"""
import sys
from PIL import Image
import numpy as np


def bands(path, scale=3.0, top_pt=59.0, bottom_pt=34.0, spread=14):
    im = Image.open(path).convert("RGB")
    a = np.asarray(im).astype(np.int16)
    h, w = a.shape[:2]
    # Ignore the status bar and the home indicator: neither is the page.
    y0, y1 = int(top_pt * scale), h - int(bottom_pt * scale)
    band = a[y0:y1]
    # Trim the left/right 4pt so a rim touching the bezel does not count.
    m = int(4 * scale)
    band = band[:, m:w - m]
    spreads = band.max(axis=1) - band.min(axis=1)       # per row, per channel
    drawn = spreads.max(axis=1) > spread
    return drawn, y0, scale, (y1 - y0) / scale


def runs(mask, bridge=0):
    """Runs of True. `bridge` closes gaps shorter than that, in rows: a band of
    type is a stack of letter rows with a row of air between every pair, and
    reporting each of those as a gap is reporting the leading."""
    out, start = [], None
    for i, v in enumerate(mask):
        if v and start is None:
            start = i
        elif not v and start is not None:
            out.append((start, i)); start = None
    if start is not None:
        out.append((start, len(mask)))
    if bridge <= 0 or not out:
        return out
    merged = [list(out[0])]
    for s, e in out[1:]:
        if s - merged[-1][1] < bridge:
            merged[-1][1] = e
        else:
            merged.append([s, e])
    return [tuple(r) for r in merged]


def faint(path, scale=3.0, top_pt=59.0, bottom_pt=34.0):
    """**How much of this page is drawn but too quiet to see.**

    The owner, 2026-10-01: "the memories looks good but you cant really see
    anything half the time ... the empty state has to look just as good."

    `bands` and `signature` cannot answer that: they ask whether a row has
    anything on it, and a row of 1-level recesses counts as empty. This asks the
    other question. For every pixel in the usable band it reports the distance
    from the page's own ground, bucketed, so a screen whose structure is all in
    the 1-to-3 bucket is named rather than described.

    The buckets are chosen off this app's own measurements rather than a source:
    a calendar cell's recess is **1 level**, `TowerLattice`'s pane is **2.7
    levels** on a light page, a block rim reaches **+4**, and ordinary ink is
    tens. Anything in the first two buckets is structure the instrument cannot
    see, and the question each time is whether a person can.
    """
    from PIL import ImageFilter
    im = Image.open(path).convert("RGB")
    h, w = im.height, im.width
    y0, y1 = int(top_pt * scale), h - int(bottom_pt * scale)
    m = int(4 * scale)
    box = (m, y0, w - m, y1)
    band = im.crop(box)
    # **Against a blurred copy of itself, not against one ground value.**
    #
    # `WarmBackground` is a vertical gradient (247 at the top to 241 at the
    # bottom) and `GroundField`'s mesh moves under it, so a flat "distance from
    # the most common pixel" counts the page's own shading as structure and
    # reports two thirds of an empty screen as drawn-but-faint whatever is on it.
    # A 24pt blur keeps every gradient and loses every edge, so the difference
    # is the structure and nothing else.
    blurred = band.filter(ImageFilter.GaussianBlur(radius=8 * scale))
    a = np.asarray(band).astype(int)
    b = np.asarray(blurred).astype(int)
    d = np.abs(a - b).max(axis=2).reshape(-1)
    g = np.asarray(band).reshape(-1, 3)
    vals, counts = np.unique(g, axis=0, return_counts=True)
    g = vals[counts.argmax()]
    total = d.size
    edges = [(0, 0), (1, 3), (4, 8), (9, 20), (21, 60), (61, 255)]
    names = ["ground", "1-3 invisible", "4-8 faint", "9-20 quiet",
             "21-60 read", "61+ ink"]
    print(f"{path}")
    print(f"  ground rgb{tuple(int(x) for x in g)}")
    for (lo, hi), name in zip(edges, names):
        n = int(((d >= lo) & (d <= hi)).sum())
        print(f"  {name:>14}  {100 * n / total:5.1f}%")
    drawn = (d >= 1).sum()
    if drawn:
        below = ((d >= 1) & (d <= 3)).sum()
        print(f"  of everything drawn, {100 * below / drawn:.1f}% is within 3 levels of the ground")


def signature(path, **kw):
    """The page's layout as one line: the gap and band heights, in points.
    Two captures of the same screen agree; two screens do not."""
    drawn, y0, scale, _ = bands(path, **kw)
    bridge = int(8 * scale)
    parts, prev = [], 0
    for s, e in runs(drawn, bridge=bridge):
        parts.append(f"{(s - prev) / scale:.1f}/{(e - s) / scale:.1f}")
        prev = e
    parts.append(f"{(len(drawn) - prev) / scale:.1f}")
    return " ".join(parts)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(zip([a for a in sys.argv[1:] if a.startswith("--")],
                    [None] * 10))
    kw = {}
    argv = sys.argv[1:]
    for i, a in enumerate(argv):
        if a == "--scale": kw["scale"] = float(argv[i + 1])
        if a == "--top": kw["top_pt"] = float(argv[i + 1])
        if a == "--bottom": kw["bottom_pt"] = float(argv[i + 1])
    if "--faint" in argv:
        for path in args:
            faint(path, **{k: v for k, v in kw.items() if k != "spread"})
        return
    if "--signature" in argv:
        seen = {}
        for path in args:
            sig = signature(path, **kw)
            mark = f"   SAME LAYOUT AS {seen[sig]}" if sig in seen else ""
            seen.setdefault(sig, path)
            print(f"{path}\n  {sig}{mark}")
        return
    path = args[0]
    drawn, y0, scale, usable = bands(path, **kw)
    empty = ~drawn
    print(f"{path}")
    print(f"  usable {usable:.0f}pt   empty rows {100 * empty.mean():.1f}%")
    # 8pt is the ladder's smallest rung, so anything under it is not a gap on
    # the page, it is the air inside a thing.
    bridge = int(8 * scale)
    gaps = runs(empty, bridge=0)
    if gaps:
        big = max(gaps, key=lambda r: r[1] - r[0])
        print(f"  biggest break {(big[1] - big[0]) / scale:.0f}pt "
              f"at y {(y0 + big[0]) / scale:.0f}-{(y0 + big[1]) / scale:.0f}")
    print("  bands (drawn), with the gap above each:")
    prev_end = 0
    for s, e in runs(drawn, bridge=bridge):
        gap = (s - prev_end) / scale
        if prev_end or gap:
            print(f"    gap {gap:6.1f}pt   band {(e - s) / scale:6.1f}pt   "
                  f"y {(y0 + s) / scale:.0f}-{(y0 + e) / scale:.0f}")
        prev_end = e
    print(f"    gap {(len(drawn) - prev_end) / scale:6.1f}pt   (to the bottom)")


if __name__ == "__main__":
    main()
