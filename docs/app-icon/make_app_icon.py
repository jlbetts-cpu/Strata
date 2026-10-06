"""The app icon from the owner's drawing (Procreate, 2026-10-06: "Made the
logo a camera make sure to optimize it and make a light and dark mode
varient... and making the white part transparent cleaning everything up").

Run from docs/app-icon: reads source.png, writes AppIcon-light.png,
AppIcon-dark.png and AppIcon-tinted.png (1024 px) for
Assets.xcassets/AppIcon.appiconset.

The mark was redrawn the same day as an outline ("here is the new and
improved some wins logo"): his strokes are the shape and the rest is
see-through, so the icon is the line on a flat ground.

- light: opaque, the camera in ink on a warm white ground (the App Store
  icon must have no transparency).
- dark: transparent, the camera in warm white, so iOS lays its own dark
  ground behind it (Apple's guidance for dark icons, iOS 18).
- tinted: transparent, the camera in white, which iOS tints.
"""
import numpy as np
from PIL import Image, ImageFilter

# **The owner's redrawn mark** (2026-10-06: "here is the new and improved
# some wins logo"): clean black strokes on white, an outline camera rather
# than the filled one. It is already drawn clean, so nothing is closed or
# smoothed: the strokes are the shape, their own antialiasing kept, and
# everything else, the inside of the camera included, is see-through.
src = np.array(Image.open('source.png').convert('RGB')).astype(float)
L = src.mean(-1)
# Levels: paper (and the faint grey a white ground picks up) to nothing, ink
# to solid, the edge between as it was drawn.
ink_alpha = np.clip((215 - L) / (215 - 45), 0, 1)
SIZE = 1024
GLYPH = 0.62        # the camera's width, as a share of the icon

full = Image.fromarray((ink_alpha * 255).astype(np.uint8))
full = full.crop(full.point(lambda v: 255 if v > 20 else 0).getbbox())
k = SIZE * GLYPH / full.width
glyph = full.resize((round(full.width * k), round(full.height * k)), Image.LANCZOS)
mask = Image.new('L', (SIZE, SIZE), 0)
# Optically centred: a touch above the middle, as a camera with a top bump sits.
mask.paste(glyph, ((SIZE - glyph.width) // 2, (SIZE - glyph.height) // 2 - 8))

def solid(rgb):
    return Image.new('RGB', (SIZE, SIZE), rgb)

ink = (38, 33, 29)          # AppColors.drawingInk, light
paper = (253, 252, 250)     # the page, warm
warm_white = (244, 239, 230)

light = solid(paper); light.paste(solid(ink), (0, 0), mask); light.save('AppIcon-light.png')
dark = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0)); dark.paste(Image.new('RGBA', (SIZE, SIZE), warm_white + (255,)), (0, 0), mask); dark.save('AppIcon-dark.png')
tint = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0)); tint.paste(Image.new('RGBA', (SIZE, SIZE), (255, 255, 255, 255)), (0, 0), mask); tint.save('AppIcon-tinted.png')
print('ok', glyph.size)

# The mark alone, for the launch and Settings: a template the code colours,
# 128pt wide (the launch S was 122 x 128).
for scale in (2, 3):
    w = 128 * scale
    g = full.resize((w, round(full.height * w / full.width)), Image.LANCZOS)
    black = Image.new('L', g.size, 0)
    Image.merge('RGBA', [black, black, black, g]).save(f'BrandCamera@{scale}x.png')
print('mark', g.size)

# iOS 26's own icon format (Icon Composer): a flat ground and the camera as
# one layer, with the glass, specular, shadow and translucency off. Given a
# flat PNG icon, iOS 26 dresses it in glass itself, and the owner saw that as
# "a bit blurry and it has that weird outline" (2026-10-06): a dark rim, a
# grey fill and a halo round each hole. Here the camera layer is drawn as it
# is, ink in light and warm white in dark and tinted.
import json, os
bundle = '../../Strata/AppIcon.icon'
os.makedirs(f'{bundle}/Assets', exist_ok=True)
for old in os.listdir(f'{bundle}/Assets'):
    os.remove(f'{bundle}/Assets/{old}')
layer = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
layer.paste(Image.new('RGBA', (SIZE, SIZE), (255, 255, 255, 255)), (0, 0), mask)
layer.save(f'{bundle}/Assets/camera.png')
def srgb(rgb):
    return 'srgb:' + ','.join(f'{v / 255:.5f}' for v in rgb) + ',1.00000'
icon = {
    'fill-specializations': [
        {'value': {'solid': srgb(paper)}},
        {'appearance': 'dark', 'value': {'solid': srgb((28, 26, 24))}},
    ],
    'groups': [{
        'layers': [{
            'name': 'camera',
            'image-name': 'camera.png',
            # Coloured by the layer's fill, Icon Composer's own way: ink in
            # light, warm white in dark. (A per-appearance image was not
            # taken: the build left the dark one out.)
            'fill-specializations': [
                {'value': {'solid': srgb(ink)}},
                {'appearance': 'dark', 'value': {'solid': srgb(warm_white)}},
            ],
            'glass': False,
        }],
        'shadow': {'kind': 'none', 'opacity': 0},
        'specular': False,
        'translucency': {'enabled': False, 'value': 0},
    }],
    'supported-platforms': {'squares': 'shared'},
}
with open(f'{bundle}/icon.json', 'w') as f:
    json.dump(icon, f, indent=2)
print('icon bundle written')
