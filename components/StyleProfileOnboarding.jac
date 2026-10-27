"""Tyyli — a thoughtful, personal style discovery."""
import from "@jac/mobui" { View, Text, Pressable, TextInput, ScrollView, Image, useWindowDimensions }
import from .AppIcon { AppIcon }
import from ..assets_body_shapes { BODY_SHAPE_CREDIT, BODY_SHAPE_IMAGES }
import from ..storage { StyleProfile }
import from ..theme { buildStyles }
import from .Dropdown { Dropdown }

glob C: dict[str, str] = {
    "bg": "#F7F4EF", "surface": "#FFFEFC", "ink": "#28251F",
    "muted": "#827B70", "line": "#E6E0D6", "accent": "#725747",
    "accentText": "#FFFFFF", "soft": "#EEE7DE", "sage": "#DCE4D9"
};
glob styles = buildStyles(C);
glob options: dict[str, list[str]] = {
    "styles": ["Casual", "Minimal", "Streetwear", "Preppy", "Sporty", "Vintage", "Y2K", "Classic", "Business casual", "Romantic", "Edgy", "Bohemian"],
    "colors": ["Black", "White", "Cream", "Brown", "Grey", "Navy", "Blue", "Green", "Red", "Pink", "Yellow", "Purple"],
    "sections": ["Women's", "Men's", "Both"],
    "letter_sizes": ["XXS", "XS", "S", "M", "L", "XL", "XXL", "3XL"],
    "body_shapes": ["Hourglass", "Pear", "Apple", "Rectangle", "Inverted triangle"],
    "stores": ["Aritzia", "Zara", "H&M", "Uniqlo", "Gap", "Banana Republic", "Abercrombie", "American Eagle", "Urban Outfitters", "Nordstrom", "Madewell", "J.Crew", "Everlane", "Lululemon", "Brandy Melville", "Garage", "Free People", "Amazon", "Thrift / vintage"],
    "brands": ["Nike", "Adidas", "New Balance", "Levi's", "Polo Ralph Lauren", "Carhartt", "The North Face", "Patagonia", "Arc'teryx", "Alo", "Skims", "Reformation", "COS", "Ganni", "Sézane", "Alex Mill", "Dr. Martens", "Birkenstock", "UGG"],
    "occasions": ["School", "Work", "Casual everyday", "Going out", "Dates", "Formal events", "Gym"],
    "mbti": ["INTJ", "INTP", "ENTJ", "ENTP", "INFJ", "INFP", "ENFJ", "ENFP", "ISTJ", "ISFJ", "ESTJ", "ESFJ", "ISTP", "ISFP", "ESTP", "ESFP"],
    "zodiac": ["Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo", "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"]
};
glob SHAPE_HINTS: dict[str, str] = {
    "Hourglass": "Shoulders and hips about equal, with a clearly narrower waist.",
    "Pear": "Hips wider than the shoulders; weight sits lower.",
    "Apple": "Fuller through the middle, slimmer hips and legs.",
    "Rectangle": "Shoulders, waist and hips roughly in line.",
    "Inverted triangle": "Shoulders wider than the hips."
};

# Steps: 0 welcome, 1 styles, 2 colors, 3 fit & sizes, 4 measurements & body
# shape, 5 stores, 6 brands, 7 inspiration, 8 MBTI, 9 zodiac, 10 occasions, 11 summary.
glob TOTAL: int = 11,
     OPTIONAL_STEPS: list[int] = [3, 4, 5, 6, 7, 8, 9];


def _range(start: int, stop: int) -> list[str] {
    values: list[str] = [];
    n = start;
    while n <= stop {
        values.append(str(n));
        n = n + 1;
    }
    return values;
}


def _half_sizes(start: int, stop: int) -> list[str] {
    values: list[str] = [];
    n = start;
    while n <= stop {
        values.append(str(n));
        if n < stop { values.append(str(n) + ".5"); }
        n = n + 1;
    }
    return values;
}


