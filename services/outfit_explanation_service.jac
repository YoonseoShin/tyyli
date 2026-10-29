"""Build the AI explanation request from device-side outfit metadata."""
import from ..models { CalendarEvent, Outfit, OutfitExplanation, WeatherInfo }
import from ..outfit_ai { explain_outfit_recommendations }
import from ..storage { ClothingItem, StyleProfile }
import from .weather_service { describe_weather }


def _joined(values: list[str]) -> str {
    return ", ".join(values) if values else "not specified";
}


def _item_line(item: ClothingItem) -> str {
    return (
        "- " + item.name + " | category: " + item.category
        + " | colors: " + _joined(item.colors)
        + " | mood: " + _joined(item.style_tags)
        + " | best for: " + _joined(item.occasions)
        + " | warmth: " + str(item.warmth) + "/5"
        + ((" | description: " + item.description) if item.description else "")
    );
}


def:pub outfit_set_key(picks: list[Outfit]) -> str {
    return "|".join([pick.outfit_id + ":" + ",".join(pick.clothing_item_ids) for pick in picks]);
}


async def:pub request_outfit_explanations(
    picks: list[Outfit],
    clothes: list[ClothingItem],
    weather: WeatherInfo | None,
    events: list[CalendarEvent],
    profile: StyleProfile | None
) -> list[OutfitExplanation] {
    if not picks { return []; }
    by_id = {item.clothing_item_id: item for item in clothes};
    unit = profile.temperature_unit if profile is not None else "F";
    lines: list[str] = [
        "Weather: " + describe_weather(weather, unit),
        "Chance of precipitation: " + (str(weather.precipitation_chance) + "%" if weather is not None else "unknown"),
        "Today's plans: " + ("; ".join([event.title + " (" + event.kind + ", formality " + str(event.formality) + "/5)" for event in events]) if events else "open calendar")
    ];
    if profile is not None {
        lines.append(
            "User profile: styles " + _joined(profile.preferred_styles)
            + "; colors " + _joined(profile.preferred_colors)
            + "; common occasions " + _joined(profile.occasions)
            + "; body shape " + (profile.body_shape or "not specified")
            + "; shopping section " + (profile.shop_section or "not specified")
            + "; usual top size " + (profile.top_size or "not specified")
            + "; usual bottom size " + (profile.bottom_size or "not specified") + "."
        );
    }
    for (index, pick) in enumerate(picks) {
        lines.append("\nOUTFIT " + str(index + 1) + " — " + pick.style_name);
        lines.append("Plan: " + (pick.event_title or "everyday plans"));
        lines.append("Pieces:");
        for item_id in pick.clothing_item_ids {
            if item_id in by_id { lines.append(_item_line(by_id[item_id])); }
        }
    }
    raw_explanations = await explain_outfit_recommendations("\n".join(lines));
    return [
        OutfitExplanation(
            color=value.get("color", ""),
            mood=value.get("mood", ""),
            weather=value.get("weather", ""),
            plans=value.get("plans", ""),
            personal=value.get("personal", "")
        )
        for value in raw_explanations
    ];
}


def:pub apply_ai_explanations(picks: list[Outfit], explanations: list[OutfitExplanation]) -> list[Outfit] {
    enriched: list[Outfit] = [];
    for (index, pick) in enumerate(picks) {
        explanation = explanations[index] if index < len(explanations) else None;
        color_reason = explanation.color if explanation is not None and explanation.color else pick.color_reason;
        mood_reason = explanation.mood if explanation is not None and explanation.mood else pick.mood_reason;
        weather_reason = explanation.weather if explanation is not None and explanation.weather else pick.weather_reason;
        plan_reason = explanation.plans if explanation is not None and explanation.plans else pick.plan_reason;
        personal_reason = explanation.personal if explanation is not None and explanation.personal else pick.personal_reason;
        reason = " ".join([color_reason, mood_reason, weather_reason, plan_reason, personal_reason]);
        enriched.append(Outfit(
            outfit_id=pick.outfit_id,
            date=pick.date,
            style_name=pick.style_name,
            reason=reason,
            description=pick.description,
            color_reason=color_reason,
            mood_reason=mood_reason,
            weather_reason=weather_reason,
            plan_reason=plan_reason,
            personal_reason=personal_reason,
            clothing_item_ids=pick.clothing_item_ids,
            event_title=pick.event_title,
            match_reasons=pick.match_reasons,
            confidence=pick.confidence
        ));
    }
    return enriched;
}
