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
        formality: int = 2,
        is_major: bool = True;
}


obj:pub OutfitExplanation {
    has color: str = "",
        mood: str = "",
        weather: str = "",
        plans: str = "",
        personal: str = "";
}


obj:pub Outfit {
    has outfit_id: str,
        date: str,
        style_name: str = "",
        reason: str = "",
        description: str = "",
        color_reason: str = "",
        mood_reason: str = "",
        weather_reason: str = "",
        plan_reason: str = "",
        personal_reason: str = "",
        clothing_item_ids: list[str] = [],
        event_title: str = "",
        match_reasons: list[str] = [],
        confidence: int = 0;
}


obj:pub ShopItem {
    has title: str = "",
        price: str = "",
        source: str = "",
        link: str = "",
        thumbnail: str = "",
        reason: str = "";
}


obj:pub ChatMessage {
    has role: str,
        text: str,
        clothing_item_ids: list[str] = [],
        shop_items: list[ShopItem] = [];
}


# One look the user marked as "Wearing Today", kept in the History tab.
obj:pub HistoryEntry {
    has entry_id: str,
        date: str,
        style_name: str = "",
        clothing_item_ids: list[str] = [],
        event_title: str = "",
        formality_label: str = "",
        temperature_f: int = 0,
        created_at: str = "";
}
