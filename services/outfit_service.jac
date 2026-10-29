"""Explainable outfit recommendations built from the user's own closet.

Claude already turns each clothing photo into structured metadata. This
service uses that metadata as the input to a deterministic recommender, so an
outfit appears immediately when the app opens and still works offline. The
calendar service can later replace its sample events with Google Calendar
without changing this module's public interface.
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
    "formal": ["formal", "wedding", "event", "ceremony", "gala"]
},
    FORMAL_WORDS: list[str] = ["formal", "wedding", "ceremony", "gala", "black tie"],
    BUSINESS_WORDS: list[str] = ["business", "office", "work", "professional", "meeting", "tailored"],
    SMART_WORDS: list[str] = ["smart casual", "preppy", "classic", "dinner", "date", "elegant"],
    ACTIVE_WORDS: list[str] = ["gym", "workout", "sport", "active", "athletic", "lounge"],
    NEUTRAL_COLORS: list[str] = ["black", "white", "cream", "ivory", "beige", "tan", "brown", "gray", "grey", "navy", "denim"],
    # Second word of a look's name, by the kind of event it is dressed for.
    LOOK_NOUNS: dict[str, str] = {
        "school": "Scholar",
        "work": "Office",
        "social": "Night Out",
        "exercise": "Active",
        "formal": "Formal"
    },
    # These signals are deliberately additive, not restrictive. They let a
    # saved body-shape preference influence ranking when the AI clothing
    # description contains useful silhouette details, without excluding any
    # style the user likes.
    BODY_SHAPE_SIGNALS: dict[str, list[str]] = {
        "hourglass": ["wrap", "fitted", "tailored", "belted", "waist"],
        "pear": ["a-line", "wide leg", "structured shoulder", "boat neck", "statement sleeve"],
        "apple": ["v-neck", "open neckline", "longline", "straight", "structured"],
        "rectangle": ["belted", "peplum", "pleated", "layered", "cropped"],
        "inverted triangle": ["a-line", "wide leg", "full skirt", "simple top", "straight leg"]
    };


def:pub capitalize(word: str) -> str {
    return word[:1].upper() + word[1:] if word else word;
}


def:pub lower_all(values: list[str]) -> list[str] {
    return [v.lower() for v in values];
}


def _contains_any(values: list[str], words: list[str]) -> bool {
    for value in lower_all(values) {
        for word in words {
            if word in value { return True; }
        }
    }
    return False;
}


def _season_for(days_from_today: int) -> str {
    day = new(Date, Date.now() + days_from_today * 86400000);
    month = int(day.getMonth()) + 1;
    if month in [12, 1, 2] { return "winter"; }
    if month in [3, 4, 5] { return "spring"; }
    if month in [6, 7, 8] { return "summer"; }
    return "fall";
}


def _rain_risk(weather: WeatherInfo | None) -> bool {
    if weather is None { return False; }
    condition = weather.condition.lower();
    return weather.precipitation_chance >= 40 or "rain" in condition or "storm" in condition or "snow" in condition;
}


def _item_formality(item: ClothingItem) -> int {
    words = item.occasions + item.style_tags + [item.description];
    if _contains_any(words, FORMAL_WORDS) { return 5; }
    if _contains_any(words, BUSINESS_WORDS) { return 4; }
    if _contains_any(words, SMART_WORDS) { return 3; }
    if _contains_any(words, ACTIVE_WORDS) { return 1; }
    return 2;
}


def _body_shape_match(item: ClothingItem, profile: StyleProfile | None) -> str {
    if profile is None or not profile.body_shape { return ""; }
    signals = BODY_SHAPE_SIGNALS.get(profile.body_shape.lower(), []);
    searchable = " ".join([item.name, item.description] + item.style_tags).lower();
    for signal in signals {
        if signal in searchable { return signal; }
    }
    return "";
}


def _is_neutral(color: str) -> bool {
    lowered = color.lower();
    return any([neutral in lowered for neutral in NEUTRAL_COLORS]);
}


def _outfit_mood(picked: list[ClothingItem], profile: StyleProfile | None, variation: int) -> str {
    if profile is not None and profile.preferred_styles {
        for offset in range(len(profile.preferred_styles)) {
            preferred = profile.preferred_styles[(variation + offset) % len(profile.preferred_styles)];
            for item in picked {
                if preferred.lower() in lower_all(item.style_tags) {
                    return capitalize(preferred);
                }
            }
        }
    }
    for item in picked {
        if item.style_tags { return capitalize(item.style_tags[0]); }
    }
    return "Everyday";
}


def:pub color_pair_score(first: ClothingItem, second: ClothingItem) -> int {
    first_colors = lower_all(first.colors);
    second_colors = lower_all(second.colors);
    if not first_colors or not second_colors { return 0; }
    for color in first_colors {
        if color in second_colors { return 5; }
    }
    if any([_is_neutral(c) for c in first_colors]) or any([_is_neutral(c) for c in second_colors]) {
        return 3;
    }
    return 0;
}


def:pub score_item(
    item: ClothingItem,
    warmth: int,
    event: CalendarEvent | None,
    profile: StyleProfile | None,
    season: str = "",
    rain_risk: bool = False
) -> int {
    score = 0;
    if item.warmth > 0 and item.category not in ["Bag", "Accessory"] {
        score += 8 - abs(item.warmth - warmth) * 3;
    } elif item.category not in ["Bag", "Accessory"] {
        score -= 2;
    }
    if season and item.seasons {
        score += 4 if season in lower_all(item.seasons) else -3;
    }
    if event is not None {
        words = OCCASION_WORDS.get(event.kind, []);
        if _contains_any(item.occasions + item.style_tags, words) {
            score += 7;
        }
        score += 6 - abs(_item_formality(item) - event.formality) * 3;
    }
    if profile is not None {
        liked = lower_all(profile.preferred_styles);
        for tag in lower_all(item.style_tags) {
            if tag in liked { score += 5; }
        }
        preferred_colors = lower_all(profile.preferred_colors);
        for color in lower_all(item.colors) {
            if color in preferred_colors { score += 3; }
        }
        if _contains_any(item.occasions, profile.occasions) { score += 2; }
        if _body_shape_match(item, profile) { score += 3; }
    }
    return score;
}


def:pub pick(
    items: list[ClothingItem],
    categories: list[str],
    warmth: int,
    event: CalendarEvent | None,
    profile: StyleProfile | None,
    rotation: int,
    season: str = "",
    rain_risk: bool = False,
    anchor: ClothingItem | None = None,
    excluded_ids: list[str] = []
) -> ClothingItem | None {
    candidates = [i for i in items if i.category in categories and i.clothing_item_id not in excluded_ids];
    if not candidates { return None; }
    # Shuffle cycles through the best three candidates instead of returning a
    # random poor match. It also makes the result stable and testable.
    rank = rotation % min(3, len(candidates));
    pool = candidates;
    chosen: ClothingItem | None = None;
    for _ in range(rank + 1) {
        scores = [score_item(i, warmth, event, profile, season, rain_risk) + (color_pair_score(anchor, i) if anchor is not None else 0) for i in pool];
        best_score = max(scores);
        chosen = pool[scores.index(best_score)];
        pool = [i for i in pool if i.clothing_item_id != chosen.clothing_item_id];
    }
    return chosen;
}


# A short, friendly name such as "Cozy Scholar" or "Minimal Office".
def:pub look_name(mood: str, event: CalendarEvent | None) -> str {
    noun = LOOK_NOUNS.get(event.kind, "Everyday") if event is not None else "Everyday";
    if mood == "Everyday" and noun == "Everyday" { return "Everyday Easy"; }
    return mood + " " + noun;
}


def _named_piece(item: ClothingItem) -> str {
    color = item.colors[0].lower() if item.colors else "";
    return (color + " " + item.name) if color and color not in item.name.lower() else item.name;
}


def _palette_sentence(picked: list[ClothingItem]) -> str {
    colored = [item for item in picked if item.colors];
    if len(colored) < 2 {
        return "The selected pieces keep the visual focus on silhouette and texture.";
    }
    first = colored[0];
    second = colored[1];
    first_color = first.colors[0].lower();
    second_color = second.colors[0].lower();
    if first_color == second_color {
        return "The repeated " + first_color + " in the " + first.name + " and " + second.name + " makes the outfit feel intentional and streamlined.";
    }
    if _is_neutral(first_color) or _is_neutral(second_color) {
        return "The " + first_color + " " + first.name + " and " + second_color + " " + second.name + " create an easy, balanced palette because the neutral anchors the other color.";
    }
    return "The " + first_color + " " + first.name + " and " + second_color + " " + second.name + " add controlled contrast, so the outfit has interest without feeling disconnected.";
}


def _mood_sentence(picked: list[ClothingItem], mood: str) -> str {
    tags: list[str] = [];
    for item in picked {
        for tag in item.style_tags {
            if tag.lower() not in lower_all(tags) { tags.append(tag); }
        }
    }
    details = ", ".join(tags[:3]);
    if details {
        return "Together, their " + details.lower() + " details create a " + mood.lower() + " mood rather than looking like unrelated pieces.";
    }
    return "The proportions work as one " + mood.lower() + " look rather than a set of unrelated basics.";
}


def _weather_sentence(picked: list[ClothingItem], warmth: int, weather: WeatherInfo | None, unit: str, rain_risk: bool) -> str {
    warm_pieces = [item for item in picked if item.warmth > 0 and item.category not in ["Bag", "Accessory"]];
    warmth_detail = ", ".join([item.name + " " + str(item.warmth) + "/5" for item in warm_pieces[:3]]);
    sentence = "For " + describe_weather(weather, unit) + ", the outfit targets warmth " + str(warmth) + "/5";
    sentence = sentence + ((" the key layers are " + warmth_detail + ".") if warmth_detail else " the pieces stay light and adaptable.");
    if rain_risk {
        sentence = sentence + " The forecast includes precipitation, so add your preferred rain protection if needed.";
    }
    return sentence;
}


def _occasion_sentence(picked: list[ClothingItem], event: CalendarEvent | None, formality: int) -> str {
    anchor_names = [_named_piece(item) for item in picked if item.category in ["Top", "Bottom", "Dress", "Outerwear"]][:2];
    anchors = " and ".join(anchor_names) or "These pieces";
    if event is not None {
        return "For " + event.title + ", " + anchors + " keep the look " + formality_label(formality).lower() + " while still being practical for the rest of the day.";
    }
    return anchors + " make this a flexible everyday combination that can move between casual plans.";
}


def _personal_sentence(picked: list[ClothingItem], profile: StyleProfile | None, mood: str) -> str {
    if profile is None {
        return "This look is based on the strongest matches available in your saved closet.";
    }
    preferred_matches: list[str] = [];
    preferred_styles = lower_all(profile.preferred_styles);
    preferred_colors = lower_all(profile.preferred_colors);
    for item in picked {
        for tag in item.style_tags {
            if tag.lower() in preferred_styles and tag.lower() not in lower_all(preferred_matches) {
                preferred_matches.append(tag);
            }
        }
        for color in item.colors {
            if color.lower() in preferred_colors and color.lower() not in lower_all(preferred_matches) {
                preferred_matches.append(color);
            }
        }
    }
    preference_text = (
        "It reflects your saved preference for " + ", ".join(preferred_matches[:3]) + "."
        if preferred_matches else
        "It keeps the overall direction close to your saved " + mood.lower() + " style preferences."
    );
    if profile.body_shape {
        for item in picked {
            signal = _body_shape_match(item, profile);
            if signal {
                return "For your " + profile.body_shape.lower() + " fit profile, the " + signal + " shape of the " + item.name + " informed the proportions. " + preference_text;
            }
        }
        return "Your " + profile.body_shape.lower() + " fit profile was considered without guessing details that are not in your closet data. " + preference_text;
    }
    return preference_text;
}


# focus_event: dress for this event instead of the day's most formal one.
def:pub build_outfit(
    clothes: list[ClothingItem],
    profile: StyleProfile | None,
    weather: WeatherInfo | None,
    events: list[CalendarEvent],
    days_from_today: int = 0,
    variation: int = 0,
    focus_event: CalendarEvent | None = None
) -> Outfit | None {
    date = date_key(days_from_today);
    event = focus_event if focus_event is not None else main_event(events_on(events, date));
    warmth = target_warmth(weather);
    season = _season_for(days_from_today);
    rain_risk = _rain_risk(weather);
    analyzed = [c for c in clothes if c.category != "Uncategorized"];

    picked: list[ClothingItem] = [];
    rotation = days_from_today + variation;
    dress = pick(analyzed, ["Dress"], warmth, event, profile, rotation, season, rain_risk);
    top = pick(analyzed, ["Top"], warmth, event, profile, rotation, season, rain_risk);
    bottom = pick(analyzed, ["Bottom"], warmth, event, profile, rotation, season, rain_risk, top);

    dress_score = score_item(dress, warmth, event, profile, season, rain_risk) * 2 if dress is not None else -1000;
    pair_score = (
        score_item(top, warmth, event, profile, season, rain_risk)
        + score_item(bottom, warmth, event, profile, season, rain_risk)
        + color_pair_score(top, bottom)
    ) if top is not None and bottom is not None else -1000;
    if dress is not None and (pair_score == -1000 or dress_score >= pair_score) {
        picked.append(dress);
    } else {
        if top is not None { picked.append(top); }
        if bottom is not None { picked.append(bottom); }
    }
    # A recommendation must have a wearable base: one dress, or both a top and
    # a bottom. Outerwear and accessories alone are not presented as an outfit.
    if not picked or (picked[0].category != "Dress" and len(picked) < 2) {
        return None;
    }

    picked_ids = [i.clothing_item_id for i in picked];
    anchor = picked[0] if picked else None;
    if warmth >= 3 or rain_risk {
        outer = pick(analyzed, ["Outerwear"], warmth, event, profile, rotation, season, rain_risk, anchor, picked_ids);
        if outer is not None { picked.append(outer); }
    }
    picked_ids = [i.clothing_item_id for i in picked];
    for extra in [["Shoes"], ["Bag", "Accessory"]] {
        item = pick(analyzed, extra, warmth, event, profile, rotation, season, rain_risk, anchor, picked_ids);
        if item is not None { picked.append(item); }
        picked_ids = [i.clothing_item_id for i in picked];
    }
    if not picked { return None; }

    formality = event.formality if event is not None else 2;
    mood = _outfit_mood(picked, profile, variation);
    match_reasons: list[str] = ["Weather-ready", formality_label(formality)];
    if event is not None { match_reasons.append(event.title); }
    if mood != "Everyday" { match_reasons.append("Your " + mood + " style"); }
    if rain_risk { match_reasons.append("Rain considered"); }

    unit = profile.temperature_unit if profile is not None else "F";
    color_reason = _palette_sentence(picked);
    mood_reason = _mood_sentence(picked, mood);
    weather_reason = _weather_sentence(picked, warmth, weather, unit, rain_risk);
    plan_reason = _occasion_sentence(picked, event, formality);
    personal_reason = _personal_sentence(picked, profile, mood);
    reason = " ".join([color_reason, mood_reason, weather_reason, plan_reason, personal_reason]);
    confidence = 55 + (10 if weather is not None else 0) + (10 if event is not None else 0) + (10 if profile is not None else 0) + min(15, len(picked) * 3);
    return Outfit(
        outfit_id="outfit-" + date + "-" + str(variation),
        date=date,
        style_name=look_name(mood, event),
        reason=reason,
        description="Pairs " + ", ".join([i.name for i in picked]) + ".",
        color_reason=color_reason,
        mood_reason=mood_reason,
        weather_reason=weather_reason,
        plan_reason=plan_reason,
        personal_reason=personal_reason,
        clothing_item_ids=[i.clothing_item_id for i in picked],
        event_title=event.title if event is not None else "",
        match_reasons=match_reasons,
        confidence=min(98, confidence)
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


# Up to `count` different looks for today (the Outfit Picks chips). Shuffle
# moves `variation` forward so a fresh set comes up.
def:pub build_picks(
    clothes: list[ClothingItem],
    profile: StyleProfile | None,
    weather: WeatherInfo | None,
    events: list[CalendarEvent],
    variation: int = 0,
    focus_event: CalendarEvent | None = None,
    count: int = 3
) -> list[Outfit] {
    picks: list[Outfit] = [];
    seen: list[str] = [];
    for offset in range(count * 2) {
        outfit = build_outfit(clothes, profile, weather, events, 0, variation * count + offset, focus_event);
        if outfit is None { continue; }
        signature = ",".join(sorted(outfit.clothing_item_ids));
        if signature in seen { continue; }
        seen.append(signature);
        picks.append(outfit);
        if len(picks) >= count { break; }
    }
    return picks;
}


# The outfit with pieces the user swapped in from the closet. Each swapped item
# replaces the piece of the same category (or is added if there was none).
def:pub apply_swaps(
    outfit: Outfit,
    clothes: list[ClothingItem],
    swap_ids: list[str]
) -> Outfit {
    by_id = {c.clothing_item_id: c for c in clothes};
    ids = list(outfit.clothing_item_ids);
    for swap_id in swap_ids {
        if swap_id not in by_id or swap_id in ids { continue; }
        category = by_id[swap_id].category;
        same = [i for i in ids if i in by_id and by_id[i].category == category];
        if same {
            ids = [swap_id if i == same[0] else i for i in ids];
        } else {
            ids = ids + [swap_id];
        }
    }
    # Swapping is a visual try-on tool. The explanation intentionally remains
    # about the original AI suggestion rather than evaluating user-made swaps.
    return Outfit(
        outfit_id=outfit.outfit_id,
        date=outfit.date,
        style_name=outfit.style_name,
        reason=outfit.reason,
        description=outfit.description,
        color_reason=outfit.color_reason,
        mood_reason=outfit.mood_reason,
        weather_reason=outfit.weather_reason,
        plan_reason=outfit.plan_reason,
        personal_reason=outfit.personal_reason,
        clothing_item_ids=ids,
        event_title=outfit.event_title,
        match_reasons=outfit.match_reasons,
        confidence=outfit.confidence
    );
}
