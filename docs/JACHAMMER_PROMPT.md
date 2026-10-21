# Tyyli — JacHammer build prompt

Paste the sections below into JacHammer one phase at a time (Phase 0 first, then
Phase 1, and so on). Start the project with the **Mobile App** template. Each
phase is self-contained enough for one or two JacHammer turns; the "Reference"
section at the end holds the exact API contracts and prompts, so paste it along
with Phase 3.

---

## Phase 0 — What we are building

Build **Tyyli**, a mobile closet / personal styling app (iOS + Android via React
Native, one Jac source). The user photographs their clothes, the app analyzes
each photo with Claude, finds a clean product photo of the item online (Google
Lens through SerpApi, with Claude choosing the closest picture), and stores
everything locally on the phone with SQLite. Later phases will put the items on a
human avatar, so the stored pictures should be clean cut-out-friendly product
shots whenever possible.

Tabs: Home, Closet, Outfits, Chat, Profile. This prompt covers the **Closet** tab
and the two server functions it needs; keep the other tabs as simple
placeholders (Home shows a greeting and today's date; Outfits/Chat/Profile show
"Coming soon") unless already built.

Design: warm neutral palette (off-white background `#F6F4F0`, surface `#FFFDF9`,
ink `#1F1B16`, muted `#7A7269`, accent terracotta `#A5533F`, soft `#EFE9E1`,
line `#E4DED5`, danger `#9A3B2E`). Rounded cards (radius 24), buttons (radius
16), 16 px page padding, max content width 560.

All secrets live in environment variables on the server, never in the client:
`ANTHROPIC_API_KEY`, `SERPAPI_KEY`, optional `CLAUDE_MODEL` (default
`claude-opus-5-5`) and `LENS_TYPE` (default `visual_matches`).

---

## Phase 1 — Data model and Closet screen (local only, no AI yet)

### ClothingItem (stored in SQLite on the phone; the web preview may use AsyncStorage)

| field | type | notes |
|---|---|---|
| clothing_item_id | str | `"<source>-<Date.now()>-<random>"`, source is camera / gallery / url / web |
| name | str | starts as "Camera photo" / "Gallery photo", replaced by AI |
| category | str | "Uncategorized" until analyzed; then one of Top, Bottom, Dress, Outerwear, Shoes, Bag, Accessory, Other |
| colors | list[str] | |
| seasons | list[str] | spring / summer / fall / winter |
| style_tags | list[str] | shown as "Mood" |
| occasions | list[str] | shown as "Best for" |
| warmth | int | 0–5, 0 = adds no warmth (bags, jewellery) |
| waterproof | bool | |
| description | str | one sentence |
| image_path | str | app-storage relative path `images/<id>.jpg` |
| source_image_url | str | where a product photo came from |
| source_product_url | str | the listing page |
| brand | str | |
| price | str | e.g. "$285*" |
| original_image_path | str | the user's own photo, kept when the picture is swapped for a product photo; "" otherwise |
| lookup_status | str | "", "matched", "similar", "picked", "no_match" |
| lookup_note | str | Claude's reasoning or a short note |
| created_at | str | |

Use `CREATE TABLE IF NOT EXISTS` plus `ALTER TABLE … ADD COLUMN` migrations
guarded by `PRAGMA table_info`, so existing installs keep their data.

### Photo storage (native)

- Photos from the camera / gallery are copied into `documentDirectory/images/<id>.jpg`,
  resized so the longest edge is ≤ 1280 px, JPEG quality 0.7 (expo-image-manipulator).
- `read_clothing_image_data(path)` returns a `data:image/jpeg;base64,…` URL (for analysis).
- `read_clothing_image_data_for_search(path)` returns a smaller one: width 900 px,
  quality 0.6 (Google Lens uploads must be under 500 KB).
- `download_clothing_photo(url, id)` downloads with browser-like headers
  (`User-Agent` of mobile Safari, `Accept: image/webp,image/avif,image/*,*/*;q=0.8`)
  then runs the same resize.
- `save_clothing_photo_data(data_url, id)` writes a base64 data URL to a file then resizes it.
- `get_clothing_image_size(path)` → `{"width", "height"}` in pixels.
- `crop_clothing_image_for_search(path, left, top, width, height)` — box given as
  fractions 0..1 of the image; crops, resizes to ≤ 900 px wide, returns a JPEG data URL.

### Closet screen — grid

- Title "My closet", subtitle "<n> item(s)".
- Card with buttons **Take photo** and **From gallery** (expo-image-picker;
  gallery allows multiple selection). Each new photo is saved immediately, shown
  in the grid, and analyzed in the background (Phase 2).
- Under those, a **web search** row (text input + Search) — Phase 4.
- Grid: 2 columns, each tile = image (height 160, cover) + name (1 line) + category
  (or "Analyzing..." while the AI runs).
