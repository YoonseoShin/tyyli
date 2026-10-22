"""Today's weather for outfit recommendations.

Uses the public Open-Meteo API without an API key. It prefers the user's current
coordinates on the device, falls back to a city lookup if available, and
returns the same WeatherInfo shape the screens expect.
"""
import from "expo-location" {
    Accuracy,
    getCurrentPositionAsync,
    requestForegroundPermissionsAsync,
}

import from ..models { WeatherInfo }


def:pub c_to_f(celsius: float) -> int {
    return int(round((celsius * 9.0 / 5.0) + 32.0));
}


def _weather_code_label(code: int) -> str {
    # Open-Meteo weather codes: https://open-meteo.com/en/docs
    if code in [0] { return "Clear"; }
    if code in [1, 2, 3] { return "Partly cloudy"; }
    if code in [45, 48] { return "Foggy"; }
    if code in [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82] { return "Rainy"; }
    if code in [71, 73, 75, 77, 85, 86] { return "Snowy"; }
    if code in [95, 96, 99] { return "Stormy"; }
    return "Cloudy";
}


async def _fetch_json(url: str) -> dict[str, any] {
    try {
        response = await fetch(url, {"headers": {"User-Agent": "tyyli-weather/1.0"}});
        if not response.ok {
            raise ValueError("HTTP " + str(response.status));
        }
        payload = await response.json();
        return payload as dict[str, any];
    } except Exception as e {
        print("Weather debug: fetch failed for " + url + " -> " + str(e));
        raise;
    }
}


async def _reverse_geocode_name(lat: float, lon: float) -> str {
    url = (
        "https://nominatim.openstreetmap.org/reverse?format=jsonv2" +
        "&lat=" + str(lat) +
        "&lon=" + str(lon) +
        "&zoom=10&addressdetails=1"
    );
    try {
        response = await fetch(url, {"headers": {"User-Agent": "tyyli-weather/1.0", "Accept-Language": "en"}});
        if not response.ok {
            raise ValueError("HTTP " + str(response.status));
        }

        payload = await response.json();
        data = payload as dict[str, any];
        address = data.get("address", {}) as dict[str, any];
        display_name = str(data.get("display_name") or "");
        candidate = (
            str(address.get("city") or address.get("town") or address.get("village") or address.get("suburb") or address.get("county") or display_name or "")
        );
        if candidate != "" {
            return candidate;
        }
    } except Exception as e {
        print("Weather debug: reverse geocoding failed for " + str(lat) + ", " + str(lon) + " -> " + str(e));
    }
    return "Lat " + str(lat) + ", Lon " + str(lon);
}


async def _device_coords() -> dict[str, any] {
    try {
        permission = await requestForegroundPermissionsAsync();
        print("Weather debug: permission status = " + str(permission.status));
        if permission.status != "granted" {
            raise ValueError("Location permission not granted");
        }

        location = await getCurrentPositionAsync({"accuracy": Accuracy.Balanced});
        lat = float(location.coords.latitude);
        lon = float(location.coords.longitude);
        print("Weather debug: raw coords = " + str(lat) + ", " + str(lon));

        city_name = await _reverse_geocode_name(lat, lon);
        print("Weather debug: resolved city label = " + city_name);
        return {"lat": lat, "lon": lon, "city": city_name};
    } except Exception as e {
        print("Weather debug: geolocation failed: " + str(e));
        print("Weather debug: fallback to Ann Arbor (42.2808, -83.7430)");
        return {"lat": 42.2808, "lon": -83.7430, "city": "Ann Arbor"};
    }
}


async def:pub get_today_weather -> WeatherInfo {
    location = await _device_coords();
    city_name = str(location.get("city", "Your location"));
    lat = float(location.get("lat", 42.2808));
    lon = float(location.get("lon", -83.7430));
    forecast_url = (
        "https://api.open-meteo.com/v1/forecast?latitude=" + str(lat) +
        "&longitude=" + str(lon) +
        "&current=temperature_2m,precipitation,weather_code&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto&forecast_days=1"
    );
    print("Weather debug: fetch URL = " + forecast_url);

    try {
        data = await _fetch_json(forecast_url);
        current = data.get("current", {}) as dict[str, any];
        daily = data.get("daily", {}) as dict[str, any];

        temps_max = daily.get("temperature_2m_max", []) as list;
        temps_min = daily.get("temperature_2m_min", []) as list;
        precip_chance = daily.get("precipitation_probability_max", []) as list;
        weather_code = int(current.get("weather_code", 0));

        current_temp_c = float(current.get("temperature_2m", 0.0));
        high_temp_c = float(temps_max[0]) if len(temps_max) > 0 else current_temp_c;
        low_temp_c = float(temps_min[0]) if len(temps_min) > 0 else current_temp_c;
        chance = int(float(precip_chance[0])) if len(precip_chance) > 0 else 0;

        current_temp = c_to_f(current_temp_c);
        high_temp = c_to_f(high_temp_c);
        low_temp = c_to_f(low_temp_c);

        return WeatherInfo(
            city=city_name,
            condition=_weather_code_label(weather_code),
            temperature_f=current_temp,
            high_f=high_temp,
            low_f=low_temp,
            precipitation_chance=chance,
            is_placeholder=False
        );
    } except Exception as e {
        print("Weather debug: forecast request failed for " + city_name + " at " + str(lat) + ", " + str(lon) + " -> " + str(e));
        return WeatherInfo(
            city=city_name,
            condition="Partly cloudy",
            temperature_f=54,
            high_f=59,
            low_f=45,
            precipitation_chance=20,
            is_placeholder=True
        );
    }
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
