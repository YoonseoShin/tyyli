"""Ask the server-side AI stylist to choose complete looks from the closet."""
import from ..models { CalendarEvent, HistoryEntry, Outfit, WeatherInfo }
import from ..outfit_ai { recommend_outfits }
import from ..storage { ClothingItem, StyleProfile }
import from .calendar_service { events_on, formality_label }
import from .dates { date_key }
import from .weather_service { describe_weather }


def _joined(values: list[str]) -> str {
    return ", ".join(values) if values else "not specified";
}


def _item_line(item: ClothingItem) -> str {
    return (
        "- clothing_item_id: " + item.clothing_item_id
        + " | name: " + item.name
        + " | category: " + item.category
        + " | colors: " + _joined(item.colors)
        + " | style: " + _joined(item.style_tags)
        + " | occasions: " + _joined(item.occasions)
        + " | seasons: " + _joined(item.seasons)
        + " | warmth: " + str(item.warmth) + "/5"
        + ((" | visual details: " + item.description) if item.description else "")
    );
}


def _profile_line(profile: StyleProfile | None) -> str {
    if profile is None { return "User profile: not available."; }
    return (
        "User profile: preferred styles " + _joined(profile.preferred_styles)
        + "; preferred colors " + _joined(profile.preferred_colors)
        + "; common occasions " + _joined(profile.occasions)
        + "; body shape " + (profile.body_shape or "not specified")
        + "; shopping section " + (profile.shop_section or "not specified")
        + "; usual top size " + (profile.top_size or "not specified")
        + "; usual bottom size " + (profile.bottom_size or "not specified")
        + "; shoe size " + (profile.shoe_size or "not specified")
        + "; inspiration " + (profile.inspiration or "not specified") + "."
    );
}


def _valid_ids(raw_ids: list[str], by_id: dict[str, ClothingItem]) -> list[str] {
    chosen: list[str] = [];
    categories: list[str] = [];
    for item_id in raw_ids {
        # Reject the whole result instead of silently deleting pieces while
        # keeping an explanation that may describe those deleted pieces.
        if item_id not in by_id or item_id in chosen { return []; }
        category = by_id[item_id].category;
        if category in categories { return []; }
        chosen.append(item_id);
        categories.append(category);
    }
    has_dress = "Dress" in categories;
    has_pair = "Top" in categories and "Bottom" in categories;
    if not has_dress and not has_pair { return []; }
    if has_dress and ("Top" in categories or "Bottom" in categories) { return []; }
    return chosen;
}


def _recent_history(
    history: list[HistoryEntry],
    by_id: dict[str, ClothingItem]
) -> tuple[list[str], list[str]] {
    recent_dates = [date_key(-offset) for offset in range(1, 8)];
    entries = [look for look in history if look.date in recent_dates];
    recent_ids: list[str] = [];
    lines: list[str] = [];
    for look in entries {
        names: list[str] = [];
        for item_id in look.clothing_item_ids {
            if item_id not in recent_ids { recent_ids.append(item_id); }
            names.append(by_id[item_id].name + " [" + item_id + "]" if item_id in by_id else item_id);
        }
        if names { lines.append(look.date + ": " + ", ".join(names)); }
    }
    return (recent_ids, lines);
}


def _int_score(value: any) -> int {
    try { return max(0, min(100, int(value))); }
    except Exception { return 0; }
}


def _same_outfit_items(first_ids: list[str], second_ids: list[str]) -> bool {
    if len(first_ids) != len(second_ids) { return False; }
    return all([item_id in second_ids for item_id in first_ids]);
}


def _partition_duplicate_event_outfits(
    all_day: Outfit | None,
    event_results: dict[str, Outfit],
    major_events: list[CalendarEvent]
) -> tuple[dict[str, Outfit], dict[str, Outfit]] {
    retained: list[Outfit] = [];
    if all_day is not None { retained.append(all_day); }
    distinct_events: dict[str, Outfit] = {};
    duplicate_events: dict[str, Outfit] = {};
    for event in major_events {
        if event.event_id not in event_results { continue; }
        candidate = event_results[event.event_id];
        is_duplicate = any([
            _same_outfit_items(candidate.clothing_item_ids, existing.clothing_item_ids)
            for existing in retained
        ]);
        if is_duplicate {
            duplicate_events[event.event_id] = candidate;
            continue;
        }
        distinct_events[event.event_id] = candidate;
        retained.append(candidate);
    }
    return (distinct_events, duplicate_events);
}


def _retained_outfit_lines(
    all_day: Outfit | None,
    event_results: dict[str, Outfit],
    major_events: list[CalendarEvent]
) -> list[str] {
    lines: list[str] = [];
    if all_day is not None {
        lines.append("- all_day | clothing_item_ids: " + ", ".join(all_day.clothing_item_ids));
    }
    for event in major_events {
        if event.event_id in event_results {
            lines.append(
                "- event_id " + event.event_id
                + " | clothing_item_ids: " + ", ".join(event_results[event.event_id].clothing_item_ids)
            );
        }
    }
    return lines;
}


