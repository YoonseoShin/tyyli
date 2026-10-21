"""Tyyli — a thoughtful, personal style discovery."""
import from "@jac/mobui" { View, Text, Pressable, TextInput, ScrollView, useWindowDimensions }
import from ..storage { StyleProfile }
import from ..theme { buildStyles }

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

# Silhouette proportions (shoulders, waist, hips) as fractions of the card width.
glob SHAPE_WIDTHS: dict[str, list[float]] = {
    "Hourglass": [0.78, 0.48, 0.78],
    "Pear": [0.6, 0.5, 0.82],
    "Apple": [0.74, 0.78, 0.62],
    "Rectangle": [0.68, 0.62, 0.68],
    "Inverted triangle": [0.84, 0.52, 0.58]
};
glob SHAPE_HINTS: dict[str, str] = {
    "Hourglass": "Bust and hips about equal, waist clearly narrower.",
    "Pear": "Hips wider than bust and shoulders.",
    "Apple": "Waist is the widest part; slimmer hips and legs.",
    "Rectangle": "Bust, waist and hips all within a few inches.",
    "Inverted triangle": "Shoulders or bust wider than the hips."
};

# Steps: 0 welcome, 1 styles, 2 colors, 3 fit & sizes, 4 measurements & body
# shape, 5 stores, 6 brands, 7 inspiration, 8 MBTI, 9 zodiac, 10 occasions, 11 summary.
glob TOTAL: int = 11,
     OPTIONAL_STEPS: list[int] = [3, 4, 5, 6, 7, 8, 9];


