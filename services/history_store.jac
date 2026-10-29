"""Outfit history ("Wearing Today" log), saved on the device.

Uses AsyncStorage on both web and native, so it needs no database schema. The
list is newest first and capped so it never grows without bound.
"""
import from "@react-native-async-storage/async-storage" { default as AsyncStorage }
import from ..models { HistoryEntry }


glob HISTORY_KEY: str = "@tyyli/outfit-history/v1",
    MAX_ENTRIES: int = 200;


def _text(raw: dict[str, any], key: str) -> str {
    value = raw.get(key);
    return value if value else "";
}


def _entry_from_json(raw: dict[str, any]) -> HistoryEntry {
    ids = raw.get("clothing_item_ids");
    temp = raw.get("temperature_f");
    return HistoryEntry(
        entry_id=_text(raw, "entry_id"),
        date=_text(raw, "date"),
        style_name=_text(raw, "style_name"),
        clothing_item_ids=ids if ids else [],
        event_title=_text(raw, "event_title"),
        formality_label=_text(raw, "formality_label"),
        temperature_f=temp if temp else 0,
        created_at=_text(raw, "created_at")
    );
}


def _entry_to_json(look: HistoryEntry) -> dict[str, any] {
    return {
        "entry_id": look.entry_id,
        "date": look.date,
        "style_name": look.style_name,
        "clothing_item_ids": look.clothing_item_ids,
        "event_title": look.event_title,
        "formality_label": look.formality_label,
        "temperature_f": look.temperature_f,
        "created_at": look.created_at
    };
}


async def:pub load_history -> list[HistoryEntry] {
    raw: str | None = await AsyncStorage.getItem(HISTORY_KEY);
    if not raw {
        return [];
    }
    try {
        parsed = JSON.parse(raw);
        return [_entry_from_json(item as dict[str, any]) for item in parsed if item];
    } except Exception {
        return [];
    }
}


# Saves the look; wearing a new outfit on the same day replaces that day's look.
async def:pub save_history_entry(look: HistoryEntry) -> list[HistoryEntry] {
    current = await load_history();
    kept = [e for e in current if e.date != look.date];
    updated = ([look] + kept)[:MAX_ENTRIES];
    await AsyncStorage.setItem(HISTORY_KEY, JSON.stringify([_entry_to_json(e) for e in updated]));
    return updated;
}


async def:pub delete_history_entry(entry_id: str) -> list[HistoryEntry] {
    current = await load_history();
    updated = [e for e in current if e.entry_id != entry_id];
    await AsyncStorage.setItem(HISTORY_KEY, JSON.stringify([_entry_to_json(e) for e in updated]));
    return updated;
}
