"""Screen header (DESIGN_SYSTEM.md 6): a row with a glass back button and
optional trailing items (passed as children, e.g. a weather chip), then the
sans title and an optional caption below it.
"""
import from "@jac/mobui" { Pressable, Text, View }
import from .AppIcon { AppIcon }
import from ..ui.kit { C, S, ui }


def:pub ScreenHeader(
    title: str,
    subtitle: str = "",
    on_back: Callable[[], None] | None = None,
    children: any = None
) -> JsxElement {
    return <View style={{"gap": S.md}}>
        {(
            <View style={ui.rowBetween}>
                {(
                    <Pressable
                        accessibilityRole="button"
                        accessibilityLabel="Back"
                        style={ui.glassCircle}
                        onPress={lambda { if on_back { on_back(); } }}
                    >
                        <AppIcon name="chevron-left" size={22} color={C.text_primary}/>
                    </Pressable>
                ) if on_back else <View/>}
                {children}
            </View>
        ) if on_back or children else None}
        <View style={{"gap": 2}}>
            <Text style={ui.textH1} accessibilityRole="header" numberOfLines={1}>{title}</Text>
            {(<Text style={[ui.textCaption, {"fontSize": 13}]} numberOfLines={1}>{subtitle}</Text>) if subtitle else None}
        </View>
    </View>;
}
