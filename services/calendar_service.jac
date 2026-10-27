"""Editable local test events used until Google Calendar is connected."""
import from "@react-native-async-storage/async-storage" { default as AsyncStorage }
import from ..models { CalendarEvent }
import from .dates { date_key }


glob TEST_EVENTS_KEY: str = "@tyyli/test-calendar-events/v1";


def _event_from_json(raw: dict[str, any]) -> CalendarEvent {
    return CalendarEvent(
        event_id=str(raw.get("event_id") or "event-" + str(Date.now())),
        title=str(raw.get("title") or "Untitled plan"),
        date=str(raw.get("date") or date_key(0)),
        start_time=str(raw.get("start_time") or ""),
        kind=str(raw.get("kind") or "other"),
        formality=max(1, min(5, int(raw.get("formality") or 2))),
        is_major=bool(raw.get("is_major")) if raw.get("is_major") is not None else True
    );
}


def _event_to_json(event: CalendarEvent) -> dict[str, any] {
    return {
        "event_id": event.event_id,
        "title": event.title,
        "date": event.date,
        "start_time": event.start_time,
        "kind": event.kind,
        "formality": event.formality,
        "is_major": event.is_major
    };
}


async def:pub get_week_events -> list[CalendarEvent] {
    raw: str | None = await AsyncStorage.getItem(TEST_EVENTS_KEY);
    if raw is not None {
        try {
            values = JSON.parse(raw) as list;
            events = [_event_from_json(value as dict[str, any]) for value in values if value is not None];
            # Remove the sample records created by earlier development builds.
            return [event for event in events if not event.event_id.startswith("sample-")];
        } except Exception {}
    }
    return [];
}


async def:pub save_week_events(events: list[CalendarEvent]) {
    await AsyncStorage.setItem(TEST_EVENTS_KEY, JSON.stringify([_event_to_json(event) for event in events]));
}


def:pub events_on(events: list[CalendarEvent], date: str) -> list[CalendarEvent] {
    return [e for e in events if e.date == date];
}


def:pub main_event(events: list[CalendarEvent]) -> CalendarEvent | None {
    # The most formal event of the day decides how dressed-up the outfit is.
    best: CalendarEvent | None = None;
    for e in events {
        if best is None or e.formality > best.formality {
            best = e;
        }
    }
    return best;
}


def:pub formality_label(level: int) -> str {
    labels = ["", "Very casual", "Casual", "Smart casual", "Business", "Formal"];
    return labels[max(1, min(5, level))];
}
