"""Tyyli — a thoughtful, personal style discovery."""
import from "@jac/mobui" { View, Text, Pressable, TextInput, ScrollView, useWindowDimensions }
import from .theme { buildStyles }

glob C: dict = {
    "bg": "#F7F4EF", "surface": "#FFFEFC", "ink": "#28251F",
    "muted": "#827B70", "line": "#E6E0D6", "accent": "#725747",
    "accentText": "#FFFFFF", "soft": "#EEE7DE", "sage": "#DCE4D9"
};
glob styles = buildStyles(C);
glob options: dict = {
    "styles": ["Casual", "Minimal", "Streetwear", "Preppy", "Sporty", "Vintage", "Y2K", "Classic", "Business casual", "Romantic", "Edgy", "Bohemian"],
    "colors": ["Black", "White", "Cream", "Brown", "Grey", "Navy", "Blue", "Green", "Red", "Pink", "Yellow", "Purple"],
    "occasions": ["School", "Work", "Casual everyday", "Going out", "Dates", "Formal events", "Gym"],
    "mbti": ["INTJ", "INTP", "ENTJ", "ENTP", "INFJ", "INFP", "ENFJ", "ENFP", "ISTJ", "ISFJ", "ESTJ", "ESFJ", "ISTP", "ISFP", "ESTP", "ESFP"],
    "zodiac": ["Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo", "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"]
};