# "5 ft 6 in" -> ["5", "6"]; anything else -> ["", ""].
def _parse_feet(value: str) -> list[str] {
    parts = value.split(" ");
    if len(parts) >= 4 and parts[1] == "ft" and parts[3] == "in" {
        return [parts[0], parts[2]];
    }
    if len(parts) >= 2 and parts[1] == "ft" {
        return [parts[0], ""];
    }
    return ["", ""];
}


# "168 cm" / "61 kg" / "27 in" -> "168" when the unit matches, else "".
def _number_with_unit(value: str, unit: str) -> str {
    parts = value.split(" ");
    if len(parts) >= 2 and parts[1] == unit {
        return parts[0];
    }
    return "";
}


def _unit_of(value: str, fallback: str) -> str {
    parts = value.split(" ");
    return parts[1] if len(parts) >= 2 and parts[1] else fallback;
}


def:pub StyleProfileOnboarding(
    on_finish: Callable[[StyleProfile], None] | None = None,
    initial: StyleProfile | None = None
) -> JsxElement {
    # Every answer lives in component state, so Back / Continue never lose a selection.
    has step: int = 0,
        user_name: str = initial.name if initial else "",
        selected_styles: list[str] = initial.preferred_styles if initial else [],
        selected_colors: list[str] = initial.preferred_colors if initial else [],
        selected_occasions: list[str] = initial.occasions if initial else [],
        inspiration: str = initial.inspiration if initial else "",
        mbti: str = initial.mbti if initial else "",
        zodiac: str = initial.zodiac if initial else "",
        shop_section: str = initial.shop_section if initial else "",
        height_unit: str = _unit_of(initial.height, "ft") if initial else "ft",
        height_ft: str = _parse_feet(initial.height)[0] if initial else "",
        height_in: str = _parse_feet(initial.height)[1] if initial else "",
        height_cm: str = _number_with_unit(initial.height, "cm") if initial else "",
        weight_unit: str = _unit_of(initial.weight, "lb") if initial else "lb",
        weight_value: str = (_number_with_unit(initial.weight, "lb") or _number_with_unit(initial.weight, "kg")) if initial else "",
        measure_unit: str = ("cm" if initial.units in ["cm", "metric"] else "in") if initial else "in",
        top_size: str = initial.top_size if initial else "",
        bottom_size: str = initial.bottom_size if initial else "",
        shoe_size: str = initial.shoe_size if initial else "",
        waist: str = (_number_with_unit(initial.waist, "in") or _number_with_unit(initial.waist, "cm")) if initial else "",
        hips: str = (_number_with_unit(initial.hips, "in") or _number_with_unit(initial.hips, "cm")) if initial else "",
        body_shape: str = initial.body_shape if initial else "",
        brand_sizes: list[str] = initial.brand_sizes if initial else [],
        show_brand_sizes: bool = False,
        show_measure_guide: bool = False,
        brand_size_kind: str = "Top",
        brand_size_brand: str = "",
        brand_size_value: str = "",
        selected_stores: list[str] = initial.favorite_stores if initial else [],
        selected_brands: list[str] = initial.favorite_brands if initial else [],
        store_draft: str = "",
        brand_draft: str = "";
    viewport = useWindowDimensions();
    progress = (step * 100) / TOTAL;
    mens = shop_section == "Men's";

    def toggle(values: list[str], value: str) -> list[str] {
        if value in values { return [v for v in values if v != value]; }
        return values + [value];
    }

    def chip(label: str, active: bool, on_press: Callable[[], None]) -> JsxElement {
        return <Pressable key={label} style={[styles.chip, styles.chipOn if active else {}]} onPress={lambda { on_press(); }}>
            <Text style={[styles.chipText, styles.chipTextOn if active else {}]}>{label}</Text>
        </Pressable>;
    }

    # A two-way unit switch shown at the right of a field label.
    def unit_switch(left: str, right: str, current: str, on_change: Callable[[str], None]) -> JsxElement {
        return <View style={{"flexDirection": "row", "borderRadius": 999, "backgroundColor": C["soft"], "padding": 3}}>
            {[
                <Pressable key={u} style={{"paddingVertical": 6, "paddingHorizontal": 12, "borderRadius": 999, "backgroundColor": C["accent"] if current == u else "transparent"}} onPress={lambda { on_change(u); }}>
                    <Text style={{"fontSize": 12, "fontWeight": "bold", "color": C["accentText"] if current == u else C["ink"]}}>{u}</Text>
                </Pressable>
                for u in [left, right]
            ]}
        </View>;
    }

    def labelled_row(label: str, control: JsxElement) -> JsxElement {
        return <View style={{"flexDirection": "row", "justifyContent": "space-between", "alignItems": "center"}}>
            <Text style={styles.inputLabel}>{label}</Text>
            {control}
        </View>;
    }

    def number_input(value: str, placeholder: str, on_change: Callable[[str], None]) -> JsxElement {
        return <TextInput style={[styles.input, {"flex": 1}]} value={value} placeholder={placeholder} placeholderTextColor={C["muted"]} keyboardType="numeric" onChangeText={lambda (t: str) { on_change(t); }}/>;
    }

    def add_custom(kind: str) {
        if kind == "store" {
            value = store_draft.strip();
            if value and value not in selected_stores { selected_stores = selected_stores + [value]; }
            store_draft = "";
        } else {
            value = brand_draft.strip();
            if value and value not in selected_brands { selected_brands = selected_brands + [value]; }
            brand_draft = "";
        }
    }

    def add_brand_size {
        brand = brand_size_brand.strip();
        if not brand or not brand_size_value { return; }
        entry_text = brand_size_kind + ": " + brand + " " + brand_size_value;
        if entry_text not in brand_sizes { brand_sizes = brand_sizes + [entry_text]; }
        brand_size_brand = "";
        brand_size_value = "";
    }

    def custom_row(kind: str, value: str, placeholder: str) -> JsxElement {
        return <View style={{"flexDirection": "row", "gap": 8, "alignItems": "center"}}>
            <TextInput
                style={[styles.input, {"flex": 1}]}
                value={value}
                placeholder={placeholder}
                placeholderTextColor={C["muted"]}
                onChangeText={lambda (t: str) { if kind == "store" { store_draft = t; } else { brand_draft = t; } }}
                onSubmitEditing={lambda { add_custom(kind); }}
                returnKeyType="done"
            />
            <Pressable style={styles.chip} onPress={lambda { add_custom(kind); }}>
                <Text style={styles.chipText}>Add</Text>
            </Pressable>
        </View>;
    }

    def height_text -> str {
        if height_unit == "cm" {
            return (height_cm.strip() + " cm") if height_cm.strip() else "";
        }
        if not height_ft.strip() and not height_in.strip() { return ""; }
        return (height_ft.strip() or "0") + " ft " + (height_in.strip() or "0") + " in";
    }

    def weight_text -> str {
        return (weight_value.strip() + " " + weight_unit) if weight_value.strip() else "";
    }

    def go_next { if step < TOTAL { step = step + 1; } }
    def go_back { if step > 0 { step = step - 1; } }

    def finish {
        if on_finish {
            on_finish(StyleProfile(
                name=user_name.strip(),
                preferred_styles=selected_styles,
                preferred_colors=selected_colors,
                occasions=selected_occasions,
                inspiration=inspiration,
                mbti=mbti,
                zodiac=zodiac,
                shop_section=shop_section,
                units=measure_unit,
                height=height_text(),
                weight=weight_text(),
                top_size=top_size,
                bottom_size=bottom_size,
                shoe_size=shoe_size,
                waist=(waist + " " + measure_unit) if waist else "",
                hips=(hips + " " + measure_unit) if hips else "",
                body_shape=body_shape,
                brand_sizes=brand_sizes,
                temperature_unit=initial.temperature_unit if initial else ("C" if height_unit == "cm" else "F"),
                favorite_stores=selected_stores,
                favorite_brands=selected_brands
            ));
        }
    }

    # Option lists depend on the unit and the section the user shops in.
    waist_values = _range(55, 125) if measure_unit == "cm" else _range(22, 50);
    hip_values = _range(75, 140) if measure_unit == "cm" else _range(30, 56);
    bottom_values = options["letter_sizes"] + (_range(26, 44) if mens else _range(23, 40));
    shoe_values = _half_sizes(6, 15) if mens else _half_sizes(4, 13);
    brand_size_values = shoe_values if brand_size_kind == "Shoes" else bottom_values if brand_size_kind == "Bottom" else options["letter_sizes"];
    card_width = (Math.min(viewport.width, 560) - 40 - 12) / 2;

    titles = [
        "Let's find your style.", "What styles best describe you?", "What colors do you like wearing?",
        "Tell us about your fit.", "Your shape, your way.", "Where do you love to shop?", "Brands you keep coming back to?",
        "Whose style inspires you?", "Want to add a little personality?", "Want to add a little personality?",
        "What do you usually dress for?", "Your style profile is ready."
    ];
    subtitles = [
        "Answer a few quick questions so we can learn what you like.", "Choose all that feel like you.", "Pick the colors you reach for most.",
        "Sizes help the stylist suggest pieces that actually fit. Everything here is optional.",
        "Two measurements and a shape make shopping suggestions much more accurate. Optional, and it stays on your phone.",
        "Pick your go-to stores, or add your own.", "Pick the labels you wear most, or add your own.",
        "A celebrity, creator, or anyone whose looks you love.", "Just for fun. Your style choices matter most.", "Just for fun. Your style choices matter most.",
        "Select the moments you want outfits for.", "A little more you in every outfit."
    ];

    return <ScrollView style={[styles.screen, {"height": viewport.height}]} contentContainerStyle={styles.page} keyboardShouldPersistTaps="handled" automaticallyAdjustKeyboardInsets={True}>
        <View style={styles.topbar}>
            <Text style={styles.brand}>tyyli<Text style={styles.brandDot}>.</Text></Text>
            {(<Text style={styles.stepLabel}>{str(step) + " / " + str(TOTAL)}</Text>) if step > 0 and step < TOTAL else <Text style={styles.stepLabel}>YOUR PERSONAL STYLIST</Text>}
        </View>
        {(<View style={styles.progressTrack}><View style={[styles.progressFill, {"width": str(progress) + "%"}]}/></View>) if step > 0 and step < TOTAL else <View style={styles.progressPlaceholder}/>}

        {(<View style={styles.heroArt}>
            <View style={styles.artOrb}><Text style={styles.artSerif}>t</Text></View>
            <View style={styles.artNote}><Text style={styles.artNoteText}>A style that's yours</Text></View>
            <View style={styles.artFlower}><Text style={styles.flowerText}>✳</Text></View>
        </View>) if step == 0 or step == TOTAL else None}

        <View style={styles.headingBlock}>
            <Text style={styles.eyebrow}>{"STYLE DISCOVERY  /  " + ("0" + str(step + 1) if step < 9 else str(step + 1))}</Text>
            <Text style={styles.title}>{titles[step]}</Text>
            <Text style={styles.subtitle}>{subtitles[step]}</Text>
        </View>

        {step == 0 and <View style={[styles.welcomeNote, {"gap": 12}]}>
            <Text style={styles.welcomeQuote}>"Your wardrobe, with a little more you."</Text>
            <TextInput style={styles.input} value={user_name} placeholder="Your name" placeholderTextColor={C["muted"]} autoCapitalize="words" onChangeText={lambda (t: str) { user_name = t; }}/>
            <Text style={styles.noteSmall}>A few quick picks. About two minutes.</Text>
        </View>}
        {step == 1 and <View style={styles.optionGrid}>{[chip(x, x in selected_styles, lambda { selected_styles = toggle(selected_styles, x); }) for x in options["styles"]]}</View>}
        {step == 2 and <View style={styles.optionGrid}>{[chip(x, x in selected_colors, lambda { selected_colors = toggle(selected_colors, x); }) for x in options["colors"]]}</View>}

        {step == 3 and <View style={[styles.inputCard, {"gap": 16}]}>
            <Text style={styles.inputLabel}>I SHOP IN</Text>
            <View style={styles.optionGrid}>{[chip(x, shop_section == x, lambda { shop_section = "" if shop_section == x else x; }) for x in options["sections"]]}</View>

            {labelled_row("HEIGHT", unit_switch("ft / in", "cm", "cm" if height_unit == "cm" else "ft / in", lambda (u: str) { height_unit = "cm" if u == "cm" else "ft"; }))}
            {(
                <View style={{"flexDirection": "row", "gap": 8, "alignItems": "center"}}>
                    {number_input(height_cm, "e.g. 168", lambda (t: str) { height_cm = t; })}
                    <Text style={styles.noteSmall}>cm</Text>
                </View>
            ) if height_unit == "cm" else (
                <View style={{"flexDirection": "row", "gap": 8, "alignItems": "center"}}>
                    {number_input(height_ft, "5", lambda (t: str) { height_ft = t; })}
                    <Text style={styles.noteSmall}>ft</Text>
                    {number_input(height_in, "6", lambda (t: str) { height_in = t; })}
                    <Text style={styles.noteSmall}>in</Text>
                </View>
            )}

            {labelled_row("WEIGHT", unit_switch("lb", "kg", weight_unit, lambda (u: str) { weight_unit = u; }))}
            <View style={{"flexDirection": "row", "gap": 8, "alignItems": "center"}}>
                {number_input(weight_value, "e.g. 61" if weight_unit == "kg" else "e.g. 135", lambda (t: str) { weight_value = t; })}
                <Text style={styles.noteSmall}>{weight_unit}</Text>
            </View>

            <Dropdown label="USUAL TOP SIZE" value={top_size} options={options["letter_sizes"]} on_pick={lambda (v: str) { top_size = v; }} placeholder="Choose a size" hint="The size you reach for most often; brands vary, and that's fine."/>
            <Dropdown label="USUAL BOTTOM SIZE" value={bottom_size} options={bottom_values} on_pick={lambda (v: str) { bottom_size = v; }} placeholder="Letter size or waist" hint="Letter size or waist in inches, whichever you know."/>
            <Dropdown label="SHOE SIZE (US)" value={shoe_size} options={shoe_values} on_pick={lambda (v: str) { shoe_size = v; }} placeholder="Choose a size"/>

            <Pressable onPress={lambda { show_brand_sizes = not show_brand_sizes; }}>
                <Text style={[styles.inputHint, {"color": C["accent"], "fontWeight": "bold"}]}>{"Hide brand sizes" if show_brand_sizes else "Not sure of your size? Tell us what fits you at a brand you wear"}</Text>
            </Pressable>
            {(<View style={{"gap": 10, "padding": 12, "borderRadius": 12, "backgroundColor": C["soft"]}}>
                <Text style={styles.noteSmall}>Pick a brand you wear a lot and the size that fits you there. The stylist uses it to judge sizing at other brands.</Text>
                <View style={styles.optionGrid}>{[chip(k, brand_size_kind == k, lambda { brand_size_kind = k; brand_size_value = ""; }) for k in ["Top", "Bottom", "Shoes"]]}</View>
                <TextInput style={styles.input} value={brand_size_brand} placeholder="Brand, e.g. Aritzia" placeholderTextColor={C["muted"]} onChangeText={lambda (t: str) { brand_size_brand = t; }}/>
                <Dropdown label="SIZE THERE" value={brand_size_value} options={brand_size_values} on_pick={lambda (v: str) { brand_size_value = v; }} placeholder="Choose a size"/>
                <Pressable style={[styles.chip, {"alignSelf": "flex-start"}]} onPress={lambda { add_brand_size(); }}>
                    <Text style={styles.chipText}>Add this size</Text>
                </Pressable>
                {(<View style={styles.optionGrid}>{[chip(b + "  Remove", True, lambda { brand_sizes = [v for v in brand_sizes if v != b]; }) for b in brand_sizes]}</View>) if brand_sizes else None}
            </View>) if show_brand_sizes else None}
        </View>}

        {step == 4 and <View style={[styles.inputCard, {"gap": 16}]}>
            {labelled_row("MEASURE IN", unit_switch("in", "cm", measure_unit, lambda (u: str) { measure_unit = u; waist = ""; hips = ""; }))}
            <Pressable onPress={lambda { show_measure_guide = not show_measure_guide; }}>
                <Text style={[styles.inputHint, {"color": C["accent"], "fontWeight": "bold"}]}>{"Hide the measuring guide" if show_measure_guide else "How do I measure? (takes a minute with a soft tape)"}</Text>
            </Pressable>
            {(<View style={{"gap": 8, "padding": 12, "borderRadius": 12, "backgroundColor": C["soft"]}}>
                <Text style={styles.noteSmall}>Use a soft tape over light clothing, snug but not tight, and keep it level all the way round.</Text>
                <Text style={styles.noteSmall}>Waist: around the narrowest part of your torso, usually just above the belly button.</Text>
                <Text style={styles.noteSmall}>Hips: around the fullest part of your hips and seat, feet together.</Text>
                <Text style={styles.noteSmall}>No tape? Skip this: your usual sizes already help a lot.</Text>
            </View>) if show_measure_guide else None}
            <View style={{"flexDirection": "row", "gap": 10}}>
                <Dropdown label={"WAIST (" + measure_unit + ")"} value={waist} options={waist_values} on_pick={lambda (v: str) { waist = v; }} placeholder="Pick"/>
                <Dropdown label={"HIPS (" + measure_unit + ")"} value={hips} options={hip_values} on_pick={lambda (v: str) { hips = v; }} placeholder="Pick"/>
            </View>

            <Text style={styles.inputLabel}>BODY SHAPE</Text>
            <View style={{"flexDirection": "row", "flexWrap": "wrap", "gap": 12}}>
                {[
                    <Pressable key={shape} style={{"width": card_width, "borderRadius": 16, "borderWidth": 2, "borderColor": C["accent"] if body_shape == shape else C["line"], "backgroundColor": C["sage"] if body_shape == shape else C["surface"], "padding": 10, "alignItems": "center", "gap": 6}} onPress={lambda { body_shape = "" if body_shape == shape else shape; }}>
                        <Image source={{"uri": BODY_SHAPE_IMAGES[shape]}} style={{"width": card_width - 20, "height": 170}} resizeMode="contain"/>
                        <Text style={[styles.chipText, {"fontWeight": "bold"}]}>{shape}</Text>
                        <Text style={[styles.inputHint, {"textAlign": "center"}]}>{SHAPE_HINTS[shape]}</Text>
                    </Pressable>
                    for shape in options["body_shapes"]
                ]}
            </View>
            <Text style={styles.inputHint}>{"Not sure? Pick the closest, or skip. " + BODY_SHAPE_CREDIT}</Text>
        </View>}

        {step == 5 and <View style={{"gap": 12}}>
            <View style={styles.optionGrid}>{[chip(x, x in selected_stores, lambda { selected_stores = toggle(selected_stores, x); }) for x in options["stores"] + [s for s in selected_stores if s not in options["stores"]]]}</View>
            {custom_row("store", store_draft, "Another store you love")}
        </View>}
        {step == 6 and <View style={{"gap": 12}}>
            <View style={styles.optionGrid}>{[chip(x, x in selected_brands, lambda { selected_brands = toggle(selected_brands, x); }) for x in options["brands"] + [b for b in selected_brands if b not in options["brands"]]]}</View>
            {custom_row("brand", brand_draft, "Another brand you wear")}
        </View>}
        {step == 7 and <View style={styles.inputCard}>
            <Text style={styles.inputLabel}>NAME SOMEONE YOU ADMIRE</Text>
            <TextInput style={styles.input} value={inspiration} placeholder="e.g. Zendaya, Emma Chamberlain" placeholderTextColor={C["muted"]} onChangeText={lambda (t: str) { inspiration = t; }}/>
            <Text style={styles.inputHint}>Optional — skip if no one comes to mind.</Text>
        </View>}
        {step == 8 and <View style={styles.optionGrid}>{[chip(x, mbti == x, lambda { mbti = "" if mbti == x else x; }) for x in options["mbti"]]}</View>}
        {step == 9 and <View style={styles.optionGrid}>{[chip(x, zodiac == x, lambda { zodiac = "" if zodiac == x else x; }) for x in options["zodiac"]]}</View>}
        {step == 10 and <View style={styles.optionGrid}>{[chip(x, x in selected_occasions, lambda { selected_occasions = toggle(selected_occasions, x); }) for x in options["occasions"]]}</View>}
        {step == TOTAL and <View style={styles.summaryCard}>
            <View style={styles.summaryHeader}><Text style={styles.summaryMark}>t.</Text><Text style={styles.summaryCaption}>YOUR STYLE NOTES</Text></View>
            <View style={styles.summaryRow}><Text style={styles.summaryLabel}>THE VIBE</Text><Text style={styles.summaryValue}>{", ".join(selected_styles) if selected_styles else "Still discovering"}</Text></View>
            <View style={styles.summaryRow}><Text style={styles.summaryLabel}>COLORS</Text><Text style={styles.summaryValue}>{", ".join(selected_colors) if selected_colors else "Open to anything"}</Text></View>
            <View style={styles.summaryRow}><Text style={styles.summaryLabel}>FIT</Text><Text style={styles.summaryValue}>{" · ".join([v for v in [shop_section, height_text(), weight_text(), ("top " + top_size) if top_size else "", ("bottom " + bottom_size) if bottom_size else "", ("shoe " + shoe_size) if shoe_size else "", body_shape] if v]) or "Not specified"}</Text></View>
            <View style={styles.summaryRow}><Text style={styles.summaryLabel}>MEASUREMENTS</Text><Text style={styles.summaryValue}>{" · ".join([v for v in [("waist " + waist + " " + measure_unit) if waist else "", ("hips " + hips + " " + measure_unit) if hips else ""] if v]) or "Not specified"}</Text></View>
            {(<View style={styles.summaryRow}><Text style={styles.summaryLabel}>SIZES BY BRAND</Text><Text style={styles.summaryValue}>{", ".join(brand_sizes)}</Text></View>) if brand_sizes else None}
            <View style={styles.summaryRow}><Text style={styles.summaryLabel}>SHOPS AT</Text><Text style={styles.summaryValue}>{", ".join(selected_stores) if selected_stores else "Anywhere"}</Text></View>
            <View style={styles.summaryRow}><Text style={styles.summaryLabel}>BRANDS</Text><Text style={styles.summaryValue}>{", ".join(selected_brands) if selected_brands else "No favourites yet"}</Text></View>
            <View style={styles.summaryRow}><Text style={styles.summaryLabel}>INSPIRED BY</Text><Text style={styles.summaryValue}>{inspiration if inspiration else "Not specified"}</Text></View>
            <View style={styles.summaryRow}><Text style={styles.summaryLabel}>PERSONALITY</Text><Text style={styles.summaryValue}>{" · ".join([v for v in [mbti, zodiac] if v]) or "Not specified"}</Text></View>
            <View style={styles.summaryRow}><Text style={styles.summaryLabel}>DRESSING FOR</Text><Text style={styles.summaryValue}>{", ".join(selected_occasions) if selected_occasions else "Everyday life"}</Text></View>
            <Text style={styles.summaryFooter}>A good outfit starts with knowing what feels like you.</Text>
        </View>}

        <View style={styles.footer}>
            {step > 0 and <Pressable style={styles.backButton} onPress={lambda { go_back(); }}><Text style={styles.backText}>Back</Text></Pressable>}
            {step == 0 and <View style={styles.backButton}><Text style={styles.timeText}>PERSONALIZED, NOT PRESCRIBED</Text></View>}
            <Pressable style={styles.primaryButton} onPress={lambda { if step == TOTAL { finish(); } else { go_next(); } }}>
                <Text style={styles.primaryText}>{"Start styling" if step == TOTAL else "Let's go" if step == 0 else "Continue"}</Text>
                <AppIcon name="arrow-right" size={18} color={C["accentText"]}/>
            </Pressable>
        </View>
        {step in OPTIONAL_STEPS and <Pressable style={styles.skip} onPress={lambda { go_next(); }}><Text style={styles.skipText}>Skip this question</Text></Pressable>}
        {step == TOTAL and <Pressable style={styles.skip} onPress={lambda { step = 1; }}><Text style={styles.skipText}>Edit my answers</Text></Pressable>}
    </ScrollView>;
}
