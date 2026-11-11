"""The Stylist's note (DESIGN_SYSTEM.md 8.2): the look's name, the stylist's
line, a short summary, keywords and the style score, on a glass panel with a
soft blush glow. After a swap it says plainly that the note and score
describe the original pick.
"""
import from "@jac/mobui" { Image, Pressable, Text, View }
import from .AppIcon { AppIcon }
import from .Tag { Tag }
import from ..models { Outfit }
import from ..ui.kit { C, R, S, ui }
import from ..ui.materials { NOTE_GLOW }


# The first reason the stylist gave, for picks saved before summaries existed.
def fallback_summary(outfit: Outfit) -> str {
    for text in [outfit.plan_reason, outfit.mood_reason, outfit.color_reason, outfit.weather_reason, outfit.personal_reason, outfit.reason] {
        if text { return text; }
    }
    return "";
}


def:pub StylistNote(outfit: Outfit, swapped: bool = False, on_reset: Callable[[], None] | None = None) -> JsxElement {
    # New picks carry a headline: the look's name becomes the eyebrow above it.
    # Older picks show the look's name as the line itself, with no eyebrow.
    eyebrow = outfit.style_name if outfit.headline else "";
    headline = outfit.headline or outfit.style_name or "Today's look";
    summary = outfit.summary or fallback_summary(outfit);
    keywords = outfit.keywords[:3] if outfit.keywords else [];
    return <View style={ui.glass}>
        <View style={{"borderRadius": R.panel - 1, "overflow": "hidden", "padding": 22, "gap": S.sm}}>
            <Image source={{"uri": NOTE_GLOW}} style={{"position": "absolute", "right": -60, "top": -70, "width": 220, "height": 220}} resizeMode="stretch" accessibilityElementsHidden={True} importantForAccessibility="no"/>
            <View style={ui.rowBetween}>
                <View style={ui.row}>
                    <View style={{"width": 26, "height": 26, "borderRadius": 13, "backgroundColor": C.primary, "alignItems": "center", "justifyContent": "center"}} accessibilityElementsHidden={True} importantForAccessibility="no-hide-descendants">
                        <Text style={[ui.tabMonogram, {"fontSize": 16, "lineHeight": 20, "marginTop": -1}]} allowFontScaling={False}>t</Text>
                    </View>
                    <Text style={[ui.textCaption, ui.w600]} accessibilityRole="header">Stylist’s note</Text>
                </View>
                {(
                    <View style={{"alignItems": "flex-end"}} accessibilityLabel={"Style score " + str(outfit.confidence) + " out of 100" + (", for the original pick" if swapped else "")}>
                        <View style={{"flexDirection": "row", "alignItems": "baseline", "gap": 2}}>
                            <Text style={[ui.textDisplay, {"fontSize": 36, "lineHeight": 38}, {"color": C.text_secondary} if swapped else None]}>{str(outfit.confidence)}</Text>
                            <Text style={ui.textCaption}>/100</Text>
                        </View>
                        <Text style={[ui.textMicro, {"marginTop": -2}]}>Style score</Text>
                    </View>
                ) if outfit.confidence > 0 else None}
            </View>
            {(<Text style={[ui.textEyebrow, {"marginTop": S.xs}]}>{eyebrow}</Text>) if eyebrow else None}
            <Text style={[ui.textQuote, {"marginTop": 0 if eyebrow else S.xs}]}>{headline}</Text>
            {(<Text style={ui.textBodyLarge}>{summary}</Text>) if summary else None}
            {(
                <View style={[ui.wrap, {"gap": 6, "marginTop": S.xs}]}>
                    {[<Tag key={word} label={word} variant="glass"/> for word in keywords]}
                </View>
            ) if keywords else None}
            {(
                <View style={{"flexDirection": "row", "alignItems": "flex-start", "gap": S.sm, "marginTop": S.xs, "padding": S.md, "borderRadius": 16, "backgroundColor": C.glass_strong, "borderWidth": 1, "borderColor": C.keyword_edge}} accessibilityLiveRegion="polite">
                    <AppIcon name="information-outline" size={17} color={C.text_secondary}/>
                    <Text style={[ui.textCaption, ui.flex1, {"color": C.primary_light, "lineHeight": 17}]}>You swapped pieces. This note and score describe the original pick.</Text>
                    {(
                        <Pressable accessibilityRole="button" accessibilityLabel="Reset to the original pick" hitSlop={{"top": 12, "bottom": 12, "left": 8, "right": 8}} onPress={lambda { if on_reset { on_reset(); } }}>
                            <Text style={[ui.textLabel, ui.w600, {"textDecorationLine": "underline"}]}>Reset</Text>
                        </Pressable>
                    ) if on_reset else None}
                </View>
            ) if swapped else None}
        </View>
    </View>;
}
