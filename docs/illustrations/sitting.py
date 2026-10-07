"""The crow sitting, without the scarecrow's shoulder under it: his perched
crow with the branch line taken away, so it can sit on a hand (the owner,
2026-10-06: "make sure it actually looks like the bird is sitting on the hand,
not like fake sitting"). The belly is each
column's line along y 243 to 249; the branch lies under it, from 250. The
feet cross both and stay."""
import numpy as np
from PIL import Image

FEET = [(500, 518), (523, 540)]

def sitting(path='originals/MonthOctoberCrow.png'):
    a = np.array(Image.open(path).convert('RGBA'))
    al = a[:, :, 3].copy()
    for x in range(430, 552):
        if any(f0 <= x <= f1 for f0, f1 in FEET):
            continue
        if x < 456:
            # Left of the body: only the branch is down here.
            al[246:262, x] = 0
            continue
        # The belly runs along y 243 to 249; the branch lies under it.
        al[250:262, x] = 0
    a[:, :, 3] = al
    return Image.fromarray(a)

if __name__ == '__main__':
    out = sitting()
    out.alpha_composite(Image.open('originals/MonthOctoberCrowHead.png').convert('RGBA'))
    c = out.crop((425, 165, 560, 265)); bg = Image.new('RGBA', c.size, (255, 255, 255, 255)); bg.alpha_composite(c)
    bg.resize((c.width * 6, c.height * 6), Image.NEAREST).convert('RGB').save(
        '/private/tmp/claude-501/-Users-jaydenbetts-Downloads-portfolioo-v392/45be4ee6-6066-4ba0-a7f9-f2a3b71bea03/scratchpad/sitview.png')
