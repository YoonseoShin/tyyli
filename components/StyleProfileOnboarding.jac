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
    "top_sizes": ["XXS", "XS", "S", "M", "L", "XL", "XXL"],
    "body_shapes": ["Hourglass", "Pear", "Apple", "Rectangle", "Inverted triangle", "Athletic", "Petite", "Tall"],
    "stores": ["Aritzia", "Zara", "H&M", "Uniqlo", "Gap", "Banana Republic", "Abercrombie", "American Eagle", "Urban Outfitters", "Nordstrom", "Madewell", "J.Crew", "Everlane", "Lululemon", "Brandy Melville", "Garage", "Free People", "Amazon", "Thrift / vintage"],
    "brands": ["Nike", "Adidas", "New Balance", "Levi's", "Polo Ralph Lauren", "Carhartt", "The North Face", "Patagonia", "Arc'teryx", "Alo", "Skims", "Reformation", "COS", "Ganni", "Sézane", "Alex Mill", "Dr. Martens", "Birkenstock", "UGG"],
    "occasions": ["School", "Work", "Casual everyday", "Going out", "Dates", "Formal events", "Gym"],
    "mbti": ["INTJ", "INTP", "ENTJ", "ENTP", "INFJ", "INFP", "ENFJ", "ENFP", "ISTJ", "ISFJ", "ESTJ", "ESFJ", "ISTP", "ISFP", "ESTP", "ESFP"],
    "zodiac": ["Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo", "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"]
};

# Steps: 0 welcome, 1 styles, 2 colors, 3 body & sizes, 4 stores, 5 brands,
# 6 inspiration, 7 MBTI, 8 zodiac, 9 occasions, 10 summary.
glob TOTAL: int = 10,
     OPTIONAL_STEPS: list[int] = [3, 4, 5, 6, 7, 8];

