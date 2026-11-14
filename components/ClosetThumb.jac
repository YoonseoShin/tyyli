"""Square clothing-photo tile (DESIGN_SYSTEM.md 6) on the champagne image
backdrop, plus the dashed "Add item" placeholder of the same size.
"""
import from "@jac/mobui" { Image, Pressable, Text, View }
import from .AppIcon { AppIcon }
import from ..ui.kit { C, R, S, SHADOW_COMPACT, ui }


# uri:      an already-resolved image URI.
# fit:      "cover" for closet photos (default; they have backgrounds),
#           "contain" for cut-outs that must not be cropped.
# selected: espresso edge plus a check (the piece currently in the outfit).
# badge:    optional small label in the top-left corner (e.g. "Original").
def:pub ClosetThumb(
    uri: str,
    selected: bool = False,
    size: int = 70,
    label: str = "",
    on_press: Callable[[], None] | None = None,
    fit: str = "cover",
    badge: str = ""
) -> JsxElement {
    has photo_failed: bool = False;
    return <Pressable
        accessibilityRole="button"
        accessibilityLabel={label or "Clothing item"}
        accessibilityState={{"selected": selected}}
        disabled={on_press is None}
        style={{"width": size, "gap": 6}}
        onPress={lambda { if on_press is not None { on_press(); } }}
    >
        <View style={[
            SHADOW_COMPACT,
            {"width": size, "height": size, "borderRadius": R.tile, "backgroundColor": C.champagne, "borderWidth": 1, "borderColor": C.glass_edge},
            {"borderWidth": 2, "borderColor": C.primary} if selected else None
        ]}>
            <View style={{"flex": 1, "borderRadius": R.tile - 1, "overflow": "hidden", "padding": 0 if fit == "cover" else 6}}>
                {(
                    <Image source={{"uri": uri}} style={{"width": "100%", "height": "100%"}} resizeMode={fit} onError={lambda { photo_failed = True; }}/>
                ) if uri and not photo_failed else (
                    <View style={{"flex": 1, "alignItems": "center", "justifyContent": "center"}} accessibilityLabel="Photo unavailable">
                        <AppIcon name="image-off-outline" size={22} color={C.text_secondary}/>
                    </View>
                )}
            </View>
            {(
                <View style={{"position": "absolute", "left": 6, "top": 6, "paddingVertical": 2, "paddingHorizontal": 7, "borderRadius": R.pill, "backgroundColor": C.glass_strong, "borderWidth": 1, "borderColor": C.keyword_edge}}>
                    <Text style={[ui.textNav, ui.w600, {"color": C.tag_text}]}>{badge}</Text>
                </View>
            ) if badge else None}
            {(
                <View style={{"position": "absolute", "right": 6, "top": 6, "width": 20, "height": 20, "borderRadius": 10, "alignItems": "center", "justifyContent": "center", "backgroundColor": C.primary}}>
                    <AppIcon name="check" size={13} color={C.cta_text}/>
                </View>
            ) if selected else None}
        </View>
        {(<Text style={[ui.textCaption, ui.w500, {"color": C.text_primary}]} numberOfLines={2}>{label}</Text>) if label else None}
    </Pressable>;
}


# Dashed placeholder shown where a closet has no items yet.
def:pub AddItemTile(on_press: Callable[[], None], size: int = 70, label: str = "Add item") -> JsxElement {
    return <Pressable
        accessibilityRole="button"
        accessibilityLabel={label}
        style={{"width": size, "gap": S.xs, "alignItems": "center"}}
        onPress={lambda { on_press(); }}
    >
        <View style={{"width": size, "height": size, "borderRadius": R.tile, "borderWidth": 1.5, "borderColor": C.accent, "borderStyle": "dashed", "alignItems": "center", "justifyContent": "center"}}>
            <AppIcon name="plus" size={22} color={C.accent}/>
        </View>
        <Text style={ui.textCaption}>{label}</Text>
    </Pressable>;
}
