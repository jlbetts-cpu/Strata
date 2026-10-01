#!/usr/bin/env python3
"""Measure a simulator screenshot in POINTS, so a claim about a screen is a number.

The screen audit's rule is that every finding names the thing that fails it.
That needs an instrument: a 3x screenshot is 1206x2622 device pixels and every
margin, gutter and gap in the design system is written in points, so eyeballing
a PNG cannot tell 16 from 21 — the add sheet's swatch row was off the margin by
5pt for weeks and looked fine.

    screen-measure.py shot.png bands        vertical content runs + the gaps
    screen-measure.py shot.png edges        left/right content edge per band
    screen-measure.py shot.png sample X Y   RGB at a point (points, not pixels)
    screen-measure.py shot.png contrast X1 Y1 X2 Y2
    screen-measure.py shot.png greys        distinct near-grey values, by area
    screen-measure.py shot.png row Y        runs across one row
    screen-measure.py shot.png col X        runs down one column
"""
import sys, collections
from PIL import Image

SCALE = 3  # iPhone @3x. Everything below reports points.

def load(path):
    im = Image.open(path).convert("RGB")
    return im

def ground(im):
    """The page's own colour, taken as the most common pixel."""
    small = im.resize((im.width // 6, im.height // 6))
    return collections.Counter(small.getdata()).most_common(1)[0][0]

def differs(px, g, tol):
    return abs(px[0]-g[0]) > tol or abs(px[1]-g[1]) > tol or abs(px[2]-g[2]) > tol

def luminance(c):
    def ch(v):
        v = v / 255
        return v/12.92 if v <= 0.03928 else ((v+0.055)/1.055) ** 2.4
    r, g, b = (ch(x) for x in c)
    return 0.2126*r + 0.7152*g + 0.0722*b

def contrast(a, b):
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)

def runs(flags, minrun=1):
    out, start = [], None
    for i, f in enumerate(flags):
        if f and start is None:
            start = i
        elif not f and start is not None:
            if i - start >= minrun:
                out.append((start, i))
            start = None
    if start is not None:
        out.append((start, len(flags)))
    return out

def cmd_bands(im, tol=6, minrun=2):
    g = ground(im)
    w, h = im.size
    px = im.load()
    step = SCALE  # one sample per point row
    rowhas = []
    for y in range(0, h, step):
        hit = False
        for x in range(0, w, SCALE * 2):
            if differs(px[x, y], g, tol):
                hit = True
                break
        rowhas.append(hit)
    print(f"ground {g}   page {w//SCALE}x{h//SCALE}pt")
    print("band   top     bottom  height   gap-above")
    prev_end = 0
    for i, (a, b) in enumerate(runs(rowhas, minrun), 1):
        top, bot = a, b
        print(f"{i:>3}  {top:>7.1f} {bot:>8.1f} {bot-top:>8.1f} {top-prev_end:>10.1f}")
        prev_end = bot
    print(f"content ends at {prev_end:.1f}pt of {h//SCALE}  "
          f"({100*(1 - prev_end/(h/SCALE)):.0f}% empty below)")

def cmd_edges(im, tol=6, minrun=2):
    g = ground(im)
    w, h = im.size
    px = im.load()
    rowhas, extents = [], []
    for y in range(0, h, SCALE):
        lo, hi = None, None
        for x in range(0, w):
            if differs(px[x, y], g, tol):
                if lo is None: lo = x
                hi = x
        rowhas.append(lo is not None)
        extents.append((lo, hi))
    print(f"ground {g}   page {w//SCALE}x{h//SCALE}pt")
    print("band   top    bottom   left    right")
    for a, b in runs(rowhas, minrun):
        ls = [extents[y][0] for y in range(a, b) if extents[y][0] is not None]
        rs = [extents[y][1] for y in range(a, b) if extents[y][1] is not None]
        if not ls: continue
        print(f"     {a:>6.1f} {b:>8.1f} {min(ls)/SCALE:>7.1f} {max(rs)/SCALE:>8.1f}")

def cmd_row(im, y, tol=6):
    g = ground(im); px = im.load(); w = im.width
    flags = [differs(px[x, int(y*SCALE)], g, tol) for x in range(w)]
    print(f"row y={y}pt  ground {g}")
    for a, b in runs(flags, SCALE):
        mid = px[(a+b)//2, int(y*SCALE)]
        print(f"  {a/SCALE:>7.1f} .. {b/SCALE:>7.1f}  width {(b-a)/SCALE:>6.1f}  rgb {mid}")

def cmd_col(im, x, tol=6):
    g = ground(im); px = im.load(); h = im.height
    flags = [differs(px[int(x*SCALE), y], g, tol) for y in range(h)]
    print(f"col x={x}pt  ground {g}")
    for a, b in runs(flags, SCALE):
        mid = px[int(x*SCALE), (a+b)//2]
        print(f"  {a/SCALE:>7.1f} .. {b/SCALE:>7.1f}  height {(b-a)/SCALE:>6.1f}  rgb {mid}")

def cmd_sample(im, x, y):
    px = im.load()
    c = px[int(x*SCALE), int(y*SCALE)]
    print(f"({x}, {y})pt = rgb{c}  luminance {luminance(c):.4f}")

def cmd_contrast(im, x1, y1, x2, y2):
    px = im.load()
    a = px[int(x1*SCALE), int(y1*SCALE)]
    b = px[int(x2*SCALE), int(y2*SCALE)]
    r = contrast(a, b)
    verdict = "text PASS" if r >= 4.5 else ("shape PASS" if r >= 3.0 else "FAIL")
    print(f"rgb{a} vs rgb{b} = {r:.2f}:1   {verdict}  (text 4.5, shape 3.0)")

def cmd_greys(im, tol=4):
    """Every near-neutral colour on the page, by area. Check 6 is a count."""
    w, h = im.size
    small = im.resize((w//SCALE, h//SCALE))
    counts = collections.Counter()
    for c in small.getdata():
        if max(c) - min(c) <= tol:      # neutral
            counts[c] += 1
    total = sum(counts.values())
    print(f"{len(counts)} distinct neutral values over {total} pt^2")
    for c, n in counts.most_common(18):
        print(f"  rgb{c}  {n:>8}pt^2  {100*n/total:>5.1f}%")

def main():
    path, cmd, *rest = sys.argv[1:]
    im = load(path)
    nums = [float(r) for r in rest] if rest else []
    if cmd == "bands":    cmd_bands(im)
    elif cmd == "edges":  cmd_edges(im)
    elif cmd == "row":    cmd_row(im, nums[0])
    elif cmd == "col":    cmd_col(im, nums[0])
    elif cmd == "sample": cmd_sample(im, *nums[:2])
    elif cmd == "contrast": cmd_contrast(im, *nums[:4])
    elif cmd == "greys":  cmd_greys(im)
    else: print(__doc__)

if __name__ == "__main__":
    main()
