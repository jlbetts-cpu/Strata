#!/usr/bin/env python3
"""Build one page that shows every screen, so the app can be looked at whole.

    tools/gallery.py <captures-dir> <out.html> [--grades docs/screen-audit.md]

The audit grades screens one at a time and a person reads it one screen at a
time, which is the wrong way round for the question the owner actually asks:
"does this look like one app?" A drift between two screens is invisible in two
separate reports and obvious when they sit side by side.

Captures are grouped by the prefix before the first dash and paired by scheme
when a `-dark` twin exists. Images are embedded as data URIs so the page is one
file that opens anywhere with nothing beside it.
"""
import base64, io, os, re, sys
from PIL import Image


def thumb(path, width=402):
    im = Image.open(path).convert("RGB")
    h = round(im.height * width / im.width)
    im = im.resize((width, h), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=82)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()


def grades(audit):
    """Pull `| **Screen** | ... | **10** |` rows out of the audit, loosely."""
    out = {}
    if not audit or not os.path.exists(audit):
        return out
    for line in open(audit):
        m = re.match(r"\|\s*\*?\*?([^|*]+?)\*?\*?\s*\|.*\|\s*\*\*(\d+(?:/\d+)?)[^|]*\*\*", line)
        if m:
            out[m.group(1).strip().lower()] = m.group(2)
    return out


def main():
    src, out = sys.argv[1], sys.argv[2]
    audit = sys.argv[sys.argv.index("--grades") + 1] if "--grades" in sys.argv else None
    g = grades(audit)
    files = sorted(f for f in os.listdir(src) if f.endswith(".png") and "settling" not in f)
    light = [f for f in files if not f.endswith("-dark.png")]
    cards = []
    for f in light:
        name = f[:-4]
        dark = f"{name}-dark.png"
        label = re.sub(r"^\d+[a-z]?-", "", name).replace("-", " ")
        grade = next((v for k, v in g.items() if k and k in label.lower()), "")
        imgs = f'<img src="{thumb(os.path.join(src, f))}" alt="{label}, light">'
        if dark in files:
            imgs += f'<img src="{thumb(os.path.join(src, dark))}" alt="{label}, dark">'
        badge = f'<span class="g">{grade}</span>' if grade else ""
        cards.append(f'<figure><div class="pair">{imgs}</div>'
                     f'<figcaption>{label}{badge}</figcaption></figure>')
    html = f"""<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Strata, every screen</title>
<style>
:root {{ --bg:#f5f5f5; --ink:#1c1c1e; --quiet:#6b6b70; }}
@media (prefers-color-scheme: dark) {{ :root {{ --bg:#111; --ink:#f2f2f2; --quiet:#9a9a9f; }} }}
body {{ margin:0; background:var(--bg); color:var(--ink);
  font:500 15px/1.5 -apple-system, system-ui, sans-serif; }}
header {{ padding:48px 16px 8px; max-width:1400px; margin:auto; }}
h1 {{ font-weight:700; font-size:34px; margin:0 0 4px; }}
p.sub {{ color:var(--quiet); margin:0; }}
main {{ display:grid; gap:64px 32px; padding:48px 16px 96px; max-width:1400px; margin:auto;
  grid-template-columns:repeat(auto-fill, minmax(300px, 1fr)); }}
figure {{ margin:0; }}
.pair {{ display:flex; gap:8px; }}
.pair img {{ width:100%; min-width:0; border-radius:22px; display:block;
  box-shadow:0 0 0 1px rgba(127,127,127,.18); }}
figcaption {{ margin-top:12px; display:flex; justify-content:space-between; align-items:baseline;
  text-transform:lowercase; letter-spacing:.02em; }}
.g {{ font-weight:700; }}
</style></head><body>
<header><h1>Strata</h1><p class="sub">{len(light)} screens, light and dark where both were captured</p></header>
<main>{''.join(cards)}</main></body></html>"""
    open(out, "w").write(html)
    print(f"{out}: {len(light)} screens")


if __name__ == "__main__":
    main()
