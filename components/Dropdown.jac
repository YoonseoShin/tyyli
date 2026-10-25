"""A dropdown menu: a field that opens a scrollable list of options in a modal."""
import from "@jac/mobui" { Modal, Pressable, ScrollView, Text, View, useWindowDimensions }
import from ..ui.kit { C, ui }


def:pub Dropdown(
    label: str,
    value: str,
    options: list[str],
    on_pick: Callable[[str], None],
    placeholder: str = "Select",
    hint: str = ""
) -> JsxElement {
    has open: bool = False;
    viewport = useWindowDimensions();

    return <View style={{"gap": 6, "flex": 1}}>
        {(<Text style={ui.label}>{label}</Text>) if label else None}
        <Pressable
            style={[ui.input, ui.rowBetween, {"flex": 0}]}
            onPress={lambda { open = True; }}
        >
            <Text style={[ui.body, {"color": C.ink if value else C.muted}]}>{value or placeholder}</Text>
            <Text style={ui.muted}>▾</Text>
        </Pressable>
        {(<Text style={ui.muted}>{hint}</Text>) if hint else None}
        <Modal visible={open} transparent={True} animationType="fade" onRequestClose={lambda { open = False; }}>
            <Pressable style={{"flex": 1, "backgroundColor": "rgba(0,0,0,0.35)", "justifyContent": "flex-end"}} onPress={lambda { open = False; }}>
                <View style={[ui.card, {"borderBottomLeftRadius": 0, "borderBottomRightRadius": 0, "maxHeight": viewport.height * 0.6, "paddingBottom": 32}]}>
                    <View style={ui.rowBetween}>
                        <Text style={ui.heading}>{label or placeholder}</Text>
                        <Pressable onPress={lambda { open = False; }}>
                            <Text style={ui.link}>Done</Text>
                        </Pressable>
                    </View>
                    <ScrollView>
                        {(
                            <Pressable style={{"paddingVertical": 12}} onPress={lambda { on_pick(""); open = False; }}>
                                <Text style={ui.muted}>Clear selection</Text>
                            </Pressable>
                        ) if value else None}
                        {[
                            <Pressable
                                key={opt}
                                style={{"paddingVertical": 12, "borderTopWidth": 1, "borderColor": C.line, "flexDirection": "row", "justifyContent": "space-between"}}
                                onPress={lambda { on_pick(opt); open = False; }}
                            >
                                <Text style={[ui.body, {"fontWeight": "bold" if opt == value else "normal"}]}>{opt}</Text>
                                {(<Text style={ui.link}>✓</Text>) if opt == value else None}
                            </Pressable>
                            for opt in options
                        ]}
                    </ScrollView>
                </View>
            </Pressable>
        </Modal>
    </View>;
}
