"""tyyli onboarding: from first open to a named personal style.

Flow: splash, how it works, a short intro, ten numbered questions, a
"generating" pause, "we think your style is ...", and a welcome. From the
result the user can retake the quiz or describe their style in their own
words, which re-runs the stylist with those words as the strongest signal.
Editing an existing profile starts straight at the first question.
"""
import from "@jac/mobui" { Image, Platform, Pressable, ScrollView, Text, TextInput, View, useWindowDimensions }
import from ..assets_body_shapes { BODY_SHAPE_CREDIT, BODY_SHAPE_IMAGES }
import from ..services.style_identity_service { discover_style_identity }
import from ..storage { StyleProfile }
import from ..theme { C, indexed, styles }
import from .Dropdown { Dropdown }
import from .OnboardingUi { Backdrop, OptionPill, PillButton, Pulse, Reveal }


glob options: dict[str, list[str]] = {
    "styles": ["Casual", "Minimal", "Streetwear", "Preppy", "Sporty", "Vintage", "Y2K", "Classic", "Business casual", "Romantic", "Edgy", "Bohemian"],
    "colors": ["Black", "White", "Cream", "Brown", "Grey", "Navy", "Blue", "Green", "Red", "Pink", "Yellow", "Purple"],
    "sections": ["Women's", "Men's", "Both"],
    "letter_sizes": ["XXS", "XS", "S", "M", "L", "XL", "XXL", "3XL"],
    "body_shapes": ["Hourglass", "Pear", "Apple", "Rectangle", "Inverted triangle"],
    "stores": ["Aritzia", "Zara", "H&M", "Uniqlo", "Gap", "Banana Republic", "Abercrombie", "American Eagle", "Urban Outfitters", "Nordstrom", "Madewell", "J.Crew", "Everlane", "Lululemon", "Brandy Melville", "Garage", "Free People", "Amazon", "Thrift / vintage"],
    "brands": ["Nike", "Adidas", "New Balance", "Levi's", "Polo Ralph Lauren", "Carhartt", "The North Face", "Patagonia", "Arc'teryx", "Alo", "Skims", "Reformation", "COS", "Ganni", "Sézane", "Alex Mill", "Dr. Martens", "Birkenstock", "UGG"],
    "occasions": ["School", "Work", "Casual everyday", "Going out", "Dates", "Formal events", "Gym"],
    "mbti": ["ISTJ", "ISFJ", "INFJ", "INTJ", "ISTP", "ISFP", "INFP", "INTP", "ESTP", "ESFP", "ENFP", "ENTP", "ESTJ", "ESFJ", "ENFJ", "ENTJ"],
    "zodiac": ["Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo", "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"]
};
glob SHAPE_HINTS: dict[str, str] = {
    "Hourglass": "Shoulders and hips about equal, with a clearly narrower waist.",
    "Pear": "Hips wider than the shoulders; weight sits lower.",
    "Apple": "Fuller through the middle, slimmer hips and legs.",
    "Rectangle": "Shoulders, waist and hips roughly in line.",
    "Inverted triangle": "Shoulders wider than the hips."
};

# Screen order. Questions sit between FIRST and GENERATING, in QUESTIONS order.
glob SPLASH: int = 0,
     HOW: int = 1,
     INTRO: int = 2,
     FIRST: int = 3,
     GENERATING: int = 13,
     RESULT: int = 14,
     DESCRIBE: int = 15,
     WELCOME: int = 16;
glob QUESTIONS: list[str] = ["styles", "colors", "occasions", "fit", "shape", "stores", "brands", "inspiration", "mbti", "zodiac"],
     REQUIRED: list[str] = ["styles", "colors", "occasions"];
glob TITLES: dict[str, str] = {
    "styles": "What styles best describe you?",
    "colors": "What colors do you like wearing?",
    "occasions": "What do you usually dress for?",
    "fit": "Tell us about your fit.",
    "shape": "Your shape, your way.",
    "stores": "Where do you love to shop?",
    "brands": "Brands you keep coming back to?",
    "inspiration": "Whose style inspires you?",
    "mbti": "What is your MBTI?",
    "zodiac": "What is your zodiac sign?"
};
glob HINTS: dict[str, str] = {
    "styles": "Choose all that feel like you.",
    "colors": "Pick the colors you reach for most.",
    "occasions": "Select the moments you want outfits for.",
    "fit": "Sizes help the stylist suggest pieces that actually fit.",
    "shape": "Two measurements and a shape make shopping suggestions much more accurate. It stays on your phone.",
    "stores": "Pick your go-to stores, or add your own.",
    "brands": "Pick the labels you wear most, or add your own.",
    "inspiration": "A celebrity, creator, or anyone whose looks you love.",
    "mbti": "Just for fun. Your style choices matter most.",
    "zodiac": "Just for fun. Your style choices matter most."
};


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


