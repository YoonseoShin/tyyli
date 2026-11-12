"""The stylist's detailed reasons behind an outfit, as numbered rows
(DESIGN_SYSTEM.md 8.2, "The details"). Optionally a collapsible glass panel.
"""
import from "@jac/mobui" { Pressable, Text, View }
import from .AppIcon { AppIcon }
import from ..models { Outfit }
import from ..ui.kit { C, S, ui }


# [label, text] per category. Older saved/demo outfits fall back to their single
# explanation or a neutral line, exactly as before.
def insight_rows(outfit: Outfit) -> list[list[str]] {
    return [
        ["Palette", outfit.color_reason or outfit.reason or "The palette is balanced across the selected pieces."],
        ["Mood", outfit.mood_reason or "The pieces share a consistent style direction."],
        ["Weather", outfit.weather_reason or "Warmth and layers are matched to today's forecast."],
        ["Your day", outfit.plan_reason or "The level of polish fits today's plans."],
        ["For you", outfit.personal_reason or "The choices reflect your saved style preferences."]
    ];
}


def InsightRow(number: int, label: str, detail: str) -> JsxElement {
    return <View style={{"paddingVertical": 14, "borderTopWidth": 1, "borderTopColor": C.hairline, "gap": 4}}>
        <View style={{"flexDirection": "row", "alignItems": "baseline", "gap": S.sm}}>
            <Text style={[ui.textMicro, ui.w600, {"width": 15}]}>{"0" + str(number)}</Text>
            <Text style={[ui.textLabel, ui.w600]}>{label}</Text>
        </View>
        <Text style={[ui.textBody, {"lineHeight": 21, "color": C.primary_light, "paddingLeft": 23}]}>{detail}</Text>
    </View>;
}


# collapsible: show a "The details" header that opens and closes the rows.
# note: replaces the header's caption (e.g. after a swap).
def:pub OutfitInsights(
    outfit: Outfit,
    collapsible: bool = False,
    initially_open: bool = True,
    note: str = ""
) -> JsxElement {
    has open: bool = initially_open;
    rows = insight_rows(outfit);
    shown = open or not collapsible;
    return <View style={ui.glass}>
        {(
            <Pressable
                accessibilityRole="button"
                accessibilityLabel={"The details, " + ("expanded" if open else "collapsed")}
                accessibilityState={{"expanded": open}}
                style={{"flexDirection": "row", "alignItems": "center", "justifyContent": "space-between", "gap": S.md, "paddingHorizontal": S.xl, "paddingVertical": 18, "minHeight": 64}}
                onPress={lambda { open = not open; }}
            >
                <View style={[ui.flex1, {"gap": 2}]}>
                    <Text style={ui.textH2}>The details</Text>
                    <Text style={ui.textCaption}>{note or "Palette, mood, weather, your day, for you"}</Text>
                </View>
                <View style={[ui.glassCircle, {"width": 36, "height": 36, "borderRadius": 18}]}>
                    <AppIcon name={"chevron-up" if open else "chevron-down"} size={20} color={C.text_primary}/>
                </View>
            </Pressable>
        ) if collapsible else (
            <View style={{"paddingHorizontal": S.xl, "paddingTop": 18, "paddingBottom": 6}}>
                <Text style={ui.textH2} accessibilityRole="header">Why it works</Text>
            </View>
        )}
        {(
            <View style={{"paddingHorizontal": S.xl, "paddingBottom": S.sm}}>
                {[<InsightRow key={row[0]} number={n + 1} label={row[0]} detail={row[1]}/> for (n, row) in enumerate(rows)]}
            </View>
        ) if shown else None}
    </View>;
}
