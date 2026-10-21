"""Today's weather summary used on the home screen."""
import from "@jac/mobui" { Pressable, Text, View }
import from ..models { WeatherInfo }
import from ..services.weather_service { describe_weather }
import from ..ui.kit { ui }


# unit is "F" or "C"; on_toggle_unit flips it (the choice is saved in the profile).
def:pub WeatherCard(weather: WeatherInfo | None, unit: str = "F", on_toggle_unit: Callable[[], None] | None = None) -> JsxElement {
    return <View style={ui.card}>
        <View style={ui.rowBetween}>
            <Text style={ui.label}>TODAY'S WEATHER</Text>
            {(
                <View style={ui.segment}>
                    <Pressable style={[ui.segmentItem, ui.segmentItemOn if unit != "C" else {}, {"paddingHorizontal": 10}]} onPress={lambda { if unit == "C" { on_toggle_unit(); } }}>
                        <Text style={ui.chipText}>°F</Text>
                    </Pressable>
                    <Pressable style={[ui.segmentItem, ui.segmentItemOn if unit == "C" else {}, {"paddingHorizontal": 10}]} onPress={lambda { if unit != "C" { on_toggle_unit(); } }}>
                        <Text style={ui.chipText}>°C</Text>
                    </Pressable>
                </View>
            ) if on_toggle_unit else None}
        </View>
        <Text style={ui.heading}>{describe_weather(weather, unit)}</Text>
        {(<Text style={ui.muted}>{weather.city + " · " + str(weather.precipitation_chance) + "% chance of rain"}</Text>) if weather is not None else None}
        {(<Text style={ui.muted}>Sample data. Weather API not connected yet.</Text>) if weather is not None and weather.is_placeholder else None}
    </View>;
}
