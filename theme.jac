"""Onboarding design system: a warm beige gradient, soft circles, serif
headlines and dark pill buttons. Only the onboarding flow uses this file; the
rest of the app styles itself from `ui/kit.jac`.
"""
import from "@jac/mobui" { Platform, StyleSheet }


glob:pub C: dict[str, str] = {
    "gradientTop": "#F0DFD3",
    "gradientBottom": "#F9F3EE",
    "circle": "#E6D2C4",
    "ink": "#3B2A1E",
    "copy": "#A4785C",
    "copySoft": "#B9957D",
    "line": "#E3D1C3",
    "surface": "#FFFDFB",
    "pill": "#3E2C21",
    "pillText": "#FFF8F2",
    "dotDone": "#C9A98F",
    "swatchBorder": "#EAD9CC"
};

# Top to bottom bands of the background gradient (no gradient package on
# either platform, so the backdrop stacks these as thin strips).
glob:pub GRADIENT_BANDS: list[str] = [
    "#F0DFD3", "#F1E0D5", "#F1E2D7", "#F2E3D8", "#F2E4DA", "#F3E6DC", "#F4E7DE", "#F4E8E0",
    "#F5EAE1", "#F5EBE3", "#F6ECE5", "#F7EEE7", "#F7EFE9", "#F8F0EA", "#F8F2EC", "#F9F3EE"
];

glob:pub BAND_INDEX: list[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];

# [["0", "#FFF"], ["1", "#000"], ...]: stable keys for colour swatch rows.
def:pub indexed(values: list[str]) -> list[list[str]] {
    pairs: list[list[str]] = [];
    n = 0;
    while n < len(values) {
        pairs.append([str(n), values[n]]);
        n = n + 1;
    }
    return pairs;
}

glob:pub SERIF: str = Platform.select({"ios": "Georgia", "android": "serif", "default": "Georgia, 'Times New Roman', serif"});

