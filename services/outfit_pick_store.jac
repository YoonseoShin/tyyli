"""Today's AI outfit picks, persisted on the user's device.

Only the latest daily batch is needed. A batch from an earlier date is ignored,
so the Home screen can ask the user to generate a fresh set for today.
"""
import from "@react-native-async-storage/async-storage" { default as AsyncStorage }
import from ..models { Outfit }


# v3 invalidates picks whose Style Score was calculated by the previous local
# rules so the next Generate uses Claude's holistic score.
glob OUTFIT_PICKS_KEY: str = "@tyyli/ai-outfit-picks/v3";


obj:pub SavedOutfitPicks {
    has date: str = "",
        variation: int = 0,
        outfits: list[Outfit] = [];
}


def _text(raw: dict[str, any], key: str) -> str {
    value = raw.get(key);
    return str(value) if value else "";
}


def _outfit_from_json(raw: dict[str, any]) -> Outfit {
    ids = raw.get("clothing_item_ids");
    reasons = raw.get("match_reasons");
    confidence = raw.get("confidence");
    return Outfit(
        outfit_id=_text(raw, "outfit_id"),
        date=_text(raw, "date"),
        style_name=_text(raw, "style_name"),
        reason=_text(raw, "reason"),
        description=_text(raw, "description"),
        color_reason=_text(raw, "color_reason"),
        mood_reason=_text(raw, "mood_reason"),
        weather_reason=_text(raw, "weather_reason"),
        plan_reason=_text(raw, "plan_reason"),
        personal_reason=_text(raw, "personal_reason"),
        clothing_item_ids=ids if ids else [],
        event_title=_text(raw, "event_title"),
        match_reasons=reasons if reasons else [],
        confidence=int(confidence) if confidence else 0
    );
}


def _outfit_to_json(outfit: Outfit) -> dict[str, any] {
    return {
        "outfit_id": outfit.outfit_id,
        "date": outfit.date,
        "style_name": outfit.style_name,
        "reason": outfit.reason,
        "description": outfit.description,
        "color_reason": outfit.color_reason,
        "mood_reason": outfit.mood_reason,
        "weather_reason": outfit.weather_reason,
        "plan_reason": outfit.plan_reason,
        "personal_reason": outfit.personal_reason,
        "clothing_item_ids": outfit.clothing_item_ids,
        "event_title": outfit.event_title,
        "match_reasons": outfit.match_reasons,
        "confidence": outfit.confidence
    };
}


async def:pub load_daily_outfit_picks(today: str) -> SavedOutfitPicks {
    raw: str | None = await AsyncStorage.getItem(OUTFIT_PICKS_KEY);
    if not raw { return SavedOutfitPicks(); }
    try {
        parsed = JSON.parse(raw) as dict[str, any];
        if _text(parsed, "date") != today { return SavedOutfitPicks(); }
        raw_outfits = parsed.get("outfits");
        variation = parsed.get("variation");
        return SavedOutfitPicks(
            date=today,
            variation=int(variation) if variation else 0,
            outfits=[_outfit_from_json(item as dict[str, any]) for item in raw_outfits if item] if raw_outfits else []
        );
    } except Exception {
        return SavedOutfitPicks();
    }
}


async def:pub save_daily_outfit_picks(date: str, variation: int, outfits: list[Outfit]) {
    payload = {
        "date": date,
        "variation": variation,
        "outfits": [_outfit_to_json(outfit) for outfit in outfits]
    };
    await AsyncStorage.setItem(OUTFIT_PICKS_KEY, JSON.stringify(payload));
}
