# TYYLI Design System — v2 "Atelier Soft"

> Version 2.0 · November 2026 · supersedes v1.0 (the classic-editorial direction)
> Platform: Jac mobile app (`kind = "mobile"`) → React Native / Expo SDK 58, iOS first, Android parity, web via react-native-web.
> Source of truth in code: [`ui/kit.jac`](ui/kit.jac) (tokens + shared stylesheet) and [`ui/materials.jac`](ui/materials.jac) (pre-rendered material images).

Status labels used below:

- **[LIVE]** implemented in the app.
- **[PLANNED]** decided, not implemented yet; the note says what stands in for it today.

---

## 1. Direction

TYYLI is a personal stylist. The interface should feel **light, polished and softly layered**: a modern atelier, not a heritage fashion magazine and not a generic e-commerce template.

Principles:

1. **Materials, not boxes.** Depth comes from translucent white surfaces over a warm, softly blurred background, a fine white edge, and wide, faint shadows. No heavy card shadows, no hard outlines.
2. **Sans-led type with a serif voice.** DM Sans carries the interface. Instrument Serif appears only where the stylist "speaks": the stylist's line, the style-score numeral, the logo and the Stylist monogram.
3. **Warm neutrals, one temperature.** Cream, white, espresso and tan, with blush, sand and champagne used only as soft light, never as fills behind text.
4. **Image first.** Clothing photos sit on one consistent champagne board so every closet photo reads like a product shot.
5. **Few, clear moments per screen.** One headline, one primary action. Secondary detail is available on request (disclosures, sheets).
6. **The stylist's voice, not the machine's.** UI copy never labels things "AI" ("AI pick", "AI style score"). Say "Original", "Style score", "Stylist's note".

Avoid: pill chips for everything, stacked identical cards, pastel icon tiles, sparkle icons, gradients as decoration, heavy frosting, dark luxury styling, all-caps labels on every section.

---

## 2. Color

### 2.1 Core palette [LIVE]

| Token (`C.`) | Value | Use |
|---|---|---|
| `background` | `#F7F3EF` | Every screen's base |
| `surface` | `#FFFFFF` | Solid surfaces: sheets, inputs, legacy cards |
| `primary` | `#2C1A0E` | Primary text, primary buttons, Stylist button |
| `primary_light` | `#3D2B1F` | Summary text, selected states |
| `accent` | `#C9A882` | Tan: icons, small highlights, keyword edges. **Never text** (2.2:1 on white) |
| `accent_dark` | `#8B6A50` | Decorative fills only |
| `text_primary` | `#2C1A0E` | Headings, body |
| `text_secondary` | `#806048` | Captions, meta, inactive tabs. Darker than v1's `#8B6A50`, which failed AA on cream |
| `text_tertiary` / `accent_muted` | `#B08060` | Decorative/disabled only (3.1:1) |
| `tag_bg` / `tag_text` | `#F0E8DF` / `#6A4A30` | Neutral tags |
| `divider` | `#E8D8C8` | Solid rules on solid surfaces |
| `cta_text` | `#F5EFE8` | Text and icons on espresso |
| `error` | `#C9534F` | Badges and error dots only |
| `danger` | `#9B4A43` | Destructive buttons (white text 5.3:1) |
| `success` / `success_bg` | `#3E6A48` / `#DDEBD9` | Confirmations ("Saved to History") |

### 2.2 Atelier Soft accents [LIVE]

| Token | Value | Use |
|---|---|---|
| `blush` | `#F1D6CB` | Background light only (aura, note glow) |
| `sand` | `#EBDCC6` | Background light only (aura) |
| `champagne` | `#FBF6F1` | Image tiles, outfit board highlight |
| `board` | `#F3EBE2` | Outfit board base (under the gradient image) |

Blush and sand are never solid fills behind text. They only appear blended into the background at ≤ 50% strength (see 2.4).

### 2.3 Translucency [LIVE]