- Tapping a tile opens the detail view.

### Closet screen — item detail

- "← Closet" link, the photo (height 300, contain), the name as the title.
- Metadata card: Type, Colors, Mood, Best for, Seasons, Warmth "n/5" (hidden when
  warmth is 0; "· Waterproof" appended when true), description in muted text.
  Show "Not analyzed yet." before analysis.
- Buttons (rows of two, ghost style): **Re-analyze** | **Find online**; **Crop & search**
  | **Search by name**; **Use my photo** (only when `original_image_path` is set) |
  **Delete** (red).
- A status line in muted text at the bottom shows the last message
  ("Analyzed …", "Found it on …", errors).

Buttons must give feedback: dim to 60 % opacity while pressed, 45 % when
disabled, and show a small `ActivityIndicator` inside while their job runs. While
any search or analysis runs, show a card with a spinner and the current step
("Searching the web for Navy cardigan…") under the title. Both scroll views need
`keyboardShouldPersistTaps="handled"` and `automaticallyAdjustKeyboardInsets`
so text inputs are not hidden behind the keyboard.

---

## Phase 2 — Photo analysis with Claude (server function)

Server function `analyze_clothing_image(image_data: str) -> ClothingAnalysis`
called from the client after each photo is added and from **Re-analyze**.

`ClothingAnalysis`: name, category, colors, style_tags, occasions, seasons,
warmth (int), waterproof (bool), description.

Implementation (Python stdlib `urllib`, no SDK needed):

- `POST https://api.anthropic.com/v1/messages`
- headers: `Content-Type: application/json`, `x-api-key: <ANTHROPIC_API_KEY>`,
  `anthropic-version: 2023-06-01`, `anthropic-beta: server-side-fallback-2026-07-01`
- body:

```json
{
  "model": "claude-opus-5-5",
  "max_tokens": 1024,
  "fallbacks": "default",
  "output_config": {
    "effort": "low",
    "format": {"type": "json_schema", "schema": <ANALYSIS_SCHEMA>}
  },
  "messages": [{"role": "user", "content": [
    {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": "<base64>"}},
    {"type": "text", "text": "<ANALYSIS_PROMPT>"}
  ]}]
}
```

- Read the first `content` block of type `text` and `json.loads` it. If
  `stop_reason == "refusal"`, raise "Claude declined to analyze this photo."
- Retry up to 3 times with backoff (1 s, 2 s + jitter) on HTTP 408, 429, 500,
  502, 503, 504, 529. Any other HTTP error is raised with the response body.
- Clamp warmth to 0..5 after parsing.

ANALYSIS_PROMPT:

> Analyze the single main clothing item in this photo for a personal styling
> app. If several items are visible, describe the most prominent one. Use short
> English values. Name visible colors from most dominant to least dominant.
> Only mark waterproof true when rain resistance is visually clear. Rate warmth
> from 1 (very light) to 5 (very warm), but use 0 for items that add no warmth,
> such as bags, jewellery, belts, sunglasses, and other non-wearable accessories
> (a scarf or hat does add warmth). Describe material, pattern, fit, and styling
> details in one concise sentence.

ANALYSIS_SCHEMA (Claude's structured output rejects `minimum`/`maximum` on
integers, so do not include them):

```json
{
  "type": "object",
  "properties": {
    "name": {"type": "string"},
    "category": {"type": "string", "enum": ["Top","Bottom","Dress","Outerwear","Shoes","Bag","Accessory","Other"]},
    "colors": {"type": "array", "items": {"type": "string"}},
    "style_tags": {"type": "array", "items": {"type": "string"}},
    "occasions": {"type": "array", "items": {"type": "string"}},
    "seasons": {"type": "array", "items": {"type": "string", "enum": ["spring","summer","fall","winter"]}},
    "warmth": {"type": "integer"},
    "waterproof": {"type": "boolean"},
    "description": {"type": "string"}
  },
  "required": ["name","category","colors","style_tags","occasions","seasons","warmth","waterproof","description"],
  "additionalProperties": false
}
```

Client: `analyze_item(item)` reads the photo as a data URL, calls the function,
saves name/category/colors/seasons/style_tags/occasions/warmth/waterproof/
description onto the item (keeping all other fields). Show a 75 s client-side
timeout message if the call hangs.

---

## Phase 3 — "Find online": Google Lens + Claude picks the closest picture

Goal: like pointing Google Lens at the item. Any store counts (brand sites,
department stores, Amazon, resale shops). Brand identification is a bonus, not a
requirement. The chosen picture replaces the item's photo (the original is kept
so "Use my photo" can undo it).

### Server objects

```
ProductCandidate { title, source, link, price, image, thumbnail }   // all str
ProductLookup {
  matched: bool, match_type: "exact" | "similar" | "none",
  brand, product_name, color, title, source, product_url, price,
  image_url, thumbnail_url, confidence: float, note, best_index: int,
  candidates: list[ProductCandidate]   // chosen first, then runner-ups
}
```

