"""Chat with the styling assistant."""
import from "@jac/mobui" { KeyboardAvoidingView, Platform, Pressable, ScrollView, Text, TextInput, View }
import from ..models { ChatMessage }
import from ..ui.kit { ui }


def:pub ChatScreen(messages: list[ChatMessage], sending: bool, on_send: Callable[[str], None]) -> JsxElement {
    has draft: str = "";

    def submit {
        text = draft.strip();
        if not text or sending { return; }
        draft = "";
        on_send(text);
    }

    return <KeyboardAvoidingView style={ui.screen} behavior={"padding" if Platform.OS == "ios" else "height"}>
        <ScrollView style={ui.flex1} contentContainerStyle={ui.page}>
            <Text style={ui.title}>Stylist</Text>
            {(<Text style={ui.muted}>Ask what to wear, how to style an item, or what fits your plans.</Text>) if not messages else None}
            {[
                <View key={str(n)} style={ui.bubbleUser if m.role == "user" else ui.bubbleBot}>
                    <Text style={ui.bubbleUserText if m.role == "user" else ui.body}>{m.text}</Text>
                </View>
                for (n, m) in enumerate(messages)
            ]}
            {(<Text style={ui.muted}>Thinking...</Text>) if sending else None}
        </ScrollView>
        <View style={[ui.row, {"padding": 12}]}>
            <TextInput
                style={ui.input}
                value={draft}
                placeholder="What should I wear today?"
                onChangeText={lambda (t: str) { draft = t; }}
                onSubmitEditing={lambda { submit(); }}
            />
            <Pressable style={ui.button} onPress={lambda { submit(); }}>
                <Text style={ui.buttonText}>Send</Text>
            </Pressable>
        </View>
    </KeyboardAvoidingView>;
}
