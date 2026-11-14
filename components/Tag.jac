"""Tags and chips (DESIGN_SYSTEM.md 6).

`Tag` is a read-only label: "glass" for the stylist's keywords, "light" for
neutral metadata, "dark" for a selected state, "outline", and "success".
`ChoiceChip` is a tappable option in a set that fills espresso when selected.
"""
import from "@jac/mobui" { Pressable, Text, View }
import from .AppIcon { AppIcon }
import from ..ui.kit { C, R, S, ui }


def:pub Tag(label: str, variant: str = "light", icon: str = "") -> JsxElement {
    dark = variant == "dark";
    outline = variant == "outline";
    success = variant == "success";
    glass = variant == "glass";
    text_color = C.cta_text if dark else (C.success if success else C.tag_text);
    return <View style={[
        ui.keyword if glass else ui.chip,
        {"flexDirection": "row", "alignItems": "center", "gap": S.xs, "alignSelf": "flex-start"},
        ui.chipOn if dark else None,
        {"backgroundColor": C.surface, "borderWidth": 1, "borderColor": C.divider} if outline else None,
        ui.chipSage if success else None
    ]}>
        {(<AppIcon name={icon} size={13} color={text_color}/>) if icon else None}
        <Text style={[ui.keywordText if glass else ui.chipText, {"color": text_color}]} numberOfLines={1}>{label}</Text>
    </View>;
}


def:pub ChoiceChip(label: str, selected: bool, on_press: Callable[[], None]) -> JsxElement {
    return <Pressable
        accessibilityRole="button"
        accessibilityLabel={label}
        accessibilityState={{"selected": selected}}
        hitSlop={{"top": 4, "bottom": 4}}
        style={[
            {
                "minHeight": 36,
                "justifyContent": "center",
                "paddingVertical": 6,
                "paddingHorizontal": 14,
                "borderRadius": R.pill,
                "borderWidth": 1,
                "borderColor": C.keyword_edge,
                "backgroundColor": C.glass_strong
            },
            {"backgroundColor": C.primary, "borderColor": C.primary} if selected else None
        ]}
        onPress={lambda { on_press(); }}
    >
        <Text style={[ui.chipText, {"color": C.primary_light}, ui.chipTextOn if selected else None]}>{label}</Text>
    </Pressable>;
}
