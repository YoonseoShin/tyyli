"""History: the outfits the user marked as "Wearing Today", newest first."""
import from "@jac/mobui" { Pressable, ScrollView, Text, View }
import from ..components.AppIcon { AppIcon }
import from ..components.OutfitCollage { OutfitCollage }
import from ..models { HistoryEntry }
import from ..services.weather_service { to_unit }
import from ..storage { ClothingItem }
import from ..ui.kit { C, ui }


glob MONTHS: list[str] = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];


def items_of(look: HistoryEntry, clothes: list[ClothingItem]) -> list[ClothingItem] {
    by_id = {c.clothing_item_id: c for c in clothes};
    return [by_id[i] for i in look.clothing_item_ids if i in by_id];
}


# "2026-10-18" -> ["OCT", "18"]
def date_parts(date: str) -> list[str] {
    parts = date.split("-");
    if len(parts) != 3 { return ["", date]; }
    return [str(MONTHS[int(parts[1]) - 1]), str(int(parts[2]))];
}


def:pub HistoryScreen(
    looks: list[HistoryEntry],
    clothes: list[ClothingItem],
    temperature_unit: str,
    on_delete: Callable[[str], None]
) -> JsxElement {
    has open_id: str = "";
    unit = "C" if temperature_unit == "C" else "F";

    return <ScrollView style={ui.screen} contentContainerStyle={[ui.page, {"gap": 12}]}>
        <Text style={{"fontSize": 22, "fontWeight": "bold", "color": C.ink}}>History</Text>

        {(
            <View style={[ui.card, {"gap": 6}]}>
                <Text style={ui.bodyBold}>No looks logged yet</Text>
                <Text style={ui.muted}>Open an outfit pick and tap "Wearing Today". It will show up here.</Text>
            </View>
        ) if not looks else None}

        {[
            <Pressable key={look.entry_id} style={[ui.card, {"padding": 12, "gap": 10}]} onPress={lambda { open_id = "" if open_id == look.entry_id else look.entry_id; }}>
                <View style={[ui.row, {"gap": 12, "alignItems": "flex-start"}]}>
                    <View style={{"width": 34, "alignItems": "center", "paddingTop": 4}}>
                        <Text style={{"fontSize": 10, "fontWeight": "bold", "color": C.muted}}>{date_parts(look.date)[0]}</Text>
                        <Text style={[ui.serifNumber, {"fontSize": 22}]}>{date_parts(look.date)[1]}</Text>
                    </View>
                    <View style={{"width": 64}}>
                        <OutfitCollage items={items_of(look, clothes)} compact={True} height={76} item_cards={False}/>
                    </View>
                    <View style={[ui.flex1, {"gap": 4}]}>
                        <Text style={ui.bodyBold} numberOfLines={1}>{look.style_name}</Text>
                        <Text style={ui.small} numberOfLines={2}>{" · ".join([i.name for i in items_of(look, clothes)]) or "Items were removed from the closet"}</Text>
                        <View style={ui.wrap}>
                            {(<View style={[ui.chip, {"paddingVertical": 3, "paddingHorizontal": 8}]}>
                                <Text style={{"fontSize": 11, "color": C.ink}} numberOfLines={1}>{look.event_title or look.formality_label}</Text>
                            </View>) if look.event_title or look.formality_label else None}
                            {(<View style={[ui.chipSage, {"paddingVertical": 3, "paddingHorizontal": 8}]}>
                                <View style={[ui.row, {"gap": 4}]}>
                                    <AppIcon name="check" size={13} color={C.sage_ink}/>
                                    <Text style={{"fontSize": 11, "color": C.sage_ink}}>{str(to_unit(look.temperature_f, unit)) + "°" + unit}</Text>
                                </View>
                            </View>) if look.temperature_f else None}
                        </View>
                    </View>
                </View>
                {(
                    <View style={{"gap": 10}}>
                        <OutfitCollage items={items_of(look, clothes)} height={260} item_cards={False}/>
                        <Pressable style={[ui.button, ui.buttonGhost]} onPress={lambda { on_delete(look.entry_id); }}>
                            <Text style={[ui.buttonText, ui.buttonGhostText]}>Remove from history</Text>
                        </Pressable>
                    </View>
                ) if open_id == look.entry_id else None}
            </Pressable>
            for look in looks
        ]}
    </ScrollView>;
}
