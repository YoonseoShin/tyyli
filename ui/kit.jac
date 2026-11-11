"""Design tokens and the shared stylesheet for the A+ "Atelier Soft" look.

DESIGN_SYSTEM.md (v2) documents every token and style here. To restyle the
app, edit the token defaults below or the entries in `ui`; screens only
reference these names. Pre-rendered material images (aura, board gradient,
note glow) live in `ui/materials.jac`.

The onboarding flow has its own look in `theme.jac` and does not use this file.
"""
import from "@jac/mobui" { Platform, StyleSheet }


obj Colors {
    # --- Core palette (DESIGN_SYSTEM.md 2.1) ---
    has background: str = "#F7F3EF",      # every screen's base
        surface: str = "#FFFFFF",         # solid surfaces: sheets, inputs, legacy cards
        primary: str = "#2C1A0E",         # primary text, primary buttons, Stylist button
        primary_light: str = "#3D2B1F",   # summary text, selected states
        accent: str = "#C9A882",          # tan: icons and highlights only, never text (2.2:1)
        accent_dark: str = "#8B6A50",     # decorative fills
        accent_muted: str = "#B08060",    # decorative/disabled only (3.1:1)
        tag_bg: str = "#F0E8DF",
        tag_text: str = "#6A4A30",
        divider: str = "#E8D8C8",         # solid rules on solid surfaces
        shadow: str = "#6E4A30",          # shadow tint (opacity is set per shadow)
        text_primary: str = "#2C1A0E",
        # Darker than v1's #8B6A50 (4.45:1 on cream): passes AA on every surface,
        # including the aura background (worst pixel 4.64:1).
        text_secondary: str = "#806048",
        text_tertiary: str = "#B08060",   # placeholders/disabled only
        cta_text: str = "#F5EFE8",        # text and icons on espresso
        error: str = "#C9534F",           # badges, error dots
        success: str = "#3E6A48",         # "Saved to History"
        success_bg: str = "#DDEBD9",
        danger: str = "#9B4A43",          # destructive buttons (white text 5.3:1)
        # --- Atelier Soft accents (2.2): light, never fills behind text ---
        blush: str = "#F1D6CB",
        sand: str = "#EBDCC6",
        champagne: str = "#FBF6F1",       # image tiles
        board: str = "#F3EBE2",           # outfit board base under its gradient image
        # --- Translucency (2.3) ---
        glass_soft: str = "rgba(255,255,255,0.45)",
        glass: str = "rgba(255,255,255,0.62)",
        glass_strong: str = "rgba(255,255,255,0.80)",
        glass_edge: str = "rgba(255,255,255,0.85)",
        hairline: str = "rgba(201,168,130,0.30)",
        keyword_edge: str = "rgba(201,168,130,0.35)",
        overlay: str = "rgba(44,26,14,0.28)",   # modal scrim
        # --- Legacy aliases ---
        # Screens not yet redesigned still read these names; each points at the
        # closest role above. Move screens onto the names above as they are redone.
        bg: str = "#F7F3EF",              # -> background
        ink: str = "#2C1A0E",             # -> text_primary
        muted: str = "#806048",           # -> text_secondary
        line: str = "#E8D8C8",            # -> divider
        accent_text: str = "#F5EFE8",     # -> cta_text
        soft: str = "#F0E8DF",            # -> tag_bg
        dark: str = "#2C1A0E",            # -> primary
        dark_muted: str = "#806048",      # -> text_secondary
        sage: str = "#DDEBD9",            # -> success_bg
        sage_ink: str = "#3E6A48";        # -> success
}

# 4-pt grid (DESIGN_SYSTEM.md 4.1). `2xl`/`3xl` are spelled xxl/xxxl.
obj Spacing {
    has xs: int = 4, sm: int = 8, md: int = 12, lg: int = 16, xl: int = 20, xxl: int = 24, xxxl: int = 32;
}

