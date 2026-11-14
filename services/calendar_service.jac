"""Editable local test events used until Google Calendar is connected.

Manual event helpers let users add one-time or recurring events directly in
app while keeping everything persisted locally.
"""
import from "@react-native-async-storage/async-storage" { default as AsyncStorage }
import from ..models { CalendarEvent }
import from .dates { date_key }


glob TEST_EVENTS_KEY: str = "@tyyli/test-calendar-events/v1";


def _string_list(value: any) -> list[str] {
    return [str(item) for item in value if item] if isinstance(value, list) else [];
}


def _event_from_json(raw: dict[str, any]) -> CalendarEvent {
    return CalendarEvent(
        event_id=str(raw.get("event_id") or "event-" + str(Date.now())),
        title=str(raw.get("title") or "Untitled plan"),
        date=str(raw.get("date") or date_key(0)),
        start_time=str(raw.get("start_time") or ""),
        kind=str(raw.get("kind") or "other"),
        formality=max(1, min(5, int(raw.get("formality") or 2))),
        is_major=bool(raw.get("is_major")) if raw.get("is_major") is not None else True,
        recurrence=str(raw.get("recurrence") or "one_time"),
        excluded_dates=_string_list(raw.get("excluded_dates"))
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
        "is_major": event.is_major,
        "recurrence": event.recurrence,
        "excluded_dates": event.excluded_dates or []
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


async def:pub clear_week_events {
    await AsyncStorage.removeItem(TEST_EVENTS_KEY);
}


def _normalized_time(start_time: str) -> str {
    def _clock_piece(raw: str) -> str {
        piece = raw.strip();
        if ":" not in piece { return ""; }
        parts = piece.split(":");
        if len(parts) != 2 { return ""; }
        hour_text = parts[0].strip();
        minute_text = parts[1].strip();
        if minute_text == "" or len(minute_text) != 2 { return ""; }
        try {
            hour = int(hour_text);
            minute = int(minute_text);
            if hour < 0 or hour > 23 or minute < 0 or minute > 59 { return ""; }
            return ("0" + str(hour) if hour < 10 else str(hour)) + ":" + minute_text;
        } except Exception {
            return "";
        }
    }

    time = start_time.strip();
    compact = time.replace(" ", "");
    if "-" in compact {
        parts = compact.split("-");
        if len(parts) == 2 {
            left = _clock_piece(parts[0]);
            right = _clock_piece(parts[1]);
            return left + " - " + right if left and right else "";
        }
        return "";
    }
    return _clock_piece(time);
}


def _valid_date_key(value: str) -> bool {
    parts = value.split("-");
    if len(parts) != 3 { return False; }
    return len(parts[0]) == 4 and len(parts[1]) == 2 and len(parts[2]) == 2;
}


def _positive_int(value: str, fallback: int) -> int {
    try {
        parsed = int(value);
        return parsed if parsed > 0 else fallback;
    } except Exception {
        return fallback;
    }
}


def _parse_weekdays(value: str) -> list[int] {
    picked: list[int] = [];
    for raw in value.split(",") {
        cleaned = raw.strip();
        if cleaned == "" { continue; }
        try {
            day = int(cleaned);
            if day in [0, 1, 2, 3, 4, 5, 6] and day not in picked {
                picked.append(day);
            }
        } except Exception {}
    }
    return picked;
}


def _recurrence_value(recurrence: str, wanted: str) -> str {
    for part in recurrence.split("|")[1:] {
        if "=" not in part { continue; }
        pieces = part.split("=");
        if pieces[0].strip() == wanted {
            return pieces[1].strip();
        }
    }
    return "";
}


def _days_between(start: str, target: str) -> int {
    start_parts = [int(value) for value in start.split("-")];
    target_parts = [int(value) for value in target.split("-")];
    start_utc = Date.UTC(start_parts[0], start_parts[1] - 1, start_parts[2]);
    target_utc = Date.UTC(target_parts[0], target_parts[1] - 1, target_parts[2]);
    return int((target_utc - start_utc) / 86400000);
}


def _occurs_on(event: CalendarEvent, target: str) -> bool {
    if not _valid_date_key(target) or target < event.date or target in (event.excluded_dates or []) { return False; }
    recurrence = event.recurrence or "one_time";
    if recurrence == "one_time" { return event.date == target; }
    if recurrence == "daily" { return True; }
    weekday = int(new(Date, target + "T00:00:00").getDay());
    if recurrence == "weekdays" { return weekday not in [0, 6]; }
    if recurrence.startswith("custom|") {
        weekdays = _parse_weekdays(_recurrence_value(recurrence, "weekdays"));
        interval_weeks = _positive_int(_recurrence_value(recurrence, "interval"), 1);
        return weekday in weekdays and int(_days_between(event.date, target) / 7) % interval_weeks == 0;
    }
    if recurrence.startswith("custom_days|") {
        interval_days = _positive_int(_recurrence_value(recurrence, "interval_days"), 1);
        return _days_between(event.date, target) % interval_days == 0;
    }
    return event.date == target;
}


def _event_for_date(event: CalendarEvent, target: str) -> CalendarEvent {
    return CalendarEvent(
        event_id=event.event_id,
        title=event.title,
        date=target,
        start_time=event.start_time,
        kind=event.kind,
        formality=event.formality,
        is_major=event.is_major,
        recurrence=event.recurrence,
        excluded_dates=event.excluded_dates or []
    );
}


def:pub add_manual_events(
    existing: list[CalendarEvent],
    title: str,
    date: str,
    start_time: str,
    kind: str,
    formality: int,
    recurrence: str,
    is_major: bool = True
) -> list[CalendarEvent] {
    clean_title = title.strip() if title.strip() else "Event";
    clean_kind = kind.strip() if kind.strip() else "other";
    clean_formality = max(1, min(5, formality));
    start = date if _valid_date_key(date) else date_key(0);
    created = CalendarEvent(
        event_id="manual-" + str(Date.now()),
        title=clean_title,
        date=start,
        start_time=_normalized_time(start_time),
        kind=clean_kind,
        formality=clean_formality,
        is_major=is_major,
        recurrence=recurrence or "one_time",
        excluded_dates=[]
    );
    return existing + [created];
}


def:pub add_quick_events(
    existing: list[CalendarEvent],
    preset: str,
    date: str,
    recurrence: str
) -> list[CalendarEvent] {
    key = preset.lower().strip();
    if key == "work" {
        return add_manual_events(existing, "Work", date, "09:00", "work", 4, recurrence);
    }
    if key == "gym" {
        return add_manual_events(existing, "Gym", date, "18:30", "exercise", 1, recurrence);
    }
    if key == "class" {
        return add_manual_events(existing, "Class", date, "13:00", "school", 3, recurrence);
    }
    if key == "social" {
        return add_manual_events(existing, "Social plans", date, "19:00", "social", 2, recurrence);
    }
    return existing;
}


def:pub events_on(events: list[CalendarEvent], date: str) -> list[CalendarEvent] {
    return [_event_for_date(event, date) for event in events if _occurs_on(event, date)];
}


def:pub is_recurring(event: CalendarEvent) -> bool {
    return bool(event.recurrence and event.recurrence != "one_time");
}


def _weekday_name(day: int) -> str {
    return ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][day];
}


def _natural_list(values: list[str]) -> str {
    if len(values) == 1 { return values[0]; }
    if len(values) == 2 { return values[0] + " and " + values[1]; }
    return ", ".join(values[:-1]) + ", and " + values[-1];
}


def:pub recurrence_label(event: CalendarEvent) -> str {
    recurrence = event.recurrence or "one_time";
    if recurrence == "daily" { return "Every day"; }
    if recurrence == "weekdays" { return "Every weekday"; }
    if recurrence.startswith("custom|") {
        picked = _parse_weekdays(_recurrence_value(recurrence, "weekdays"));
        names = [_weekday_name(day) for day in [1, 2, 3, 4, 5, 6, 0] if day in picked];
        return "Every " + _natural_list(names) if names else "Recurring";
    }
    if recurrence.startswith("custom_days|") {
        interval = _positive_int(_recurrence_value(recurrence, "interval_days"), 1);
        return "Every day" if interval == 1 else "Every " + str(interval) + " days";
    }
    return "Does not repeat";
}


def:pub remove_event_occurrence(events: list[CalendarEvent], event_id: str, date: str) -> list[CalendarEvent] {
    updated: list[CalendarEvent] = [];
    for event in events {
        if event.event_id != event_id {
            updated.append(event);
        } elif is_recurring(event) {
            excluded = event.excluded_dates or [];
            if date not in excluded {
                event.excluded_dates = excluded + [date];
            }
            updated.append(event);
        }
    }
    return updated;
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