glob:pub styles = StyleSheet.create({
    "root": {"flex": 1, "backgroundColor": C["gradientBottom"], "overflow": "hidden"},
    "scroll": {"flex": 1, "backgroundColor": "transparent"},
    "page": {"flexGrow": 1, "paddingHorizontal": 28, "paddingTop": 14, "paddingBottom": 28, "maxWidth": 520, "width": "100%", "alignSelf": "center"},
    "body": {"flex": 1},
    "topbar": {"flexDirection": "row", "alignItems": "center", "justifyContent": "space-between", "height": 36},
    "navText": {"fontSize": 15, "color": C["copy"]},
    "counter": {"fontSize": 12, "color": C["copySoft"], "letterSpacing": 1.2},
    "spacer": {"flex": 1, "minHeight": 24},

    # Intro screens
    "hero": {"flex": 1, "alignItems": "center", "justifyContent": "center", "gap": 18, "paddingVertical": 24},
    "logo": {"fontFamily": SERIF, "fontSize": 68, "color": C["ink"], "letterSpacing": -1, "lineHeight": 78},
    "logoSmall": {"fontFamily": SERIF, "fontSize": 56, "color": C["ink"], "letterSpacing": -1, "lineHeight": 66},
    "tagline": {"fontSize": 16, "color": C["copy"], "marginTop": -10},
    "lead": {"fontSize": 24, "lineHeight": 33, "color": C["copy"], "textAlign": "center", "paddingHorizontal": 8},
    "leadSmall": {"fontSize": 19, "lineHeight": 28, "color": C["copy"], "textAlign": "center", "paddingHorizontal": 8},
    "headline": {"fontFamily": SERIF, "fontSize": 32, "lineHeight": 40, "color": C["ink"], "textAlign": "center"},
    "headlineSmall": {"fontFamily": SERIF, "fontSize": 26, "lineHeight": 33, "color": C["ink"], "textAlign": "center"},

    # Question screens
    "questionBlock": {"gap": 8, "marginTop": 22, "marginBottom": 22},
    "questionRow": {"flexDirection": "row", "alignItems": "flex-start"},
    "questionIndex": {"width": 34},
    "questionBody": {"paddingLeft": 34, "gap": 4},
    "questionNumber": {"fontSize": 13, "color": C["copySoft"], "letterSpacing": 1.2},
    "question": {"fontFamily": SERIF, "fontSize": 25, "lineHeight": 32, "color": C["ink"]},
    "hint": {"fontSize": 14, "lineHeight": 20, "color": C["copy"]},
    "optionalTag": {"fontSize": 12, "color": C["copySoft"]},
    "dots": {"flexDirection": "row", "gap": 6, "alignItems": "center", "justifyContent": "center", "marginTop": 2},
    "dot": {"height": 5, "width": 5, "borderRadius": 999, "backgroundColor": C["line"]},
    "dotDone": {"backgroundColor": C["dotDone"]},
    "dotNow": {"backgroundColor": C["ink"], "width": 18},

    # Options
    "optionWrap": {"flexDirection": "row", "flexWrap": "wrap", "gap": 10},
    "optionColumns": {"flexDirection": "row", "flexWrap": "wrap", "justifyContent": "space-between", "rowGap": 10},
    "option": {"paddingVertical": 12, "paddingHorizontal": 18, "borderRadius": 999, "backgroundColor": C["surface"], "borderWidth": 1, "borderColor": C["line"]},
    "optionOn": {"backgroundColor": C["pill"], "borderColor": C["pill"]},
    "optionHalf": {"alignItems": "center", "paddingVertical": 14},
    "optionText": {"fontSize": 15, "color": C["ink"]},
    "optionTextOn": {"color": C["pillText"], "fontWeight": "bold"},
    "optionTextWide": {"letterSpacing": 2.5, "fontSize": 16},

    # Fields
    "card": {"padding": 18, "gap": 16, "borderRadius": 24, "backgroundColor": C["surface"]},
    "cardSoft": {"padding": 14, "gap": 8, "borderRadius": 16, "backgroundColor": "#F6EBE2"},
    "label": {"fontSize": 11, "color": C["copy"], "letterSpacing": 1.3, "fontWeight": "bold"},
    "input": {"paddingVertical": 14, "paddingHorizontal": 16, "borderRadius": 16, "borderWidth": 1, "borderColor": C["line"], "backgroundColor": C["surface"], "color": C["ink"], "fontSize": 16},
    "textArea": {"minHeight": 150, "paddingVertical": 14, "paddingHorizontal": 16, "borderRadius": 18, "backgroundColor": "#FFFFFF", "color": C["ink"], "fontSize": 15, "lineHeight": 22, "textAlignVertical": "top"},
    "small": {"fontSize": 13, "lineHeight": 19, "color": C["copy"]},
    "link": {"fontSize": 13, "color": C["copy"], "fontWeight": "bold"},
    "unitSwitch": {"flexDirection": "row", "borderRadius": 999, "backgroundColor": "#F1E4D9", "padding": 3},
    "unitItem": {"paddingVertical": 6, "paddingHorizontal": 12, "borderRadius": 999},
    "unitItemOn": {"backgroundColor": C["pill"]},
    "unitText": {"fontSize": 12, "fontWeight": "bold", "color": C["ink"]},
    "unitTextOn": {"color": C["pillText"]},
    "shapeCard": {"borderRadius": 18, "borderWidth": 2, "borderColor": C["line"], "backgroundColor": C["surface"], "padding": 10, "alignItems": "center", "gap": 6},
    "shapeCardOn": {"borderColor": C["pill"], "backgroundColor": "#F6EBE2"},

    # Buttons
    "pill": {"flexDirection": "row", "alignItems": "center", "justifyContent": "center", "gap": 14, "paddingVertical": 16, "paddingHorizontal": 30, "borderRadius": 999, "backgroundColor": C["pill"], "alignSelf": "center", "minWidth": 200},
    "pillText": {"fontSize": 18, "color": C["pillText"], "fontWeight": "600"},
    "pillArrow": {"fontSize": 22, "lineHeight": 24, "color": C["pillText"]},
    "pillSmall": {"paddingVertical": 10, "paddingHorizontal": 18, "minWidth": 0, "gap": 8},
    "pillSmallText": {"fontSize": 13},
    "footer": {"alignItems": "center", "gap": 14, "paddingTop": 22},
    "footnote": {"fontSize": 12, "color": C["copySoft"]},
    "footnoteLink": {"textDecorationLine": "underline", "color": C["copy"]},

    # Result
    "resultName": {"fontFamily": SERIF, "fontSize": 44, "lineHeight": 52, "color": C["ink"], "textAlign": "center"},
    "resultCopy": {"fontSize": 15, "lineHeight": 22, "color": C["copy"], "textAlign": "center", "paddingHorizontal": 6},
    "swatches": {"flexDirection": "row", "alignSelf": "center", "borderRadius": 6, "overflow": "hidden", "borderWidth": 1, "borderColor": C["swatchBorder"]},
    "swatch": {"width": 44, "height": 44},
    "pulse": {"width": 120, "height": 120, "borderRadius": 999, "backgroundColor": C["circle"], "alignSelf": "center", "opacity": 0.7}
});