# Corner radii (4.2).
obj Radii {
    has thumb: int = 8,      # small photos inside dense rows
        compact: int = 12,   # compact items, closet grid
        field: int = 16,     # non-pill inputs, chat bubbles
        tile: int = 18,      # item thumbnail tiles
        card: int = 20,      # solid cards on screens not yet redesigned
        panel: int = 28,     # glass panels, outfit board, bottom sheets
        button: int = 999,   # pill buttons
        pill: int = 999;     # segmented control, keyword tags
}

# Type sizes (3.2).
obj Fonts {
    has logo: int = 32, display: int = 40, quote: int = 30, h1: int = 28, h2: int = 18, h3: int = 15,
        body_large: int = 15, body: int = 14, label: int = 13, caption: int = 12, micro: int = 11, nav: int = 10;
}


glob:pub C = Colors(),
    S = Spacing(),
    R = Radii(),
    F = Fonts();


# Typefaces (DESIGN_SYSTEM.md 3.1). On iOS/Android each name is a font loaded
# by `ui/fonts.native.jac` before the app renders; every weight is its own font
# because Android ignores `fontWeight` on custom fonts, so these styles set the
# weight through the family. On web the CSS family plus weight is used, with
# system fallbacks.
def _face(native: str, web_family: str, weight: str) -> dict[str, any] {
    return {
        "fontFamily": Platform.select({"web": web_family, "default": native}),
        "fontWeight": Platform.select({"web": weight, "default": "normal"})
    };
}


glob SANS_WEB: str = "'DM Sans', system-ui, -apple-system, sans-serif",
    SERIF_WEB: str = "'Instrument Serif', Georgia, serif";

glob:pub F_SANS = _face("DMSans_400Regular", SANS_WEB, "400"),
    F_SANS_MEDIUM = _face("DMSans_500Medium", SANS_WEB, "500"),
    F_SANS_SEMIBOLD = _face("DMSans_600SemiBold", SANS_WEB, "600"),
    F_SANS_BOLD = _face("DMSans_700Bold", SANS_WEB, "700"),
    F_SERIF = _face("InstrumentSerif_400Regular", SERIF_WEB, "400"),
    F_SERIF_ITALIC = {
        **_face("InstrumentSerif_400Regular_Italic", SERIF_WEB, "400"),
        "fontStyle": Platform.select({"web": "italic", "default": "normal"})
    },
    # Serif family name for screens that set fontFamily inline (Profile).
    SERIF = Platform.select({"web": SERIF_WEB, "default": "InstrumentSerif_400Regular"});


# Shadows (4.3): wide, faint, tinted. Android draws `elevation` through
# translucent fills as a grey haze, so glass carries no elevation.
glob:pub SHADOW_CARD = {
    "shadowColor": "#6E4A30",
    "shadowOffset": {"width": 0, "height": 10},
    "shadowOpacity": 0.08,
    "shadowRadius": 24,
    "elevation": 2
};

glob:pub SHADOW_GLASS = {
    "shadowColor": "#6E4A30",
    "shadowOffset": {"width": 0, "height": 12},
    "shadowOpacity": 0.08,
    "shadowRadius": 28
};

glob:pub SHADOW_COMPACT = {
    "shadowColor": "#6E4A30",
    "shadowOffset": {"width": 0, "height": 4},
    "shadowOpacity": 0.08,
    "shadowRadius": 12
};

glob:pub SHADOW_FLOAT = {
    "shadowColor": "#6E4A30",
    "shadowOffset": {"width": 0, "height": 12},
    "shadowOpacity": 0.16,
    "shadowRadius": 28,
    "elevation": 6
};


