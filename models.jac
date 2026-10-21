"""App-level data types shared by screens and services.

Clothing items and the style profile live in `storage.jac` because they are
persisted on the device. The types here are produced by services (weather,
calendar, outfit recommendation, chat) and are not persisted yet.
"""


obj:pub WeatherInfo {
    has city: str = "",
        condition: str = "",
        temperature_f: int = 0,
        high_f: int = 0,
        low_f: int = 0,
        precipitation_chance: int = 0,
        is_placeholder: bool = True;
}


obj:pub CalendarEvent {
    has event_id: str,
        title: str,
        date: str,
        start_time: str = "",
        kind: str = "other",
        formality: int = 2;
}


obj:pub Outfit {
    has outfit_id: str,
        date: str,
        style_name: str = "",
        reason: str = "",
        description: str = "",
        clothing_item_ids: list[str] = [],
        event_title: str = "";
}


obj:pub ChatMessage {
    has role: str,
        text: str,
        clothing_item_ids: list[str] = [];
}