### Server function `find_product_online(image_data: str) -> ProductLookup`

1. **Upload** the photo to SerpApi: `POST https://serpapi.com/image` as
   multipart/form-data with fields `api_key` and `image` (file, < 500 KB).
   Response JSON has `image_id`.
2. **Google Lens**: `GET https://serpapi.com/search.json?engine=google_lens&image_id=<id>&type=visual_matches&hl=en&country=us&api_key=…`.
   Collect `visual_matches` (also `products` / `exact_matches` if present).
   Each item has `title`, `source`, `link`, `thumbnail` (small, Google-hosted),
   `image` (full size), optional `price: {value, extracted_value, currency}`.
   If the response has `error` ("Google Lens hasn't returned any results…") or
   fewer than 3 usable results, retry once with `type=all` and take at most 6
   from it.
3. **Filter**: drop results without an image, duplicates (same image URL
   without query string, or same title+source), and social/video pages (hosts
   containing pinterest, pinimg, facebook, fbsbx, instagram, threads, tiktok,
   twitter, x.com, reddit, redd.it, tumblr, weibo, sinaimg, youtube, lemon8,
   flickr, naver, koreaboo, fandom). Keep at most 12.
4. **Fallback** when Lens gave fewer than 3 shop results: ask Claude for a 4–8
   word Google Images query describing the garment (see DESCRIBE_PROMPT), then
   `GET https://serpapi.com/search.json?engine=google_images&q=<query>&hl=en&gl=us&api_key=…`
   and add `images_results` (fields `title`, `source`, `link`, `thumbnail`,
   `original` as the full image) until the pool has 12.
5. **Pick** (one Claude call, effort "medium", same request shape as Phase 2):
   content = PICK_PROMPT text, the user's photo, then for each candidate a text
   label `Candidate <i>: <title> - <source> - <price>` followed by its
   thumbnail as an image block (fetch thumbnails in parallel, 12 s timeout;
   label an unfetchable one "(image unavailable; do not pick)"). Use
   PICK_SCHEMA. Gates: `exact` with confidence < 0.7 becomes `similar`;
   confidence < 0.4 or `best_index` out of range becomes `none`.
6. Reorder `candidates` as: chosen, then Claude's `alternatives`, then the rest.
   Fill the result fields from the chosen candidate; `note` = Claude's
   reasoning. Log each stage with timings to the server console.

### Server function `fetch_product_image(image_url: str, fallback_url: str = "") -> str`

Downloads an image server-side with a desktop Chrome `User-Agent` and returns
it as a `data:<media type>;base64,…` URL, or `""` if nothing could be fetched.
Try, in order: the URL with its query string removed when it contains `w=`,
`width=` or `sw=` (CDNs size images through the query; the bare URL is the
original), the URL as given, then the fallback (the thumbnail). Detect the media
type from magic bytes (JPEG/PNG/WebP/GIF); cap at 6 MB.

### Client: `find_online(item, image_data="")`

- Image = the user's own photo (`original_image_path` if set, else
  `image_path`), shrunk for search, unless a cropped `image_data` is passed.
- Call `find_product_online`. Set `name = "<brand> <product_name>"` when a
  product name came back, `brand`, `lookup_note = note`.
- No match → `lookup_status = "no_match"`, save, done.
- Otherwise store the chosen picture: try `download_clothing_photo(image)` on
  the phone first (it passes CDN bot checks that block servers, e.g.
  assets.aritzia.com returns 403 to any server), then
  `fetch_product_image(image, thumbnail)` + `save_clothing_photo_data`. Save
  `price`, `image_path` (new), `original_image_path` (the user's photo, unless
  already set), `source_image_url`, `source_product_url`,
  `lookup_status = "matched"` for exact or `"similar"` otherwise. If the picture
  could not be stored, `lookup_status = "no_match"` and append
  "(The product photo could not be downloaded.)" to the note.
- `use_original_photo(item)` swaps `image_path` back to `original_image_path`,
  clears it, deletes the product file.
- `use_candidate(item, cand)` — the user tapped a runner-up: store that picture
  the same way, set `name` from the listing title (take the part before " | ",
  strip a leading "Amazon.com:", drop " - 42% Off"-style pieces and the store
  name), `lookup_status = "picked"`, `lookup_note = "Picked by you from the search results."`.

### Detail screen additions

- Result card (hidden while busy):
  - heading "Found online: <name>" (matched), "Closest-looking picture online:
    <name>" (similar), "Picked by you: <name>" (picked);
  - "Brand: …", "Price: …" when present, the product URL (2 lines), the note,
    and "Your own photo is kept; tap "Use my photo" to switch back." when
    `original_image_path` is set.
  - For no_match: "Brand: …" if any, then "No close picture found online. <note>".
