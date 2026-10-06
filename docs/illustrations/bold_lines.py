"""The owner's illustrations at the bold line weight (2026-10-06: "i noticed
there lines feel a lot thicker and just feel more premium... we need to go
much thicker on the line", then "thickening lines removing the access lines
and makeing sure you arent removing any key things").

Run from docs/illustrations: reads originals/*.png (his drawings as he drew
them) and writes the app's assets in Strata/Assets.xcassets.

- Two weights, like the logo: the outside line thickens more than the lines
  inside it, easing between the two along a line. At 4x and scaled back
  down, so every edge is one crisp edge. (Thickening only the sparse
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
from PIL import Image, ImageDraw, ImageFilter

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

def dilate(mask, px):
    g = mask
    for _ in range(int(round(px))):
        g = g.filter(ImageFilter.MaxFilter(3))
    return g

def outside_of(ink, close):
    """Background reachable from the edge, once gaps up to 2 x close are shut."""
    shut = np.array(dilate(Image.fromarray(ink.astype(np.uint8) * 255), close)) > 0
    pad = Image.fromarray(np.pad(~shut, 1, constant_values=True).astype(np.uint8) * 128).copy()
    ImageDraw.floodfill(pad, (0, 0), 255)
    return (np.array(pad) == 255)[1:-1, 1:-1]

def blur(arr, sigma):
    im = Image.fromarray(np.clip(arr * 255, 0, 255).astype(np.uint8))
    return np.array(im.filter(ImageFilter.GaussianBlur(sigma))).astype(float) / 255

def bold(img, r_out, r_in, remove=None, spare=None, close=6, ease=10, steps=6):
    """Two weights, as the logo has them (the owner, 2026-10-06: "notice how
    the outside line is thicker than the inside line... two weight strokes,
    thick and a still thick but a bit thinner"): the line that traces the
    figure's outside thickens by r_out, every line inside it by r_in.

    Where a line turns from the outside inward the weight eases along it
    over about `ease` pixels, rather than stepping: the share of the ink
    around a point that is outside line sets its radius."""
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
    ink = a > 0.5
    near = np.array(dilate(Image.fromarray(outside_of(ink, close).astype(np.uint8) * 255), close + 3)) > 0
    outer = ink & near
    w = np.clip(blur(outer.astype(float), ease) / np.maximum(blur(ink.astype(float), ease), 1e-3), 0, 1)
    A = Image.fromarray((a * 255).astype(np.uint8))
    big = A.resize((A.width * UP, A.height * UP), Image.BICUBIC)
    g = np.array(big) >= 128
    W = np.array(Image.fromarray((w * 255).astype(np.uint8)).resize(big.size, Image.BILINEAR)).astype(float) / 255
    acc = np.zeros(g.shape, np.uint8)
    for i in range(steps + 1 if r_out != r_in else 1):
        t = i / steps
        sel = g & (W >= t - 1e-6) if i else g
        acc = np.maximum(acc, np.array(dilate(Image.fromarray(sel.astype(np.uint8) * 255),
                                              (r_in + (r_out - r_in) * t) * UP)))
    out = Image.new('RGBA', img.size, (0, 0, 0, 0))
    out.putalpha(Image.fromarray(acc).resize(img.size, Image.LANCZOS))
    return out

# Pieces of the scarecrow that stand apart from the figure (see the module note).
OCTOBER_EXTRAS = {2, 3, 8, 10, 12, 13, 14, 15, 16, 17, 20, 21, 23, 25}
# The trouser patch (17) is drawn touching the right leg's outer line, so the
# two are one piece: removing the patch took the leg's line with it (the
# owner, 2026-10-06: "the scarecrows leg line is missing on the right side").
# The line is everything of 17 from x = 393: the patch's strokes end at 390
# and one meets the line at 391-392, which left a nub there.
OCTOBER_SPARE = {17: 393}

# (name, outside line, inside lines, pieces removed, part spared). The crows
# keep their lighter pen, at the same two-to-one; the mouth and the cheer's
# marks are inside lines only, at one weight.
JOBS = [
    ('MonthOctober', 3.0, 1.5, OCTOBER_EXTRAS, OCTOBER_SPARE),
    ('MonthOctoberCrow', 2.2, 1.1, None, None),
    ('MonthOctoberCrowDown', 2.2, 1.1, None, None),
    ('MonthOctoberCrowHead', 2.2, 1.1, None, None),
    ('MonthOctoberCrowOut', 2.2, 1.1, None, None),
    ('MonthOctoberMouth', 1.0, 1.0, None, None),
    ('CrewsTogether', 3.0, 1.5, None, None),
    ('CrewsTogetherCheer', 1.0, 1.0, None, None),
]

if __name__ == '__main__':
    for name, r_out, r_in, remove, spare in JOBS:
        src = Image.open(f'originals/{name}.png').convert('RGBA')
        out = bold(src, r_out, r_in, remove, spare)
        folder = f'{ASSETS}/{name}.imageset'
        target = [f for f in os.listdir(folder) if f.endswith('.png')][0]
        out.save(f'{folder}/{target}')
        print(name, r_out, r_in)
