"""Embed the body-shape reference sheets for the mobile onboarding UI.

The app displays individual figures by clipping the two source images at
runtime. Re-run this file whenever either source image is replaced.

The full-size sources live in spikes/body_shape_sources/, outside assets/,
so the native build does not copy them into the app. The embedded copies are made smaller
here: each card shows the sheet at about 14% scale (roughly 240pt wide), so
800px keeps it sharp on 3x screens. Re-encoding through Pillow with a
reduced palette also drops embedded metadata such as C2PA provenance.
The UI positions figures in source-pixel units (1774 wide) and stretches the
image to that size, so the smaller copy needs no code changes.

    python3 spikes/embed_body_shape_sheet.py   # needs Pillow
"""

import base64
import io
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent.parent
MEN_SOURCE = ROOT / "spikes" / "body_shape_sources" / "body-shapes-men.png"
WOMEN_SOURCE = ROOT / "spikes" / "body_shape_sources" / "body-shapes-women.png"
OUTPUT = ROOT / "assets_body_shape_sheet.jac"
EMBED_WIDTH = 800
COLORS = 64


def encode(path: Path) -> str:
    image = Image.open(path).convert("RGBA")
    height = round(image.height * EMBED_WIDTH / image.width)
    image = image.resize((EMBED_WIDTH, height), Image.LANCZOS)
    image = image.quantize(colors=COLORS, method=Image.Quantize.FASTOCTREE)
    buffer = io.BytesIO()
    image.save(buffer, "PNG", optimize=True)
    print(f"{path.name}: {path.stat().st_size // 1024} KB -> {len(buffer.getvalue()) // 1024} KB")
    return base64.b64encode(buffer.getvalue()).decode("ascii")


men_encoded = encode(MEN_SOURCE)
women_encoded = encode(WOMEN_SOURCE)
OUTPUT.write_text(
    '"""Body-shape reference sheets embedded for the mobile onboarding UI."""\n\n'
    'glob:pub MEN_BODY_SHAPE_SHEET: str = "data:image/png;base64,'
    + men_encoded
    + '";\n\n'
    'glob:pub WOMEN_BODY_SHAPE_SHEET: str = "data:image/png;base64,'
    + women_encoded
    + '";\n',
    encoding="utf-8",
)
print(f"wrote {OUTPUT} ({OUTPUT.stat().st_size // 1024} KB)")
