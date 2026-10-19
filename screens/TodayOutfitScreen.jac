"""Today's outfit in full: why it was picked and each piece's details."""
import from "@jac/mobui" { Image, Text, View }
import from ..components.OutfitCard { OutfitCard, items_for }
import from ..models { Outfit }
import from ..photo_storage { resolve_clothing_image_uri }
import from ..storage { ClothingItem }
import from ..ui.kit { ui }


def:pub TodayOutfitScreen(outfit: Outfit | None, clothes: list[ClothingItem]) -> JsxElement {
    if outfit is None {
        return <View style={ui.card}>
            <Text style={ui.body}>No outfit yet. Add and analyze a top and a bottom in your closet.</Text>
        </View>;
    }
    return <View style={{"gap": 16}}>
        <OutfitCard outfit={outfit} clothes={clothes} heading="Today"/>
        <Text style={ui.label}>THE PIECES</Text>
        {[
            <View key={item.clothing_item_id} style={[ui.card, ui.row]}>
                <Image source={{"uri": resolve_clothing_image_uri(item.image_path)}} style={ui.thumb} resizeMode="cover"/>
                <View style={ui.flex1}>
                    <Text style={ui.body}>{item.name}</Text>
                    <Text style={ui.muted}>{item.category + " · " + ", ".join(item.colors)}</Text>
                    <Text style={ui.muted}>{", ".join(item.style_tags)}</Text>
                </View>
            </View>
            for item in items_for(outfit, clothes)
        ]}
    </View>;
}