def:pub StyleProfileOnboarding(
    on_finish: Callable[[StyleProfile], None] | None = None,
    initial: StyleProfile | None = None
) -> JsxElement {
    has step: int = 0,
        selected_styles: list[str] = initial.preferred_styles if initial else [],
        selected_colors: list[str] = initial.preferred_colors if initial else [],
        selected_occasions: list[str] = initial.occasions if initial else [],
        inspiration: str = initial.inspiration if initial else "",
        mbti: str = initial.mbti if initial else "",
        zodiac: str = initial.zodiac if initial else "",
        shop_section: str = initial.shop_section if initial else "",
        height: str = initial.height if initial else "",
        weight: str = initial.weight if initial else "",
        top_size: str = initial.top_size if initial else "",
        bottom_size: str = initial.bottom_size if initial else "",
        shoe_size: str = initial.shoe_size if initial else "",
        body_shape: str = initial.body_shape if initial else "",
        selected_stores: list[str] = initial.favorite_stores if initial else [],
        selected_brands: list[str] = initial.favorite_brands if initial else [],
        store_draft: str = "",
        brand_draft: str = "";
    viewport = useWindowDimensions();
    progress = (step * 100) / TOTAL;

    def toggle(values: list[str], value: str) -> list[str] {
        if value in values { return [v for v in values if v != value]; }
        return values + [value];
    }

    def chip(label: str, active: bool, on_press: Callable[[], None]) -> JsxElement {
        return <Pressable key={label} style={[styles.chip, styles.chipOn if active else {}]} onPress={lambda { on_press(); }}>
            <Text style={[styles.chipText, styles.chipTextOn if active else {}]}>{label}</Text>
        </Pressable>;
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

    def go_next {
        if step < TOTAL { step = step + 1; }
    }
    def go_back {
        if step > 0 { step = step - 1; }
    }

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
                height=height,
                weight=weight,
                top_size=top_size,
                bottom_size=bottom_size,
                shoe_size=shoe_size,
                body_shape=body_shape,
                favorite_stores=selected_stores,
                favorite_brands=selected_brands
            ));
        }
    }

    def field(label: str, value: str, placeholder: str, on_change: Callable[[str], None]) -> JsxElement {
        return <View style={{"gap": 6}}>
            <Text style={styles.inputLabel}>{label}</Text>
            <TextInput style={styles.input} value={value} placeholder={placeholder} placeholderTextColor={C["muted"]} onChangeText={lambda (t: str) { on_change(t); }}/>
        </View>;
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

    titles = [
        "Let's find your style.", "What styles best describe you?", "What colors do you like wearing?",
        "Tell us about your fit.", "Where do you love to shop?", "Brands you keep coming back to?",
        "Whose style inspires you?", "Want to add a little personality?", "Want to add a little personality?",
        "What do you usually dress for?", "Your style profile is ready."
    ];
    subtitles = [
        "Answer a few quick questions so we can learn what you like.", "Choose all that feel like you.", "Pick the colors you reach for most.",
        "Sizes help the stylist suggest pieces that actually fit. All optional.", "Pick your go-to stores, or add your own.", "Pick the labels you wear most, or add your own.",
        "A celebrity, creator, or anyone whose looks you love.", "Just for fun. Your style choices matter most.", "Just for fun. Your style choices matter most.",
        "Select the moments you want outfits for.", "A little more you in every outfit."
    ];

    return <ScrollView style={[styles.screen, {height: viewport.height}]} contentContainerStyle={styles.page} keyboardShouldPersistTaps="handled" automaticallyAdjustKeyboardInsets={True}>
        <View style={styles.topbar}>
            <Text style={styles.brand}>tyyli<Text style={styles.brandDot}>.</Text></Text>
            {(<Text style={styles.stepLabel}>{str(step) + " / " + str(TOTAL)}</Text>) if step > 0 and step < TOTAL else <Text style={styles.stepLabel}>YOUR PERSONAL STYLIST</Text>}
        </View>
        {(<View style={styles.progressTrack}><View style={[styles.progressFill, {width: str(progress) + "%"}]}/></View>) if step > 0 and step < TOTAL else <View style={styles.progressPlaceholder}/>}

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
        {step == 3 and <View style={[styles.inputCard, {"gap": 14}]}>
            <Text style={styles.inputLabel}>I SHOP IN</Text>
            <View style={styles.optionGrid}>{[chip(x, shop_section == x, lambda { shop_section = "" if shop_section == x else x; }) for x in options["sections"]]}</View>
            <View style={{"flexDirection": "row", "gap": 8}}>
                <View style={{"flex": 1}}>{field("HEIGHT", height, "e.g. 5'6\" or 168 cm", lambda (t: str) { height = t; })}</View>
                <View style={{"flex": 1}}>{field("WEIGHT", weight, "e.g. 135 lb", lambda (t: str) { weight = t; })}</View>
            </View>
            <Text style={styles.inputLabel}>TOP SIZE</Text>
            <View style={styles.optionGrid}>{[chip(x, top_size == x, lambda { top_size = "" if top_size == x else x; }) for x in options["top_sizes"]]}</View>
            <View style={{"flexDirection": "row", "gap": 8}}>
                <View style={{"flex": 1}}>{field("BOTTOM SIZE", bottom_size, "e.g. 27, 30x32, M", lambda (t: str) { bottom_size = t; })}</View>
                <View style={{"flex": 1}}>{field("SHOE SIZE", shoe_size, "e.g. 8 US", lambda (t: str) { shoe_size = t; })}</View>
            </View>
            <Text style={styles.inputLabel}>BODY SHAPE</Text>
            <View style={styles.optionGrid}>{[chip(x, body_shape == x, lambda { body_shape = "" if body_shape == x else x; }) for x in options["body_shapes"]]}</View>
            <Text style={styles.inputHint}>Only used to tailor suggestions. Stays on your phone.</Text>
        </View>}
        {step == 4 and <View style={{"gap": 12}}>
            <View style={styles.optionGrid}>{[chip(x, x in selected_stores, lambda { selected_stores = toggle(selected_stores, x); }) for x in options["stores"] + [s for s in selected_stores if s not in options["stores"]]]}</View>
            {custom_row("store", store_draft, "Another store you love")}
        </View>}
        {step == 5 and <View style={{"gap": 12}}>
            <View style={styles.optionGrid}>{[chip(x, x in selected_brands, lambda { selected_brands = toggle(selected_brands, x); }) for x in options["brands"] + [b for b in selected_brands if b not in options["brands"]]]}</View>
            {custom_row("brand", brand_draft, "Another brand you wear")}
        </View>}
        {step == 6 and <View style={styles.inputCard}>
            <Text style={styles.inputLabel}>NAME SOMEONE YOU ADMIRE</Text>
            <TextInput style={styles.input} value={inspiration} placeholder="e.g. Zendaya, Emma Chamberlain" placeholderTextColor={C["muted"]} onChangeText={lambda (t: str) { inspiration = t; }}/>
            <Text style={styles.inputHint}>Optional — skip if no one comes to mind.</Text>
        </View>}
        {step == 7 and <View style={styles.optionGrid}>{[chip(x, mbti == x, lambda { mbti = "" if mbti == x else x; }) for x in options["mbti"]]}</View>}
        {step == 8 and <View style={styles.optionGrid}>{[chip(x, zodiac == x, lambda { zodiac = "" if zodiac == x else x; }) for x in options["zodiac"]]}</View>}
        {step == 9 and <View style={styles.optionGrid}>{[chip(x, x in selected_occasions, lambda { selected_occasions = toggle(selected_occasions, x); }) for x in options["occasions"]]}</View>}
        {step == TOTAL and <View style={styles.summaryCard}>
            <View style={styles.summaryHeader}><Text style={styles.summaryMark}>t.</Text><Text style={styles.summaryCaption}>YOUR STYLE NOTES</Text></View>
            <View style={styles.summaryRow}><Text style={styles.summaryLabel}>THE VIBE</Text><Text style={styles.summaryValue}>{", ".join(selected_styles) if selected_styles else "Still discovering"}</Text></View>
            <View style={styles.summaryRow}><Text style={styles.summaryLabel}>COLORS</Text><Text style={styles.summaryValue}>{", ".join(selected_colors) if selected_colors else "Open to anything"}</Text></View>
            <View style={styles.summaryRow}><Text style={styles.summaryLabel}>FIT</Text><Text style={styles.summaryValue}>{" · ".join([v for v in [shop_section, height, weight, top_size, bottom_size, shoe_size, body_shape] if v]) or "Not specified"}</Text></View>
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
