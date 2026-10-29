"""Building blocks for the onboarding flow: the gradient backdrop with drifting
circles, pill buttons that spring under the finger, selectable option pills,
and a fade-and-rise reveal for each new screen.
"""
import from "@jac/mobui" { Animated, Easing, Platform, Pressable, Text, View }
import from ..theme { BAND_INDEX, C, GRADIENT_BANDS, styles }


glob AnimatedView = Animated.View;
glob AnimatedValue = Animated.Value;
# The native driver is not available on react-native-web.
glob NATIVE_DRIVER: bool = Platform.OS != "web";
glob EASE_OUT = Easing.out(Easing.cubic);
glob EASE_IN_OUT = Easing.inOut(Easing.sin);


def _drift(value: any, distance: float, duration: int) {
    Animated.loop(Animated.sequence([
        Animated.timing(value, {"toValue": distance, "duration": duration, "easing": EASE_IN_OUT, "useNativeDriver": NATIVE_DRIVER}),
        Animated.timing(value, {"toValue": 0.0 - distance, "duration": duration, "easing": EASE_IN_OUT, "useNativeDriver": NATIVE_DRIVER})
    ])).start();
}


# The gradient is stacked strips (no gradient package on either platform);
# three pale circles drift slowly and slide to a new spot on every step.
def:pub Backdrop(width: float, height: float, phase: int = 0) -> JsxElement {
    has drift_a: any = new(AnimatedValue, 0.0),
        drift_b: any = new(AnimatedValue, 0.0),
        drift_c: any = new(AnimatedValue, 0.0),
        shift_a: any = new(AnimatedValue, 0.0),
        shift_b: any = new(AnimatedValue, 0.0),
        shift_c: any = new(AnimatedValue, 0.0);

    can with entry {
        _drift(drift_a, 14.0, 5200);
        _drift(drift_b, 10.0, 6800);
        _drift(drift_c, 12.0, 6000);
    }

    can with [phase] entry {
        # A deterministic, step-dependent offset so the circles wander a little
        # with every screen without ever leaving their corner.
        Animated.parallel([
            Animated.timing(shift_a, {"toValue": ((phase * 37) % 60) - 30, "duration": 900, "easing": EASE_OUT, "useNativeDriver": NATIVE_DRIVER}),
            Animated.timing(shift_b, {"toValue": ((phase * 53) % 80) - 40, "duration": 1100, "easing": EASE_OUT, "useNativeDriver": NATIVE_DRIVER}),
            Animated.timing(shift_c, {"toValue": ((phase * 71) % 50) - 25, "duration": 1000, "easing": EASE_OUT, "useNativeDriver": NATIVE_DRIVER})
        ]).start();
    }

    band_height = height / len(GRADIENT_BANDS) + 1.0;
    big = width * 0.72;
    return <View pointerEvents="none" style={{"position": "absolute", "top": 0, "left": 0, "width": width, "height": height, "overflow": "hidden"}}>
        {[
            <View key={str(i)} style={{"position": "absolute", "left": 0, "right": 0, "top": i * band_height - 1.0, "height": band_height + 1.0, "backgroundColor": GRADIENT_BANDS[i]}}/>
            for i in BAND_INDEX
        ]}
        <AnimatedView style={{"position": "absolute", "top": 0.0 - big * 0.55, "right": 0.0 - big * 0.35, "width": big, "height": big, "borderRadius": 999, "backgroundColor": C["circle"], "opacity": 0.55, "transform": [{"translateX": shift_a}, {"translateY": drift_a}]}}/>
        <AnimatedView style={{"position": "absolute", "bottom": height * 0.04, "left": 0.0 - big * 0.6, "width": big, "height": big, "borderRadius": 999, "backgroundColor": C["circle"], "opacity": 0.45, "transform": [{"translateY": shift_b}, {"translateX": drift_b}]}}/>
        <AnimatedView style={{"position": "absolute", "bottom": 0.0 - big * 0.25, "right": 0.0 - big * 0.4, "width": big * 0.9, "height": big * 0.9, "borderRadius": 999, "backgroundColor": C["circle"], "opacity": 0.35, "transform": [{"translateX": shift_c}, {"translateY": drift_c}]}}/>
    </View>;
}


# Fades and rises its children when mounted; give it a changing `key` to
# replay the entrance on every new screen.
def:pub Reveal(children: any = None, delay: int = 0, distance: float = 18.0, grow: bool = False) -> JsxElement {
    has fade: any = new(AnimatedValue, 0.0),
        rise: any = new(AnimatedValue, distance);

    can with entry {
        Animated.parallel([
            Animated.timing(fade, {"toValue": 1.0, "duration": 460, "delay": delay, "easing": EASE_OUT, "useNativeDriver": NATIVE_DRIVER}),
            Animated.timing(rise, {"toValue": 0.0, "duration": 520, "delay": delay, "easing": EASE_OUT, "useNativeDriver": NATIVE_DRIVER})
        ]).start();
    }

    return <AnimatedView style={[{"opacity": fade, "transform": [{"translateY": rise}]}, {"flex": 1} if grow else {}]}>{children}</AnimatedView>;
}


