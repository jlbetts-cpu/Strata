"""October's crow on its own, bigger (the owner, 2026-10-06: "instead of the
scarecrow could we just have the bird, make it bigger and then fly in and sit
down").

Run from docs/illustrations: reads originals/MonthOctoberCrow*.png (his crow,
drawn in place on the scarecrow's shoulder at 580 x 870) and writes
MonthOctoberBird*.imageset. All four drawings are cut from one box, so they
stay on top of each other as they were drawn, and enlarged from his strokes
(not from the bolded assets, whose weight would enlarge with them). The
weight is then added at the new size, so the bird's line matches the other
drawings' line on screen rather than being three times it.
"""
import json
import os
from PIL import Image
from bold_lines import bold, ASSETS

SCALE = 3
# The union of the four drawings' ink, with room for the line to thicken.
BOX = (420, 166, 577, 279)
# His lines at three times are already most of the bold weight; this is the rest.
OUTSIDE, INSIDE = 1.2, 0.6

LAYERS = {
    'MonthOctoberCrow': 'MonthOctoberBird',
    'MonthOctoberCrowHead': 'MonthOctoberBirdHead',
    'MonthOctoberCrowDown': 'MonthOctoberBirdDown',
    'MonthOctoberCrowOut': 'MonthOctoberBirdOut',
}

if __name__ == '__main__':
    for source, name in LAYERS.items():
        src = Image.open(f'originals/{source}.png').convert('RGBA').crop(BOX)
        big = src.resize((src.width * SCALE, src.height * SCALE), Image.BICUBIC)
        out = bold(big, OUTSIDE, INSIDE)
        folder = f'{ASSETS}/{name}.imageset'
        os.makedirs(folder, exist_ok=True)
        out.save(f'{folder}/{name}.png')
        with open(f'{folder}/Contents.json', 'w') as f:
            json.dump({'images': [{'filename': f'{name}.png', 'idiom': 'universal'}],
                       'info': {'author': 'xcode', 'version': 1},
                       'properties': {'template-rendering-intent': 'template'}}, f, indent=2)
        print(name, out.size)
