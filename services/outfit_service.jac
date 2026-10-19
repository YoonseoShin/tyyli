"""Outfit recommendations built from the user's own closet.

PLACEHOLDER: a simple rule-based picker so the screens have real data to
show. Swap `build_outfit` for an AI call later (a server `def:pub ... by
llm()` that receives the closet metadata, style profile, weather and the
day's events, and returns an `Outfit`). Screens only depend on `Outfit`.
"""
import from ..models { CalendarEvent, Outfit, WeatherInfo }
import from ..storage { ClothingItem, StyleProfile }
import from .calendar_service { events_on, formality_label, main_event }
import from .dates { date_key }
import from .weather_service { describe_weather, target_warmth }


glob OCCASION_WORDS: dict[str, list[str]] = {
    "work": ["work", "office", "business", "commute", "meeting"],
    "school": ["school", "class", "campus", "everyday", "casual"],
    "social": ["date", "dinner", "weekend", "going out", "social"],
    "exercise": ["workout", "gym", "sport", "active"],
    "formal": ["formal", "wedding", "event", "ceremony"]
};


def:pub capitalize(word: str) -> str {
    return word[:1].upper() + word[1:] if word else word;
}


def:pub lower_all(values: list[str]) -> list[str] {
    return [v.lower() for v in values];
}


def:pub score_item(item: ClothingItem, warmth: int, event: CalendarEvent | None, profile: StyleProfile | None) -> int {
    score = 0;
    if item.warmth > 0 {
        score -= abs(item.warmth - warmth) * 2;
    }
    if event is not None {
        words = OCCASION_WORDS.get(event.kind, []);
        for occasion in lower_all(item.occasions) {
            for word in words {
                if word in occasion { score += 3; }
            }
        }
    }
    if profile is not None {
        liked = lower_all(profile.preferred_styles);
        for tag in lower_all(item.style_tags) {
            if tag in liked { score += 2; }
        }
    }
    return score;
}


def:pub pick(items: list[ClothingItem], categories: list[str], warmth: int, event: CalendarEvent | None, profile: StyleProfile | None, rotation: int) -> ClothingItem | None {
    candidates = [i for i in items if i.category in categories];
    if not candidates { return None; }
    scores = [score_item(i, warmth, event, profile) for i in candidates];
    best_score = max(scores);
    best = [candidates[n] for n in range(len(candidates)) if scores[n] == best_score];
    # Rotate between equally good items so the week doesn't repeat one look.
    return best[rotation % len(best)];
}


def:pub build_outfit(
    clothes: list[ClothingItem],
    profile: StyleProfile | None,
    weather: WeatherInfo | None,
    events: list[CalendarEvent],
    days_from_today: int = 0
) -> Outfit | None {
    date = date_key(days_from_today);
    event = main_event(events_on(events, date));
    warmth = target_warmth(weather);
    analyzed = [c for c in clothes if c.category != "Uncategorized"];

    picked: list[ClothingItem] = [];
    top = pick(analyzed, ["Dress"], warmth, event, profile, days_from_today) if event is not None and event.formality >= 5 else None;
    if top is None {
        top = pick(analyzed, ["Top"], warmth, event, profile, days_from_today);
        if top is not None { picked.append(top); }
        bottom = pick(analyzed, ["Bottom"], warmth, event, profile, days_from_today);
        if bottom is not None { picked.append(bottom); }
    } else {
        picked.append(top);
    }
    if warmth >= 3 {
        outer = pick(analyzed, ["Outerwear"], warmth, event, profile, days_from_today);
        if outer is not None { picked.append(outer); }
    }
    for extra in [["Shoes"], ["Bag", "Accessory"]] {
        item = pick(analyzed, extra, warmth, event, profile, days_from_today);
        if item is not None { picked.append(item); }
    }
    if not picked { return None; }

    formality = event.formality if event is not None else 2;
    mood = capitalize(picked[0].style_tags[0]) if picked[0].style_tags else "Everyday";
    return Outfit(
        outfit_id="outfit-" + date,
        date=date,
        style_name=mood + " " + formality_label(formality),
        reason=(
            ("Dressed for " + event.title + " (" + formality_label(formality).lower() + "). " if event is not None else "No plans on the calendar, so comfort comes first. ")
            + "Weather: " + describe_weather(weather) + "."
        ),
        description="Pairs " + ", ".join([i.name for i in picked]) + ".",
        clothing_item_ids=[i.clothing_item_id for i in picked],
        event_title=event.title if event is not None else ""
    );
}


def:pub build_week(
    clothes: list[ClothingItem],
    profile: StyleProfile | None,
    weather: WeatherInfo | None,
    events: list[CalendarEvent]
) -> list[Outfit] {
    week: list[Outfit] = [];
    for offset in range(7) {
        outfit = build_outfit(clothes, profile, weather, events, offset);
        if outfit is not None { week.append(outfit); }
    }
    return week;
}
