"""Pill buttons with press feedback, a disabled look, and an optional busy spinner."""
import from "@jac/mobui" { ActivityIndicator, Pressable, Text, View }
import from .AppIcon { AppIcon }
import from ..ui.kit { C, ui }


# kind: "primary" (espresso), "secondary" (glass with a white edge), or
#       "danger" (red). "ghost" is the older name for "secondary".
# grow: stretch to fill its row (False for a button next to a text input).
# icon: optional leading icon name (MaterialCommunityIcons), e.g. "check".
# icon_color: overrides the icon's color (e.g. C.success for a confirmed state).
def:pub Button(
    label: str,
    on_press: Callable[[], None],
    kind: str = "primary",
    disabled: bool = False,
    busy: bool = False,
    grow: bool = True,
    icon: str = "",
    icon_color: str = ""
) -> JsxElement {
    has pressed: bool = False;
    secondary = kind == "secondary" or kind == "ghost";
    danger = kind == "danger";
    text_color = C.primary if secondary else C.cta_text;
    default_icon_color = text_color if secondary or danger else C.accent;
    return <Pressable
        accessibilityRole="button"
        accessibilityLabel={label}
        accessibilityState={{"disabled": disabled, "busy": busy}}
        style={[
            ui.button,
            ui.buttonGhost if secondary else None,
            ui.buttonDanger if danger else None,
            ui.flex1 if grow else None,
            {"opacity": 0.45 if disabled else (0.75 if pressed else 1.0)}
        ]}
        disabled={disabled}
        onPressIn={lambda { pressed = True; }}
        onPressOut={lambda { pressed = False; }}
        onPress={lambda { on_press(); }}
    >
        <View style={ui.row}>
            {(<ActivityIndicator size="small" color={text_color}/>) if busy else None}
            {(<AppIcon name={icon} size={17} color={icon_color or default_icon_color}/>) if icon and not busy else None}
            <Text style={[ui.buttonText, ui.buttonGhostText if secondary else None]}>{label}</Text>
        </View>
    </Pressable>;
}


# A "still working" banner for anything that takes more than a moment.
def:pub Busy(label: str) -> JsxElement {
    return <View style={[ui.card, ui.row]} accessibilityLiveRegion="polite">
        <ActivityIndicator size="small" color={C.accent}/>
        <Text style={[ui.textBody, ui.flex1]}>{label}</Text>
    </View>;
}
