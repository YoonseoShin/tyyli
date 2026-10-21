"""Styling chatbot: packs the closet, style profile, weather and plans into a
context block and asks the Claude-backed server stylist for a reply."""
import from ..models { CalendarEvent, ChatMessage, ShopItem, WeatherInfo }
import from ..storage { ClothingItem, StyleProfile }
import from ..stylist_ai { StylistReply, StylistTurn, chat_with_stylist }
import from .dates { date_key, day_label }
import from .weather_service { describe_weather }


def _join(values: list[str]) -> str {
    return ", ".join(values) if values else "-";
}


def _closet_line(item: ClothingItem) -> str {
    line = "- id=" + item.clothing_item_id + " | " + item.name + " | " + item.category;
    if item.brand { line = line + " | brand: " + item.brand; }
    line = line + " | colors: " + _join(item.colors);
    if item.style_tags { line = line + " | style: " + _join(item.style_tags); }
    if item.occasions { line = line + " | for: " + _join(item.occasions); }
    if item.seasons { line = line + " | seasons: " + _join(item.seasons); }
    if item.warmth > 0 { line = line + " | warmth " + str(item.warmth) + "/5"; }
    if item.waterproof { line = line + " | waterproof"; }
    if item.description { line = line + " | " + item.description; }
    return line;
}


def:pub build_stylist_context(
    clothes: list[ClothingItem],
    profile: StyleProfile | None,
    weather: WeatherInfo | None,
    events: list[CalendarEvent]
) -> str {
    lines: list[str] = ["Today: " + date_key(0) + " (" + day_label(0) + ")."];
    if weather is not None {
        lines.append("Weather in " + weather.city + ": " + describe_weather(weather)
            + ", " + str(weather.precipitation_chance) + "% chance of rain.");
    }
    if profile is not None {
        lines.append("Style profile: likes " + _join(profile.preferred_styles)
            + "; favourite colours " + _join(profile.preferred_colors)
            + "; dresses mostly for " + _join(profile.occasions)
            + (("; inspiration: " + profile.inspiration) if profile.inspiration else "")
            + (("; MBTI " + profile.mbti) if profile.mbti else "")
            + (("; zodiac " + profile.zodiac) if profile.zodiac else "") + ".");
    }
    if events {
        lines.append("Upcoming plans:");
        for e in events {
            lines.append("- " + e.date + (" " + e.start_time if e.start_time else "") + ": " + e.title
                + " (" + e.kind + ", formality " + str(e.formality) + "/5)");
        }
    }
    analyzed = [c for c in clothes if c.category != "Uncategorized"];
    if analyzed {
        lines.append("Closet (" + str(len(analyzed)) + " items):");
        for item in analyzed {
            lines.append(_closet_line(item));
        }
    } else {
        lines.append("Closet: empty so far (the user has not added or analyzed any clothes yet).");
    }
    return "\n".join(lines);
}


async def:pub send_chat_message(
    history: list[ChatMessage],
    clothes: list[ClothingItem],
    profile: StyleProfile | None = None,
    weather: WeatherInfo | None = None,
    events: list[CalendarEvent] = []
) -> ChatMessage {
    turns = [StylistTurn(role=m.role, text=m.text) for m in history];
    context = build_stylist_context(clothes, profile, weather, events);
    reply: StylistReply = await chat_with_stylist(turns, context);
    known = [c.clothing_item_id for c in clothes];
    ids = [i for i in reply.clothing_item_ids if i in known];
    shop_items: list[ShopItem] = [];
    for suggestion in reply.shopping {
        for product in suggestion.products {
            shop_items.append(ShopItem(
                title=product.title,
                price=product.price,
                source=product.source,
                link=product.link,
                thumbnail=product.thumbnail,
                reason=suggestion.reason or suggestion.query
            ));
        }
    }
    return ChatMessage(role="assistant", text=reply.text, clothing_item_ids=ids, shop_items=shop_items);
}
