"""The user's style profile, presented as compact cards and readable tags."""
import from "@jac/mobui" { Pressable, ScrollView, Text, View }
import from ..components.AppIcon { AppIcon }
import from ..storage { StyleProfile }
import from ..theme { indexed }
import from ..ui.kit { C, SERIF, ui }


def ProfileTags(label: str, values: list[str]) -> JsxElement {
    display_values = values if values else ["Not set"];
    return <View style={{"gap": 8}}>
        <Text style={ui.label}>{label}</Text>
        <View style={ui.wrap}>
            {[
                <View key={label + "-" + value} style={[ui.chipOutline, {"paddingVertical": 7, "paddingHorizontal": 11}]}>
                    <Text style={{"fontSize": 12, "fontWeight": "bold", "color": C.ink}}>{value}</Text>
                </View>
                for value in display_values
            ]}
        </View>
    </View>;
}


def ProfileTile(label: str, value: str) -> JsxElement {
    return <View style={{"width": "48%", "minHeight": 72, "padding": 12, "gap": 5, "borderRadius": 14, "backgroundColor": C.soft}}>
        <Text style={ui.label}>{label}</Text>
        <Text style={ui.bodyBold}>{value or "Not set"}</Text>
    </View>;
}


def:pub ProfileScreen(
    profile: StyleProfile | None,
    on_edit_profile: Callable[[], None],
    on_reset: Callable[[], None] | None = None
) -> JsxElement {
    if profile is None {
        return <ScrollView style={ui.screen} contentContainerStyle={ui.page}>
            <Text style={ui.title}>Profile</Text>
            <View style={ui.card}>
                <Text style={ui.body}>Your style profile has not been created yet.</Text>
                <Pressable style={ui.button} onPress={lambda { on_edit_profile(); }}>
                    <Text style={ui.buttonText}>Create style profile</Text>
                </Pressable>
            </View>
        </ScrollView>;
    }

    personality = [value for value in [profile.mbti, profile.zodiac] if value];
    fit_summary = [value for value in [profile.shop_section, profile.body_shape] if value];

    return <ScrollView style={ui.screen} contentContainerStyle={[ui.page, {"gap": 14}]}>
        <View style={ui.rowBetween}>
            <Text style={ui.title}>{"Hello, " + (profile.name or "there")}</Text>
            <Pressable accessibilityLabel="Edit my profile" style={ui.iconButton} onPress={lambda { on_edit_profile(); }}>
                <AppIcon name="pencil-outline" size={19} color={C.ink}/>
            </Pressable>
        </View>

        {(<View style={[ui.card, {"alignItems": "center", "gap": 10}]}>
            <Text style={ui.label}>YOUR STYLE</Text>
            <Text style={{"fontFamily": SERIF, "fontSize": 34, "color": C.ink, "textAlign": "center"}}>{profile.style_name}</Text>
            <Text style={[ui.muted, {"textAlign": "center"}]}>{profile.style_description}</Text>
            {(<View style={{"flexDirection": "row", "borderRadius": 6, "overflow": "hidden", "borderWidth": 1, "borderColor": C.line}}>
                {[<View key={pair[0]} style={{"width": 40, "height": 40, "backgroundColor": pair[1]}}/> for pair in indexed(profile.style_palette)]}
            </View>) if profile.style_palette else None}
        </View>) if profile.style_name else None}

        <View style={[ui.card, {"gap": 16}]}>
            <Text style={ui.heading}>Style Preferences</Text>
            <ProfileTags label="STYLES" values={profile.preferred_styles}/>
            <View style={ui.divider}/>
            <ProfileTags label="COLORS" values={profile.preferred_colors}/>
            <View style={ui.divider}/>
            <ProfileTags label="DRESSING FOR" values={profile.occasions}/>
            <View style={ui.divider}/>
            <ProfileTags label="PERSONALITY" values={personality}/>
            {(
                <View style={{"padding": 12, "borderRadius": 14, "backgroundColor": C.soft, "gap": 4}}>
                    <Text style={ui.label}>INSPIRED BY</Text>
                    <Text style={ui.body}>{profile.inspiration}</Text>
                </View>
            ) if profile.inspiration else None}
        </View>

        <View style={[ui.card, {"gap": 14}]}>
            <Text style={ui.heading}>Fit & Sizing</Text>
            <View style={[ui.wrap, {"justifyContent": "space-between"}]}>
                <ProfileTile label="HEIGHT" value={profile.height}/>
                <ProfileTile label="WEIGHT" value={profile.weight}/>
                <ProfileTile label="TOP" value={profile.top_size}/>
                <ProfileTile label="BOTTOM" value={profile.bottom_size}/>
                <ProfileTile label="SHOES" value={profile.shoe_size}/>
                <ProfileTile label="BUST / WAIST / HIPS" value={" / ".join([value for value in [profile.bust, profile.waist, profile.hips] if value])}/>
            </View>
            <ProfileTags label="FIT PROFILE" values={fit_summary}/>
            <ProfileTags label="SIZES BY BRAND" values={profile.brand_sizes}/>
        </View>

        <View style={[ui.card, {"gap": 16}]}>
            <Text style={ui.heading}>Favorites</Text>
            <ProfileTags label="STORES" values={profile.favorite_stores}/>
            <View style={ui.divider}/>
            <ProfileTags label="BRANDS" values={profile.favorite_brands}/>
        </View>

        {(<View style={ui.card}>
            <Text style={ui.label}>DEVELOPER</Text>
            <Pressable style={[ui.button, ui.buttonDanger]} onPress={lambda { on_reset(); }}>
                <Text style={ui.buttonText}>Reset app data (back to onboarding)</Text>
            </Pressable>
            <Text style={ui.muted}>Reset deletes the style profile and every closet item on this device.</Text>
        </View>) if on_reset else None}

    </ScrollView>;
}