# A soft breathing circle for the "generating" screen.
def:pub Pulse -> JsxElement {
    has scale: any = new(AnimatedValue, 1.0);

    can with entry {
        Animated.loop(Animated.sequence([
            Animated.timing(scale, {"toValue": 1.12, "duration": 1300, "easing": EASE_IN_OUT, "useNativeDriver": NATIVE_DRIVER}),
            Animated.timing(scale, {"toValue": 0.94, "duration": 1300, "easing": EASE_IN_OUT, "useNativeDriver": NATIVE_DRIVER})
        ])).start();
    }

    return <AnimatedView style={[styles.pulse, {"transform": [{"scale": scale}]}]}/>;
}


# The dark pill button: springs down under the finger, the arrow nudges right.
def:pub PillButton(
    label: str,
    on_press: Callable[[], None],
    arrow: bool = True,
    disabled: bool = False,
    small: bool = False
) -> JsxElement {
    has scale: any = new(AnimatedValue, 1.0),
        nudge: any = new(AnimatedValue, 0.0);

    def press_in {
        Animated.parallel([
            Animated.spring(scale, {"toValue": 0.95, "speed": 40, "bounciness": 4, "useNativeDriver": NATIVE_DRIVER}),
            Animated.timing(nudge, {"toValue": 6.0, "duration": 160, "easing": EASE_OUT, "useNativeDriver": NATIVE_DRIVER})
        ]).start();
    }

    def press_out {
        Animated.parallel([
            Animated.spring(scale, {"toValue": 1.0, "speed": 20, "bounciness": 8, "useNativeDriver": NATIVE_DRIVER}),
            Animated.timing(nudge, {"toValue": 0.0, "duration": 220, "easing": EASE_OUT, "useNativeDriver": NATIVE_DRIVER})
        ]).start();
    }

    return <AnimatedView style={{"transform": [{"scale": scale}], "opacity": 0.4 if disabled else 1.0, "alignSelf": "center"}}>
        <Pressable
            style={[styles.pill, styles.pillSmall if small else {}]}
            disabled={disabled}
            onPressIn={lambda { press_in(); }}
            onPressOut={lambda { press_out(); }}
            onPress={lambda { on_press(); }}
        >
            <Text style={[styles.pillText, styles.pillSmallText if small else {}]}>{label}</Text>
            {(<AnimatedView style={{"transform": [{"translateX": nudge}]}}><Text style={styles.pillArrow}>→</Text></AnimatedView>) if arrow else None}
        </Pressable>
    </AnimatedView>;
}


# A selectable pill: cream when idle, dark when chosen, with a quick bounce.
# `half` lays two per row (used for short single-choice lists like MBTI).
def:pub OptionPill(
    label: str,
    active: bool,
    on_press: Callable[[], None],
    half: bool = False,
    spaced: bool = False
) -> JsxElement {
    has scale: any = new(AnimatedValue, 1.0);

    def bounce {
        Animated.sequence([
            Animated.timing(scale, {"toValue": 0.93, "duration": 80, "easing": EASE_OUT, "useNativeDriver": NATIVE_DRIVER}),
            Animated.spring(scale, {"toValue": 1.0, "speed": 30, "bounciness": 10, "useNativeDriver": NATIVE_DRIVER})
        ]).start();
    }

    return <AnimatedView style={[{"transform": [{"scale": scale}]}, {"width": "48%"} if half else {}]}>
        <Pressable
            style={[styles.option, styles.optionHalf if half else {}, styles.optionOn if active else {}]}
            onPress={lambda { bounce(); on_press(); }}
        >
            <Text style={[styles.optionText, styles.optionTextWide if spaced else {}, styles.optionTextOn if active else {}]}>{label}</Text>
        </Pressable>
    </AnimatedView>;
}


# Small underlined text action ("Skip this question", "Sign in").
def:pub TextLink(label: str, on_press: Callable[[], None], prefix: str = "") -> JsxElement {
    return <Pressable onPress={lambda { on_press(); }} style={{"paddingVertical": 6, "flexDirection": "row", "gap": 4}}>
        {(<Text style={styles.footnote}>{prefix}</Text>) if prefix else None}
        <Text style={[styles.footnote, styles.footnoteLink]}>{label}</Text>
    </Pressable>;
}