def _range(start: int, stop: int, step: int = 1) -> list[str] {
    values: list[str] = [];
    n = start;
    while n <= stop {
        values.append(str(n));
        n = n + step;
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


# Guess a body shape from bust / waist / hips (all in the same unit).
def _shape_from_measurements(bust: str, waist: str, hips: str) -> str {
    try {
        b = float(bust); w = float(waist); h = float(hips);
    } except Exception { return ""; }
    if b <= 0 or w <= 0 or h <= 0 { return ""; }
    if w >= b * 0.9 or w >= h * 0.9 { return "Apple"; }
    if h >= b * 1.05 and w < h * 0.8 { return "Pear"; }
    if b >= h * 1.05 and w < b * 0.8 { return "Inverted triangle"; }
    if w <= b * 0.75 and w <= h * 0.75 { return "Hourglass"; }
    return "Rectangle";
}


def:pub Silhouette(shape: str, active: bool) -> JsxElement {
    widths = SHAPE_WIDTHS[shape] if shape in SHAPE_WIDTHS else [0.68, 0.62, 0.68];
    tone = C["accentText"] if active else C["accent"];
    return <View style={{"alignItems": "center", "gap": 2, "width": 84, "paddingVertical": 4}}>
        <View style={{"width": 16, "height": 16, "borderRadius": 8, "backgroundColor": tone}}/>
        <View style={{"width": 84 * widths[0], "height": 26, "borderTopLeftRadius": 14, "borderTopRightRadius": 14, "borderBottomLeftRadius": 6, "borderBottomRightRadius": 6, "backgroundColor": tone}}/>
        <View style={{"width": 84 * widths[1], "height": 18, "borderRadius": 6, "backgroundColor": tone}}/>
        <View style={{"width": 84 * widths[2], "height": 30, "borderRadius": 12, "backgroundColor": tone}}/>
    </View>;
}


def:pub StyleProfileOnboarding(
    on_finish: Callable[[StyleProfile], None] | None = None,
    initial: StyleProfile | None = None
) -> JsxElement {
    # Every answer lives in component state, so Back / Continue never lose a selection.
    has step: int = 0,
        selected_styles: list[str] = initial.preferred_styles if initial else [],
        selected_colors: list[str] = initial.preferred_colors if initial else [],
        selected_occasions: list[str] = initial.occasions if initial else [],
        inspiration: str = initial.inspiration if initial else "",
        mbti: str = initial.mbti if initial else "",
        zodiac: str = initial.zodiac if initial else "",
        shop_section: str = initial.shop_section if initial else "",
        units: str = (initial.units or "imperial") if initial else "imperial",
        height_text: str = initial.height if initial else "",
        weight_text: str = initial.weight if initial else "",
        top_size: str = initial.top_size if initial else "",
        bottom_size: str = initial.bottom_size if initial else "",
        shoe_size: str = initial.shoe_size if initial else "",
        bust: str = initial.bust if initial else "",
        waist: str = initial.waist if initial else "",
        hips: str = initial.hips if initial else "",
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
    metric = units == "metric";
    length_unit = "cm" if metric else "in";
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

    # A single-choice row of chips that scrolls sideways: the mobile "dropdown".
    def picker(label: str, values: list[str], current: str, on_pick: Callable[[str], None], hint: str = "") -> JsxElement {
        return <View style={{"gap": 6}}>
            <Text style={styles.inputLabel}>{label}</Text>
            <ScrollView horizontal={True} showsHorizontalScrollIndicator={False}>
                <View style={{"flexDirection": "row", "gap": 8, "paddingVertical": 2}}>
                    {[chip(v, current == v, lambda { on_pick("" if current == v else v); }) for v in values]}
                </View>
            </ScrollView>
            {(<Text style={styles.inputHint}>{hint}</Text>) if hint else None}
        </View>;
    }

    def field(label: str, value: str, placeholder: str, on_change: Callable[[str], None], numeric: bool = False) -> JsxElement {
        return <View style={{"gap": 6, "flex": 1}}>
            <Text style={styles.inputLabel}>{label}</Text>
            <TextInput style={styles.input} value={value} placeholder={placeholder} placeholderTextColor={C["muted"]} keyboardType={"numeric" if numeric else "default"} onChangeText={lambda (t: str) { on_change(t); }}/>
        </View>;
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

    def go_next { if step < TOTAL { step = step + 1; } }
    def go_back { if step > 0 { step = step - 1; } }

    def finish {
        if on_finish {
            on_finish(StyleProfile(
                preferred_styles=selected_styles,
                preferred_colors=selected_colors,
                occasions=selected_occasions,
                inspiration=inspiration,
                mbti=mbti,
                zodiac=zodiac,
                shop_section=shop_section,
                units=units,
                height=height_text,
                weight=weight_text,
                top_size=top_size,
                bottom_size=bottom_size,
                shoe_size=shoe_size,
                bust=bust,
                waist=waist,
                hips=hips,
                body_shape=body_shape,
                brand_sizes=brand_sizes,
                temperature_unit=initial.temperature_unit if initial else ("C" if metric else "F"),
                favorite_stores=selected_stores,
                favorite_brands=selected_brands
            ));
        }
    }

    # Size lists depend on the unit system and the section the user shops in.
    waist_values = _range(55, 125, 1) if metric else _range(22, 50, 1);
    hip_values = _range(75, 140, 1) if metric else _range(30, 56, 1);
    bust_values = _range(70, 130, 1) if metric else _range(28, 52, 1);
    bottom_values = options["letter_sizes"] + (_range(26, 44, 1) if mens else _range(23, 40, 1));
    shoe_values = _half_sizes(6, 15) if mens else _half_sizes(4, 13);

    titles = [
        "Let's find your style.", "What styles best describe you?", "What colors do you like wearing?",
        "Tell us about your fit.", "Your shape, your way.", "Where do you love to shop?", "Brands you keep coming back to?",
        "Whose style inspires you?", "Want to add a little personality?", "Want to add a little personality?",
        "What do you usually dress for?", "Your style profile is ready."
    ];
    subtitles = [
        "Answer a few quick questions so we can learn what you like.", "Choose all that feel like you.", "Pick the colors you reach for most.",
        "Sizes help the stylist suggest pieces that actually fit. Everything here is optional.",
        "A few measurements make shopping suggestions much more accurate. Optional, and it stays on your phone.",
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

        {step == 0 and <View style={styles.welcomeNote}><Text style={styles.welcomeQuote}>"Your wardrobe, with a little more you."</Text><Text style={styles.noteSmall}>A few quick picks. About two minutes.</Text></View>}
        {step == 1 and <View style={styles.optionGrid}>{[chip(x, x in selected_styles, lambda { selected_styles = toggle(selected_styles, x); }) for x in options["styles"]]}</View>}
        {step == 2 and <View style={styles.optionGrid}>{[chip(x, x in selected_colors, lambda { selected_colors = toggle(selected_colors, x); }) for x in options["colors"]]}</View>}

        {step == 3 and <View style={[styles.inputCard, {"gap": 16}]}>
            <View style={{"flexDirection": "row", "justifyContent": "space-between", "alignItems": "center"}}>
                <Text style={styles.inputLabel}>UNITS</Text>
                <View style={{"flexDirection": "row", "gap": 6}}>
                    {chip("ft · in · lb", not metric, lambda { units = "imperial"; })}
                    {chip("cm · kg", metric, lambda { units = "metric"; })}
                </View>
            </View>
            <Text style={styles.inputLabel}>I SHOP IN</Text>
            <View style={styles.optionGrid}>{[chip(x, shop_section == x, lambda { shop_section = "" if shop_section == x else x; }) for x in options["sections"]]}</View>
            <View style={{"flexDirection": "row", "gap": 8}}>
                {field("HEIGHT", height_text, "e.g. 168 cm" if metric else "e.g. 5'6\"", lambda (t: str) { height_text = t; })}
                {field("WEIGHT", weight_text, "e.g. 61 kg" if metric else "e.g. 135 lb", lambda (t: str) { weight_text = t; })}
            </View>
            {picker("USUAL TOP SIZE", options["letter_sizes"], top_size, lambda (v: str) { top_size = v; }, "The size you reach for most often; brands vary, and that's fine.")}
            {picker("USUAL BOTTOM SIZE", bottom_values, bottom_size, lambda (v: str) { bottom_size = v; }, "Letter size or waist in inches, whichever you know.")}
            {picker("SHOE SIZE (US)", shoe_values, shoe_size, lambda (v: str) { shoe_size = v; })}

            <Pressable onPress={lambda { show_brand_sizes = not show_brand_sizes; }}>
                <Text style={[styles.inputHint, {"color": C["accent"], "fontWeight": "bold"}]}>{"Hide brand sizes" if show_brand_sizes else "Not sure of your size? Tell us what fits you at a brand you wear"}</Text>
            </Pressable>
            {show_brand_sizes and <View style={{"gap": 10, "padding": 12, "borderRadius": 12, "backgroundColor": C["soft"]}}>
                <Text style={styles.noteSmall}>Pick a brand you wear a lot and the size that fits you there. The stylist uses it to judge sizing at other brands.</Text>
                <View style={styles.optionGrid}>{[chip(k, brand_size_kind == k, lambda { brand_size_kind = k; brand_size_value = ""; }) for k in ["Top", "Bottom", "Shoes"]]}</View>
                <TextInput style={styles.input} value={brand_size_brand} placeholder="Brand, e.g. Aritzia" placeholderTextColor={C["muted"]} onChangeText={lambda (t: str) { brand_size_brand = t; }}/>
                {picker("SIZE THERE", (shoe_values if brand_size_kind == "Shoes" else bottom_values if brand_size_kind == "Bottom" else options["letter_sizes"]), brand_size_value, lambda (v: str) { brand_size_value = v; })}
                <Pressable style={[styles.chip, {"alignSelf": "flex-start"}]} onPress={lambda { add_brand_size(); }}>
                    <Text style={styles.chipText}>Add this size</Text>
                </Pressable>
                {(<View style={styles.optionGrid}>{[chip(b + "  ✕", True, lambda { brand_sizes = [v for v in brand_sizes if v != b]; }) for b in brand_sizes]}</View>) if brand_sizes else None}
            </View>}
        </View>}

        {step == 4 and <View style={[styles.inputCard, {"gap": 16}]}>
            <Pressable onPress={lambda { show_measure_guide = not show_measure_guide; }}>
                <Text style={[styles.inputHint, {"color": C["accent"], "fontWeight": "bold"}]}>{"Hide the measuring guide" if show_measure_guide else "How do I measure? (takes a minute with a soft tape)"}</Text>
            </Pressable>
            {show_measure_guide and <View style={{"gap": 8, "padding": 12, "borderRadius": 12, "backgroundColor": C["soft"]}}>
                <Text style={styles.noteSmall}>Use a soft tape over light clothing, snug but not tight, and keep it level all the way round.</Text>
                <Text style={styles.noteSmall}>Bust: around the fullest part of your chest, arms relaxed at your sides.</Text>
                <Text style={styles.noteSmall}>Waist: around the narrowest part of your torso, usually just above the belly button.</Text>
                <Text style={styles.noteSmall}>Hips: around the fullest part of your hips and seat, feet together.</Text>
                <Text style={styles.noteSmall}>No tape? Skip this: your usual sizes already help a lot.</Text>
            </View>}
            {picker("BUST (" + length_unit + ")", bust_values, bust, lambda (v: str) { bust = v; })}
            {picker("WAIST (" + length_unit + ")", waist_values, waist, lambda (v: str) { waist = v; })}
            {picker("HIPS (" + length_unit + ")", hip_values, hips, lambda (v: str) { hips = v; })}

            <View style={{"flexDirection": "row", "justifyContent": "space-between", "alignItems": "center"}}>
                <Text style={styles.inputLabel}>BODY SHAPE</Text>
                {(<Pressable onPress={lambda { body_shape = _shape_from_measurements(bust, waist, hips); }}>
                    <Text style={[styles.inputHint, {"color": C["accent"], "fontWeight": "bold"}]}>Suggest from my measurements</Text>
                </Pressable>) if bust and waist and hips else None}
            </View>
            <ScrollView horizontal={True} showsHorizontalScrollIndicator={False}>
                <View style={{"flexDirection": "row", "gap": 10}}>
                    {[
                        <Pressable key={shape} style={[styles.chip, styles.chipOn if body_shape == shape else {}, {"alignItems": "center", "paddingHorizontal": 10, "paddingVertical": 8, "borderRadius": 16}]} onPress={lambda { body_shape = "" if body_shape == shape else shape; }}>
                            <Silhouette shape={shape} active={body_shape == shape}/>
                            <Text style={[styles.chipText, styles.chipTextOn if body_shape == shape else {}]}>{shape}</Text>
                        </Pressable>
                        for shape in options["body_shapes"]
                    ]}
                </View>
            </ScrollView>
            <Text style={styles.inputHint}>{SHAPE_HINTS[body_shape] if body_shape in SHAPE_HINTS else "Not sure? Pick the closest, use the suggestion above, or skip."}</Text>
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
            <View style={styles.summaryRow}><Text style={styles.summaryLabel}>FIT</Text><Text style={styles.summaryValue}>{" · ".join([v for v in [shop_section, height_text, weight_text, ("top " + top_size) if top_size else "", ("bottom " + bottom_size) if bottom_size else "", ("shoe " + shoe_size) if shoe_size else "", body_shape] if v]) or "Not specified"}</Text></View>
            <View style={styles.summaryRow}><Text style={styles.summaryLabel}>MEASUREMENTS</Text><Text style={styles.summaryValue}>{" · ".join([v for v in [("bust " + bust + " " + length_unit) if bust else "", ("waist " + waist + " " + length_unit) if waist else "", ("hips " + hips + " " + length_unit) if hips else ""] if v]) or "Not specified"}</Text></View>
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
                <Text style={styles.arrow}>→</Text>
            </Pressable>
        </View>
        {step in OPTIONAL_STEPS and <Pressable style={styles.skip} onPress={lambda { go_next(); }}><Text style={styles.skipText}>Skip this question</Text></Pressable>}
        {step == TOTAL and <Pressable style={styles.skip} onPress={lambda { step = 1; }}><Text style={styles.skipText}>Edit my answers</Text></Pressable>}
    </ScrollView>;
}
