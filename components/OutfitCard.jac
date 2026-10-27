"""One recommended outfit with a sticker-board preview and explanation."""
import from "@jac/mobui" { Text, View }
import from ..models { Outfit }
import from ..storage { ClothingItem }
import from ..ui.kit { ui }
import from .OutfitCollage { OutfitCollage }
import from .OutfitInsights { OutfitInsights }


def:pub items_for(outfit: Outfit, clothes: list[ClothingItem]) -> list[ClothingItem] {
    by_id = {c.clothing_item_id: c for c in clothes};
    return [by_id[i] for i in outfit.clothing_item_ids if i in by_id];
}


def:pub OutfitCard(outfit: Outfit, clothes: list[ClothingItem], heading: str = "", compact: bool = False) -> JsxElement {
    items = items_for(outfit, clothes);
    return <View style={[ui.card, {"gap": 13, "borderWidth": 0, "shadowColor": "#5B4637", "shadowOpacity": 0.07, "shadowRadius": 14, "shadowOffset": {"width": 0, "height": 5}, "elevation": 2}]}>
        <View style={ui.rowBetween}>
            <View style={{"flex": 1, "gap": 4}}>
                {(<Text style={ui.label}>{heading.upper()}</Text>) if heading else None}
                <Text style={ui.heading}>{outfit.style_name}</Text>
            </View>
            {(<View style={{"paddingVertical": 7, "paddingHorizontal": 10, "borderRadius": 999, "backgroundColor": "#E2E7DA"}}>
                <Text style={{"fontSize": 11, "fontWeight": "bold", "color": "#4C5944"}}>{str(outfit.confidence) + "% match"}</Text>
            </View>) if outfit.confidence > 0 else None}
        </View>
        <OutfitCollage items={items} compact={compact}/>
        <View style={ui.wrap}>
            {[
                <View key={label} style={ui.chip}>
                    <Text style={ui.chipText}>{label}</Text>
                </View>
                for label in outfit.match_reasons[:4]
            ]}
        </View>
        {(<OutfitInsights outfit={outfit}/>) if not compact else None}
    </View>;
}