async def:pub request_ai_outfit_recommendations(
    clothes: list[ClothingItem],
    profile: StyleProfile | None,
    weather: WeatherInfo | None,
    events: list[CalendarEvent],
    history: list[HistoryEntry],
    variation: int = 0
) -> list[Outfit] {
    analyzed = [item for item in clothes if item.category != "Uncategorized"];
    categories = [item.category for item in analyzed];
    if "Dress" not in categories and not ("Top" in categories and "Bottom" in categories) {
        return [];
    }
    today = date_key(0);
    today_events = events_on(events, today);
    major_events = [event for event in today_events if event.is_major];
    unit = profile.temperature_unit if profile is not None else "F";
    by_id = {item.clothing_item_id: item for item in analyzed};
    (_recent_ids, recent_lines) = _recent_history(history, by_id);
    schedule_lines = [
        "- event_id: " + event.event_id
        + " | title: " + event.title
        + " | time: " + (event.start_time or "unspecified")
        + " | kind: " + event.kind
        + " | formality: " + str(event.formality) + "/5"
        for event in today_events
    ];
    major_event_lines = [
        "- event_id: " + event.event_id + " | title: " + event.title
        for event in major_events
    ];
    required = (
        "Return exactly one all_day outfit and exactly one event outfit for each of the "
        + str(len(major_events)) + " major events below."
        if major_events else
        "Return exactly one all_day outfit. There are no major events, so do not return any event outfit."
    );
    lines: list[str] = [
        "Recommendation batch: " + str(variation) + ". Use this number as a variation cue so Regenerate produces new strong combinations.",
        "Required recommendations: " + required,
        "Weather: " + describe_weather(weather, unit),
        "Chance of precipitation: " + (str(weather.precipitation_chance) + "%" if weather is not None else "unknown"),
        "Today's full schedule for the all_day outfit:\n" + ("\n".join(schedule_lines) if schedule_lines else "none"),
        "Major events requiring their own event outfit:\n" + ("\n".join(major_event_lines) if major_event_lines else "none"),
        "Recently worn during the previous 7 days:\n" + ("\n".join(recent_lines) if recent_lines else "none"),
        _profile_line(profile),
        "Available closet items:",
        "\n".join([_item_line(item) for item in analyzed])
    ];
    context = "\n".join(lines);
    by_event_id = {event.event_id: event for event in major_events};
    all_day: Outfit | None = None;
    event_results: dict[str, Outfit] = {};
    fallback_events: dict[str, Outfit] = {};
    # Correction calls fill omitted or invalid targets and replace only outfits
    # composed of exactly the same clothing items as a retained look.
    for generation_attempt in range(3) {
        missing_targets: list[str] = [];
        if all_day is None { missing_targets.append("all_day"); }
        for event in major_events {
            if event.event_id not in event_results { missing_targets.append("event_id " + event.event_id); }
        }
        if not missing_targets { break; }
        request_context = context;
        if generation_attempt > 0 {
            retained_lines = _retained_outfit_lines(all_day, event_results, major_events);
            request_context += (
                "\n\nCorrection: regenerate the missing recommendations for: "
                + ", ".join(missing_targets)
                + ". Return the complete required set again. Keep the retained outfits below unchanged, and make "
                + "sure each replacement changes at least one clothing_item_id. Reusing any number of pieces is "
                + "allowed as long as the complete set of item IDs is not identical.\nRetained outfits:\n"
                + ("\n".join(retained_lines) if retained_lines else "none")
            );
        }
        raw = await recommend_outfits(request_context);
        for (index, value) in enumerate(raw) {
            ids = _valid_ids(value.get("clothing_item_ids", []) as list[str], by_id);
            if not ids { continue; }
            target_type = str(value.get("target_type", ""));
            event_id = str(value.get("event_id", ""));
            event_title = "";
            match_reasons: list[str] = ["AI selected"];
            if target_type == "all_day" {
                if all_day is not None or event_id { continue; }
                event_title = "All day";
                match_reasons.append("All-day");
            } elif target_type == "event" {
                if event_id not in by_event_id or event_id in event_results { continue; }
                chosen_event = by_event_id[event_id];
                event_title = chosen_event.title;
                match_reasons += [formality_label(chosen_event.formality), chosen_event.title];
            } else {
                continue;
            }
            color_reason = str(value.get("color", ""));
            mood_reason = str(value.get("mood", ""));
            weather_reason = str(value.get("weather", ""));
            plan_reason = str(value.get("plans", ""));
            personal_reason = str(value.get("personal", ""));
            selected_names = [by_id[item_id].name for item_id in ids];
            result = Outfit(
                outfit_id="ai-outfit-" + today + "-" + str(variation) + "-" + str(generation_attempt) + "-" + str(index),
                date=today,
                style_name=str(value.get("style_name", "")) or ("AI Pick " + str(index + 1)),
                reason=" ".join([color_reason, mood_reason, weather_reason, plan_reason, personal_reason]),
                description="Pairs " + ", ".join(selected_names) + ".",
                color_reason=color_reason,
                mood_reason=mood_reason,
                weather_reason=weather_reason,
                plan_reason=plan_reason,
                personal_reason=personal_reason,
                clothing_item_ids=ids,
                event_title=event_title,
                match_reasons=match_reasons,
                confidence=_int_score(value.get("confidence", 0))
            );
            if target_type == "all_day" { all_day = result; }
            else { event_results[event_id] = result; }
        }
        (event_results, duplicate_events) = _partition_duplicate_event_outfits(
            all_day,
            event_results,
            major_events
        );
        for (event_id, candidate) in duplicate_events.items() {
            if event_id not in fallback_events {
                fallback_events[event_id] = candidate;
            }
        }
    }
    # Never make a required major-event card disappear solely because Claude
    # kept changing no items during the correction calls. In that rare case,
    # preserve the required event card instead of silently reducing the count.
    for event in major_events {
        if event.event_id not in event_results and event.event_id in fallback_events {
            event_results[event.event_id] = fallback_events[event.event_id];
        }
    }
    results: list[Outfit] = [];
    if all_day is not None { results.append(all_day); }
    for event in major_events {
        if event.event_id in event_results { results.append(event_results[event.event_id]); }
    }
    return results;
}
