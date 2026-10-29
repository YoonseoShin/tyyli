"""Chat with the styling assistant."""
import from "@jac/mobui" { ActivityIndicator, Image, Linking, Platform, Pressable, ScrollView, Text, TextInput, View }
import from ..components.Button { Button }
import from ..models { ChatMessage }
import from ..photo_storage { resolve_clothing_image_uri }
import from ..storage { ClothingItem }
import from ..ui.kit { C, ui }


glob SUGGESTIONS: list[str] = [
    "What should I wear tonight?",
    "Put together an outfit for class tomorrow",
    "How do I style my favourite jacket?",
    "What should I buy next?"
];


def:pub ChatScreen(
    messages: list[ChatMessage],
    sending: bool,
    clothes: list[ClothingItem],
    on_send: Callable[[str], None],
    on_edit: Callable[[int], None] | None = None,
    keyboard_height: float = 0.0
) -> JsxElement {
    has draft: str = "",
        scroll_ref: Ref[any] = Ref();

    def scroll_to_latest {
        _ = setTimeout(
            lambda {
                scroller: any = scroll_ref.current;
                if scroller { scroller.scrollToEnd({"animated": True}); }
            },
            60
        );
    }

    def start_edit(index: int, text: str) {
        if sending { return; }
        draft = text;
        if on_edit { on_edit(index); }
        scroll_to_latest();
    }

    def submit {
        text = draft.strip();
        if not text or sending { return; }
        draft = "";
        on_send(text);
    }

    def items_for(ids: list[str]) -> list[ClothingItem] {
        by_id = {c.clothing_item_id: c for c in clothes};
        return [by_id[i] for i in ids if i in by_id];
    }

    # Expo Go on iOS can ignore KeyboardAvoidingView when the screen is nested
    # inside our custom tab shell. Reserve the measured keyboard space directly
    # so the composer always sits immediately above the keyboard.
    keyboard_inset = keyboard_height if Platform.OS == "ios" else 0.0;

    return <View style={ui.screen}>
        <ScrollView
            ref={scroll_ref}
            style={ui.flex1}
            contentContainerStyle={ui.page}
            keyboardShouldPersistTaps="handled"
            keyboardDismissMode="interactive"
            onContentSizeChange={lambda (_width: float, _height: float) { scroll_to_latest(); }}
        >
            <Text style={ui.title}>Stylist</Text>
            {(
                <View style={{"gap": 8}}>
                    <Text style={ui.muted}>Ask what to wear, how to style an item, or what fits your plans. I know your closet, the weather and your calendar.</Text>
                    <View style={ui.wrap}>
                        {[
                            <View key={s} style={[ui.chip, {"backgroundColor": "#E2D1C2", "borderWidth": 1, "borderColor": "#D2BBA8"}]}>
                                <Text style={ui.chipText} onPress={lambda { draft = ""; on_send(s); }}>{s}</Text>
                            </View>
                            for s in SUGGESTIONS
                        ]}
                    </View>
                </View>
            ) if not messages else None}
            {[
                <View key={str(n)} style={{"gap": 6}}>
                    <View style={ui.bubbleUser if m.role == "user" else ui.bubbleBot}>
                        <Text style={ui.bubbleUserText if m.role == "user" else ui.body}>{m.text}</Text>
                    </View>
                    {(
                        <Pressable style={{"alignSelf": "flex-end"}} onPress={lambda { start_edit(n, m.text); }}>
                            <Text style={ui.link}>Edit & resend</Text>
                        </Pressable>
                    ) if m.role == "user" and not sending else None}
                    {(
                        <ScrollView horizontal={True} showsHorizontalScrollIndicator={False}>
                            <View style={ui.row}>
                                {[
                                    <View key={item.clothing_item_id} style={{"width": 84, "gap": 2}}>
                                        <Image source={{"uri": resolve_clothing_image_uri(item.image_path)}} style={[ui.thumb, {"width": 84, "height": 84}]} resizeMode="cover"/>
                                        <Text style={ui.muted} numberOfLines={2}>{item.name}</Text>
                                    </View>
                                    for item in items_for(m.clothing_item_ids)
                                ]}
                            </View>
                        </ScrollView>
                    ) if m.role == "assistant" and m.clothing_item_ids else None}
                    {(
                        <View style={{"gap": 4}}>
                            <Text style={ui.muted}>Shop the pieces (tap to open):</Text>
                            <ScrollView horizontal={True} showsHorizontalScrollIndicator={False}>
                                <View style={ui.row}>
                                    {[
                                        <Pressable key={p.link + p.title} style={[ui.card, {"width": 150, "padding": 8, "gap": 4}]} onPress={lambda { Linking.openURL(p.link); }}>
                                            <Image source={{"uri": p.thumbnail}} style={{"width": "100%", "height": 120, "borderRadius": 10, "backgroundColor": C.soft}} resizeMode="contain"/>
                                            <Text style={ui.body} numberOfLines={2}>{p.title}</Text>
                                            <Text style={ui.muted} numberOfLines={1}>{(p.price + " · " if p.price else "") + p.source}</Text>
                                            {(<Text style={ui.muted} numberOfLines={2}>{p.reason}</Text>) if p.reason else None}
                                        </Pressable>
                                        for p in m.shop_items
                                    ]}
                                </View>
                            </ScrollView>
                        </View>
                    ) if m.role == "assistant" and m.shop_items else None}
                </View>
                for (n, m) in enumerate(messages)
            ]}
            {(
                <View style={[ui.bubbleBot, ui.row]}>
                    <ActivityIndicator size="small" color={C.accent}/>
                    <Text style={ui.muted}>Thinking...</Text>
                </View>
            ) if sending else None}
        </ScrollView>
        <View style={[ui.row, {"padding": 12, "marginBottom": keyboard_inset, "backgroundColor": C.bg, "borderTopWidth": 1, "borderColor": C.line}]}>
            <TextInput
                style={ui.input}
                value={draft}
                placeholder="What should I wear today?"
                onChangeText={lambda (t: str) { draft = t; }}
                onFocus={lambda { scroll_to_latest(); }}
                onSubmitEditing={lambda { submit(); }}
                returnKeyType="send"
                editable={not sending}
            />
            <Button label="Send" grow={False} disabled={sending or not draft.strip()} busy={sending} on_press={lambda { submit(); }}/>
        </View>
    </View>;
}
