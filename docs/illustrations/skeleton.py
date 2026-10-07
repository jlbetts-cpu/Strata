"""October: the dancing skeleton (the owner, 2026-10-06: "the idea was a
dancing skeleton since all the bones are separate", "make sure the skeleton
actually looks like he's dancing ... without overlapping elements"). The crow
that landed on his hand came out on 2026-10-07 ("remove the bird for now").

Run from docs/illustrations: reads originals/MonthOctoberSkeleton.png (his
Procreate export, trace layer and all) and writes MonthOctoberSkel*.imageset
and skeleton-rig.json (every joint, in the canvas's pixels).

- His lines are kept and the trace layer dropped: the fill is white and the
  shadow layer is black at low opacity, so ink is what is both opaque and
  dark.
- Every bone is its own layer, the same canvas size, so they line up.
- The whole skeleton then gets a light second weight, outside lines more
  than inside ones, as his other drawings have.
"""
import json
import os
from collections import deque
import numpy as np
from PIL import Image
from bold_lines import bold, ASSETS

# The canvas, in the artwork's own 2048 pixels: the skeleton, with room for
# his point to swing out to the right.
CANVAS = (600, 320, 1500, 1640)
OUT_HEIGHT = 900
K = OUT_HEIGHT / (CANVAS[3] - CANVAS[1])
# **His pen's weight, not heavier** (the owner, 2026-10-07: "make sure the
# skeleton matches the style, I feel like right now it feels a bit too
# thick"). Measured at Memories' 290pt it was 4.0pt, the heaviest line in
# the app, where his own pen draws 2.5pt (`InkPen.width`). His Procreate
# line is already about 2.4pt at this size, so the outside takes only a
# touch more (about 2.6pt) and the inside nothing. The day before, 2.3pt
# "looked too thin": this sits just above it.
OUTSIDE, INSIDE = 0.4, 0.0

BONES = {   # the pieces of each bone, by the order they are first met
    'Skull': [5, 7, 8, 10, 11], 'Ribs': [12], 'Pelvis': [15, 16, 17],
    'RUpper': [9], 'RFore': [6], 'RHand': [1, 2, 3, 4],
    'LUpper': [13], 'LFore': [14], 'LHand': [18, 19, 20, 21],
    'LThigh': [22], 'LShin': [24], 'LFoot': [27, 30, 31],
    'RThigh': [23], 'RShin': [25], 'RFoot': [26, 28, 29],
}
JOINTS = {
    'neck': (990, 780), 'waist': (1065, 1090), 'pelvis': (1065, 1135),
    'rShoulder': (1177, 809), 'rElbow': (1252, 648), 'rWrist': (1288, 473),
    'lShoulder': (838, 852), 'lElbow': (766, 1026), 'lWrist': (731, 1165),
    'lHip': (943, 1189), 'lKnee': (920, 1360), 'lAnkle': (917, 1533),
    'rHip': (1173, 1208), 'rKnee': (1187, 1368), 'rAnkle': (1186, 1524),
}

def lines_only(img):
    a = np.array(img.convert('RGBA')).astype(float)
    al = a[:, :, 3] / 255
    lum = a[:, :, 0] * 0.3 + a[:, :, 1] * 0.59 + a[:, :, 2] * 0.11
    c = np.clip((al * np.clip((170 - lum) / 120, 0, 1) - 0.3) / 0.4, 0, 1)
    return (c * c * (3 - 2 * c) * 255).round().astype(np.uint8)

def label(alpha):
    A = alpha > 60
    H, W = A.shape
    lab = np.zeros(A.shape, np.int32); n = 0
    ys, xs = np.nonzero(A)
    for y, x in zip(ys, xs):
        if lab[y, x]: continue
        n += 1; q = deque([(y, x)]); lab[y, x] = n
        while q:
            cy, cx = q.popleft()
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = cy + dy, cx + dx
                    if 0 <= ny < H and 0 <= nx < W and A[ny, nx] and not lab[ny, nx]:
                        lab[ny, nx] = n; q.append((ny, nx))
    return lab

def to_canvas(alpha2048):
    """A layer in the artwork's pixels, cut to the canvas and sized down."""
    im = Image.fromarray(alpha2048).crop(CANVAS)
    return im.resize((round(im.width * K), OUT_HEIGHT), Image.LANCZOS)

# Fingers and toes are small open ovals: the full weight closes them, so
# they take less.
SMALL = {'RHand', 'LHand', 'LFoot', 'RFoot'}

def save(name, alpha, small=False):
    rgba = Image.new('RGBA', alpha.size, (0, 0, 0, 0)); rgba.putalpha(alpha)
    if small: out = bold(rgba, 0.0, 0.0)
    else: out = bold(rgba, OUTSIDE, INSIDE)
    folder = f'{ASSETS}/{name}.imageset'
    os.makedirs(folder, exist_ok=True)
    out.save(f'{folder}/{name}.png')
    with open(f'{folder}/Contents.json', 'w') as f:
        json.dump({'images': [{'filename': f'{name}.png', 'idiom': 'universal'}],
                   'info': {'author': 'xcode', 'version': 1},
                   'properties': {'template-rendering-intent': 'template'}}, f, indent=2)
    return out

if __name__ == '__main__':
    lines = lines_only(Image.open('originals/MonthOctoberSkeleton.png'))
    lab = label(lines)
    for bone, ids in BONES.items():
        layer = np.where(np.isin(lab, ids), lines, 0).astype(np.uint8)
        save('MonthOctoberSkel' + bone, to_canvas(layer), small=bone in SMALL)
        print(bone)
    rig = {k: [round((x - CANVAS[0]) * K, 2), round((y - CANVAS[1]) * K, 2)] for k, (x, y) in JOINTS.items()}
    rig['size'] = [round((CANVAS[2] - CANVAS[0]) * K), OUT_HEIGHT]
    with open('skeleton-rig.json', 'w') as f:
        json.dump(rig, f, indent=1)
    print(rig)

