"""Floating glass tab bar (DESIGN_SYSTEM.md 6).

A capsule inset from the screen edges, sitting in the layout below the screens
(so no screen needs extra bottom padding). The round center button with the
serif "t" monogram opens the Stylist chat.
"""
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
    return <View style={ui.tabBarWrap}>
        <View style={ui.tabBar} accessibilityRole="tablist">
            {[
                (
                    <Pressable
                        key={tab[0]}
                        style={ui.tabItem}
                        accessibilityRole="tab"
                        accessibilityLabel="Stylist chat"
                        accessibilityState={{"selected": active == "chat"}}
                        onPress={lambda { on_select(tab[0]); }}
                    >
                        <View style={[ui.tabCenter, ui.tabCenterOn if active == "chat" else None]}>
                            <Text style={ui.tabMonogram} allowFontScaling={False}>t</Text>
                        </View>
                    </Pressable>
                ) if tab[0] == "chat" else (
                    <Pressable
                        key={tab[0]}
                        style={ui.tabItem}
                        accessibilityRole="tab"
                        accessibilityLabel={tab[1]}
                        accessibilityState={{"selected": tab[0] == active}}
                        onPress={lambda { on_select(tab[0]); }}
                    >
                        <AppIcon name={tab[2]} size={22} color={C.text_primary if tab[0] == active else C.text_secondary}/>
                        <Text style={[ui.tabText, ui.tabTextOn] if tab[0] == active else ui.tabText}>{tab[1]}</Text>
                    </Pressable>
                )
                for tab in TABS
            ]}
        </View>
    </View>;
}
