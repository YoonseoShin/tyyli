"""One outfit: the user's own clothing photos plus style name, reason and description."""
import from "@jac/mobui" { Image, ScrollView, Text, View }
import from ..models { Outfit }
import from ..photo_storage { resolve_clothing_image_uri }
import from ..storage { ClothingItem }
import from ..ui.kit { ui }


def:pub items_for(outfit: Outfit, clothes: list[ClothingItem]) -> list[ClothingItem] {
    by_id = {c.clothing_item_id: c for c in clothes};
    return [by_id[i] for i in outfit.clothing_item_ids if i in by_id];
}


def:pub OutfitCard(outfit: Outfit, clothes: list[ClothingItem], heading: str = "", compact: bool = False) -> JsxElement {
    items = items_for(outfit, clothes);
    return <View style={ui.card}>
        {(<Text style={ui.label}>{heading.upper()}</Text>) if heading else None}
        <Text style={ui.heading}>{outfit.style_name}</Text>
        {(<Text style={ui.muted}>{"For " + outfit.event_title}</Text>) if outfit.event_title else None}
        <ScrollView horizontal={True} showsHorizontalScrollIndicator={False}>
            <View style={ui.row}>
                {[
                    <View key={item.clothing_item_id} style={{"width": 72, "gap": 4}}>
                        <Image source={{"uri": resolve_clothing_image_uri(item.image_path)}} style={ui.thumb} resizeMode="cover"/>
                        <Text style={ui.muted} numberOfLines={1}>{item.category}</Text>
                    </View>
                    for item in items
                ]}
            </View>
        </ScrollView>
        {(<Text style={ui.body}>{outfit.reason}</Text>) if not compact else None}
        {(<Text style={ui.muted}>{outfit.description}</Text>) if not compact else None}
    </View>;
}
