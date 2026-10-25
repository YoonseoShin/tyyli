#!/usr/bin/env python
"""Tyyli scan spike: photo -> Google Lens (SerpApi) -> Claude pick -> hi-res image -> rembg PNG.

Standalone validation script. No app, no database.

Usage (from the repo root, with the venv active):

    python spikes/scan_test.py spikes/samples            # all photos in a folder
    python spikes/scan_test.py spikes/samples --limit 2  # first two only
    python spikes/scan_test.py photo.jpg                 # a single photo

Keys are read from `.env` at the repo root (see `.env.example`):
    SERPAPI_KEY         - without it the Lens search is skipped and the original photo is cut out
    ANTHROPIC_API_KEY   - without it the Claude comparison is skipped (no match is chosen)
    CLAUDE_MODEL        - optional, defaults to claude-opus-5-5
    LENS_TYPE           - optional google_lens `type`: visual_matches (default; the only one that returns
                          shopping results with prices) | exact_matches (web pages, no prices) | all
                          (for product photos `all` often returns only an ai_overview and no matches)
    REMBG_MODEL         - optional, defaults to isnet-general-use (see timings below)

Every external call is wrapped so one failure degrades the pipeline instead of aborting the run.

Background-removal timings measured on this Intel i5 MacBook (CPU only, 1280px photo):
    birefnet-general       ~7-17 min per photo  (928 MB model)  best edges, unusable interactively
    birefnet-general-lite  ~70 s per photo      (224 MB model)
    isnet-general-use      ~3 s per photo       (177 MB model)  default here
Set REMBG_MODEL=birefnet-general to get the original request's model back.
"""

from __future__ import annotations

import argparse
import base64
import io
import json
import os
import sys
import time
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any

import requests
from dotenv import load_dotenv
from PIL import Image, ImageOps

try:  # iPhone photos are HEIC by default
    from pillow_heif import register_heif_opener
    register_heif_opener()
except ImportError:
    pass

SPIKES_DIR = Path(__file__).resolve().parent
REPO_ROOT = SPIKES_DIR.parent
OUTPUT_DIR = SPIKES_DIR / "output"
load_dotenv(REPO_ROOT / ".env", override=True)  # .env wins over stale shell exports

SERPAPI_KEY = os.environ.get("SERPAPI_KEY", "").strip()
ANTHROPIC_API_KEY = os.environ.get("ANTHROPIC_API_KEY", "").strip()
CLAUDE_MODEL = os.environ.get("CLAUDE_MODEL", "claude-opus-5-5").strip()
LENS_TYPE = os.environ.get("LENS_TYPE", "visual_matches").strip()
REMBG_MODEL = os.environ.get("REMBG_MODEL", "isnet-general-use").strip()

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".heic", ".heif"}
SERPAPI_UPLOAD_LIMIT_BYTES = 500 * 1024  # documented Image API limit
CLAUDE_MAX_EDGE = 1024  # keep vision requests small and cheap
LOW_RES_EDGE = 800  # below this, try the product page's og:image
TOP_N = 5
HTTP_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/124.0 Safari/537.36"
    )
}


def log(msg: str) -> None:
    print(msg, flush=True)


# ---------------------------------------------------------------------------
# Data shapes
# ---------------------------------------------------------------------------


@dataclass
class Candidate:
    title: str = ""
    source: str = ""
    link: str = ""
    price: str = ""
    thumbnail: str = ""
    image: str = ""
    result_type: str = ""  # which SerpApi key it came from


@dataclass
class ScanResult:
    photo: str
    matched: bool = False
    product_title: str = ""
    confidence: float = 0.0
    link: str = ""
    price: str = ""
    source_image: str = ""  # "product" | "original"
    output_png: str = ""
    candidates: list[dict[str, Any]] = field(default_factory=list)
    claude_reasoning: str = ""
    errors: list[str] = field(default_factory=list)


# ---------------------------------------------------------------------------
# Image helpers
# ---------------------------------------------------------------------------


