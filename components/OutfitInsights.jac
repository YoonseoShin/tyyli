"""Scannable, category-based reasons behind an outfit recommendation."""
import from "@jac/mobui" { Text, View }
import from .AppIcon { AppIcon }
import from ..models { Outfit }
import from ..ui.kit { C, ui }


def InsightRow(icon_name: str, title: str, detail: str, tint: str, last: bool = False) -> JsxElement {
    return <View style={{"flexDirection": "row", "gap": 11, "paddingVertical": 11, "borderBottomWidth": 0 if last else 1, "borderBottomColor": C.line}}>
        <View style={{"width": 34, "height": 34, "borderRadius": 12, "alignItems": "center", "justifyContent": "center", "backgroundColor": tint}}>
            <AppIcon name={icon_name} size={17} color={C.ink}/>
        </View>
        <View style={{"flex": 1, "gap": 3}}>
            <Text style={{"fontSize": 11, "fontWeight": "bold", "letterSpacing": 0.45, "color": C.muted}}>{title.upper()}</Text>
            <Text style={{"fontSize": 13, "lineHeight": 18, "color": C.ink}}>{detail}</Text>
        </View>
    </View>;
}


def:pub OutfitInsights(outfit: Outfit) -> JsxElement {
    # Older saved/demo outfits can still fall back to their single explanation.
    color_detail = outfit.color_reason or outfit.reason or "The palette is balanced across the selected pieces.";
    mood_detail = outfit.mood_reason or "The pieces share a consistent style direction.";
    weather_detail = outfit.weather_reason or "Warmth and layers are matched to today's forecast.";
    plan_detail = outfit.plan_reason or "The level of polish fits today's plans.";
    personal_detail = outfit.personal_reason or "The choices reflect your saved style preferences.";
    return <View style={[ui.card, {"paddingVertical": 10, "gap": 0}]}>
        <Text style={[ui.label, {"marginBottom": 3}]}>WHY THIS WORKS</Text>
        <InsightRow icon_name="palette-outline" title="Color harmony" detail={color_detail} tint="#F1E3D5"/>
        <InsightRow icon_name="creation-outline" title="Style mood" detail={mood_detail} tint="#E9E2F0"/>
        <InsightRow icon_name="weather-partly-cloudy" title="Weather & warmth" detail={weather_detail} tint="#E1E9DF"/>
        <InsightRow icon_name="calendar-blank-outline" title="Today's plans" detail={plan_detail} tint="#ECE7DB"/>
        <InsightRow icon_name="account-heart-outline" title="Personal fit" detail={personal_detail} tint="#F1E1DE" last={True}/>
    </View>;
}