# Type scale (3.2): DM Sans + Instrument Serif, for redesigned screens and the
# shared design-system components.
glob T_LOGO = {**F_SERIF, "fontSize": 32, "lineHeight": 36, "color": "#2C1A0E"};
glob T_DISPLAY = {**F_SERIF, "fontSize": 40, "lineHeight": 42, "color": "#2C1A0E"};
glob T_QUOTE = {**F_SERIF_ITALIC, "fontSize": 31, "lineHeight": 35, "letterSpacing": -0.2, "color": "#2C1A0E"};
glob T_H1 = {**F_SANS_SEMIBOLD, "fontSize": 28, "lineHeight": 34, "letterSpacing": -0.6, "color": "#2C1A0E"};
glob T_H2 = {**F_SANS_SEMIBOLD, "fontSize": 18, "lineHeight": 24, "letterSpacing": -0.2, "color": "#2C1A0E"};
glob T_H3 = {**F_SANS_SEMIBOLD, "fontSize": 15, "lineHeight": 20, "letterSpacing": -0.1, "color": "#2C1A0E"};
glob T_BODY_LARGE = {**F_SANS, "fontSize": 15, "lineHeight": 23, "color": "#3D2B1F"};
glob T_BODY = {**F_SANS, "fontSize": 14, "lineHeight": 20, "color": "#2C1A0E"};
glob T_LABEL = {**F_SANS_MEDIUM, "fontSize": 13, "lineHeight": 18, "color": "#2C1A0E"};
glob T_CAPTION = {**F_SANS, "fontSize": 12, "lineHeight": 16, "color": "#806048"};
glob T_EYEBROW = {**F_SANS_SEMIBOLD, "fontSize": 11, "lineHeight": 14, "letterSpacing": 1.4, "textTransform": "uppercase", "color": "#806048"};
glob T_MICRO = {**F_SANS, "fontSize": 11, "lineHeight": 14, "color": "#806048"};
glob T_NAV = {**F_SANS_MEDIUM, "fontSize": 10, "lineHeight": 12, "color": "#806048"};

# Legacy text (platform sans) for the style names screens not yet redesigned
# use; they set weights inline, which custom fonts would not honour.
glob L_H1 = {"fontSize": 28, "fontWeight": "600", "lineHeight": 34, "letterSpacing": -0.5, "color": "#2C1A0E"};
glob L_H2 = {"fontSize": 18, "fontWeight": "600", "lineHeight": 24, "letterSpacing": -0.2, "color": "#2C1A0E"};
glob L_BODY = {"fontSize": 14, "fontWeight": "400", "lineHeight": 20, "color": "#2C1A0E"};
glob L_CAPTION = {"fontSize": 12, "fontWeight": "400", "lineHeight": 16, "color": "#806048"};


