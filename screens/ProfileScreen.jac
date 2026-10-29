"""The user's style profile from onboarding."""
import from "@jac/mobui" { Pressable, ScrollView, Text, View }
import from ..storage { StyleProfile }
import from ..theme { SERIF, indexed }
import from ..ui.kit { ui }


def ProfileRow(label: str, value: str) -> JsxElement {
    return <View style={{"gap": 2}}>
        <Text style={ui.label}>{label}</Text>
        <Text style={ui.body}>{value}</Text>
    </View>;
}


def or_dash(values: list[str]) -> str {
    return ", ".join(values) if values else "-";
}


def:pub ProfileScreen(
    profile: StyleProfile | None,
    clothes_count: int,
    on_edit_profile: Callable[[], None],
    on_open_storage_test: Callable[[], None],
    on_reset: Callable[[], None] | None = None
) -> JsxElement {
    return <ScrollView style={ui.screen} contentContainerStyle={ui.page}>
        <Text style={ui.title}>Profile</Text>

        {(<View style={[ui.card, {"alignItems": "center", "gap": 10}]}>
            <Text style={ui.label}>YOUR STYLE</Text>
            <Text style={{"fontFamily": SERIF, "fontSize": 34, "color": "#3B2A1E", "textAlign": "center"}}>{profile.style_name}</Text>
            <Text style={[ui.muted, {"textAlign": "center"}]}>{profile.style_description}</Text>
            {(<View style={{"flexDirection": "row", "borderRadius": 6, "overflow": "hidden", "borderWidth": 1, "borderColor": "#EAD9CC"}}>
                {[<View key={pair[0]} style={{"width": 40, "height": 40, "backgroundColor": pair[1]}}/> for pair in indexed(profile.style_palette)]}
            </View>) if profile.style_palette else None}
        </View>) if profile and profile.style_name else None}

        <View style={ui.card}>
            <ProfileRow label="STYLES" value={or_dash(profile.preferred_styles) if profile else "-"}/>
            <ProfileRow label="COLORS" value={or_dash(profile.preferred_colors) if profile else "-"}/>
            <ProfileRow label="DRESSING FOR" value={or_dash(profile.occasions) if profile else "-"}/>
            <ProfileRow label="INSPIRED BY" value={(profile.inspiration or "-") if profile else "-"}/>
            <ProfileRow label="PERSONALITY" value={" · ".join([v for v in [profile.mbti, profile.zodiac] if v]) or "-" if profile else "-"}/>
            <ProfileRow label="FIT" value={" · ".join([v for v in [profile.shop_section, profile.height, profile.weight, ("top " + profile.top_size) if profile.top_size else "", ("bottom " + profile.bottom_size) if profile.bottom_size else "", ("shoe " + profile.shoe_size) if profile.shoe_size else "", profile.body_shape] if v]) or "-" if profile else "-"}/>
            <ProfileRow label="MEASUREMENTS" value={" · ".join([v for v in [("waist " + profile.waist) if profile.waist else "", ("hips " + profile.hips) if profile.hips else ""] if v]) or "-" if profile else "-"}/>
            <ProfileRow label="SIZES BY BRAND" value={or_dash(profile.brand_sizes) if profile else "-"}/>
            <ProfileRow label="SHOPS AT" value={or_dash(profile.favorite_stores) if profile else "-"}/>
            <ProfileRow label="BRANDS" value={or_dash(profile.favorite_brands) if profile else "-"}/>
            <Pressable style={ui.button} onPress={lambda { on_edit_profile(); }}>
                <Text style={ui.buttonText}>Edit style profile</Text>
            </Pressable>
        </View>

        <View style={ui.card}>
            <Text style={ui.label}>CLOSET</Text>
            <Text style={ui.body}>{str(clothes_count) + " item(s) saved on this device"}</Text>
        </View>

        <View style={ui.card}>
            <Text style={ui.label}>DEVELOPER</Text>
            <Pressable style={[ui.button, ui.buttonGhost]} onPress={lambda { on_open_storage_test(); }}>
                <Text style={[ui.buttonText, ui.buttonGhostText]}>Open storage test screen</Text>
            </Pressable>
            {(<Pressable style={[ui.button, ui.buttonDanger]} onPress={lambda { on_reset(); }}>
                <Text style={ui.buttonText}>Reset app data (back to onboarding)</Text>
            </Pressable>) if on_reset else None}
            <Text style={ui.muted}>Reset deletes the style profile and every closet item on this device.</Text>
        </View>
    </ScrollView>;
}
