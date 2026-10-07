"""The logo's strokes as centrelines, for the launch's drawing (2026-10-06).

Run from docs/app-icon: reads source.png, writes logo-paths.json. The Swift
data in Strata/Views/LogoStrokes.swift is generated from that json (the
point arrays, the two weights); regenerate both when the mark changes.

Each stroke is one connected piece of ink: the body and the lens are loops,
traced as the midpoint of the ink along rays from their centre; the eyes are
straight, their ends inset by half a width; the smile is binned by its angle
round the lens and averaged. Coordinates are in the glyph's square, centred
on 0, one unit across.
"""
import json, math
from collections import deque
import numpy as np
from PIL import Image

ink = np.array(Image.open('source.png').convert('L')) < 128
H, W = ink.shape
lab = np.zeros((H, W), int); n = 0; sizes = {}
for y in range(H):
    for x in np.nonzero(ink[y] & (lab[y] == 0))[0]:
        if lab[y, x]: continue
        n += 1; q = deque([(y, x)]); lab[y, x] = n; c = 0
        while q:
            cy, cx = q.popleft(); c += 1
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = cy + dy, cx + dx
                if 0 <= ny < H and 0 <= nx < W and ink[ny, nx] and not lab[ny, nx]:
                    lab[ny, nx] = n; q.append((ny, nx))
        sizes[n] = c
# Biggest first: body, lens, smile, then the two eyes (left is the one further left).
order = [k for k, v in sorted(sizes.items(), key=lambda kv: -kv[1]) if v > 500]
body_k, lens_k, smile_k = order[0], order[1], order[2]
eyes = sorted(order[3:5], key=lambda k: np.nonzero(lab == k)[1].mean())

ys, xs = np.nonzero(lab > 0)
X0, X1, Y0, Y1 = xs.min(), xs.max(), ys.min(), ys.max()
side = max(X1 - X0, Y1 - Y0); cx0 = (X0 + X1) / 2; cy0 = (Y0 + Y1) / 2
def norm(p): return [round((p[0] - cx0) / side, 4), round((p[1] - cy0) / side, 4)]

def loop(k, step):
    m = lab == k; ys, xs = np.nonzero(m); cx, cy = xs.mean(), ys.mean()
    pts, widths = [], []
    for deg in np.arange(-90, 270, step):
        t = math.radians(deg); dx, dy = math.cos(t), math.sin(t); hits = []
        for r in np.arange(0, 1400, 1.0):
            x, y = int(round(cx + dx * r)), int(round(cy + dy * r))
            if not (0 <= x < W and 0 <= y < H): break
            if m[y, x]: hits.append(r)
        if not hits: continue
        run = [hits[0]]
        for h in hits[1:]:
            if h - run[-1] <= 2: run.append(h)
            else: break
        r = (run[0] + run[-1]) / 2; widths.append(run[-1] - run[0])
        pts.append((cx + dx * r, cy + dy * r))
    return [norm(p) for p in pts], float(np.median(widths))

def line(k):
    ys, xs = np.nonzero(lab == k); pts = np.stack([xs, ys], 1).astype(float)
    c = pts.mean(0); _, _, vt = np.linalg.svd(pts - c); d = vt[0]
    proj = (pts - c) @ d; w = float(np.ptp((pts - c) @ vt[1]))
    a, b = c + d * (proj.min() + w / 2), c + d * (proj.max() - w / 2)
    if a[0] > b[0]: a, b = b, a
    return [norm(a), norm(b)], w

def smile(k, bins=24):
    ys, xs = np.nonzero(lab == k); ly, lx = np.nonzero(lab == lens_k)
    ang = np.arctan2(ys - ly.mean(), xs - lx.mean())
    edges = np.linspace(ang.min(), ang.max(), bins + 1); pts = []
    for i in range(bins):
        sel = (ang >= edges[i]) & (ang <= edges[i + 1])
        if sel.sum() >= 5: pts.append((xs[sel].mean(), ys[sel].mean()))
    return [norm(p) for p in pts]

body, bw = loop(body_k, 3); lens, _ = loop(lens_k, 6)
el, ew = line(eyes[0]); er, _ = line(eyes[1])
json.dump({'body': body, 'lens': lens, 'eyeL': el, 'eyeR': er, 'smile': smile(smile_k),
           'outer': round(bw / side, 4), 'inner': round(ew / side, 4)},
          open('logo-paths.json', 'w'))
print('ok')
