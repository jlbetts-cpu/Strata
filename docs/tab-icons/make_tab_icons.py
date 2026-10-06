"""The tab bar's three icons, from the owner's drawing (Procreate, 2026-10-06).

Run from docs/tab-icons: reads source.png (three icons on one canvas) and
writes Tab*@2x.png and Tab*@3x.png for Assets.xcassets, as template images.

Each icon is taken as a clean silhouette: the drawn black edge and the thin
light gap just inside it (which came out as a faint ring round every icon,
the owner: "a weird outline around them") are closed, and only his real
cut-outs, the white marks well inside the shape (the smile, the lens, the
calendar's dots and band), are kept as holes. The contour is then smoothed
at 8x and scaled down with proper anti-aliasing, so the edges are even
rather than the 127px source's stair-steps ("more smooth and high quality").
"""
import numpy as np
from PIL import Image, ImageFilter

src = np.array(Image.open('source.png').convert('RGBA')).astype(float)
A = src[..., 3] / 255
L = (0.299 * src[..., 0] + 0.587 * src[..., 1] + 0.114 * src[..., 2]) / 255
NAMES = ['TabWins', 'TabCamera', 'TabMemories']
SPANS = [(486, 613), (979, 1107), (1472, 1600)]
EDGE = 5        # source px: white this close to the outside is the edge gap
UP = 8          # supersampling
SMOOTH = 1.8    # source px of blur before the outer contour is re-cut
HOLES = 0.9     # gentler for his cut-outs: the lens ring broke at 1.8

def shift_or(m, k):
    out = m.copy()
    for dy in range(-k, k + 1):
        for dx in range(-k, k + 1):
            if dx * dx + dy * dy <= k * k:
                out |= np.roll(np.roll(m, dy, 0), dx, 1)
    return out

def outside_of(solid):
    h, w = solid.shape
    out = np.zeros_like(solid)
    stack = [(y, x) for y in (0, h - 1) for x in range(w)] + [(y, x) for x in (0, w - 1) for y in range(h)]
    while stack:
        y, x = stack.pop()
        if 0 <= y < h and 0 <= x < w and not out[y, x] and not solid[y, x]:
            out[y, x] = True
            stack += [(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)]
    return out

masks = []
for x0, x1 in SPANS:
    a = A[:, x0 - 14:x1 + 14]; l = L[:, x0 - 14:x1 + 14]
    rows = np.where(a.max(axis=1) > 0.1)[0]
    a = a[rows[0] - 14:rows[-1] + 15]; l = l[rows[0] - 14:rows[-1] + 15]
    drawn = a > 0.35
    outside = outside_of(drawn)
    silhouette = ~outside
    near_edge = shift_or(outside, EDGE)
    white = (a > 0.35) & (l > 0.45)
    holes = white & ~near_edge
    masks.append((Image.fromarray(silhouette.astype(np.uint8) * 255),
                  Image.fromarray(holes.astype(np.uint8) * 255)))

def smooth(mask, sigma):
    big = mask.resize((mask.width * UP, mask.height * UP), Image.BICUBIC)
    big = big.filter(ImageFilter.GaussianBlur(sigma * UP))
    return np.array(big) >= 128

smoothed = [Image.fromarray(((smooth(sil, SMOOTH) & ~smooth(hol, HOLES)) * 255).astype(np.uint8))
            for sil, hol in masks]
boxes = [s.getbbox() for s in smoothed]
side = max(max(b[2] - b[0], b[3] - b[1]) for b in boxes)
for name, s, b in zip(NAMES, smoothed, boxes):
    glyph = s.crop(b)
    for scale in (2, 3):
        canvas, target = 28 * scale, 24 * scale
        k = target / side
        g = glyph.resize((max(1, round(glyph.width * k)), max(1, round(glyph.height * k))), Image.LANCZOS)
        a = Image.new('L', (canvas, canvas), 0)
        a.paste(g, ((canvas - g.width) // 2, (canvas - g.height) // 2))
        black = Image.new('L', a.size, 0)
        Image.merge('RGBA', [black, black, black, a]).save(f'{name}@{scale}x.png')
print('ok', [m[0].size for m in masks])
