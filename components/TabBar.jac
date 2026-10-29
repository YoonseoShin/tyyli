"""Bottom nav bar with one consistent outline icon family."""
import from "@jac/mobui" { Pressable, Text, View }
import from .AppIcon { AppIcon }
import from ..ui.kit { C, ui }


# [id, label, icon]. "chat" is the round center button.
glob:pub TABS: list[list[str]] = [
    ["home", "Home", "home-outline"],
    ["closet", "Closet", "hanger"],
    ["chat", "Stylist", "creation-outline"],
    ["history", "History", "history"],
    ["profile", "Profile", "account-outline"]
];


def:pub TabBar(active: str, on_select: Callable[[str], None]) -> JsxElement {
    return <View style={ui.tabBar}>
        {[
            (
                <Pressable key={tab[0]} style={ui.tabItem} onPress={lambda { on_select(tab[0]); }}>
                    <View style={[ui.tabCenter, {"backgroundColor": C.surface if active == "chat" else C.accent, "borderColor": C.accent if active == "chat" else C.dark}]}>
                        <AppIcon name={tab[2]} size={22} color={C.dark if active == "chat" else C.accent_text}/>
                    </View>
                </Pressable>
            ) if tab[0] == "chat" else (
                <Pressable key={tab[0]} style={ui.tabItem} onPress={lambda { on_select(tab[0]); }}>
                    <AppIcon name={tab[2]} size={21} color={C.accent_text if tab[0] == active else C.dark_muted}/>
                    <Text style={[ui.tabText, ui.tabTextOn] if tab[0] == active else ui.tabText}>{tab[1]}</Text>
                </Pressable>
            )
            for tab in TABS
        ]}
    </View>;
}
