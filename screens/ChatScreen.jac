"""Chat with the styling assistant."""
import from "@jac/mobui" { ActivityIndicator, Image, KeyboardAvoidingView, Platform, ScrollView, Text, TextInput, View }
import from ..components.Button { Button }
import from ..models { ChatMessage }
import from ..photo_storage { resolve_clothing_image_uri }
import from ..storage { ClothingItem }
import from ..ui.kit { C, ui }


glob SUGGESTIONS: list[str] = [
    "What should I wear tonight?",
    "Put together an outfit for class tomorrow",
    "How do I style my favourite jacket?",
    "What's missing from my closet?"
];


def:pub ChatScreen(
    messages: list[ChatMessage],
    sending: bool,
    clothes: list[ClothingItem],
    on_send: Callable[[str], None]
) -> JsxElement {
    has draft: str = "";

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

    return <KeyboardAvoidingView style={ui.screen} behavior={"padding" if Platform.OS == "ios" else "height"}>
        <ScrollView style={ui.flex1} contentContainerStyle={ui.page} keyboardShouldPersistTaps="handled">
            <Text style={ui.title}>Stylist</Text>
            {(
                <View style={{"gap": 8}}>
                    <Text style={ui.muted}>Ask what to wear, how to style an item, or what fits your plans. I know your closet, the weather and your calendar.</Text>
                    <View style={ui.wrap}>
                        {[
                            <View key={s} style={ui.chip}>
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
        <View style={[ui.row, {"padding": 12}]}>
            <TextInput
                style={ui.input}
                value={draft}
                placeholder="What should I wear today?"
                onChangeText={lambda (t: str) { draft = t; }}
                onSubmitEditing={lambda { submit(); }}
                returnKeyType="send"
                editable={not sending}
            />
            <Button label="Send" grow={False} disabled={sending or not draft.strip()} busy={sending} on_press={lambda { submit(); }}/>
        </View>
    </KeyboardAvoidingView>;
}