def load_rgb(path: Path) -> Image.Image:
    """Open an image, honour EXIF rotation, and drop alpha."""
    img = Image.open(path)
    img = ImageOps.exif_transpose(img)
    return img.convert("RGB")


def jpeg_under_limit(img: Image.Image, limit: int, max_edge: int = 1280) -> bytes:
    """Encode as JPEG under `limit` bytes by shrinking and lowering quality."""
    work = img.copy()
    work.thumbnail((max_edge, max_edge))
    for quality in (90, 80, 70, 60, 50, 40):
        buf = io.BytesIO()
        work.save(buf, format="JPEG", quality=quality, optimize=True)
        if buf.tell() <= limit:
            return buf.getvalue()
        if quality == 40:
            work.thumbnail((work.width // 2, work.height // 2))
            quality = 90
    buf = io.BytesIO()
    work.save(buf, format="JPEG", quality=35, optimize=True)
    return buf.getvalue()


def to_claude_image_block(img: Image.Image) -> dict[str, Any]:
    work = img.copy()
    work.thumbnail((CLAUDE_MAX_EDGE, CLAUDE_MAX_EDGE))
    buf = io.BytesIO()
    work.save(buf, format="JPEG", quality=85)
    data = base64.standard_b64encode(buf.getvalue()).decode("utf-8")
    return {
        "type": "image",
        "source": {"type": "base64", "media_type": "image/jpeg", "data": data},
    }


def fetch_image(url: str, timeout: int = 30) -> Image.Image | None:
    if not url:
        return None
    try:
        resp = requests.get(url, headers=HTTP_HEADERS, timeout=timeout)
        resp.raise_for_status()
        img = Image.open(io.BytesIO(resp.content))
        img.load()
        return ImageOps.exif_transpose(img).convert("RGB")
    except Exception as exc:  # noqa: BLE001 - any network/decoding failure is "no image"
        log(f"    ! could not fetch image {url[:80]}: {exc}")
        return None


# ---------------------------------------------------------------------------
# Step 1: SerpApi upload + Google Lens
# ---------------------------------------------------------------------------


def normalize_price(raw: Any) -> str:
    """SerpApi returns price as a string in some engines and as a dict in Lens."""
    if raw is None:
        return ""
    if isinstance(raw, dict):
        value = raw.get("value") or raw.get("extracted_value")
        currency = raw.get("currency") or ""
        if value is None:
            return ""
        if isinstance(value, str):
            return value
        return f"{value} {currency}".strip()
    return str(raw)


def extract_candidates(payload: dict[str, Any]) -> list[Candidate]:
    """Collect result items from every list-shaped key Lens may return, products first."""
    found: list[Candidate] = []
    for key in ("exact_matches", "products", "shopping_results", "visual_matches"):
        items = payload.get(key)
        if not isinstance(items, list):
            continue
        for item in items:
            if not isinstance(item, dict):
                continue
            found.append(
                Candidate(
                    title=str(item.get("title") or ""),
                    source=str(item.get("source") or ""),
                    link=str(item.get("link") or ""),
                    price=normalize_price(item.get("price")),
                    thumbnail=str(item.get("thumbnail") or ""),
                    image=str(item.get("image") or item.get("thumbnail") or ""),
                    result_type=key,
                )
            )
    # Shopping-style results (with a price) are what the stylist wants, so rank them first,
    # then other shop pages, then social/media pages (whose images are often not fetchable),
    # keeping the original relevance order inside each group.
    priced = [c for c in found if c.price and not is_social(c)]
    other = [c for c in found if not c.price and not is_social(c)]
    social = [c for c in found if is_social(c)]
    return priced + other + social


SOCIAL_HOSTS = ("pinterest", "facebook", "fbsbx", "instagram", "threads", "tiktok", "twitter", "x.com", "reddit", "tumblr", "weibo")


def is_social(cand: Candidate) -> bool:
    hay = f"{cand.source} {cand.link} {cand.image}".lower()
    return any(h in hay for h in SOCIAL_HOSTS)


def lens_search(photo: Path, img: Image.Image) -> tuple[list[Candidate], dict[str, Any]]:
    """Upload the photo to SerpApi's Image API, then run Google Lens with the image_id."""
    import serpapi  # imported lazily so the script still runs without the key

    client = serpapi.Client(api_key=SERPAPI_KEY)
    upload_bytes = jpeg_under_limit(img, SERPAPI_UPLOAD_LIMIT_BYTES)
    tmp = OUTPUT_DIR / f".upload_{photo.stem}.jpg"
    tmp.write_bytes(upload_bytes)
    try:
        upload = client.upload_image(str(tmp))
    finally:
        tmp.unlink(missing_ok=True)
    if isinstance(upload, dict) and upload.get("error"):
        raise RuntimeError(f"SerpApi upload error: {upload['error']}")
    image_id = upload["image_id"] if isinstance(upload, dict) else getattr(upload, "image_id")
    log(f"    uploaded to SerpApi (image_id={str(image_id)[:12]}..., {len(upload_bytes)//1024} KB)")

    params: dict[str, Any] = {
        "engine": "google_lens",
        "image_id": image_id,
        "type": LENS_TYPE or "visual_matches",
        "hl": "en",
        "country": "us",
    }
    results = client.search(params)
    payload = results.as_dict() if hasattr(results, "as_dict") else dict(results)
    if payload.get("error"):
        raise RuntimeError(f"SerpApi Lens error: {payload['error']}")
    keys = {k: len(v) for k, v in payload.items() if isinstance(v, list)}
    log(f"    lens result keys: {keys}")
    return extract_candidates(payload), payload


# ---------------------------------------------------------------------------
# Step 2: Claude picks the best match
# ---------------------------------------------------------------------------


def claude_pick(my_photo: Image.Image, candidates: list[Candidate]) -> tuple[int, float, str]:
    """Return (index into candidates or -1, confidence 0..1, reasoning)."""
    import anthropic
    from pydantic import BaseModel, Field

    class MatchDecision(BaseModel):
        best_index: int = Field(
            description="0-based index of the candidate that is the same garment, or -1 for NONE"
        )
        confidence: float = Field(description="0.0 to 1.0, how sure you are that it is the same product")
        reasoning: str = Field(description="One or two sentences on the deciding details")

    content: list[dict[str, Any]] = [
        {
            "type": "text",
            "text": (
                "You are matching a photo of a clothing item I own against product images found "
                "by reverse image search. Decide which candidate is the SAME product (same style, "
                "cut, colour, pattern, hardware, logo placement), not merely similar. "
                "A different colourway or a lookalike is NOT a match. If none is clearly the same "
                "product, answer -1. Here is my photo:"
            ),
        },
        to_claude_image_block(my_photo),
    ]
    attached = 0
    for i, cand in enumerate(candidates):
        cand_img = fetch_image(cand.image or cand.thumbnail, timeout=20)
        if cand_img is None:
            cand_img = fetch_image(cand.thumbnail, timeout=20) if cand.image != cand.thumbnail else None
        label = f"Candidate {i}: {cand.title or '(untitled)'} — {cand.source or 'unknown source'}"
        if cand.price:
            label += f" — {cand.price}"
        if cand_img is None:
            label += " (image unavailable, judge from the title only)"
            content.append({"type": "text", "text": label})
            continue
        content.append({"type": "text", "text": label})
        content.append(to_claude_image_block(cand_img))
        attached += 1
    if attached == 0:
        return -1, 0.0, "No candidate images could be downloaded."

    client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)
    response = client.messages.parse(
        model=CLAUDE_MODEL,
        max_tokens=2048,
        output_config={"effort": "medium"},
        messages=[{"role": "user", "content": content}],
        output_format=MatchDecision,
    )
    if response.stop_reason == "refusal":
        return -1, 0.0, "Claude declined to compare these images."
    decision = response.parsed_output
    if decision is None:
        return -1, 0.0, "Claude returned no structured decision."
    idx = decision.best_index if 0 <= decision.best_index < len(candidates) else -1
    return idx, max(0.0, min(1.0, decision.confidence)), decision.reasoning


# ---------------------------------------------------------------------------
# Step 3: highest-res product image
# ---------------------------------------------------------------------------


def og_image_url(page_url: str) -> str:
    """Scrape og:image (or twitter:image) from a product page."""
    from bs4 import BeautifulSoup

    try:
        resp = requests.get(page_url, headers=HTTP_HEADERS, timeout=20)
        resp.raise_for_status()
    except Exception as exc:  # noqa: BLE001
        log(f"    ! product page fetch failed: {exc}")
        return ""
    soup = BeautifulSoup(resp.text, "html.parser")
    for attrs in (
        {"property": "og:image:secure_url"},
        {"property": "og:image"},
        {"name": "og:image"},
        {"name": "twitter:image"},
        {"property": "twitter:image"},
    ):
        tag = soup.find("meta", attrs=attrs)
        if tag and tag.get("content"):
            return requests.compat.urljoin(page_url, tag["content"].strip())
    return ""


def best_product_image(cand: Candidate) -> Image.Image | None:
    best = fetch_image(cand.image)
    if best is None and cand.thumbnail and cand.thumbnail != cand.image:
        best = fetch_image(cand.thumbnail)
    if best is not None and max(best.size) >= LOW_RES_EDGE:
        return best
    if cand.link:
        og = og_image_url(cand.link)
        if og:
            og_img = fetch_image(og)
            if og_img is not None and (best is None or max(og_img.size) > max(best.size)):
                log(f"    using og:image ({og_img.width}x{og_img.height}) from product page")
                return og_img
    return best


# ---------------------------------------------------------------------------
# Step 4: background removal
# ---------------------------------------------------------------------------

_rembg_session = None


def remove_background(img: Image.Image) -> Image.Image:
    global _rembg_session
    from rembg import new_session, remove

    if _rembg_session is None:
        log(f"    loading rembg model '{REMBG_MODEL}' (first run downloads it)...")
        _rembg_session = new_session(REMBG_MODEL)
    out = remove(img, session=_rembg_session)
    return out.convert("RGBA")


def crop_to_content(img: Image.Image, pad: int = 12) -> Image.Image:
    """Trim transparent margins so the closet thumbnail is tight around the garment."""
    bbox = img.getchannel("A").getbbox()
    if not bbox:
        return img
    left, top, right, bottom = bbox
    return img.crop(
        (max(0, left - pad), max(0, top - pad), min(img.width, right + pad), min(img.height, bottom + pad))
    )


# ---------------------------------------------------------------------------
# Pipeline
# ---------------------------------------------------------------------------


def scan_photo(photo: Path) -> ScanResult:
    result = ScanResult(photo=photo.name)
    log(f"\n=== {photo.name}")
    try:
        my_img = load_rgb(photo)
    except Exception as exc:  # noqa: BLE001
        result.errors.append(f"could not open photo: {exc}")
        return result
    log(f"    photo {my_img.width}x{my_img.height}")

    candidates: list[Candidate] = []
    if SERPAPI_KEY:
        try:
            candidates, raw = lens_search(photo, my_img)
            (OUTPUT_DIR / f"{photo.stem}.lens.json").write_text(json.dumps(raw, indent=2))
            candidates = candidates[:TOP_N]
            for i, c in enumerate(candidates):
                log(f"    [{i}] {c.result_type}: {c.title[:60]} | {c.source} | {c.price or 'no price'}")
        except Exception as exc:  # noqa: BLE001
            result.errors.append(f"lens search failed: {exc}")
            log(f"    ! lens search failed: {exc}")
    else:
        result.errors.append("SERPAPI_KEY not set; skipped Lens search")
        log("    ! SERPAPI_KEY not set; skipping Lens search")
    result.candidates = [asdict(c) for c in candidates]

    best_idx, confidence, reasoning = -1, 0.0, ""
    if candidates and ANTHROPIC_API_KEY:
        try:
            best_idx, confidence, reasoning = claude_pick(my_img, candidates)
            log(f"    claude: index={best_idx} confidence={confidence:.2f} — {reasoning}")
        except Exception as exc:  # noqa: BLE001
            result.errors.append(f"claude comparison failed: {exc}")
            log(f"    ! claude comparison failed: {exc}")
    elif candidates:
        result.errors.append("ANTHROPIC_API_KEY not set; skipped Claude comparison")
        log("    ! ANTHROPIC_API_KEY not set; skipping Claude comparison")
    result.confidence = confidence
    result.claude_reasoning = reasoning

    source_img = my_img
    result.source_image = "original"
    if best_idx >= 0:
        chosen = candidates[best_idx]
        result.matched = True
        result.product_title = chosen.title
        result.link = chosen.link
        result.price = chosen.price
        product_img = best_product_image(chosen)
        if product_img is not None:
            source_img = product_img
            result.source_image = "product"
            product_img.save(OUTPUT_DIR / f"{photo.stem}.source.jpg", quality=92)
            log(f"    product image {product_img.width}x{product_img.height}")
        else:
            result.errors.append("matched product image could not be downloaded; used original photo")

    try:
        cutout = crop_to_content(remove_background(source_img))
        out_path = OUTPUT_DIR / f"{photo.stem}.png"
        cutout.save(out_path)
        result.output_png = str(out_path.relative_to(REPO_ROOT))
        log(f"    saved {result.output_png} ({cutout.width}x{cutout.height})")
    except Exception as exc:  # noqa: BLE001
        result.errors.append(f"background removal failed: {exc}")
        log(f"    ! background removal failed: {exc}")
    return result


def collect_photos(target: Path, limit: int | None) -> list[Path]:
    if target.is_file():
        photos = [target]
    else:
        photos = sorted(p for p in target.iterdir() if p.suffix.lower() in IMAGE_EXTENSIONS and not p.name.startswith("."))
    return photos[:limit] if limit else photos


def print_summary(results: list[ScanResult]) -> None:
    headers = ["photo", "matched", "product title", "conf", "source", "link"]
    rows = [
        [
            r.photo[:28],
            "yes" if r.matched else "no",
            (r.product_title or "-")[:40],
            f"{r.confidence:.2f}" if r.matched else "-",
            r.source_image,
            (r.link or "-")[:50],
        ]
        for r in results
    ]
    widths = [max(len(h), *(len(row[i]) for row in rows)) for i, h in enumerate(headers)] if rows else [len(h) for h in headers]
    line = " | ".join(h.ljust(w) for h, w in zip(headers, widths))
    print("\n" + line)
    print("-+-".join("-" * w for w in widths))
    for row in rows:
        print(" | ".join(c.ljust(w) for c, w in zip(row, widths)))
    for r in results:
        if r.errors:
            print(f"  {r.photo}: " + "; ".join(r.errors))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("target", help="folder of clothing photos, or one photo")
    parser.add_argument("--limit", type=int, default=None, help="only process the first N photos")
    args = parser.parse_args()

    target = Path(args.target).expanduser()
    if not target.exists():
        print(f"not found: {target}", file=sys.stderr)
        return 2
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    photos = collect_photos(target, args.limit)
    if not photos:
        print(f"no images in {target}", file=sys.stderr)
        return 2

    log(f"model={CLAUDE_MODEL} lens_type={LENS_TYPE} rembg={REMBG_MODEL}")
    log(f"serpapi key: {'set' if SERPAPI_KEY else 'MISSING'} | anthropic key: {'set' if ANTHROPIC_API_KEY else 'MISSING'}")
    started = time.time()
    results = [scan_photo(p) for p in photos]
    (OUTPUT_DIR / "summary.json").write_text(json.dumps([asdict(r) for r in results], indent=2))
    print_summary(results)
    log(f"\n{len(results)} photo(s) in {time.time() - started:.0f}s; details in {OUTPUT_DIR.relative_to(REPO_ROOT)}/summary.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
