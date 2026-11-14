"""A clear 1–5 formality scale shared by schedule forms."""
import from "@jac/mobui" { Pressable, Text, View }
import from ..ui.kit { C, ui }


def:pub FormalityScale(value: int, on_change: Callable[[int], None], title: str = "FORMALITY") -> JsxElement {
    labels: list[str] = ["Very casual", "Casual", "Smart casual", "Business", "Formal"];
    selected = max(1, min(5, value));
    return <View style={{"gap": 10}}>
        <View style={ui.rowBetween}>
            <Text style={ui.label}>{title}</Text>
            <View style={[ui.chip, ui.chipOn, {"paddingHorizontal": 12, "paddingVertical": 6}]}>
                <Text style={ui.chipTextOn}>{labels[selected - 1]}</Text>
            </View>
        </View>
        <View style={[ui.row, {"gap": 7}]}>
            {[
                <Pressable
                    key={str(index + 1)}
                    accessibilityRole="button"
                    accessibilityLabel={str(index + 1) + " out of 5, " + label}
                    accessibilityState={{"selected": selected == index + 1}}
                    style={[
                        {"flex": 1, "height": 42, "borderRadius": 21, "borderWidth": 1, "borderColor": C.divider, "backgroundColor": C.surface, "alignItems": "center", "justifyContent": "center"},
                        {"backgroundColor": C.primary, "borderColor": C.primary} if selected == index + 1 else None
                    ]}
                    onPress={lambda { on_change(index + 1); }}
                >
                    <Text style={[ui.bodyBold, {"color": C.cta_text if selected == index + 1 else C.text_primary}]}>{str(index + 1)}</Text>
                </Pressable>
                for (index, label) in enumerate(labels)
            ]}
        </View>
    </View>;
}