def:pub StyleProfileOnboarding -> JsxElement {
    has step: int = 0,
        selected_styles: list[str] = [],
        selected_colors: list[str] = [],
        selected_occasions: list[str] = [],
        inspiration: str = "",
        mbti: str = "",
        zodiac: str = "";
    viewport = useWindowDimensions();
    total = 7;
    progress = (step * 100) / total;

    def toggle(values: list[str], value: str) -> list[str] {
        if value in values { return [v for v in values if v != value]; }
        return values + [value];
    }

    def choice(label: str, active: bool) -> JsxElement {
        return <Pressable style={[styles.chip, styles.chipOn if active else {}]} onPress={lambda {
            if step == 1 { selected_styles = toggle(selected_styles, label); }
            elif step == 2 { selected_colors = toggle(selected_colors, label); }
            elif step == 4 { mbti = "" if mbti == label else label; }
            elif step == 5 { zodiac = "" if zodiac == label else label; }
            elif step == 6 { selected_occasions = toggle(selected_occasions, label); }
        }}>
            <Text style={[styles.chipText, styles.chipTextOn if active else {}]}>{label}</Text>
        </Pressable>;
    }

    def go_next {
        if step < total { step = step + 1; }
    }
    def go_back {
        if step > 0 { step = step - 1; }
    }
    def skip_optional {
        if step == 3 { step = 4; }
        elif step == 4 { step = 5; }
        elif step == 5 { step = 6; }
        else { go_next(); }
    }

    title = "Let's find your style." if step == 0 else "What styles best describe you?" if step == 1 else "What colors do you like wearing?" if step == 2 else "Whose style inspires you?" if step == 3 else "Want to add a little personality?" if step == 4 or step == 5 else "What do you usually dress for?" if step == 6 else "Your style profile is ready.";
    subtitle = "Answer a few quick questions so we can learn what you like." if step == 0 else "Choose all that feel like you." if step == 1 else "Pick the colors you reach for most." if step == 2 else "A celebrity, creator, or anyone whose looks you love." if step == 3 else "Just for fun. Your style choices matter most." if step == 4 or step == 5 else "Select the moments you want outfits for." if step == 6 else "A little more you in every outfit.";

    return <ScrollView style={[styles.screen, {height: viewport.height}]} contentContainerStyle={styles.page}>
        <View style={styles.topbar}>
            <Text style={styles.brand}>tyyli<Text style={styles.brandDot}>.</Text></Text>
            {(<Text style={styles.stepLabel}>{str(step) + " / " + str(total)}</Text>) if step > 0 and step < 7 else <Text style={styles.stepLabel}>YOUR PERSONAL STYLIST</Text>}
        </View>
        {(<View style={styles.progressTrack}><View style={[styles.progressFill, {width: str(progress) + "%"}]}/></View>) if step > 0 and step < 7 else <View style={styles.progressPlaceholder}/>}

        <View style={styles.heroArt}>
            <View style={styles.artOrb}><Text style={styles.artSerif}>t</Text></View>
            <View style={styles.artNote}><Text style={styles.artNoteText}>A style that's yours</Text></View>
            <View style={styles.artFlower}><Text style={styles.flowerText}>✳</Text></View>
        </View>

        <View style={styles.headingBlock}>
            <Text style={styles.eyebrow}>{"STYLE DISCOVERY  /  " + ("0" + str(step + 1))}</Text>
            <Text style={styles.title}>{title}</Text>
            <Text style={styles.subtitle}>{subtitle}</Text>
        </View>

        {step == 0 and <View style={styles.welcomeNote}><Text style={styles.welcomeQuote}>"Your wardrobe, with a little more you."</Text><Text style={styles.noteSmall}>A few quick picks. About a minute.</Text></View>}
        {step == 1 and <View style={styles.optionGrid}>{[choice(x, x in selected_styles) for x in options["styles"]]}</View>}
        {step == 2 and <View style={styles.optionGrid}>{[choice(x, x in selected_colors) for x in options["colors"]]}</View>}
        {step == 3 and <View style={styles.inputCard}>
            <Text style={styles.inputLabel}>NAME SOMEONE YOU ADMIRE</Text>
            <TextInput style={styles.input} value={inspiration} placeholder="e.g. Zendaya, Emma Chamberlain" placeholderTextColor={C["muted"]} onChangeText={lambda (t: str) { inspiration = t; }}/>
            <Text style={styles.inputHint}>Optional — skip if no one comes to mind.</Text>
        </View>}
        {step == 4 and <View style={styles.optionGrid}>{[choice(x, mbti == x) for x in options["mbti"]]}</View>}
        {step == 5 and <View style={styles.optionGrid}>{[choice(x, zodiac == x) for x in options["zodiac"]]}</View>}
        {step == 6 and <View style={styles.optionGrid}>{[choice(x, x in selected_occasions) for x in options["occasions"]]}</View>}
        {step == 7 and <View style={styles.summaryCard}>
            <View style={styles.summaryHeader}><Text style={styles.summaryMark}>t.</Text><Text style={styles.summaryCaption}>YOUR STYLE NOTES</Text></View>
            <View style={styles.summaryRow}><Text style={styles.summaryLabel}>THE VIBE</Text><Text style={styles.summaryValue}>{", ".join(selected_styles) if selected_styles else "Still discovering"}</Text></View>
            <View style={styles.summaryRow}><Text style={styles.summaryLabel}>COLORS</Text><Text style={styles.summaryValue}>{", ".join(selected_colors) if selected_colors else "Open to anything"}</Text></View>
            <View style={styles.summaryRow}><Text style={styles.summaryLabel}>INSPIRED BY</Text><Text style={styles.summaryValue}>{inspiration if inspiration else "Not specified"}</Text></View>
            <View style={styles.summaryRow}><Text style={styles.summaryLabel}>PERSONALITY</Text><Text style={styles.summaryValue}>{(mbti if mbti else "") + (" · " if mbti and zodiac else "") + (zodiac if zodiac else "Not specified" if not mbti else "")}</Text></View>
            <View style={styles.summaryRow}><Text style={styles.summaryLabel}>DRESSING FOR</Text><Text style={styles.summaryValue}>{", ".join(selected_occasions) if selected_occasions else "Everyday life"}</Text></View>
            <Text style={styles.summaryFooter}>A good outfit starts with knowing what feels like you.</Text>
        </View>}

        <View style={styles.footer}>
            {step > 0 and <Pressable style={styles.backButton} onPress={lambda { go_back(); }}><Text style={styles.backText}>Back</Text></Pressable>}
            {step == 0 and <View style={styles.backButton}><Text style={styles.timeText}>PERSONALIZED, NOT PRESCRIBED</Text></View>}
            <Pressable style={styles.primaryButton} onPress={lambda {
                if step == 7 { step = 0; selected_styles = []; selected_colors = []; selected_occasions = []; inspiration = ""; mbti = ""; zodiac = ""; }
                else { go_next(); }
            }}>
                <Text style={styles.primaryText}>{"Start styling" if step == 7 else "Let's go" if step == 0 else "Continue"}</Text>
                <Text style={styles.arrow}>→</Text>
            </Pressable>
        </View>
        {step > 2 and step < 6 and <Pressable style={styles.skip} onPress={lambda { skip_optional(); }}><Text style={styles.skipText}>Skip this question</Text></Pressable>}
        {step == 7 and <Pressable style={styles.skip} onPress={lambda { step = 0; }}><Text style={styles.skipText}>Edit my answers</Text></Pressable>}
    </ScrollView>;
}

def:pub app -> JsxElement {
    return <StyleProfileOnboarding/>;
}
