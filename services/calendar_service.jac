"""Calendar events used to match outfits to the day's plans.

PLACEHOLDER: returns sample events. Replace `get_week_events` with Google
Calendar (OAuth + events.list) and classify each event's `kind` and
`formality` (1 = very casual ... 5 = formal), e.g. with an AI call on the
server. Screens and the outfit service only depend on `CalendarEvent`.
"""
import from ..models { CalendarEvent }
import from .dates { date_key }


async def:pub get_week_events -> list[CalendarEvent] {
    return [
        CalendarEvent(event_id="sample-1", title="Team meeting", date=date_key(0), start_time="10:00", kind="work", formality=4),
        CalendarEvent(event_id="sample-2", title="Gym", date=date_key(0), start_time="18:30", kind="exercise", formality=1),
        CalendarEvent(event_id="sample-3", title="Dinner with friends", date=date_key(1), start_time="19:00", kind="social", formality=2),
        CalendarEvent(event_id="sample-4", title="Class presentation", date=date_key(3), start_time="13:00", kind="school", formality=3),
        CalendarEvent(event_id="sample-5", title="Wedding", date=date_key(5), start_time="16:00", kind="formal", formality=5)
    ];
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
