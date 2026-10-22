"""Server-side product lookup: Google Lens-style visual matching for a closet photo.

Pipeline:
  1. Upload the photo to SerpApi's Image API and run Google Lens "visual matches":
     dozens of shop photos that look like the garment, from any store (brand sites,
     department stores, Amazon, resale...). Brand identification is not required.
  2. If Lens returns too few candidates, Claude describes the garment and Google
     Images is searched with that description instead.
  3. Claude looks at the user's photo next to the candidate thumbnails and picks the
     one that looks most like the item, preferring a clean product shot (garment
     alone on a plain background) because the picture is later cut out and placed
     on the user's avatar. It also names the brand/product when a logo, label or
     listing title makes that clear.
  4. The chosen full-size image is fetched through the server (`fetch_product_image`)
     so hot-link protected shop CDNs still work; the phone never fetches shop URLs.

Needs SERPAPI_KEY and ANTHROPIC_API_KEY in .env (see .env.example).
"""
import base64;
import json;
import time;
import uuid;
import from concurrent.futures { ThreadPoolExecutor }
import from urllib.error { HTTPError, URLError }
import from urllib.parse { urlencode }
import from urllib.request { Request, urlopen }
import from .clothing_ai { _dev_setting, _send_claude_request }


obj:pub ProductCandidate {
    has title: str = "",
        source: str = "",
        link: str = "",
        price: str = "",
        image: str = "",
        thumbnail: str = "";
}


obj:pub ProductLookup {
    has matched: bool = False,
        match_type: str = "none",
        brand: str = "",
        product_name: str = "",
        color: str = "",
        title: str = "",
        source: str = "",
        product_url: str = "",
        price: str = "",
        image_url: str = "",
        thumbnail_url: str = "",
        confidence: float = 0.0,
        note: str = "",
        best_index: int = -1,
        candidates: list[ProductCandidate] = [];
}


glob SERPAPI_UPLOAD_LIMIT_BYTES: int = 500 * 1024,
     MAX_CANDIDATES: int = 12,
     MIN_LENS_CANDIDATES: int = 3,
     THUMBNAIL_WORKERS: int = 6,
     MAX_PRODUCT_IMAGE_BYTES: int = 6 * 1024 * 1024,
     BROWSER_UA: str = (
         "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
         "(KHTML, like Gecko) Chrome/124.0 Safari/537.36"
     ),
     # Social/video pages: their images usually cannot be fetched and are rarely clean shots.
     SOCIAL_HOSTS: list[str] = [
         "pinterest", "pinimg", "facebook", "fbsbx", "instagram", "threads", "tiktok",
         "twitter", "x.com", "reddit", "redd.it", "tumblr", "weibo", "sinaimg", "sina.com",
         "youtube", "lemon8", "flickr", "naver", "koreaboo", "fandom"
     ],
     EXACT_MIN_CONFIDENCE: float = 0.7,
     PICK_MIN_CONFIDENCE: float = 0.4;


def _log(message: str) {
    print("[product_lookup] " + message, flush=True);
}


def _decode_data_url(image_data: str) -> tuple[bytes, str] {
    if not image_data.startswith("data:image/") {
        raise ValueError("Product lookup needs the photo as an image data URL.");
    }
    separator = image_data.find(",");
    if separator < 0 {
        raise ValueError("The image data URL is incomplete.");
    }
    mime_type = image_data[5:separator].split(";")[0];
    raw = base64.b64decode(image_data[separator + 1:]);
    if not raw {
        raise ValueError("The selected image is empty.");
    }
    return (raw, mime_type);
}


def _json_request(request: Request, label: str) -> dict[str, any] {
    try {
        with urlopen(request, timeout=45) as response {
            return json.loads(response.read().decode("utf-8")) as dict[str, any];
        }
    } except HTTPError as e {
        error_body = e.read().decode("utf-8", errors="replace");
        try {
            parsed = json.loads(error_body) as dict[str, any];
            if parsed.get("error") {
                raise RuntimeError(label + " error (HTTP " + str(e.code) + "): " + str(parsed["error"]));
            }
        } except ValueError {}
        raise RuntimeError(label + " failed (HTTP " + str(e.code) + "). " + error_body[:300]);
    } except URLError as e {
        raise RuntimeError(label + " could not be reached: " + str(e.reason));
    } except (TimeoutError, OSError) as e {
        raise RuntimeError(label + " timed out or failed: " + str(e));
    }
}


