"""October: the dancing skeleton, and the crow that lands on his hand (the
owner, 2026-10-06: "the idea was a dancing skeleton since all the bones are
separate", "make sure the skeleton actually looks like he's dancing ...
without overlapping elements", and October with the crow).

Run from docs/illustrations: reads originals/MonthOctoberSkeleton.png (his
Procreate export, trace layer and all) and originals/MonthOctoberCrow*.png,
and writes MonthOctoberSkel*.imageset, MonthOctoberSkelCrow*.imageset and
skeleton-rig.json (every joint, in the canvas's pixels).

- His lines are kept and the trace layer dropped: the fill is white and the
  shadow layer is black at low opacity, so ink is what is both opaque and
  dark.
- Every bone is its own layer, the same canvas size, so they line up.
- The crow is enlarged until its pen matches his skeleton's pen, and the
  whole scene then gets the same light second weight, outside lines more
  than inside ones, as his other drawings have.
"""
import json
import os
from collections import deque
import numpy as np
from PIL import Image
from bold_lines import bold, ASSETS
from sitting import sitting

# The canvas, in the artwork's own 2048 pixels: the skeleton, and room above
# his raised hand for the crow standing on it.
CANVAS = (600, 0, 1580, 1640)
OUT_HEIGHT = 900
K = OUT_HEIGHT / (CANVAS[3] - CANVAS[1])
# The thicker, smooth outline (the owner, 2026-10-06: the 2.3pt Crews weight
# "looked too thin, I liked the thicker outline that was smoothish and
# minimal, felt more premium"): about 2.9pt on screen.
OUTSIDE, INSIDE = 2.5, 1.25

# The crow, from the scarecrow's shoulder: enlarged so its line is his
# skeleton's line, SITTING on his fingertips (the owner: "make sure it
# actually looks like the bird is sitting on the hand, not like fake
# sitting"). His perched crow without its branch (`sitting.py`), its feet on
# the two middle fingers, a touch into them as feet grip. The flying drawings
# keep the place he drew them in relative to it.
CROW_SCALE = 3.2
CROW_FEET = (518, 256)          # the sitting crow's feet, in its 580 x 870 drawing
CROW_ON = (1318, 380)           # where they hold on, in the artwork

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

def save(name, alpha, small=False, crow=False):
    rgba = Image.new('RGBA', alpha.size, (0, 0, 0, 0)); rgba.putalpha(alpha)
    if small: out = bold(rgba, 0.7, 0.7)
    # The crow's outline as thick as his, its eyes and smile left thin
    # ("make the eyes and smile of the bird skinnier, I can't really see it").
    # Its pen was finer than his, so its outline takes more to match.
    elif crow: out = bold(rgba, OUTSIDE + 1.0, 0.2)
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
    crows = {'CrowSit': sitting().getchannel('A'),
             'CrowHead': Image.open('originals/MonthOctoberCrowHead.png').convert('RGBA').getchannel('A'),
             'CrowDown': Image.open('originals/MonthOctoberCrowDown.png').convert('RGBA').getchannel('A'),
             'CrowOut': Image.open('originals/MonthOctoberCrowOut.png').convert('RGBA').getchannel('A')}
    for name, crow in crows.items():
        big = crow.resize((round(crow.width * CROW_SCALE), round(crow.height * CROW_SCALE)), Image.BICUBIC)
        art = Image.new('L', (2048, 2048), 0)
        art.paste(big, (round(CROW_ON[0] - CROW_FEET[0] * CROW_SCALE), round(CROW_ON[1] - CROW_FEET[1] * CROW_SCALE)))
        # Its eyes and smile keep his pen's width (`save`).
        save('MonthOctoberSkel' + name, to_canvas(np.array(art)), crow=True)
        print(name)
    for name, (x, y) in (('crowFeet', CROW_ON), ('crowBody', (CROW_ON[0] + (490 - CROW_FEET[0]) * CROW_SCALE,
                                                              CROW_ON[1] + (222 - CROW_FEET[1]) * CROW_SCALE)),
                         ('crowNeck', (CROW_ON[0] + (508 - CROW_FEET[0]) * CROW_SCALE,
                                       CROW_ON[1] + (220 - CROW_FEET[1]) * CROW_SCALE))):
        JOINTS[name] = (x, y)
    rig = {k: [round((x - CANVAS[0]) * K, 2), round((y - CANVAS[1]) * K, 2)] for k, (x, y) in JOINTS.items()}
    rig['size'] = [round((CANVAS[2] - CANVAS[0]) * K), OUT_HEIGHT]
    with open('skeleton-rig.json', 'w') as f:
        json.dump(rig, f, indent=1)
    print(rig)

