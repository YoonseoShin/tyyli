"""Editable local test events used until Google Calendar is connected.

Manual event helpers let users add one-time or recurring events directly in
app while keeping everything persisted locally.
"""
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


def _date_after(base: str, offset: int) -> str {
    start = new(Date, base + "T00:00:00");
    day = new(Date, start.getTime() + offset * 86400000);
    month = str(day.getMonth() + 1);
    date = str(day.getDate());
    return str(day.getFullYear()) + "-" + ("0" + month if len(month) == 1 else month) + "-" + ("0" + date if len(date) == 1 else date);
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


def _custom_recurrence_dates(start: str, recurrence: str) -> list[str] {
    interval_weeks: int = 1;
    count: int = 12;
    weekdays: list[int] = [int(new(Date, start + "T00:00:00").getDay())];

    for part in recurrence.split("|")[1:] {
        if "=" not in part { continue; }
        key = part.split("=")[0].strip();
        value = part.split("=")[1].strip();
        if key == "interval" {
            interval_weeks = _positive_int(value, 1);
        }
        if key == "count" {
            count = max(1, min(365, _positive_int(value, 12)));
        }
        if key == "weekdays" {
            parsed = _parse_weekdays(value);
            if parsed { weekdays = parsed; }
        }
    }

    planned: list[str] = [];
    max_days = max(60, count * 14);
    for offset in range(max_days) {
        day = _date_after(start, offset);
        weekday = int(new(Date, day + "T00:00:00").getDay());
        week_index = int(offset / 7);
        if weekday in weekdays and week_index % interval_weeks == 0 {
            planned.append(day);
            if len(planned) >= count {
                break;
            }
        }
    }
    return planned;
}


def _custom_day_interval_dates(start: str, recurrence: str) -> list[str] {
    interval_days: int = 2;
    count: int = 20;

    for part in recurrence.split("|")[1:] {
        if "=" not in part { continue; }
        key = part.split("=")[0].strip();
        value = part.split("=")[1].strip();
        if key == "interval_days" {
            interval_days = _positive_int(value, 2);
        }
        if key == "count" {
            count = max(1, min(365, _positive_int(value, 20)));
        }
    }

    return [_date_after(start, n * interval_days) for n in range(count)];
}


def _dates_for_recurrence(date: str, recurrence: str) -> list[str] {
    start = date if _valid_date_key(date) else date_key(0);
    if recurrence == "one_time" {
        return [start];
    }
    if recurrence.startswith("custom|") {
        return _custom_recurrence_dates(start, recurrence);
    }
    if recurrence.startswith("custom_days|") {
        return _custom_day_interval_dates(start, recurrence);
    }
    upcoming = [_date_after(start, offset) for offset in range(28)];
    if recurrence == "daily" {
        return upcoming;
    }
    if recurrence == "weekdays" {
        return [d for d in upcoming if int(new(Date, d + "T00:00:00").getDay()) not in [0, 6]];
    }
    return upcoming;
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
    planned_dates = _dates_for_recurrence(date, recurrence);
    seed = "manual-" + str(Date.now());
    created = [
        CalendarEvent(
            event_id=seed + "-" + str(n),
            title=clean_title,
            date=day,
            start_time=_normalized_time(start_time),
            kind=clean_kind,
            formality=clean_formality,
            is_major=is_major
        )
        for (n, day) in enumerate(planned_dates)
    ];
    return existing + created;
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