def _serpapi_upload(image_bytes: bytes, mime_type: str, api_key: str) -> str {
    if len(image_bytes) > SERPAPI_UPLOAD_LIMIT_BYTES {
        raise ValueError(
            "Photo is " + str(len(image_bytes) // 1024)
            + " KB; Google Lens uploads must be under 500 KB."
        );
    }
    boundary = "----tyyli" + uuid.uuid4().hex;
    extension = ".png" if "png" in mime_type else ".webp" if "webp" in mime_type else ".jpg";
    crlf = "\r\n".encode("utf-8");
    body = (
        ("--" + boundary + "\r\nContent-Disposition: form-data; name=\"api_key\"\r\n\r\n" + api_key + "\r\n").encode("utf-8")
        + ("--" + boundary + "\r\nContent-Disposition: form-data; name=\"image\"; filename=\"photo" + extension + "\"\r\n"
           + "Content-Type: " + mime_type + "\r\n\r\n").encode("utf-8")
        + image_bytes + crlf
        + ("--" + boundary + "--\r\n").encode("utf-8")
    );
    request = Request(
        "https://serpapi.com/image",
        data=body,
        headers={"Content-Type": "multipart/form-data; boundary=" + boundary},
        method="POST"
    );
    payload = _json_request(request, "SerpApi upload");
    if payload.get("error") {
        raise RuntimeError("SerpApi upload error: " + str(payload["error"]));
    }
    image_id = str(payload.get("image_id", ""));
    if not image_id {
        raise RuntimeError("SerpApi upload returned no image_id.");
    }
    return image_id;
}


def _lens_search(image_id: str, lens_type: str, api_key: str) -> dict[str, any] {
    params = {
        "engine": "google_lens",
        "image_id": image_id,
        "type": lens_type,
        "hl": "en",
        "country": "us",
        "api_key": api_key
    };
    request = Request("https://serpapi.com/search.json?" + urlencode(params), method="GET");
    payload = _json_request(request, "Google Lens");
    if payload.get("error") {
        raise RuntimeError("Google Lens: " + str(payload["error"]));
    }
    return payload;
}


def _normalize_price(raw: any) -> str {
    if raw is None { return ""; }
    if isinstance(raw, dict) {
        value = raw.get("value") or raw.get("extracted_value");
        if value is None { return ""; }
        if isinstance(value, str) { return value; }
        return (str(value) + " " + str(raw.get("currency") or "")).strip();
    }
    return str(raw);
}


def _host_of(url: str) -> str {
    without_scheme = url.split("//")[-1];
    host = without_scheme.split("/")[0].lower();
    return host[4:] if host.startswith("www.") else host;
}


def _is_social(cand: ProductCandidate) -> bool {
    hay = (cand.source + " " + cand.link + " " + cand.image).lower();
    for host in SOCIAL_HOSTS {
        if host in hay { return True; }
    }
    return False;
}


def _add_candidates(pool: list[ProductCandidate], items: any, seen: list[str], limit: int = MAX_CANDIDATES) {
    # Appends usable shop results (with an image, not social) to the pool, de-duplicated.
    if not isinstance(items, list) { return; }
    for item in items {
        if len(pool) >= limit { return; }
        if not isinstance(item, dict) { continue; }
        cand = ProductCandidate(
            title=str(item.get("title") or ""),
            source=str(item.get("source") or _host_of(str(item.get("link") or ""))),
            link=str(item.get("link") or ""),
            price=_normalize_price(item.get("price")),
            image=str(item.get("image") or item.get("original") or item.get("thumbnail") or ""),
            thumbnail=str(item.get("thumbnail") or item.get("image") or item.get("original") or "")
        );
        if not cand.image or not cand.thumbnail { continue; }
        # Same image URL, or the same listing on the same store, counts once.
        keys = [cand.image.split("?")[0]];
        if cand.title { keys.append(cand.title.strip().lower() + "|" + cand.source.strip().lower()); }
        if _is_social(cand) or [k for k in keys if k in seen] { continue; }
        seen.extend(keys);
        pool.append(cand);
    }
}


def _lens_candidates(image_id: str, api_key: str) -> tuple[list[ProductCandidate], bool] {
    # "visual_matches" is the Lens type that returns shop results with prices. Lens
    # occasionally returns nothing for a photo; "all" is tried as a second attempt,
    # but its results lean towards web pages, so only half the pool is taken from
    # it and the caller tops up with a Google Images search. The flag says whether
    # the shop-oriented search succeeded.
    pool: list[ProductCandidate] = [];
    seen: list[str] = [];
    for lens_type in [_dev_setting("LENS_TYPE", "visual_matches"), "all"] {
        started = time.time();
        try {
            payload = _lens_search(image_id, lens_type, api_key);
        } except Exception as e {
            _log("lens " + lens_type + " failed: " + str(e));
            continue;
        }
        limit = MAX_CANDIDATES if lens_type != "all" else MAX_CANDIDATES // 2;
        for key in ["visual_matches", "products", "exact_matches"] {
            _add_candidates(pool, payload.get(key), seen, limit);
        }
        _log("lens " + lens_type + ": " + str(len(pool)) + " candidates in " + str(round(time.time() - started, 1)) + "s");
        if len(pool) >= MIN_LENS_CANDIDATES {
            return (pool, lens_type != "all");
        }
    }
    return (pool, False);
}


def _google_images(query: str, api_key: str) -> list[ProductCandidate] {
    params = {"engine": "google_images", "q": query, "hl": "en", "gl": "us", "api_key": api_key};
    request = Request("https://serpapi.com/search.json?" + urlencode(params), method="GET");
    payload = _json_request(request, "Google Images");
    if payload.get("error") {
        raise RuntimeError("Google Images: " + str(payload["error"]));
    }
    pool: list[ProductCandidate] = [];
    _add_candidates(pool, payload.get("images_results"), []);
    return pool;
}


def _fetch_bytes(url: str, timeout: int = 20) -> tuple[bytes, str] {
    # Returns (bytes, content_type); (empty, "") when the download fails.
    if not url { return (bytes(), ""); }
    try {
        request = Request(url, headers={"User-Agent": BROWSER_UA, "Accept": "image/*,*/*;q=0.8"}, method="GET");
        with urlopen(request, timeout=timeout) as response {
            content_type = str(response.headers.get("Content-Type", "")).split(";")[0].strip().lower();
            return (response.read(MAX_PRODUCT_IMAGE_BYTES + 1), content_type);
        }
    } except Exception {
        return (bytes(), "");
    }
}


def _image_media_type(data: bytes, content_type: str) -> str {
    if data[:3] == bytes([255, 216, 255]) { return "image/jpeg"; }
    if data[:8] == bytes([137, 80, 78, 71, 13, 10, 26, 10]) { return "image/png"; }
    if data[:4] == "RIFF".encode("ascii") and data[8:12] == "WEBP".encode("ascii") { return "image/webp"; }
    if data[:6] in ["GIF87a".encode("ascii"), "GIF89a".encode("ascii")] { return "image/gif"; }
    if content_type in ["image/jpeg", "image/png", "image/webp", "image/gif"] { return content_type; }
    return "";
}


def _fetch_image_block(url: str) -> dict[str, any] | None {
    (data, content_type) = _fetch_bytes(url, timeout=12);
    media_type = _image_media_type(data, content_type);
    if not data or not media_type or len(data) > MAX_PRODUCT_IMAGE_BYTES { return None; }
    return {
        "type": "image",
        "source": {"type": "base64", "media_type": media_type, "data": base64.b64encode(data).decode("ascii")}
    };
}


def _fetch_thumbnails(pool: list[ProductCandidate]) -> list[dict[str, any] | None] {
    # Thumbnails are small (Google-hosted for Lens results), fetched in parallel.
    urls = [cand.thumbnail for cand in pool];
    with ThreadPoolExecutor(max_workers=THUMBNAIL_WORKERS) as executor {
        return list(executor.map(_fetch_image_block, urls));
    }
}


def _claude_json(content: list[dict[str, any]], schema: dict[str, any], effort: str, api_key: str) -> dict[str, any] | None {
    payload = {
        "model": _dev_setting("CLAUDE_MODEL", "claude-opus-5-5"),
        "max_tokens": 1024,
        "fallbacks": "default",
        "output_config": {"effort": effort, "format": {"type": "json_schema", "schema": schema}},
        "messages": [{"role": "user", "content": content}]
    };
    response_data = _send_claude_request(payload, api_key);
    if response_data.get("stop_reason") == "refusal" {
        return None;
    }
    for raw_block in response_data.get("content", []) as list {
        block = raw_block as dict[str, any];
        if block.get("type") == "text" and block.get("text") {
            return json.loads(block.get("text") as str) as dict[str, any];
        }
    }
    return None;
}


def _describe_for_search(my_block: dict[str, any], api_key: str) -> str {
    # Fallback when Lens has nothing: a short Google Images query for the garment.
    content: list[dict[str, any]] = [
        {
            "type": "text",
            "text": (
                "Write a short Google Images search query (4-8 words) that would find product "
                "photos of the main clothing item in this photo: garment type, colour, and its "
                "most distinctive details (e.g. 'navy ribbed collarless button cardigan'). "
                "Include the brand only if a logo or label is clearly visible."
            )
        },
        my_block
    ];
    schema = {
        "type": "object",
        "properties": {"search_query": {"type": "string"}},
        "required": ["search_query"],
        "additionalProperties": False
    };
    decision = _claude_json(content, schema, "low", api_key);
    if decision is None { return ""; }
    return str(decision.get("search_query", "")).strip();
}


def _pick(my_block: dict[str, any], pool: list[ProductCandidate], api_key: str) -> dict[str, any] | None {
    # One Claude call: identify the garment and choose the closest-looking candidate.
    content: list[dict[str, any]] = [
        {
            "type": "text",
            "text": (
                "Here is a photo of a clothing item I own, followed by product photos found by "
                "reverse image search. Pick the candidate whose garment looks the most like mine: "
                "same garment type, colour, neckline or collar, closure (buttons, zip), pattern, "
                "knit or fabric texture, sleeve and body length. Ignore the model, pose, background, "
                "lighting, and the listing text; the store does not matter. Among candidates that "
                "look equally close, prefer a clean e-commerce product photo (garment alone, flat or "
                "on a mannequin or hanger, plain background, no person, no text overlay) because the "
                "picture will be cut out and placed on an avatar.\n"
                "Classify the pick: 'exact' = the same product and colourway as far as you can tell; "
                "'similar' = not the same product, but the same kind of garment in a very similar "
                "colour and style; 'none' = nothing is even similar (different garment type or colour). "
                "Also list up to 3 other candidates that are also close, best first.\n"
                "Name the brand and product if a logo, label, or listing title makes it clear, "
                "otherwise leave brand empty and give a short descriptive product name such as "
                "'Navy ribbed cardigan'.\n\nMy photo:"
            )
        },
        my_block
    ];
    blocks = _fetch_thumbnails(pool);
    attached = 0;
    for (i, cand) in enumerate(pool) {
        label = "Candidate " + str(i) + ": " + (cand.title or "(untitled)") + " - " + cand.source;
        if cand.price { label = label + " - " + cand.price; }
        if blocks[i] is None {
            content.append({"type": "text", "text": label + " (image unavailable; do not pick)"});
            continue;
        }
        content.append({"type": "text", "text": label});
        content.append(blocks[i]);
        attached += 1;
    }
    if attached == 0 {
        return None;
    }
    schema = {
        "type": "object",
        "properties": {
            "brand": {"type": "string", "description": "Brand name, or empty if unknown"},
            "product_name": {"type": "string", "description": "Official product name, or a short descriptive name"},
            "color": {"type": "string"},
            "best_index": {"type": "integer", "description": "0-based index of the closest candidate, or -1"},
            "match_type": {"type": "string", "enum": ["exact", "similar", "none"]},
            "confidence": {"type": "number", "description": "0.0 to 1.0 that the pick looks like my item"},
            "alternatives": {"type": "array", "items": {"type": "integer"}, "description": "Other close candidates, best first"},
            "reasoning": {"type": "string", "description": "One or two sentences on the deciding details"}
        },
        "required": ["brand", "product_name", "color", "best_index", "match_type", "confidence", "alternatives", "reasoning"],
        "additionalProperties": False
    };
    return _claude_json(content, schema, "medium", api_key);
}


def:pub find_product_online(image_data: str) -> ProductLookup {
    serpapi_key = _dev_setting("SERPAPI_KEY");
    if not serpapi_key {
        raise ValueError("SERPAPI_KEY is not set on the Jac server. Add it to .env (see .env.example) and restart.");
    }
    anthropic_key = _dev_setting("ANTHROPIC_API_KEY");
    if not anthropic_key {
        raise ValueError("ANTHROPIC_API_KEY is not set on the Jac server. Add it to .env (see .env.example) and restart.");
    }

    (image_bytes, mime_type) = _decode_data_url(image_data);
    my_block = {
        "type": "image",
        "source": {"type": "base64", "media_type": mime_type, "data": base64.b64encode(image_bytes).decode("ascii")}
    };
    result = ProductLookup();

    # 1. Google Lens visual matches.
    pool: list[ProductCandidate] = [];
    lens_ok = False;
    note = "";
    started = time.time();
    try {
        image_id = _serpapi_upload(image_bytes, mime_type, serpapi_key);
        (pool, lens_ok) = _lens_candidates(image_id, serpapi_key);
    } except Exception as e {
        note = "Google Lens failed (" + str(e) + "). ";
        _log(note);
    }
    _log("lens total: " + str(len(pool)) + " candidates in " + str(round(time.time() - started, 1)) + "s");

    # 2. Lens shop search failed or gave too few: describe the garment and add
    #    Google Images results for that description.
    if not lens_ok or len(pool) < MIN_LENS_CANDIDATES {
        started = time.time();
        query = "";
        try {
            query = _describe_for_search(my_block, anthropic_key);
            if query {
                extra = _google_images(query, serpapi_key);
                seen = [cand.image.split("?")[0] for cand in pool];
                for cand in extra {
                    if len(pool) >= MAX_CANDIDATES { break; }
                    if cand.image.split("?")[0] in seen { continue; }
                    pool.append(cand);
                }
            }
        } except Exception as e {
            note = note + "Image search failed (" + str(e) + "). ";
        }
        _log("image search '" + query + "': " + str(len(pool)) + " candidates total in " + str(round(time.time() - started, 1)) + "s");
    }
    result.candidates = pool;
    if not pool {
        result.note = note + "No similar product photos were found for this photo.";
        return result;
    }

    # 3. Claude picks the closest-looking candidate.
    started = time.time();
    decision = _pick(my_block, pool, anthropic_key);
    if decision is None {
        result.note = note + "Could not compare the search results against your photo.";
        return result;
    }
    result.brand = str(decision.get("brand", "")).strip();
    result.product_name = str(decision.get("product_name", "")).strip();
    result.color = str(decision.get("color", "")).strip();
    idx = int(decision.get("best_index", -1));
    if idx < 0 or idx >= len(pool) { idx = -1; }
    match_type = str(decision.get("match_type", "none"));
    confidence = max(0.0, min(1.0, float(decision.get("confidence", 0.0))));
    reasoning = str(decision.get("reasoning", ""));
    if match_type == "exact" and confidence < EXACT_MIN_CONFIDENCE { match_type = "similar"; }
    if confidence < PICK_MIN_CONFIDENCE or idx < 0 { match_type = "none"; }
    _log("pick: index=" + str(idx) + " " + match_type + " conf=" + str(confidence) + " in " + str(round(time.time() - started, 1)) + "s - " + reasoning);

    # Reorder the candidates so the UI can offer the runner-ups first.
    order: list[int] = [];
    for raw in ([idx] if idx >= 0 else []) + (decision.get("alternatives", []) as list) + list(range(len(pool))) {
        try { n = int(raw); } except Exception { continue; }
        if 0 <= n < len(pool) and n not in order { order.append(n); }
    }
    result.candidates = [pool[n] for n in order];
    result.confidence = confidence;
    result.match_type = match_type;
    result.note = note + reasoning;
    if match_type == "none" {
        return result;
    }
    chosen = pool[idx];
    result.matched = True;
    result.best_index = 0;
    result.title = chosen.title;
    result.source = chosen.source;
    result.product_url = chosen.link;
    result.price = chosen.price;
    result.image_url = chosen.image;
    result.thumbnail_url = chosen.thumbnail;
    return result;
}


def:pub fetch_product_image(image_url: str, fallback_url: str = "") -> str {
    # Downloads a product photo on the server (browser user agent, so shop CDNs
    # that block app downloads still work) and returns it as an image data URL.
    # Falls back to the thumbnail; returns "" when neither can be fetched.
    # Many CDNs size the image through the query string (?w=400); the bare URL is
    # usually the full-size original, so it is tried first.
    attempts: list[str] = [];
    if "?" in image_url and ("w=" in image_url or "width=" in image_url or "sw=" in image_url) {
        attempts.append(image_url.split("?")[0]);
    }
    attempts = attempts + [image_url, fallback_url];
    for url in attempts {
        if not url { continue; }
        (data, content_type) = _fetch_bytes(url, timeout=25);
        media_type = _image_media_type(data, content_type);
        if not data or not media_type or len(data) > MAX_PRODUCT_IMAGE_BYTES {
            _log("fetch_product_image: unusable " + _host_of(url) + " (" + str(len(data)) + " bytes, " + content_type + ")");
            continue;
        }
        return "data:" + media_type + ";base64," + base64.b64encode(data).decode("ascii");
    }
    return "";
}


def:pub search_product_images(query: str) -> list[ProductCandidate] {
    # Text search ("aritzia super puff navy"): Google Images product photos the
    # user can pick from. Social pages are dropped; the rest is left in Google's order.
    serpapi_key = _dev_setting("SERPAPI_KEY");
    if not serpapi_key {
        raise ValueError("SERPAPI_KEY is not set on the Jac server. Add it to .env (see .env.example) and restart.");
    }
    cleaned = " ".join(query.split());
    if not cleaned {
        return [];
    }
    started = time.time();
    pool = _google_images(cleaned, serpapi_key);
    _log("text search '" + cleaned + "': " + str(len(pool)) + " results in " + str(round(time.time() - started, 1)) + "s");
    return pool;
}
