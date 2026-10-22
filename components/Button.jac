"""Buttons with press feedback, a disabled look, and an optional busy spinner."""
import from "@jac/mobui" { ActivityIndicator, Pressable, Text, View }
import from ..ui.kit { C, ui }


# kind: "primary" (accent), "ghost" (soft), or "danger" (red).
# grow: stretch to fill its row (False for a button next to a text input).
def:pub Button(
    label: str,
    on_press: Callable[[], None],
    kind: str = "primary",
    disabled: bool = False,
    busy: bool = False,
    grow: bool = True
) -> JsxElement {
    has pressed: bool = False;
    ghost = kind == "ghost";
    danger = kind == "danger";
    text_color = C.ink if ghost else C.accent_text;
    return <Pressable
        style={[
            ui.button,
            ui.buttonGhost if ghost else None,
            ui.buttonDanger if danger else None,
            ui.flex1 if grow else None,
            {"opacity": 0.45 if disabled else (0.6 if pressed else 1.0)}
        ]}
        disabled={disabled}
        onPressIn={lambda { pressed = True; }}
        onPressOut={lambda { pressed = False; }}
        onPress={lambda { on_press(); }}
    >
        <View style={ui.row}>
            {(<ActivityIndicator size="small" color={text_color}/>) if busy else None}
            <Text style={[ui.buttonText, {"color": text_color}]}>{label}</Text>
        </View>
    </Pressable>;
}


# A "still working" banner for anything that takes more than a moment.
def:pub Busy(label: str) -> JsxElement {
    return <View style={[ui.card, ui.row]}>
        <ActivityIndicator size="small" color={C.accent}/>
        <Text style={[ui.body, ui.flex1]}>{label}</Text>
    </View>;
}
