"""Today's weather for outfit recommendations.

PLACEHOLDER: returns fixed sample data. Replace the body of
`get_today_weather` with a real weather API call (ideally a server
`def:pub` endpoint so the API key stays off the device). Screens only depend
on the `WeatherInfo` shape, so nothing else needs to change.
"""
import from ..models { WeatherInfo }


async def:pub get_today_weather -> WeatherInfo {
    return WeatherInfo(
        city="Ann Arbor",
        condition="Partly cloudy",
        temperature_f=54,
        high_f=59,
        low_f=45,
        precipitation_chance=20,
        is_placeholder=True
    );
}


def:pub describe_weather(weather: WeatherInfo | None) -> str {
    if weather is None {
        return "Loading weather...";
    }
    return weather.condition + ", " + str(weather.temperature_f) + "°F (H " + str(weather.high_f) + "° / L " + str(weather.low_f) + "°)";
}


def:pub target_warmth(weather: WeatherInfo | None) -> int {
    # Map temperature to the 1-5 warmth scale used in clothing metadata.
    if weather is None { return 3; }
    t = weather.temperature_f;
    if t >= 77 { return 1; }
    if t >= 64 { return 2; }
    if t >= 50 { return 3; }
    if t >= 37 { return 4; }
    return 5;
}
