"""Design tokens and the shared stylesheet, matched to the Figma prototype.

To restyle the app, edit the token defaults below or the entries in `ui`;
screens only reference these names.
"""
import from "@jac/mobui" { Platform, StyleSheet }


obj Colors {
    has bg: str = "#F4EBE1",
        surface: str = "#FFFDF9",
        ink: str = "#22170F",
        muted: str = "#8C7D70",
        line: str = "#E9DFD3",
        accent: str = "#8B6B55",
        accent_text: str = "#FFFFFF",
        soft: str = "#EFE6DA",
        dark: str = "#1F140E",
        dark_muted: str = "#8E8279",
        sage: str = "#DDEBD9",
        sage_ink: str = "#3E6A48",
        board: str = "#ECEAE6",
        danger: str = "#9B4A43";
}

obj Spacing {
    has xs: int = 4, sm: int = 8, md: int = 12, lg: int = 16, xl: int = 24;
}

obj Radii {
    has sm: int = 10, md: int = 14, lg: int = 20, pill: int = 999;
}

obj Fonts {
    has xs: int = 11, sm: int = 13, md: int = 15, lg: int = 18, xl: int = 26, hero: int = 44;
}


glob:pub C = Colors(),
    S = Spacing(),
    R = Radii(),
    F = Fonts(),
    # Serif for the logo and big numbers (temperature, style score).
    SERIF = Platform.select({"ios": "Georgia", "android": "serif", "default": "Georgia, serif"});


glob:pub ui = StyleSheet.create({
    # Layout
    # The dark shell also colors the phone's bottom safe area behind the tab bar.
    "app": {"flex": 1, "backgroundColor": C.dark},
    "screen": {"flex": 1, "backgroundColor": C.bg},
    "page": {"padding": S.lg, "paddingBottom": 32, "gap": S.lg, "maxWidth": 560, "width": "100%", "alignSelf": "center"},
    "row": {"flexDirection": "row", "alignItems": "center", "gap": S.sm},
    "rowBetween": {"flexDirection": "row", "alignItems": "center", "justifyContent": "space-between", "gap": S.sm},
    "wrap": {"flexDirection": "row", "flexWrap": "wrap", "gap": S.sm},
    "flex1": {"flex": 1},

    # Text
    "title": {"fontSize": F.xl, "fontWeight": "bold", "color": C.ink},
    "logo": {"fontSize": 30, "color": C.ink, "fontFamily": SERIF},
    "heading": {"fontSize": F.lg, "fontWeight": "bold", "color": C.ink},
    "body": {"fontSize": F.md, "lineHeight": 21, "color": C.ink},
    "bodyBold": {"fontSize": F.md, "fontWeight": "bold", "color": C.ink},
    "muted": {"fontSize": F.sm, "lineHeight": 19, "color": C.muted},
    "small": {"fontSize": F.xs, "color": C.muted},
    "label": {"fontSize": F.xs, "fontWeight": "bold", "letterSpacing": 1.2, "color": C.muted},
    "link": {"fontSize": F.sm, "fontWeight": "bold", "color": C.accent},
    "serifNumber": {"fontFamily": SERIF, "color": C.ink},

    # Surfaces
    "card": {"padding": S.lg, "gap": S.sm, "borderRadius": R.lg, "backgroundColor": C.surface},
    "cardDark": {"padding": S.lg, "gap": S.sm, "borderRadius": R.lg, "backgroundColor": C.dark},
    "divider": {"height": 1, "backgroundColor": C.line},

    # Controls
    "button": {"paddingVertical": 14, "paddingHorizontal": S.lg, "borderRadius": R.pill, "backgroundColor": C.dark, "alignItems": "center", "justifyContent": "center"},
    "buttonText": {"fontSize": F.md, "fontWeight": "bold", "color": C.accent_text},
    "buttonGhost": {"backgroundColor": C.surface, "borderWidth": 1, "borderColor": C.ink},
    "buttonGhostText": {"color": C.ink},
    "buttonDanger": {"backgroundColor": C.danger},
    "iconButton": {"width": 40, "height": 40, "borderRadius": R.pill, "alignItems": "center", "justifyContent": "center", "backgroundColor": C.surface},
    "input": {"flex": 1, "borderWidth": 1, "borderColor": C.line, "borderRadius": R.pill, "paddingVertical": S.md, "paddingHorizontal": S.lg, "fontSize": F.md, "color": C.ink, "backgroundColor": C.surface},
    "chip": {"paddingVertical": 6, "paddingHorizontal": 12, "borderRadius": R.pill, "backgroundColor": C.soft},
    "chipText": {"fontSize": F.sm, "color": C.ink},
    "chipOn": {"backgroundColor": C.dark},
    "chipTextOn": {"color": C.accent_text, "fontWeight": "bold"},
    "chipOutline": {"paddingVertical": 7, "paddingHorizontal": 14, "borderRadius": R.pill, "backgroundColor": C.surface, "borderWidth": 1, "borderColor": C.line},
    "chipSage": {"paddingVertical": 6, "paddingHorizontal": 12, "borderRadius": R.pill, "backgroundColor": C.sage},
    "chipSageText": {"fontSize": F.sm, "color": C.sage_ink},
    "segment": {"flexDirection": "row", "padding": 3, "borderRadius": R.pill, "backgroundColor": C.soft},
    "segmentItem": {"flex": 1, "paddingVertical": S.sm, "borderRadius": R.pill, "alignItems": "center"},
    "segmentItemOn": {"backgroundColor": C.surface},

    # Images
    "thumb": {"width": 72, "height": 72, "borderRadius": R.sm, "backgroundColor": C.soft},
    "thumbLarge": {"width": "100%", "height": 320, "borderRadius": R.lg, "backgroundColor": C.surface},
    "gridItem": {"width": "48%", "gap": S.xs},
    "gridImage": {"width": "100%", "height": 160, "borderRadius": R.md, "backgroundColor": C.soft},

    # Tab bar
    "tabBar": {"flexDirection": "row", "alignItems": "flex-end", "backgroundColor": C.dark, "paddingTop": 10, "paddingBottom": 24, "paddingHorizontal": S.sm, "width": "100%"},
    "tabItem": {"flex": 1, "alignItems": "center", "gap": 3},
    "tabIcon": {"fontSize": 18, "color": C.dark_muted},
    "tabText": {"fontSize": F.xs, "color": C.dark_muted},
    "tabTextOn": {"color": C.accent_text, "fontWeight": "bold"},
    "tabCenter": {"width": 56, "height": 56, "borderRadius": R.pill, "backgroundColor": C.accent, "alignItems": "center", "justifyContent": "center", "marginTop": -26, "borderWidth": 4, "borderColor": C.dark},

    # Chat
    "bubbleUser": {"alignSelf": "flex-end", "maxWidth": "80%", "padding": S.md, "borderRadius": R.md, "backgroundColor": C.dark},
    "bubbleBot": {"alignSelf": "flex-start", "maxWidth": "80%", "padding": S.md, "borderRadius": R.md, "backgroundColor": C.surface},
    "bubbleUserText": {"fontSize": F.md, "lineHeight": 21, "color": C.accent_text}
});