| Token | Value | Use |
|---|---|---|
| `glass_soft` | `rgba(255,255,255,0.45)` | Segmented-control tracks, quiet panels |
| `glass` | `rgba(255,255,255,0.62)` | Standard panel (Stylist's note, In this look, details) |
| `glass_strong` | `rgba(255,255,255,0.80)` | Floating layers, glass buttons, markers, tab bar |
| `glass_edge` | `rgba(255,255,255,0.85)` | 1px edge on every glass surface |
| `hairline` | `rgba(201,168,130,0.30)` | Separators inside glass panels |
| `keyword_edge` | `rgba(201,168,130,0.35)` | Keyword tag edge |
| `overlay` | `rgba(44,26,14,0.28)` | Modal scrim |
| `shadow` | `#6E4A30` | Shadow color (opacity set per shadow) |

### 2.4 Contrast (WCAG AA, measured)

| Pair | Ratio |
|---|---|
| `text_secondary` on `background` / `surface` / `tag_bg` | 5.2 / 5.7 / 4.7 |
| `text_secondary` on the aura background, worst pixel | 4.64 (generator refuses anything under 4.5) |
| `text_secondary` on `glass` over the strongest aura | ≥ 5.1 |
| `tag_text` on a keyword tag | 7.4 |
| `cta_text` on `primary` | 14.6 |
| `success` on `surface` | ≥ 4.5 |

Rule: text sits only on `glass` (≥ 0.6 white) or stronger, or on solid surfaces. Check contrast against the darkest point that can appear behind a translucent surface.

### 2.5 Dark mode [PLANNED]
Not in scope. If added: background `#1A1008`, panels `rgba(255,255,255,0.06)` with `rgba(255,255,255,0.12)` edges, text `#F3EBE1`; the aura becomes a deep blush/umber glow.

---

## 3. Typography

### 3.1 Families

| Role | Family | Status |
|---|---|---|
| Interface (titles, body, buttons, labels) | **DM Sans** 400 / 500 / 600 / 700 | [LIVE] on redesigned screens and shared design-system components |
| Editorial accents | **Instrument Serif** regular + italic | [LIVE] everywhere the serif is used |

How it works:

- `ui/fonts.native.jac` loads the six faces with `expo-font` from `@expo-google-fonts/dm-sans` and `@expo-google-fonts/instrument-serif` (bundled, no network). `main.jac` waits for them, at most 3 s, then renders; if loading fails, text falls back to the platform fonts.
- Every weight is its own font name (`DMSans_600SemiBold`, …) because Android ignores `fontWeight` on custom fonts. Set weight through the face: `ui.w400` / `w500` / `w600` / `w700`, or the `F_SANS*` dicts in `ui/kit.jac`. Never add an inline `fontWeight` to design-system text.
- Screens not yet redesigned use the legacy style names (`title`, `heading`, `body`, `small`, `bodyBold`, `muted`, `label`, `link`), which stay on the platform sans because those screens set weights inline. Move each screen to the `text*` styles when it is redesigned.
- Web (`ui/fonts.jac`) loads nothing; the CSS families fall back to system fonts.
- Packages are pinned in `jac.toml` and in `scripts/ensure_expo_sdk_58.jac`, which `dev_mobile.sh` runs, so they install automatically.

### 3.2 Scale [LIVE] (`ui.*` style names)

| Style | Family | Size / line | Weight | Use |
|---|---|---|---|---|
| `textLogo` | Serif | 32 / 36 | 400 | "tyyli" wordmark |
| `textDisplay` | Serif | 40 / 40 | 400 | Style-score numeral |
| `textQuote` | Serif *italic* | 30 / 35, −0.3 | 400 | The stylist's line (one per screen) |
| `textH1` | Sans | 28 / 34, −0.5 | 600 | Screen titles |
| `textH2` | Sans | 18 / 24, −0.2 | 600 | Panel titles ("In this look") |
| `textH3` | Sans | 15 / 20 | 600 | Item names, row titles |
| `textBodyLarge` | Sans | 15 / 23 | 400 | Stylist's summary |
| `textBody` | Sans | 14 / 20 | 400 | Body |
| `textLabel` | Sans | 13 / 18 | 500 | Buttons in tight rows, tabs |
| `textCaption` | Sans | 12 / 16 | 400 | Meta, captions (`text_secondary`) |
| `textEyebrow` | Sans | 11 / 14, +1.4, UPPERCASE | 600 | The look's name only |
| `textMicro` | Sans | 11 / 14 | 400 | Fine print |
| `textNav` | Sans | 10 / 12 | 500 | Tab bar labels |

Rules:

- Serif appears at most twice per screen (stylist's line + score), never for body or controls.
- Uppercase is reserved for the eyebrow. Everything else is sentence case, including buttons ("Wearing today").
- Letter-spacing only as listed; never track sans body text.

---

## 4. Spacing, layout and shape

### 4.1 Spacing (`S.`) [LIVE]
4-pt grid: `xs 4 · sm 8 · md 12 · lg 16 · xl 20 · xxl 24 · xxxl 32`.

- Screen side margin: **20** on redesigned screens (`ui.pageSoft`); legacy screens keep 16 until redesigned.
- Gap between panels: **16**. Inside panels: **20–22** padding.
- Content max width 560, centered (tablets, web).

### 4.2 Corner radii (`R.`) [LIVE]

| Token | Value | Use |
|---|---|---|
| `thumb` | 8 | Small photos inside dense rows |
| `compact` | 12 | Compact items, closet grid |
| `field` | 16 | Inputs (non-pill), bubbles |
| `tile` | 18 | Item thumbnails tiles |
| `card` | 24 | Solid cards (legacy screens) |
| `panel` | 28 | Glass panels, outfit board, bottom sheets |
| `button` / `pill` | 999 | Buttons, segmented control, keyword tags |
| circle | size / 2 | Icon buttons, markers, Stylist button |

### 4.3 Shadows [LIVE]
Shadows are wide and faint, tinted with `shadow` (#6E4A30), never black.

| Name | Offset / blur / opacity | Use |
|---|---|---|
| `SHADOW_CARD` | 0,10 / 24 / 0.08 (Android elevation 2) | Solid cards |
| `SHADOW_GLASS` | 0,12 / 28 / 0.08 (no Android elevation) | Glass panels, outfit board |
| `SHADOW_COMPACT` | 0,4 / 12 / 0.08 (elevation 1) | Glass buttons, thumbnails |
| `SHADOW_FLOAT` | 0,12 / 28 / 0.16 (elevation 6) | Tab bar capsule, primary button |

Android draws `elevation` through translucent backgrounds as a grey haze, so glass surfaces carry **no elevation**: on Android they rely on their edge and the aura.

---

## 5. Materials

| Material | Recipe | Status |
|---|---|---|
| **Aura background** | `AURA_BG`: a 90×196 pre-blurred PNG (cream with blush/sand light at the corners) stretched behind the screen by `AuraBackground` | [LIVE] Outfit Picks |
| **Glass panel** | `glass` fill + 1px `glass_edge` + `SHADOW_GLASS`, radius 28 | [LIVE] |
| **Glass control** | `glass_strong` fill + edge + `SHADOW_COMPACT`; circles 44, chips 36 high | [LIVE] |
| **Outfit board** | `board` base + `BOARD_BG` gradient image (champagne → sand with a soft top light), radius 28, edge, `SHADOW_GLASS` | [LIVE] |
| **Board photo** | Each closet photo drawn at its own proportions inside its slot as a soft print: 3 pt white mat, radius 14, `SHADOW_COMPACT` (`ui.photoFrame`) | [LIVE] |
| **Missing photo** | Dashed `glass_strong` tile with an image-off icon and "Photo unavailable" (`ui.photoMissing`). Never a stand-in garment | [LIVE] |
| **Safe-area fill** | The generated native shell leaves the status-bar and home-indicator strips white; `AppShell` paints them `background` (and the aura runs into them on Outfit Picks) with views that reach past its bounds | [LIVE] iOS/Android |
| **Note glow** | `NOTE_GLOW`: a blush radial PNG in the Stylist's note corner, behind content | [LIVE] |
| **Floating layer** | `glass_strong` + edge + `SHADOW_FLOAT` (tab bar capsule) | [LIVE] |
| **Real background blur** | `expo-blur` on floating layers only | [PLANNED, optional] Not installed. Revisit if translucency alone reads flat on device |

Why images: the app has no gradient or blur package, and adding one isn't justified for a few soft gradients. The PNGs are tiny (1–3 KB), embedded as data URIs in `ui/materials.jac` (the same pattern as `assets_body_shapes.jac`), and regenerated by a script that enforces the contrast floor.

---

## 6. Components

All live in `components/` and read only `ui/kit.jac` tokens.

| Component | Spec | Status |
|---|---|---|
| `Button` | Pill, min height 52. `primary`: espresso, cream text, `SHADOW_FLOAT`. `secondary` (alias `ghost`): `glass_strong`, edge, espresso text. `danger`: `#9B4A43`. Optional leading `icon` and `icon_color`; busy spinner; pressed 0.75 opacity, disabled 0.45 | [LIVE] |
| `TabSelector` | Segmented control: `glass_soft` track (46 high, pill), white selected thumb with a soft shadow; equal widths when they fit, scrolling chips otherwise; optional count badges | [LIVE] |
| `TabBar` | Floating glass capsule (68 high, inset 14 from the sides, transparent surround) above the safe area; Home · Closet · **t** (Stylist) · History · Profile; active = espresso icon + 600 label, inactive = `text_secondary`; Stylist button = 50 espresso circle with the serif-italic "t", tan ring when active | [LIVE] |
| `ScreenHeader` | Row of glass back button (44) and optional trailing items (e.g. a weather chip); then `textH1` title and optional caption | [LIVE] |
| `Tag` | Variants `light`, `dark`, `outline`, `success`, `glass` (keyword: `glass_strong`, `keyword_edge`, 12/500 `tag_text`) | [LIVE] |
| `ClosetThumb` | Square champagne tile (radius 18) with the closet photo cropped to fill; selected = espresso edge + check; optional corner badge (e.g. "Original"); missing-photo state | [LIVE] |
| `AuraBackground` | Absolutely positioned aura image behind a screen; not focusable | [LIVE] |
| `StylistNote` | See 8.2 | [LIVE] |
| `LookItemRow` | See 8.2 | [LIVE] |
| `OutfitInsights` | Numbered detail rows (no icon tiles); optional collapsible header | [LIVE] |
| `OutfitCollage` | Sticker-board layout; optional numbered glass markers that match "In this look" | [LIVE] |

Icon style: one outline family (MaterialCommunityIcons outline glyphs), 20–22 px in navigation, 16–18 px inline, colors from tokens. No sparkle icons; the Stylist is represented by the "t" monogram.

---

## 7. Motion

| Interaction | Behaviour |
|---|---|
| Press | Opacity to 0.75 (buttons, rows); no color flashes |
| Look tabs | Selected thumb moves instantly; content swaps in place. [PLANNED] 150 ms cross-fade |
| Details disclosure | Expands in place; chevron flips. [PLANNED] 200 ms height/opacity ease-out |
| Swap sheet | Native slide-up (`Modal animationType="slide"`) |
| Screen changes | Instant (state-driven navigation) |

Motion must respect "Reduce Motion" once animations are added (`AccessibilityInfo.isReduceMotionEnabled`).

---

## 8. Screens

### 8.1 Global
- The native scaffold (`.jac/mobile-rn/app/App.tsx`, generated) wraps the app in `SafeAreaView`, so content never sits under the notch or home indicator. The tab bar adds only 10 px under the capsule.
- The keyboard hides the tab bar (existing `AppShell` behaviour).

### 8.2 Outfit Picks [LIVE]

Order:

1. **Header**: glass back button, weather chip (temperature + condition), "Outfit Picks" (`textH1`), today's date.
2. **Look tabs**: `TabSelector`, one tab per pick (the plan it's for, e.g. "All day", or the event title).
3. **Outfit board**: the look on the champagne board, each closet photo as a soft print; tapping a piece opens the swap sheet. Numbered glass markers (1, 2, 3…) sit on each photo's corner and match "In this look". A caption under the board says "Tap a piece on the board to swap it" (never over a photo).
4. **Stylist's note** (glass panel with blush glow):
   - "t" monogram + "Stylist's note"; style score at top right (`textDisplay` numeral + "/100" + "Style score").
   - Eyebrow: the look's name.
   - The stylist's line (`textQuote`, headline ≤ 8 words).
   - Summary (`textBodyLarge`, ≤ 32 words, 1–2 sentences).
   - 2–3 keyword tags.
   - After any swap: a notice that the note and score describe the original pick, with **Reset**.
5. **Actions**: secondary "Regenerate" + primary "Wearing today" (becomes "Saved to History" with a green check once logged).
6. **In this look** (glass panel): "N pieces"; one `LookItemRow` per piece: number (matching the board), 58 px champagne tile with the closet photo, name, "Category · Color" from the wardrobe, "Swapped" tag when changed, and a 44 px swap control. The row opens the swap sheet on that piece's category.
7. **The details** (glass panel, **collapsed by default**): Palette, Mood, Weather, Your day, For you; numbered rows, ≤ 18 words each.

Images: every picture of a garment is the user's closet photo, via `garment_photo_uri` in `components/OutfitCollage.jac`: the user's own photo (`original_image_path`) when "Find online" swapped in a shop photo, otherwise the stored photo (`image_path`, the optimized copy of the upload). The board, "In this look" and the swap sheet all use it, so they always match. Pieces of a saved pick that were since deleted from the closet are not drawn; the panel says how many are missing.

Fallbacks for looks saved before the concise fields existed: the eyebrow is hidden and the look's name becomes the stylist's line; the summary uses the first available existing reason; keywords are hidden. Nothing is invented on the device.

### 8.3 Other screens
Home, Closet, History, Profile, Chat and Calendar keep their current layouts. They pick up the global tokens (palette, sans titles, softer cards, pill buttons, floating tab bar) and will be redesigned individually after Outfit Picks is reviewed. Onboarding keeps its own theme (`theme.jac`).

---

## 9. AI styling copy

Generated by `outfit_ai.recommend_outfits`, stored on `Outfit`, rendered by `StylistNote` and `OutfitInsights`.

| Field | Limit | Notes |
|---|---|---|
| `style_name` | 2–3 words | The look's name (eyebrow) |
| `headline` | ≤ 8 words | The stylist's line. No trailing period required; no exclamation marks |
| `summary` | ≤ 32 words, 1–2 sentences | Names key pieces and the main reason (plans, weather) |
| `keywords` | 2–3 items, 1–3 words each | Derived only from supplied colors, style tags, and weather; trimmed to 3 in code |
| `color`, `mood`, `weather`, `plans`, `personal` | ≤ 18 words each | Shown in "The details" |
| `confidence` | 0–100 | The style score |

Voice: specific, confident, warm; names actual pieces; no filler ("This outfit is perfect for…"), no exclamation marks, never mentions AI. Use only supplied facts: never invent materials, fit, plans or features.

Compatibility: all new fields default to empty; older saved picks load unchanged and use the fallbacks in 8.2. Swapping pieces never rewrites the note; the UI says the note describes the original pick.

---

## 10. Accessibility

| Requirement | Implementation |
|---|---|
| Touch targets | ≥ 44×44 (icon buttons 44, rows ≥ 58, `hitSlop` on compact tabs) |
| Contrast | AA for all text (see 2.4); translucent surfaces measured against the darkest background point |
| Screen readers | `accessibilityLabel` on icon-only controls ("Back", "Stylist chat", "Swap Camel blazer"); roles `button`/`tab`/`header`; selected/expanded state exposed |
| Decorative images | Aura, board gradient, glow and markers are hidden from assistive tech |
| Reduce Transparency | [PLANNED] iOS `AccessibilityInfo.isReduceTransparencyEnabled` → swap `glass*` for `surface` |
| Reduce Motion | Respect once animations are added |
| Font scaling | System text scaling stays enabled; layouts wrap rather than truncate primary copy |

---

## 11. Implementation notes (Jac)

- Tokens are typed `obj`s (`Colors`, `Spacing`, `Radii`, `Fonts`) in `ui/kit.jac`; `jac check` flags any unknown token. Style names live in the single `ui` stylesheet; a missing style name is **not** caught by the compiler, so keep legacy names until no screen uses them.
- Style keys must not collide with component `has` state names (the generated JavaScript breaks).
- In client code, a dict literal with a variable key (`{item_id: value}`) compiles to the literal key `"item_id"`. Copy the dict and assign with a subscript instead (see `OutfitCollage`).
- Material images are regenerated by the script recorded in `ui/materials.jac`'s docstring; never hand-edit the base64.
- Checks before shipping UI work: `jac check`, `jac run --no-takeover scripts/compile_mobile.jac`, `scripts/check_mobile_js.sh`.
