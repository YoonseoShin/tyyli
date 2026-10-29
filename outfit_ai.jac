"""Server-side AI stylist for selecting and explaining Outfit Picks."""
import json;
import random;
import time;
import from urllib.error { HTTPError, URLError }
import from .clothing_ai { _dev_setting, _send_claude_request }


def _recommendation_schema -> dict[str, any] {
    return {
        "type": "object",
        "properties": {
            "outfits": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "target_type": {"type": "string", "enum": ["all_day", "event"]},
                        "event_id": {"type": "string"},
                        "style_name": {"type": "string"},
                        "clothing_item_ids": {"type": "array", "items": {"type": "string"}},
                        "confidence": {"type": "integer"},
                        "color": {"type": "string"},
                        "mood": {"type": "string"},
                        "weather": {"type": "string"},
                        "plans": {"type": "string"},
                        "personal": {"type": "string"}
                    },
                    "required": [
                        "target_type", "event_id", "style_name", "clothing_item_ids", "confidence",
                        "color", "mood", "weather", "plans", "personal"
                    ],
                    "additionalProperties": False
                }
            }
        },
        "required": ["outfits"],
        "additionalProperties": False
    };
}


def _response_text(response_data: dict[str, any]) -> str {
    if response_data.get("stop_reason") == "refusal" {
        raise ValueError("Claude declined to generate this styling response.");
    }
    for raw_block in response_data.get("content", []) as list {
        block = raw_block as dict[str, any];
        if block.get("type") == "text" and block.get("text") {
            return block.get("text") as str;
        }
    }
    raise ValueError("Claude returned an empty styling response.");
}


def _parse_recommendations(response_data: dict[str, any]) -> list[dict[str, any]] {
    parsed = json.loads(_response_text(response_data)) as dict[str, any];
    values = parsed.get("outfits", []);
    recommendations: list[dict[str, any]] = [];
    if isinstance(values, list) {
        for value in values {
            if isinstance(value, dict) {
                raw_ids = value.get("clothing_item_ids", []);
                recommendations.append({
                    "target_type": str(value.get("target_type", "")).strip(),
                    "event_id": str(value.get("event_id", "")).strip(),
                    "style_name": str(value.get("style_name", "")).strip(),
                    "clothing_item_ids": [str(item_id) for item_id in raw_ids] if isinstance(raw_ids, list) else [],
                    "confidence": int(value.get("confidence", 0)),
                    "color": str(value.get("color", "")).strip(),
                    "mood": str(value.get("mood", "")).strip(),
                    "weather": str(value.get("weather", "")).strip(),
                    "plans": str(value.get("plans", "")).strip(),
                    "personal": str(value.get("personal", "")).strip()
                });
            }
        }
    }
    return recommendations;
}


def:pub recommend_outfits(context: str) -> list[dict[str, any]] {
    api_key = _dev_setting("ANTHROPIC_API_KEY");
    if not api_key {
        raise ValueError("ANTHROPIC_API_KEY is not set on the Jac server.");
    }
    prompt = (
        "You are the decision-making personal stylist for a mobile app. Follow the supplied Required "
        "recommendations exactly: create one all_day outfit and one event outfit for every supplied major "
        "event. When there are no events, create only the all_day outfit. For all_day, set target_type to "
        "all_day and event_id to an empty string. For an event outfit, set target_type to event and copy its "
        "exact event_id. Select complete, distinct outfits using only exact clothing_item_id values in the "
        "supplied closet. You—not "
        "a rules engine—must evaluate the whole look: color harmony, silhouette and proportions, shared "
        "mood, the user's preferences and body-shape notes, today's weather, and the "
        "formality and practicality required by today's plans. The all_day outfit should be versatile enough "
        "for the full day rather than optimized for only one event. Event outfits should focus on their exact "
        "event. Prefer pieces not worn during the supplied recent seven-day history; repeat a recent piece "
        "only when the closet cannot make a suitable alternative. A valid outfit must contain either one "
        "Dress or both one Top and one Bottom. Add Outerwear when the conditions need it, and include "
        "Shoes when available. Never use two pieces from the same category, except that one Accessory "
        "may accompany a Bag. Do not invent an item, feature, material, fit, plan, or ID. Reusing pieces across "
        "looks is allowed, but no two outfits may contain the exact same complete set of clothing_item_ids. Change "
        "at least one item between every pair of looks. You must calculate confidence as the "
        "overall Style Score from 0 to 100. Judge it holistically using weather suitability, schedule practicality, "
        "the user's preferences and proportions, color harmony, outfit completeness, and whether recent pieces "
        "were unnecessarily repeated. Do not give a high score merely because metadata is present. Every explanation "
        "field must be a complete sentence "
        "that explains why the choice works, not a label or list. Only discuss body-shape suitability when "
        "an item's supplied visual details contain relevant silhouette evidence. Keep each field under 28 "
        "words.\n\n" + context
    );
    model = _dev_setting("CLAUDE_MODEL", "claude-opus-5-5");
    payload = {
        "model": model,
        "max_tokens": 8192,
        "fallbacks": "default",
        "output_config": {
            "effort": "medium",
            "format": {"type": "json_schema", "schema": _recommendation_schema()}
        },
        "messages": [{"role": "user", "content": prompt}]
    };
    last_error = "";
    for attempt in range(3) {
        try {
            recommendations = _parse_recommendations(_send_claude_request(payload, api_key));
            if recommendations { return recommendations; }
            last_error = "Claude returned no outfit recommendations.";
        } except HTTPError as e {
            error_body = e.read().decode("utf-8", errors="replace");
            last_error = "Claude recommendation request failed (HTTP " + str(e.code) + "). " + error_body[:240];
            if e.code not in [408, 429, 500, 502, 503, 504, 529] { raise RuntimeError(last_error); }
        } except URLError as e {
            last_error = "Could not reach Claude: " + str(e.reason);
        } except TimeoutError {
            last_error = "Claude took too long to recommend outfits.";
        } except ValueError as e {
            last_error = str(e);
        }
        if attempt < 2 {
            time.sleep(min(4.0, float(2 ** attempt)) + random.uniform(0.0, 0.5));
        }
    }
    raise RuntimeError(last_error or "Could not generate outfit recommendations.");
}