# A promise that resolves after `ms`, so short screens are not skipped in a flash.
def _wait(ms: int) -> any {
    return new(Promise, lambda (resolve: any) { setTimeout(resolve, ms); });
}


def:pub StyleProfileOnboarding(
    on_finish: Callable[[StyleProfile], None] | None = None,
    on_cancel: Callable[[], None] | None = None,
    initial: StyleProfile | None = None
) -> JsxElement {
    # Every answer lives in component state, so Back / Continue never lose a selection.
    has step: int = FIRST if initial else SPLASH,
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
        brand_draft: str = "",
        style_notes: str = initial.style_notes if initial else "",
        identity: any = None,
        # Height the screen really gets (inside the phone's safe area), measured on layout.
        frame_height: float = 0.0;
    viewport = useWindowDimensions();
    mens = shop_section == "Men's";

    def toggle(values: list[str], value: str) -> list[str] {
        if value in values { return [v for v in values if v != value]; }
        return values + [value];
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

    def build_profile -> StyleProfile {
        return StyleProfile(
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
            favorite_brands=selected_brands,
            style_name=identity.name if identity else "",
            style_description=identity.description if identity else "",
            style_palette=identity.palette if identity else [],
            style_notes=style_notes.strip()
        );
    }

    def finish {
        if on_finish { on_finish(build_profile()); }
    }

    # The two automatic screens: "generating" asks the stylist, "welcome" closes.
    async can with [step] entry {
        if step == GENERATING {
            draft = build_profile();
            await _wait(1400);
            identity = await discover_style_identity(draft, style_notes);
            step = RESULT;
        }
        if step == WELCOME {
            await _wait(2000);
            finish();
        }
    }

    def go_back {
        if step == DESCRIBE { step = RESULT; return; }
        if step == FIRST and initial and on_cancel { on_cancel(); return; }
        if step > SPLASH { step = step - 1; }
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

    def unit_switch(left: str, right: str, current: str, on_change: Callable[[str], None]) -> JsxElement {
        return <View style={styles.unitSwitch}>
            {[
                <Pressable key={u} style={[styles.unitItem, styles.unitItemOn if current == u else {}]} onPress={lambda { on_change(u); }}>
                    <Text style={[styles.unitText, styles.unitTextOn if current == u else {}]}>{u}</Text>
                </Pressable>
                for u in [left, right]
            ]}
        </View>;
    }

    def labelled_row(label: str, control: JsxElement) -> JsxElement {
        return <View style={{"flexDirection": "row", "justifyContent": "space-between", "alignItems": "center"}}>
            <Text style={styles.label}>{label}</Text>
            {control}
        </View>;
    }

    def number_input(value: str, placeholder: str, on_change: Callable[[str], None]) -> JsxElement {
        return <TextInput style={[styles.input, {"flex": 1, "minWidth": 0}]} value={value} placeholder={placeholder} placeholderTextColor={C["copySoft"]} keyboardType="numeric" onChangeText={lambda (t: str) { on_change(t); }}/>;
    }

    def custom_row(kind: str, value: str, placeholder: str) -> JsxElement {
        return <View style={{"flexDirection": "row", "gap": 8, "alignItems": "center"}}>
            <TextInput
                style={[styles.input, {"flex": 1}]}
                value={value}
                placeholder={placeholder}
                placeholderTextColor={C["copySoft"]}
                onChangeText={lambda (t: str) { if kind == "store" { store_draft = t; } else { brand_draft = t; } }}
                onSubmitEditing={lambda { add_custom(kind); }}
                returnKeyType="done"
            />
            <OptionPill label="Add" active={False} on_press={lambda { add_custom(kind); }}/>
        </View>;
    }

    def multi(key: str, values: list[str], choices: list[str], on_change: Callable[[list[str]], None]) -> JsxElement {
        return <View style={styles.optionWrap}>
            {[<OptionPill key={x} label={x} active={x in values} on_press={lambda { on_change(toggle(values, x)); }}/> for x in choices]}
        </View>;
    }

    # Option lists depend on the unit and the section the user shops in.
    waist_values = _range(55, 125) if measure_unit == "cm" else _range(22, 50);
    hip_values = _range(75, 140) if measure_unit == "cm" else _range(30, 56);
    bottom_values = options["letter_sizes"] + (_range(26, 44) if mens else _range(23, 40));
    shoe_values = _half_sizes(6, 15) if mens else _half_sizes(4, 13);
    brand_size_values = shoe_values if brand_size_kind == "Shoes" else bottom_values if brand_size_kind == "Bottom" else options["letter_sizes"];
    # Page padding (28 each side), card padding (18 each side) and the gap between two cards.
    card_width = (Math.min(viewport.width, 520) - 56 - 36 - 12) / 2;

    is_question = step >= FIRST and step < GENERATING;
    key = QUESTIONS[step - FIRST] if is_question else "";
    number = step - FIRST + 1;
    done_keys = QUESTIONS[:step - FIRST] if is_question else [];
    picks = len(selected_styles) if key == "styles" else len(selected_colors) if key == "colors" else len(selected_occasions) if key == "occasions" else 1;
    required = key in REQUIRED;
    can_continue = (not required) or picks > 0;
    # Optional questions share one button: "Skip for now" until something is answered.
    answered = (
        bool(shop_section or height_text() or weight_text() or top_size or bottom_size or shoe_size or brand_sizes) if key == "fit"
        else bool(waist or hips or body_shape) if key == "shape"
        else len(selected_stores) > 0 if key == "stores"
        else len(selected_brands) > 0 if key == "brands"
        else bool(inspiration.strip()) if key == "inspiration"
        else bool(mbti) if key == "mbti"
        else bool(zodiac) if key == "zodiac"
        else picks > 0
    );
    last_question = step == GENERATING - 1;
    button_label = "See my style" if last_question else "Continue" if required or answered else "Skip for now";

    show_back = step in [HOW, INTRO, DESCRIBE] or (is_question and (step > FIRST or (initial and on_cancel)));
    result_name = identity.name if identity else "";
    result_copy = identity.description if identity else "";
    result_palette = identity.palette if identity else [];

    return <View style={[styles.root, {"height": viewport.height} if Platform.OS == "web" else {}]} onLayout={lambda (e: any) { frame_height = e.nativeEvent.layout.height; }}>
        <Backdrop width={viewport.width} height={frame_height or viewport.height} phase={step}/>
        <ScrollView key={"scroll" + str(step)} style={styles.scroll} contentContainerStyle={styles.page} keyboardShouldPersistTaps="handled" automaticallyAdjustKeyboardInsets={True}>

            <View style={styles.topbar}>
                {(<Pressable onPress={lambda { go_back(); }} hitSlop={12}><Text style={styles.navText}>{"Cancel" if step == FIRST and initial else "←  Back"}</Text></Pressable>) if show_back else <View/>}
                {(<Text style={styles.counter}>{str(number) + " / " + str(len(QUESTIONS))}</Text>) if is_question else <View/>}
            </View>
            {(<View style={styles.dots}>
                {[<View key={q} style={[styles.dot, styles.dotDone if q in done_keys else {}, styles.dotNow if q == key else {}]}/> for q in QUESTIONS]}
            </View>) if is_question else None}

            {step == SPLASH and <Reveal key="splash" grow={True}>
                <View style={[styles.hero, {"paddingBottom": 70}]}>
                    <Text style={styles.logo}>tyyli</Text>
                    <Text style={styles.tagline}>your AI stylist</Text>
                    <View style={{"height": 36}}/>
                    <Text style={styles.lead}>Find the perfect outfit for you based on what you already have in your closet</Text>
                </View>
                <View style={styles.footer}>
                    <PillButton label="Get styled" on_press={lambda { step = HOW; }}/>
                    <Text style={styles.footnote}>About two minutes. Your answers stay on your phone.</Text>
                </View>
            </Reveal>}

            {step == HOW and <Reveal key="how" grow={True}>
                <View style={styles.hero}>
                    <Text style={styles.headline}>How does the algorithm work?</Text>
                    <Text style={styles.leadSmall}>We use AI to design personalized outfits for you based on a quiz, the current weather, and how your day looks in your personal calendar.</Text>
                </View>
                <View style={styles.footer}>
                    <PillButton label="Continue" on_press={lambda { step = INTRO; }}/>
                </View>
            </Reveal>}

            {step == INTRO and <Reveal key="intro" grow={True}>
                <View style={styles.hero}>
                    <Text style={styles.lead}>First of all, we will ask you a couple questions to know your style…</Text>
                </View>
                <View style={styles.footer}>
                    <PillButton label="Okay!" on_press={lambda { step = FIRST; }}/>
                </View>
            </Reveal>}

            {is_question and <Reveal key={"q" + str(step)} grow={True}>
                <View style={styles.questionBlock}>
                    <View style={styles.questionRow}>
                        <Text style={[styles.question, styles.questionIndex]}>{str(number) + "."}</Text>
                        <Text style={[styles.question, {"flex": 1}]}>{TITLES[key]}</Text>
                    </View>
                    <View style={styles.questionBody}>
                        <Text style={styles.hint}>{HINTS[key]}</Text>
                        {(<Text style={styles.optionalTag}>(Optional)</Text>) if not required else None}
                    </View>
                </View>

                <View style={styles.body}>
                {key == "styles" and multi("styles", selected_styles, options["styles"], lambda (v: list[str]) { selected_styles = v; })}
                {key == "colors" and multi("colors", selected_colors, options["colors"], lambda (v: list[str]) { selected_colors = v; })}
                {key == "occasions" and multi("occasions", selected_occasions, options["occasions"], lambda (v: list[str]) { selected_occasions = v; })}

                {key == "fit" and <View style={styles.card}>
                    <Text style={styles.label}>I SHOP IN</Text>
                    <View style={styles.optionWrap}>{[<OptionPill key={x} label={x} active={shop_section == x} on_press={lambda { shop_section = "" if shop_section == x else x; }}/> for x in options["sections"]]}</View>

                    {labelled_row("HEIGHT", unit_switch("ft / in", "cm", "cm" if height_unit == "cm" else "ft / in", lambda (u: str) { height_unit = "cm" if u == "cm" else "ft"; }))}
                    {(
                        <View style={{"flexDirection": "row", "gap": 8, "alignItems": "center"}}>
                            {number_input(height_cm, "e.g. 168", lambda (t: str) { height_cm = t; })}
                            <Text style={styles.small}>cm</Text>
                        </View>
                    ) if height_unit == "cm" else (
                        <View style={{"flexDirection": "row", "gap": 8, "alignItems": "center"}}>
                            {number_input(height_ft, "5", lambda (t: str) { height_ft = t; })}
                            <Text style={styles.small}>ft</Text>
                            {number_input(height_in, "6", lambda (t: str) { height_in = t; })}
                            <Text style={styles.small}>in</Text>
                        </View>
                    )}

                    {labelled_row("WEIGHT", unit_switch("lb", "kg", weight_unit, lambda (u: str) { weight_unit = u; }))}
                    <View style={{"flexDirection": "row", "gap": 8, "alignItems": "center"}}>
                        {number_input(weight_value, "e.g. 61" if weight_unit == "kg" else "e.g. 135", lambda (t: str) { weight_value = t; })}
                        <Text style={styles.small}>{weight_unit}</Text>
                    </View>

                    <Dropdown label="USUAL TOP SIZE" value={top_size} options={options["letter_sizes"]} on_pick={lambda (v: str) { top_size = v; }} placeholder="Choose a size" hint="The size you reach for most often; brands vary, and that's fine."/>
                    <Dropdown label="USUAL BOTTOM SIZE" value={bottom_size} options={bottom_values} on_pick={lambda (v: str) { bottom_size = v; }} placeholder="Letter size or waist" hint="Letter size or waist in inches, whichever you know."/>
                    <Dropdown label="SHOE SIZE (US)" value={shoe_size} options={shoe_values} on_pick={lambda (v: str) { shoe_size = v; }} placeholder="Choose a size"/>

                    <Pressable onPress={lambda { show_brand_sizes = not show_brand_sizes; }}>
                        <Text style={styles.link}>{"Hide brand sizes" if show_brand_sizes else "Not sure of your size? Tell us what fits you at a brand you wear"}</Text>
                    </Pressable>
                    {(<View style={styles.cardSoft}>
                        <Text style={styles.small}>Pick a brand you wear a lot and the size that fits you there. The stylist uses it to judge sizing at other brands.</Text>
                        <View style={styles.optionWrap}>{[<OptionPill key={k} label={k} active={brand_size_kind == k} on_press={lambda { brand_size_kind = k; brand_size_value = ""; }}/> for k in ["Top", "Bottom", "Shoes"]]}</View>
                        <TextInput style={styles.input} value={brand_size_brand} placeholder="Brand, e.g. Aritzia" placeholderTextColor={C["copySoft"]} onChangeText={lambda (t: str) { brand_size_brand = t; }}/>
                        <Dropdown label="SIZE THERE" value={brand_size_value} options={brand_size_values} on_pick={lambda (v: str) { brand_size_value = v; }} placeholder="Choose a size"/>
                        <View style={{"alignSelf": "flex-start"}}><OptionPill label="Add this size" active={False} on_press={lambda { add_brand_size(); }}/></View>
                        {(<View style={styles.optionWrap}>{[<OptionPill key={b} label={b + "  ✕"} active={True} on_press={lambda { brand_sizes = [v for v in brand_sizes if v != b]; }}/> for b in brand_sizes]}</View>) if brand_sizes else None}
                    </View>) if show_brand_sizes else None}
                </View>}

                {key == "shape" and <View style={styles.card}>
                    {labelled_row("MEASURE IN", unit_switch("in", "cm", measure_unit, lambda (u: str) { measure_unit = u; waist = ""; hips = ""; }))}
                    <Pressable onPress={lambda { show_measure_guide = not show_measure_guide; }}>
                        <Text style={styles.link}>{"Hide the measuring guide" if show_measure_guide else "How do I measure? (takes a minute with a soft tape)"}</Text>
                    </Pressable>
                    {(<View style={styles.cardSoft}>
                        <Text style={styles.small}>Use a soft tape over light clothing, snug but not tight, and keep it level all the way round.</Text>
                        <Text style={styles.small}>Waist: around the narrowest part of your torso, usually just above the belly button.</Text>
                        <Text style={styles.small}>Hips: around the fullest part of your hips and seat, feet together.</Text>
                        <Text style={styles.small}>No tape? Skip this: your usual sizes already help a lot.</Text>
                    </View>) if show_measure_guide else None}
                    <View style={{"flexDirection": "row", "gap": 10}}>
                        <Dropdown label={"WAIST (" + measure_unit + ")"} value={waist} options={waist_values} on_pick={lambda (v: str) { waist = v; }} placeholder="Pick"/>
                        <Dropdown label={"HIPS (" + measure_unit + ")"} value={hips} options={hip_values} on_pick={lambda (v: str) { hips = v; }} placeholder="Pick"/>
                    </View>

                    <Text style={styles.label}>BODY SHAPE</Text>
                    <View style={{"flexDirection": "row", "flexWrap": "wrap", "gap": 12}}>
                        {[
                            <Pressable key={shape} style={[styles.shapeCard, {"width": card_width}, styles.shapeCardOn if body_shape == shape else {}]} onPress={lambda { body_shape = "" if body_shape == shape else shape; }}>
                                <Image source={{"uri": BODY_SHAPE_IMAGES[shape]}} style={{"width": card_width - 20, "height": 170}} resizeMode="contain"/>
                                <Text style={[styles.optionText, {"fontWeight": "bold"}]}>{shape}</Text>
                                <Text style={[styles.small, {"textAlign": "center", "fontSize": 12}]}>{SHAPE_HINTS[shape]}</Text>
                            </Pressable>
                            for shape in options["body_shapes"]
                        ]}
                    </View>
                    <Text style={[styles.small, {"fontSize": 12}]}>{"Not sure? Pick the closest, or skip. " + BODY_SHAPE_CREDIT}</Text>
                </View>}

                {key == "stores" and <View style={{"gap": 14}}>
                    {multi("stores", selected_stores, options["stores"] + [s for s in selected_stores if s not in options["stores"]], lambda (v: list[str]) { selected_stores = v; })}
                    {custom_row("store", store_draft, "Another store you love")}
                </View>}
                {key == "brands" and <View style={{"gap": 14}}>
                    {multi("brands", selected_brands, options["brands"] + [b for b in selected_brands if b not in options["brands"]], lambda (v: list[str]) { selected_brands = v; })}
                    {custom_row("brand", brand_draft, "Another brand you wear")}
                </View>}
                {key == "inspiration" and <View style={styles.card}>
                    <Text style={styles.label}>NAME SOMEONE YOU ADMIRE</Text>
                    <TextInput style={styles.input} value={inspiration} placeholder="e.g. Zendaya, Emma Chamberlain" placeholderTextColor={C["copySoft"]} onChangeText={lambda (t: str) { inspiration = t; }}/>
                </View>}
                {key == "mbti" and <View style={styles.optionColumns}>{[<OptionPill key={x} label={x} active={mbti == x} half={True} spaced={True} on_press={lambda { mbti = "" if mbti == x else x; }}/> for x in options["mbti"]]}</View>}
                {key == "zodiac" and <View style={styles.optionColumns}>{[<OptionPill key={x} label={x} active={zodiac == x} half={True} on_press={lambda { zodiac = "" if zodiac == x else x; }}/> for x in options["zodiac"]]}</View>}

                <View style={styles.spacer}/>
                <View style={styles.footer}>
                    <PillButton label={button_label} disabled={not can_continue} on_press={lambda { if can_continue { step = step + 1; } }}/>
                    {(<Text style={styles.footnote}>{"Pick at least one to continue" if picks == 0 else " "}</Text>) if required else None}
                </View>
                </View>
            </Reveal>}

            {step == GENERATING and <Reveal key="generating" grow={True}>
                <View style={styles.hero}>
                    <Pulse/>
                    <View style={{"height": 8}}/>
                    <Text style={styles.lead}>Generating results…</Text>
                    <Text style={styles.leadSmall}>This might take a couple seconds</Text>
                </View>
            </Reveal>}

            {step == RESULT and <Reveal key="result" grow={True}>
                <View style={{"gap": 14, "alignItems": "center", "paddingTop": 10}}>
                    <Text style={styles.hint}>We think your style is:</Text>
                    <Text style={styles.resultName}>{result_name}</Text>
                    <Text style={styles.resultCopy}>{result_copy}</Text>
                    <Text style={[styles.headlineSmall, {"marginTop": 12}]}>Your color palette</Text>
                    <View style={styles.swatches}>{[<View key={pair[0]} style={[styles.swatch, {"backgroundColor": pair[1]}]}/> for pair in indexed(result_palette)]}</View>
                </View>
                <View style={styles.spacer}/>
                <View style={styles.footer}>
                    <Text style={styles.hint}>Ready to plan outfits?</Text>
                    <PillButton label="Let's go!" on_press={lambda { step = WELCOME; }}/>
                    <Text style={[styles.hint, {"marginTop": 14}]}>Do you disagree with the results?</Text>
                    <View style={{"flexDirection": "row", "gap": 12, "justifyContent": "center"}}>
                        <PillButton label="Take quiz again" small={True} arrow={False} on_press={lambda { step = FIRST; }}/>
                        <PillButton label="Describe my style" small={True} arrow={False} on_press={lambda { step = DESCRIBE; }}/>
                    </View>
                </View>
            </Reveal>}

            {step == DESCRIBE and <Reveal key="describe" grow={True}>
                <View style={{"gap": 16, "alignItems": "center", "paddingTop": 24}}>
                    <Text style={styles.headline}>Describe your style in words</Text>
                    <Text style={styles.resultCopy}>Include information like what colors you like, if you prefer casual or formal, if you wear a lot of accessories, etc.</Text>
                    <TextInput
                        style={[styles.textArea, {"width": "100%"}]}
                        value={style_notes}
                        placeholder="Write here…"
                        placeholderTextColor={C["copySoft"]}
                        multiline={True}
                        numberOfLines={6}
                        onChangeText={lambda (t: str) { style_notes = t; }}
                    />
                </View>
                <View style={styles.footer}>
                    <PillButton label="Done!" arrow={False} disabled={not style_notes.strip()} on_press={lambda { if style_notes.strip() { step = GENERATING; } }}/>
                </View>
            </Reveal>}

            {step == WELCOME and <Reveal key="welcome" grow={True} delay={150}>
                <View style={styles.hero}>
                    <Text style={styles.leadSmall}>Welcome to</Text>
                    <Text style={styles.logoSmall}>tyyli</Text>
                </View>
            </Reveal>}
        </ScrollView>
    </View>;
}
