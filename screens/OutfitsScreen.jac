"""Outfits tab: switch between today's outfit and this week's outfits."""
import from "@jac/mobui" { Pressable, ScrollView, Text, View }
import from ..models { Outfit }
import from ..storage { ClothingItem }
import from ..ui.kit { ui }
import from .TodayOutfitScreen { TodayOutfitScreen }
import from .WeekOutfitScreen { WeekOutfitScreen }


def:pub OutfitsScreen(today: Outfit | None, week: list[Outfit], clothes: list[ClothingItem]) -> JsxElement {
    has mode: str = "today";

    return <ScrollView style={ui.screen} contentContainerStyle={ui.page}>
        <Text style={ui.title}>Outfits</Text>
        <View style={ui.segment}>
            <Pressable style={[ui.segmentItem, ui.segmentItemOn] if mode == "today" else ui.segmentItem} onPress={lambda { mode = "today"; }}>
                <Text style={ui.chipText}>Today</Text>
            </Pressable>
            <Pressable style={[ui.segmentItem, ui.segmentItemOn] if mode == "week" else ui.segmentItem} onPress={lambda { mode = "week"; }}>
                <Text style={ui.chipText}>This week</Text>
            </Pressable>
        </View>
        {(<TodayOutfitScreen outfit={today} clothes={clothes}/>) if mode == "today" else <WeekOutfitScreen week={week} clothes={clothes}/>}
        <Text style={ui.muted}>Outfits are picked by simple rules for now. AI recommendations come next.</Text>
    </ScrollView>;
}
