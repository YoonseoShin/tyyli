"""Bottom tab bar. Tabs are plain text for now; add icons when designing."""
import from "@jac/mobui" { Pressable, Text, View }
import from ..ui.kit { ui }


glob:pub TABS: list[list[str]] = [
    ["home", "Home"],
    ["closet", "Closet"],
    ["outfits", "Outfits"],
    ["chat", "Chat"],
    ["profile", "Profile"]
];


def:pub TabBar(active: str, on_select: Callable[[str], None]) -> JsxElement {
    return <View style={ui.tabBar}>
        {[
            <Pressable key={tab[0]} style={ui.tabItem} onPress={lambda { on_select(tab[0]); }}>
                <Text style={[ui.tabText, ui.tabTextOn] if tab[0] == active else ui.tabText}>{tab[1]}</Text>
            </Pressable>
            for tab in TABS
        ]}
    </View>;
}
