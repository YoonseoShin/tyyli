"""Main screen: today's weather, today's outfit, today's plans, closet summary."""
import from "@jac/mobui" { Pressable, ScrollView, Text, View }
import from ..components.EventRow { EventRow }
import from ..components.OutfitCard { OutfitCard }
import from ..components.WeatherCard { WeatherCard }
import from ..models { CalendarEvent, Outfit, WeatherInfo }
import from ..storage { ClothingItem }
import from ..ui.kit { ui }


def:pub HomeScreen(
    weather: WeatherInfo | None,
    today_events: list[CalendarEvent],
    today_outfit: Outfit | None,
    clothes: list[ClothingItem],
    on_navigate: Callable[[str], None]
) -> JsxElement {
    return <ScrollView style={ui.screen} contentContainerStyle={ui.page}>
        <View>
            <Text style={ui.title}>tyyli.</Text>
            <Text style={ui.muted}>Here's your day.</Text>
        </View>

        <WeatherCard weather={weather}/>

        {(
            <Pressable onPress={lambda { on_navigate("outfits"); }}>
                <OutfitCard outfit={today_outfit} clothes={clothes} heading="Today's outfit" compact={True}/>
            </Pressable>
        ) if today_outfit is not None else (
            <View style={ui.card}>
                <Text style={ui.label}>TODAY'S OUTFIT</Text>
                <Text style={ui.body}>Add and analyze a few clothes to get your first outfit.</Text>
                <Pressable style={ui.button} onPress={lambda { on_navigate("closet"); }}>
                    <Text style={ui.buttonText}>Go to closet</Text>
                </Pressable>
            </View>
        )}

        <View style={ui.card}>
            <View style={ui.rowBetween}>
                <Text style={ui.label}>TODAY'S PLANS</Text>
                <Pressable onPress={lambda { on_navigate("calendar"); }}>
                    <Text style={ui.link}>Calendar</Text>
                </Pressable>
            </View>
            {(<Text style={ui.muted}>Nothing scheduled today.</Text>) if not today_events else <View style={{"gap": 10}}>{[
                <EventRow key={e.event_id} event={e}/> for e in today_events
            ]}</View>}
        </View>

        <Pressable style={ui.card} onPress={lambda { on_navigate("closet"); }}>
            <Text style={ui.label}>MY CLOSET</Text>
            <Text style={ui.body}>{str(len(clothes)) + " item(s)"}</Text>
        </Pressable>

        <Pressable style={ui.card} onPress={lambda { on_navigate("chat"); }}>
            <Text style={ui.label}>ASK YOUR STYLIST</Text>
            <Text style={ui.body}>Not sure what to wear? Ask in chat.</Text>
        </Pressable>
    </ScrollView>;
}
