"""The owner's illustrations at the bold line weight (2026-10-06: "i noticed
there lines feel a lot thicker and just feel more premium... we need to go
much thicker on the line", then "thickening lines removing the access lines
and makeing sure you arent removing any key things").

Run from docs/illustrations: reads originals/*.png (his drawings as he drew
them) and writes the app's assets in Strata/Assets.xcassets.

- Every line thickens by the same amount, at 4x and scaled back down, so the
  weight is even and every edge is one crisp edge. (Thickening only the sparse
  outlines was tried: the weight changed along a stroke and the ends beaded.)
- October's scarecrow loses only the pieces that stand apart from the figure:
  the shirt and trouser patches (but not the leg line the trouser patch
  touches), the tick marks, stray specks, and four of the
  seven ground dashes. Everything joined to the figure stays: the face, the
  hat, the hands, the straw, the crow.
- The eyes and nose are solid shapes and stay as drawn; the mouth (with its
  stitches) thickens a little less, to sit with the bolder body.
"""
import os
from collections import deque
import numpy as np
from PIL import Image, ImageFilter

UP = 4
ASSETS = '../../Strata/Assets.xcassets'

def grow(m, k):
    out = m.copy()
    for dy in range(-k, k + 1):
        for dx in range(-k, k + 1):
            if dx * dx + dy * dy <= k * k:
                out |= np.roll(np.roll(m, dy, 0), dx, 1)
    return out

def pieces(alpha):
    """Connected pieces of ink, numbered in reading order of their first pixel."""
    A = alpha > 40
    H, W = A.shape
    lab = np.zeros((H, W), int)
    sizes = {}
    n = 0
    for y in range(H):
        for x in range(W):
            if A[y, x] and not lab[y, x]:
                n += 1
                q = deque([(y, x)]); lab[y, x] = n; count = 0
                while q:
                    cy, cx = q.popleft(); count += 1
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            ny, nx = cy + dy, cx + dx
                            if 0 <= ny < H and 0 <= nx < W and A[ny, nx] and not lab[ny, nx]:
                                lab[ny, nx] = n; q.append((ny, nx))
                sizes[n] = count
    return lab, sizes

def bold(img, r, remove=None, spare=None):
    a = np.array(img.getchannel('A')).astype(float) / 255
    if remove:
        lab, sizes = pieces(np.array(img.getchannel('A')))
        gone = set(remove) | {k for k, v in sizes.items() if v <= 30}
        keep = (lab > 0) & ~np.isin(lab, list(gone))
        # Part of a removed piece that is the figure's own line, joined to
        # the patch drawn on it: kept from that column rightward.
        columns = np.arange(lab.shape[1])[None, :]
        for k, from_x in (spare or {}).items():
            keep |= (lab == k) & (columns >= from_x)
        a[grow(np.isin(lab, list(gone)) & ~keep, 3) & ~keep] = 0
    A = Image.fromarray((a * 255).astype(np.uint8))
    big = A.resize((A.width * UP, A.height * UP), Image.BICUBIC)
    g = Image.fromarray(((np.array(big) >= 128) * 255).astype(np.uint8))
    for _ in range(int(round(r * UP))):
        g = g.filter(ImageFilter.MaxFilter(3))
    out = Image.new('RGBA', img.size, (0, 0, 0, 0))
    out.putalpha(g.resize(img.size, Image.LANCZOS))
    return out

# Pieces of the scarecrow that stand apart from the figure (see the module note).
OCTOBER_EXTRAS = {2, 3, 8, 10, 12, 13, 14, 15, 16, 17, 20, 21, 23, 25}
# The trouser patch (17) is drawn touching the right leg's outer line, so the
# two are one piece: removing the patch took the leg's line with it (the
# owner, 2026-10-06: "the scarecrows leg line is missing on the right side").
# The line is everything of 17 from x = 393: the patch's strokes end at 390
# and one meets the line at 391-392, which left a nub there.
OCTOBER_SPARE = {17: 393}

JOBS = [
    ('MonthOctober', 1.5, OCTOBER_EXTRAS, OCTOBER_SPARE),
    ('MonthOctoberCrow', 1.1, None, None),
    ('MonthOctoberCrowDown', 1.1, None, None),
    ('MonthOctoberCrowHead', 1.1, None, None),
    ('MonthOctoberCrowOut', 1.1, None, None),
    ('MonthOctoberMouth', 1.0, None, None),
    ('CrewsTogether', 1.5, None, None),
    ('CrewsTogetherCheer', 1.0, None, None),
]

if __name__ == '__main__':
    for name, r, remove, spare in JOBS:
        src = Image.open(f'originals/{name}.png').convert('RGBA')
        out = bold(src, r, remove, spare)
        folder = f'{ASSETS}/{name}.imageset'
        target = [f for f in os.listdir(folder) if f.endswith('.png')][0]
        out.save(f'{folder}/{target}')
        print(name, r)
