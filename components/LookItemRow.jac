"""One piece of the current look in "In this look" (DESIGN_SYSTEM.md 8.2):
its number (matching the outfit board), the same closet photo the board shows,
name, category and color from the wardrobe, and a swap control. The whole row
opens the swap sheet.
"""
import from "@jac/mobui" { Image, Pressable, Text, View }
import from .AppIcon { AppIcon }
import from .OutfitCollage { garment_photo_uri }
import from ..storage { ClothingItem }
import from ..ui.kit { C, S, ui }


def item_meta(item: ClothingItem) -> str {
    color = (item.colors[0][:1].upper() + item.colors[0][1:]) if item.colors else "";
    category = item.category if item.category != "Uncategorized" else "";
    return " · ".join([part for part in [category, color] if part]);
}


def:pub LookItemRow(item: ClothingItem, number: int, swapped: bool, on_swap: Callable[[], None]) -> JsxElement {
    has pressed: bool = False,
        photo_failed: bool = False;
    meta = item_meta(item);
    uri = garment_photo_uri(item);
    return <Pressable
        accessibilityRole="button"
        accessibilityLabel={"Swap " + item.name + (", " + meta if meta else "") + (", swapped in" if swapped else "") + (", photo unavailable" if not uri or photo_failed else "")}
        style={{"flexDirection": "row", "alignItems": "center", "gap": S.md, "minHeight": 78, "paddingVertical": 10, "paddingLeft": S.xl, "paddingRight": 14, "opacity": 0.75 if pressed else 1.0}}
        onPressIn={lambda { pressed = True; }}
        onPressOut={lambda { pressed = False; }}
        onPress={lambda { on_swap(); }}
    >
        <Text style={[ui.textMicro, ui.w600, {"width": 16}]}>{str(number)}</Text>
        <View style={[ui.tile, {"width": 58, "height": 58}]}>
            {(
                <Image source={{"uri": uri}} style={{"width": "100%", "height": "100%"}} resizeMode="cover" onError={lambda { photo_failed = True; }}/>
            ) if uri and not photo_failed else (
                <AppIcon name="image-off-outline" size={20} color={C.text_secondary}/>
            )}
        </View>
        <View style={[ui.flex1, {"gap": 3}]}>
            <Text style={ui.textH3} numberOfLines={2}>{item.name}</Text>
            <View style={[ui.row, {"gap": 6}]}>
                {(<Text style={ui.textCaption} numberOfLines={1}>{meta}</Text>) if meta else None}
                {(
                    <View style={{"paddingHorizontal": 7, "paddingVertical": 1, "borderRadius": 8, "backgroundColor": C.tag_bg}}>
                        <Text style={[ui.textNav, ui.w600, {"color": C.tag_text}]}>Swapped</Text>
                    </View>
                ) if swapped else None}
            </View>
        </View>
        <View style={ui.glassCircle} pointerEvents="none">
            <AppIcon name="swap-horizontal" size={19} color={C.text_primary}/>
        </View>
    </Pressable>;
}