- Alternatives card: "Not the right picture? Tap a closer one:" followed by a
  horizontal row of 72×72 thumbnails (the runner-up candidates). Tapping one
  calls `use_candidate`. Keep this list in screen state only (not persisted).
- The Find online button reads "Search again" once a lookup has run; 180 s
  client-side timeout.

---

## Phase 4 — Crop & search, and text search

### Crop & search

- Opens a full-screen view (not inside a ScrollView): title "Box the item to
  search", hint "Drag your finger across the photo to draw a box around one
  piece of clothing."
- The photo is shown at the container's full width with its real aspect ratio
  (from `get_clothing_image_size`), capped at 440 px tall (shrink the width to
  keep the ratio when capped; centre it).
- `onTouchStart` records the start point, `onTouchMove` / `onTouchEnd` update
  the end point (`nativeEvent.locationX/Y`, clamped to the photo). Draw the box
  as an absolutely positioned View with a 2 px accent border and
  `rgba(255,255,255,0.25)` fill, `pointerEvents="none"`.
- Buttons: **Cancel** | **Search this area**. Require a box at least 24 px on
  each side ("Drag a box around the item first.").
- Convert the box to fractions of the displayed photo and call
  `crop_clothing_image_for_search`, then the same lookup flow as Find online.
- Remember the box per item: the button becomes "Search again (boxed area)" and
  reuses it; a link "Search the whole photo instead" clears it.

### Text search

Server function `search_product_images(query: str) -> list[ProductCandidate]`:
Google Images via SerpApi (same engine as the fallback), social hosts dropped,
duplicates removed, Google's order kept, at most 12.

- Detail screen: **Search by name** toggles a row with a text input
  (placeholder "e.g. aritzia super puff navy", return key "search") and a Search
  button. Results fill the same thumbnail row with the heading "Tap the picture
  to use for this item:"; tapping one calls `use_candidate`.
- Closet grid: a "Search the web, e.g. levi's trucker jacket" input + Search
  button. Results show in a card "Tap a picture to add it to your closet" as a
  2-column grid of thumbnails with 2-line titles and a "Clear" link. Tapping
  one creates a new item (name from the listing title, category
  "Uncategorized", `lookup_status = "matched"`, note "Added from a web search
  (<source>).") using the same download-then-proxy logic, then analyzes it.

---

## Reference — prompts and schemas for Phase 3

DESCRIBE_PROMPT (Claude, effort "low", schema `{"search_query": string}`):

> Write a short Google Images search query (4-8 words) that would find product
> photos of the main clothing item in this photo: garment type, colour, and its
> most distinctive details (e.g. 'navy ribbed collarless button cardigan').
> Include the brand only if a logo or label is clearly visible.

PICK_PROMPT (text block placed before the user's photo):

> Here is a photo of a clothing item I own, followed by product photos found by
> reverse image search. Pick the candidate whose garment looks the most like
> mine: same garment type, colour, neckline or collar, closure (buttons, zip),
> pattern, knit or fabric texture, sleeve and body length. Ignore the model,
> pose, background, lighting, and the listing text; the store does not matter.
> Among candidates that look equally close, prefer a clean e-commerce product
> photo (garment alone, flat or on a mannequin or hanger, plain background, no
> person, no text overlay) because the picture will be cut out and placed on an
> avatar.
> Classify the pick: 'exact' = the same product and colourway as far as you can
> tell; 'similar' = not the same product, but the same kind of garment in a very
> similar colour and style; 'none' = nothing is even similar (different garment
> type or colour). Also list up to 3 other candidates that are also close, best
> first.
> Name the brand and product if a logo, label, or listing title makes it clear,
> otherwise leave brand empty and give a short descriptive product name such as
> 'Navy ribbed cardigan'.
>
> My photo:

PICK_SCHEMA:

```json
{
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
  "required": ["brand","product_name","color","best_index","match_type","confidence","alternatives","reasoning"],
  "additionalProperties": false
}
```

Expected behaviour (measured on the working version): a navy Alex Mill cardigan
→ "Alex Mill Eldridge Cardigan", exact, 0.85, flat-lay photo from ModeSens; a
Polo Ralph Lauren cable V-neck → exact, 0.95, hanger shot; an unbranded patched
denim jacket → similar, 0.45, an eBay trucker-jacket product photo. A lookup
takes 10–25 s and makes 1–3 SerpApi calls plus 1–2 Claude calls.

Error messages to surface in the UI: missing `SERPAPI_KEY` / `ANTHROPIC_API_KEY`
("… is not set on the server. Add it to the environment variables and
restart."), SerpApi errors (quoted), "Photo is N KB; Google Lens uploads must be
under 500 KB.", and network timeouts (45 s per SerpApi call, 90 s per Claude
call).
