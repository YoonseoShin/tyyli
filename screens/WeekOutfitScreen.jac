"""This week's outfits, one per day."""
import from "@jac/mobui" { Text, View }
import from ..components.OutfitCard { OutfitCard }
import from ..models { Outfit }
import from ..services.dates { date_key, day_label }
import from ..storage { ClothingItem }
import from ..ui.kit { ui }


def label_for(date: str) -> str {
    for offset in range(7) {
        if date_key(offset) == date { return day_label(offset); }
    }
    return date;
}


def:pub WeekOutfitScreen(week: list[Outfit], clothes: list[ClothingItem]) -> JsxElement {
    if not week {
        return <View style={ui.card}>
            <Text style={ui.body}>No outfits yet. Add and analyze clothes in your closet.</Text>
        </View>;
    }
    return <View style={{"gap": 16}}>
        {[
            <OutfitCard key={outfit.outfit_id} outfit={outfit} clothes={clothes} heading={label_for(outfit.date)} compact={True}/>
            for outfit in week
        ]}
    </View>;
}