glob:pub ui = StyleSheet.create({
    # Layout
    # The shell color shows around the floating tab bar, so it matches screens.
    "app": {"flex": 1, "backgroundColor": C.background},
    "screen": {"flex": 1, "backgroundColor": C.background},
    "page": {"padding": S.lg, "paddingBottom": S.xxxl, "gap": S.lg, "maxWidth": 560, "width": "100%", "alignSelf": "center"},
    # Redesigned screens: 20pt side margins, 16pt between panels.
    "pageSoft": {"paddingHorizontal": S.xl, "paddingTop": S.md, "paddingBottom": S.xxxl, "gap": S.lg, "maxWidth": 560, "width": "100%", "alignSelf": "center"},
    "row": {"flexDirection": "row", "alignItems": "center", "gap": S.sm},
    "rowBetween": {"flexDirection": "row", "alignItems": "center", "justifyContent": "space-between", "gap": S.sm},
    "wrap": {"flexDirection": "row", "flexWrap": "wrap", "gap": S.sm},
    "flex1": {"flex": 1},
    "fill": {"position": "absolute", "top": 0, "left": 0, "right": 0, "bottom": 0},
    # The generated native shell (SafeAreaView) leaves the status-bar and
    # home-indicator strips to the root view's default white. These reach past
    # the app's bounds (views do not clip by default) to paint them; native only.
    "safeAreaBleed": {"position": "absolute", "top": -240, "bottom": -240, "left": 0, "right": 0, "backgroundColor": C.background},
    "auraBleed": {"position": "absolute", "top": -180, "bottom": -220, "left": 0, "right": 0},

    # Type scale (design-system names)
    "textLogo": T_LOGO,
    "textDisplay": T_DISPLAY,
    "textQuote": T_QUOTE,
    "textH1": T_H1,
    "textH2": T_H2,
    "textH3": T_H3,
    "textBodyLarge": T_BODY_LARGE,
    "textBody": T_BODY,
    "textLabel": T_LABEL,
    "textCaption": T_CAPTION,
    "textEyebrow": T_EYEBROW,
    "textMicro": T_MICRO,
    "textNav": T_NAV,

    # Weight helpers for design-system text (the face carries the weight).
    "w400": F_SANS,
    "w500": F_SANS_MEDIUM,
    "w600": F_SANS_SEMIBOLD,
    "w700": F_SANS_BOLD,

    # Text (names the screens not yet redesigned use; platform sans)
    "title": L_H1,
    "logo": T_LOGO,
    "heading": L_H2,
    "body": L_BODY,
    "bodyBold": {"fontSize": F.body, "fontWeight": "600", "lineHeight": 20, "color": C.text_primary},
    "muted": {"fontSize": F.label, "lineHeight": 18, "color": C.text_secondary},
    "small": L_CAPTION,
    "label": {"fontSize": F.micro, "fontWeight": "600", "letterSpacing": 1, "lineHeight": 14, "color": C.text_secondary},
    "link": {"fontSize": F.label, "fontWeight": "600", "color": C.text_secondary},
    "serifNumber": {**F_SERIF, "color": C.text_primary},

    # Surfaces
    # Solid card for screens not yet redesigned: white, soft wide shadow.
    "card": {**SHADOW_CARD, "padding": S.xl, "gap": S.sm, "borderRadius": R.card, "backgroundColor": C.surface},
    "cardDark": {"padding": S.xl, "gap": S.sm, "borderRadius": R.card, "backgroundColor": C.primary},
    "cardCompact": {**SHADOW_COMPACT, "elevation": 1, "padding": S.md, "gap": S.sm, "borderRadius": R.compact, "backgroundColor": C.surface},
    "shadowCard": SHADOW_CARD,
    "divider": {"height": 1, "backgroundColor": C.divider},
    "hairline": {"height": 1, "backgroundColor": C.hairline},

    # Materials (DESIGN_SYSTEM.md 5)
    "glass": {**SHADOW_GLASS, "backgroundColor": C.glass, "borderWidth": 1, "borderColor": C.glass_edge, "borderRadius": R.panel},
    "glassPanel": {**SHADOW_GLASS, "backgroundColor": C.glass, "borderWidth": 1, "borderColor": C.glass_edge, "borderRadius": R.panel, "padding": 22, "gap": S.md},
    "glassCircle": {**SHADOW_COMPACT, "width": 44, "height": 44, "borderRadius": 22, "alignItems": "center", "justifyContent": "center", "backgroundColor": C.glass_strong, "borderWidth": 1, "borderColor": C.glass_edge},
    "glassChip": {"height": 36, "paddingHorizontal": 14, "borderRadius": 18, "flexDirection": "row", "alignItems": "center", "gap": 6, "backgroundColor": C.glass_strong, "borderWidth": 1, "borderColor": C.glass_edge},
    "glassChipSmall": {"height": 32, "paddingHorizontal": 12, "borderRadius": 16, "flexDirection": "row", "alignItems": "center", "gap": 6, "backgroundColor": C.glass_strong, "borderWidth": 1, "borderColor": C.glass_edge},
    "tile": {"borderRadius": R.tile, "backgroundColor": C.champagne, "borderWidth": 1, "borderColor": C.glass_edge, "alignItems": "center", "justifyContent": "center", "overflow": "hidden"},
    "sheet": {**SHADOW_FLOAT, "paddingTop": S.sm, "paddingHorizontal": S.xl, "paddingBottom": S.xxxl, "gap": S.md, "borderTopLeftRadius": R.panel, "borderTopRightRadius": R.panel, "backgroundColor": C.champagne},
    "sheetHandle": {"alignSelf": "center", "width": 40, "height": 5, "borderRadius": 3, "backgroundColor": C.divider},

    # Buttons (DESIGN_SYSTEM.md 6): pills.
    "button": {**SHADOW_FLOAT, "paddingVertical": 14, "paddingHorizontal": S.xl, "minHeight": 52, "borderRadius": R.button, "backgroundColor": C.primary, "alignItems": "center", "justifyContent": "center"},
    "buttonText": {**F_SANS_SEMIBOLD, "fontSize": 14, "lineHeight": 18, "color": C.cta_text},
    # Secondary ("ghost"): strong glass with a white edge.
    "buttonGhost": {**SHADOW_COMPACT, "elevation": 0, "backgroundColor": C.glass_strong, "borderWidth": 1, "borderColor": C.glass_edge},
    "buttonGhostText": {**F_SANS_MEDIUM, "color": C.primary},
    "buttonDanger": {"backgroundColor": C.danger},
    "iconButton": {**SHADOW_COMPACT, "elevation": 1, "width": 44, "height": 44, "borderRadius": 22, "alignItems": "center", "justifyContent": "center", "backgroundColor": C.surface},

    # Inputs
    "input": {"flex": 1, "borderWidth": 1, "borderColor": C.divider, "borderRadius": R.pill, "paddingVertical": S.md, "paddingHorizontal": S.lg, "fontSize": F.body, "color": C.text_primary, "backgroundColor": C.surface},

    # Tags and chips
    "chip": {"paddingVertical": S.xs, "paddingHorizontal": 10, "borderRadius": R.pill, "backgroundColor": C.tag_bg},
    "chipText": {"fontSize": F.label, "fontWeight": "500", "color": C.tag_text},
    "chipOn": {"backgroundColor": C.primary_light},
    "chipTextOn": {"color": C.cta_text, "fontWeight": "600"},
    "chipOutline": {"paddingVertical": 7, "paddingHorizontal": 14, "borderRadius": R.pill, "backgroundColor": C.surface, "borderWidth": 1, "borderColor": C.divider},
    "chipSage": {"paddingVertical": S.xs, "paddingHorizontal": 10, "borderRadius": R.pill, "backgroundColor": C.success_bg},
    "chipSageText": {"fontSize": F.label, "color": C.success},
    # Keyword tag (glass): the only tags on redesigned screens.
    "keyword": {"paddingVertical": 6, "paddingHorizontal": S.md, "borderRadius": 14, "backgroundColor": C.glass_strong, "borderWidth": 1, "borderColor": C.keyword_edge},
    "keywordText": {**F_SANS_MEDIUM, "fontSize": F.caption, "lineHeight": 16, "color": C.tag_text},
    "segment": {"flexDirection": "row", "padding": 3, "borderRadius": R.pill, "backgroundColor": C.tag_bg},
    "segmentItem": {"flex": 1, "paddingVertical": S.sm, "borderRadius": R.pill, "alignItems": "center"},
    "segmentItemOn": {"backgroundColor": C.surface},

    # Segmented look selector (TabSelector)
    "segTrack": {"flexDirection": "row", "minHeight": 46, "padding": S.xs, "borderRadius": R.pill, "backgroundColor": C.glass_soft, "borderWidth": 1, "borderColor": C.glass_edge},
    "segItem": {"minHeight": 36, "paddingHorizontal": 14, "borderRadius": R.pill, "flexDirection": "row", "alignItems": "center", "justifyContent": "center", "gap": 6},
    "segItemOn": {**SHADOW_COMPACT, "backgroundColor": C.surface},
    "segText": {**F_SANS_MEDIUM, "fontSize": F.label, "color": C.text_secondary},
    "segTextOn": {**F_SANS_SEMIBOLD, "color": C.text_primary},
    "segCount": {"minWidth": 18, "height": 18, "paddingHorizontal": 5, "borderRadius": 9, "alignItems": "center", "justifyContent": "center", "backgroundColor": C.tag_bg},
    "segCountOn": {"backgroundColor": C.accent},
    "segCountText": {**F_SANS_BOLD, "fontSize": F.nav, "color": C.tag_text},
    "segCountTextOn": {"color": C.primary},

    # Images
    "thumb": {"width": 72, "height": 72, "borderRadius": R.compact, "backgroundColor": C.tag_bg},
    "thumbLarge": {"width": "100%", "height": 320, "borderRadius": R.panel, "backgroundColor": C.surface},
    "gridItem": {"width": "48%", "gap": S.xs},
    "gridImage": {"width": "100%", "height": 160, "borderRadius": R.compact, "backgroundColor": C.tag_bg},

    # Outfit board (Outfit Picks)
    "boardFrame": {**SHADOW_GLASS, "borderRadius": R.panel, "backgroundColor": C.board},
    "boardClip": {"borderRadius": R.panel, "overflow": "hidden", "borderWidth": 1, "borderColor": C.glass_edge},
    "boardMarker": {"position": "absolute", "left": 2, "top": 2, "width": 22, "height": 22, "borderRadius": 11, "alignItems": "center", "justifyContent": "center", "backgroundColor": C.glass_strong, "borderWidth": 1, "borderColor": C.glass_edge},
    "boardMarkerText": {**F_SANS_BOLD, "fontSize": F.nav, "color": C.text_primary},
    # A closet photo on the board, drawn at its own proportions as a soft print.
    "photoFrame": {**SHADOW_COMPACT, "elevation": 2, "position": "absolute", "borderRadius": 14, "padding": 3, "backgroundColor": C.surface},
    "photoInner": {"flex": 1, "borderRadius": 11, "overflow": "hidden", "backgroundColor": C.champagne},
    # Missing photo: an honest empty state, never a stand-in garment.
    "photoMissing": {"flex": 1, "borderRadius": 14, "alignItems": "center", "justifyContent": "center", "gap": S.xs, "padding": S.xs, "backgroundColor": C.glass_strong, "borderWidth": 1, "borderColor": C.keyword_edge, "borderStyle": "dashed"},

    # Floating tab bar capsule (DESIGN_SYSTEM.md 6). It sits in the layout under
    # the screens (not over them), so no screen needs extra bottom padding; the
    # scaffold's SafeAreaView already keeps it above the home indicator.
    # Transparent so the screen's own background (the aura on Outfit Picks) runs
    # under the capsule.
    "tabBarWrap": {"width": "100%", "paddingHorizontal": 14, "paddingTop": 6, "paddingBottom": 10, "backgroundColor": "transparent"},
    "tabBar": {**SHADOW_FLOAT, "flexDirection": "row", "alignItems": "center", "height": 68, "paddingHorizontal": S.sm, "borderRadius": 34, "backgroundColor": C.glass_strong, "borderWidth": 1, "borderColor": C.glass_edge, "maxWidth": 520, "width": "100%", "alignSelf": "center"},
    "tabItem": {"flex": 1, "minHeight": 52, "alignItems": "center", "justifyContent": "center", "gap": 3},
    "tabText": T_NAV,
    "tabTextOn": {**F_SANS_SEMIBOLD, "color": C.text_primary},
    "tabCenter": {**SHADOW_FLOAT, "width": 50, "height": 50, "borderRadius": 25, "backgroundColor": C.primary, "alignItems": "center", "justifyContent": "center"},
    # The Stylist screen is open: a tan ring marks the center button as active.
    "tabCenterOn": {"borderWidth": 2, "borderColor": C.accent},
    "tabMonogram": {**F_SERIF_ITALIC, "fontSize": 30, "lineHeight": 34, "color": C.cta_text, "marginTop": -2},

    # Chat
    "bubbleUser": {"alignSelf": "flex-end", "maxWidth": "80%", "padding": S.md, "borderRadius": R.field, "backgroundColor": C.primary},
    "bubbleBot": {**SHADOW_COMPACT, "elevation": 1, "alignSelf": "flex-start", "maxWidth": "80%", "padding": S.md, "borderRadius": R.field, "backgroundColor": C.surface},
    "bubbleUserText": {"fontSize": F.body, "lineHeight": 20, "color": C.cta_text}
});
