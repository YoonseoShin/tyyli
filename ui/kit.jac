"""Design tokens and the shared stylesheet.

This prototype is intentionally plain. To restyle the app, edit the token
defaults below or the entries in `ui`; screens only reference these names.
"""
import from "@jac/mobui" { StyleSheet }


obj Colors {
    has bg: str = "#F7F4EF",
        surface: str = "#FFFEFC",
        ink: str = "#28251F",
        muted: str = "#827B70",
        line: str = "#E6E0D6",
        accent: str = "#725747",
        accent_text: str = "#FFFFFF",
        soft: str = "#EEE7DE",
        danger: str = "#9B4A43";
}

obj Spacing {
    has xs: int = 4, sm: int = 8, md: int = 12, lg: int = 16, xl: int = 24;
}

obj Radii {
    has sm: int = 8, md: int = 12, lg: int = 16, pill: int = 999;
}

obj Fonts {
    has xs: int = 11, sm: int = 13, md: int = 15, lg: int = 18, xl: int = 26;
}


glob:pub C = Colors(),
    S = Spacing(),
    R = Radii(),
    F = Fonts();


glob:pub ui = StyleSheet.create({
    # Layout
    "app": {"flex": 1, "backgroundColor": C.bg},
    "screen": {"flex": 1, "backgroundColor": C.bg},
    "page": {"padding": S.lg, "paddingBottom": S.xl, "gap": S.lg, "maxWidth": 560, "width": "100%", "alignSelf": "center"},
    "row": {"flexDirection": "row", "alignItems": "center", "gap": S.sm},
    "rowBetween": {"flexDirection": "row", "alignItems": "center", "justifyContent": "space-between", "gap": S.sm},
    "wrap": {"flexDirection": "row", "flexWrap": "wrap", "gap": S.sm},
    "flex1": {"flex": 1},

    # Text
    "title": {"fontSize": F.xl, "fontWeight": "bold", "color": C.ink},
    "heading": {"fontSize": F.lg, "fontWeight": "bold", "color": C.ink},
    "body": {"fontSize": F.md, "lineHeight": 21, "color": C.ink},
    "muted": {"fontSize": F.sm, "lineHeight": 19, "color": C.muted},
    "label": {"fontSize": F.xs, "fontWeight": "bold", "letterSpacing": 1, "color": C.accent},
    "link": {"fontSize": F.sm, "fontWeight": "bold", "color": C.accent},

    # Surfaces
    "card": {"padding": S.lg, "gap": S.sm, "borderRadius": R.lg, "backgroundColor": C.surface, "borderWidth": 1, "borderColor": C.line},
    "divider": {"height": 1, "backgroundColor": C.line},

    # Controls
    "button": {"paddingVertical": S.md, "paddingHorizontal": S.lg, "borderRadius": R.md, "backgroundColor": C.accent, "alignItems": "center", "justifyContent": "center"},
    "buttonText": {"fontSize": F.md, "fontWeight": "bold", "color": C.accent_text},
    "buttonGhost": {"backgroundColor": C.soft},
    "buttonGhostText": {"color": C.ink},
    "buttonDanger": {"backgroundColor": C.danger},
    "input": {"flex": 1, "borderWidth": 1, "borderColor": C.line, "borderRadius": R.md, "paddingVertical": S.md, "paddingHorizontal": S.md, "fontSize": F.md, "color": C.ink, "backgroundColor": C.surface},
    "chip": {"paddingVertical": 6, "paddingHorizontal": 10, "borderRadius": R.pill, "backgroundColor": C.soft},
    "chipText": {"fontSize": F.sm, "color": C.ink},
    "segment": {"flexDirection": "row", "padding": 3, "borderRadius": R.md, "backgroundColor": C.soft},
    "segmentItem": {"flex": 1, "paddingVertical": S.sm, "borderRadius": R.sm, "alignItems": "center"},
    "segmentItemOn": {"backgroundColor": C.surface},

    # Images
    "thumb": {"width": 72, "height": 72, "borderRadius": R.sm, "backgroundColor": C.soft},
    "thumbLarge": {"width": "100%", "height": 300, "borderRadius": R.md, "backgroundColor": C.soft},
    "gridItem": {"width": "48%", "gap": S.xs},
    "gridImage": {"width": "100%", "height": 160, "borderRadius": R.md, "backgroundColor": C.soft},

    # Tab bar
    "tabBar": {"flexDirection": "row", "borderTopWidth": 1, "borderColor": C.line, "backgroundColor": C.surface, "paddingTop": S.sm, "paddingBottom": S.lg},
    "tabItem": {"flex": 1, "alignItems": "center", "paddingVertical": S.xs},
    "tabText": {"fontSize": F.xs, "color": C.muted},
    "tabTextOn": {"color": C.accent, "fontWeight": "bold"},

    # Chat
    "bubbleUser": {"alignSelf": "flex-end", "maxWidth": "80%", "padding": S.md, "borderRadius": R.md, "backgroundColor": C.accent},
    "bubbleBot": {"alignSelf": "flex-start", "maxWidth": "80%", "padding": S.md, "borderRadius": R.md, "backgroundColor": C.surface, "borderWidth": 1, "borderColor": C.line},
    "bubbleUserText": {"fontSize": F.md, "lineHeight": 21, "color": C.accent_text}
});
