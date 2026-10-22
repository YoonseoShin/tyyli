"""Regenerates assets_body_shapes.jac from Wikimedia Commons' public-domain
Bodyshapes.svg (four outlines; "Inverted triangle" is derived from the pear).

    python3 spikes/body_shapes.py            # needs macOS qlmanage + Pillow

Source: https://commons.wikimedia.org/wiki/File:Bodyshapes.svg
"""
import base64, os, subprocess, sys, tempfile, urllib.request
from PIL import Image, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SVG_URL = "https://upload.wikimedia.org/wikipedia/commons/1/1b/Bodyshapes.svg"
work = tempfile.mkdtemp()
svg = os.path.join(work, "Bodyshapes.svg")
urllib.request.urlretrieve(SVG_URL, svg)
subprocess.run(["qlmanage", "-t", "-s", "2400", "-o", work, svg], check=True, capture_output=True)
im = Image.open(svg + ".png").convert("RGBA")
s = im.width / 1200.0
cols = {"Rectangle": (25, 305), "Apple": (320, 600), "Pear": (610, 880), "Hourglass": (895, 1180)}
figs = {}
for name, (x0, x1) in cols.items():
    crop = im.crop((int(x0 * s), int(15 * s), int(x1 * s), int(770 * s)))
    bg = Image.new("RGBA", crop.size, (255, 255, 255, 255))
    flat = Image.alpha_composite(bg, crop).convert("RGB")
    bbox = ImageOps.invert(flat.convert("L")).point(lambda v: 255 if v > 30 else 0).getbbox()
    figs[name] = flat.crop(bbox)
pear = figs["Pear"]; pw, ph = pear.size
tri = Image.new("RGB", (int(pw * 1.15), ph), "white")
for y in range(ph):
    t = y / ph
    f = 1.0 + 0.14 * (t / 0.22) if t < 0.22 else 1.14 - 0.34 * ((t - 0.22) / 0.20) if t < 0.42 else 0.80
    row = pear.crop((0, y, pw, y + 1)).resize((max(1, int(pw * f)), 1), Image.LANCZOS)
    tri.paste(row, ((tri.width - row.width) // 2, y))
figs["Inverted triangle"] = tri
order = ["Hourglass", "Pear", "Apple", "Rectangle", "Inverted triangle"]
lines = ['"""Body-shape outlines shown in onboarding, embedded as data URIs.', '',
         'Source: Wikimedia Commons, File:Bodyshapes.svg (public domain). The',
         '"Inverted triangle" figure is derived from the pear outline. Regenerate with',
         'spikes/body_shapes.py if the set changes.', '"""', '',
         'glob:pub BODY_SHAPE_CREDIT: str = "Outlines from Wikimedia Commons (public domain).";', '',
         'glob:pub BODY_SHAPE_IMAGES: dict[str, str] = {']
for i, name in enumerate(order):
    f = figs[name]; f = f.resize((int(f.width * 560 / f.height), 560), Image.LANCZOS)
    canvas = Image.new("RGB", (f.width + 40, 600), "white"); canvas.paste(f, (20, 20))
    buf = os.path.join(work, name + ".png")
    canvas.convert("P", palette=Image.ADAPTIVE, colors=16).save(buf, optimize=True)
    data = base64.b64encode(open(buf, "rb").read()).decode()
    lines.append(f'    "{name}": "data:image/png;base64,{data}"' + ("," if i < len(order) - 1 else ""))
lines.append("};")
out = os.path.join(ROOT, "assets_body_shapes.jac")
open(out, "w").write("\n".join(lines) + "\n")
print("wrote", out, os.path.getsize(out) // 1024, "KB")
