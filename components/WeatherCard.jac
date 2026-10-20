"""Today's weather summary used on the home screen."""
import from "@jac/mobui" { Text, View }
import from ..models { WeatherInfo }
import from ..services.weather_service { describe_weather }
import from ..ui.kit { ui }


def:pub WeatherCard(weather: WeatherInfo | None) -> JsxElement {
    return <View style={ui.card}>
        <Text style={ui.label}>TODAY'S WEATHER</Text>
        <Text style={ui.heading}>{describe_weather(weather)}</Text>
        {(<Text style={ui.muted}>{weather.city + " · " + str(weather.precipitation_chance) + "% chance of rain"}</Text>) if weather is not None else None}
        {(<Text style={ui.muted}>Sample data. Weather API not connected yet.</Text>) if weather is not None and weather.is_placeholder else None}
    </View>;
}