def _explanation_schema -> dict[str, any] {
    return {
        "type": "object",
        "properties": {
            "explanations": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "color": {"type": "string"},
                        "mood": {"type": "string"},
                        "weather": {"type": "string"},
                        "plans": {"type": "string"},
                        "personal": {"type": "string"}
                    },
                    "required": ["color", "mood", "weather", "plans", "personal"],
                    "additionalProperties": False
                }
            }
        },
        "required": ["explanations"],
        "additionalProperties": False
    };
}


def _parse_explanations(response_data: dict[str, any]) -> list[dict[str, str]] {
    parsed = json.loads(_response_text(response_data)) as dict[str, any];
    values = parsed.get("explanations", []);
    explanations: list[dict[str, str]] = [];
    if isinstance(values, list) {
        for value in values {
            if isinstance(value, dict) {
                explanations.append({
                    "color": str(value.get("color", "")).strip(),
                    "mood": str(value.get("mood", "")).strip(),
                    "weather": str(value.get("weather", "")).strip(),
                    "plans": str(value.get("plans", "")).strip(),
                    "personal": str(value.get("personal", "")).strip()
                });
            }
        }
    }
    return explanations;
}


def:pub explain_outfit_recommendations(context: str) -> list[dict[str, str]] {
    api_key = _dev_setting("ANTHROPIC_API_KEY");
    if not api_key {
        raise ValueError("ANTHROPIC_API_KEY is not set on the Jac server.");
    }
    prompt = (
        "You write the 'Why this works' copy for a personal stylist app. The input contains "
        "several numbered outfits made only from the user's closet. Return exactly one structured "
        "explanation object for each outfit, in the same order. Write one concise, friendly sentence "
        "for each field: color, mood, weather, plans, and personal. Name actual pieces where helpful. "
        "Color must explain the palette; mood must explain the combined aesthetic; weather must connect "
        "warmth, layers, or protection to the forecast; plans must connect polish and practicality to the "
        "schedule; personal must connect saved style, color, occasion, and body-shape preferences to the "
        "choice. Use only supplied facts. Never promise an exact garment fit or invent materials, body "
        "details, or clothing features. Keep every field under 28 words and write polished English for "
        "a scannable app UI.\n\n"
        + context
    );
    model = _dev_setting("CLAUDE_MODEL", "claude-opus-5-5");
    payload = {
        "model": model,
        "max_tokens": 4096,
        "fallbacks": "default",
        "output_config": {
            "effort": "low",
            "format": {"type": "json_schema", "schema": _explanation_schema()}
        },
        "messages": [{"role": "user", "content": prompt}]
    };
    last_error = "";
    for attempt in range(3) {
        try {
            explanations = _parse_explanations(_send_claude_request(payload, api_key));
            if explanations { return explanations; }
            last_error = "Claude returned no outfit explanations.";
        } except HTTPError as e {
            error_body = e.read().decode("utf-8", errors="replace");
            last_error = "Claude explanation request failed (HTTP " + str(e.code) + "). " + error_body[:240];
            if e.code not in [408, 429, 500, 502, 503, 504, 529] { raise RuntimeError(last_error); }
        } except URLError as e {
            last_error = "Could not reach Claude: " + str(e.reason);
        } except TimeoutError {
            last_error = "Claude took too long to write the outfit explanations.";
        } except ValueError as e {
            last_error = str(e);
        }
        if attempt < 2 {
            time.sleep(min(4.0, float(2 ** attempt)) + random.uniform(0.0, 0.5));
        }
    }
    raise RuntimeError(last_error or "Could not generate outfit explanations.");
}
