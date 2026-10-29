"""Server-side: names the user's style from their onboarding answers.

Claude reads a plain-text summary of the quiz (the client builds it, so this
module never touches device storage) and returns a short style name, a
few sentences in the stylist's voice, and a five-colour palette.
"""
import json;
import random;
import time;
import from urllib.error { HTTPError, URLError }
import from .clothing_ai { _dev_setting, _send_claude_request }


obj:pub StyleIdentity {
    has name: str = "",
        description: str = "",
        palette: list[str] = [];
}


glob IDENTITY_SYSTEM_PROMPT: str = (
    "You are Tyyli's personal stylist. From a short summary of someone's style quiz, name their "
    "personal style and describe it the way a stylist friend would. The name is one or two words, "
    "evocative and specific, in the spirit of 'Blokette', 'Quiet Luxury', 'Soft Grunge', 'Coastal "
    "Prep', 'Scandi Minimal', 'Dark Academia' or 'Gorpcore' (invent one that fits; avoid repeating the "
    "user's own words verbatim). The description is short: exactly 3 sentences and under 60 words in "
    "total, second person. Sentence one says what they blend, sentence two gives one concrete outfit "
    "built from the kinds of pieces they like, sentence three names where to shop (their favourite "
    "stores or brands when given). Warm, confident, no hedging, no lists, no markdown. If they described their style in their own words, treat those words as the "
    "strongest signal and let them override the quiz picks. The palette is exactly five hex colours "
    "(#RRGGBB) that read as one wardrobe: mostly from the colours they like, ordered light to dark, "
    "and at most one accent."
);


def _identity_schema -> dict[str, any] {
    return {
        "type": "object",
        "properties": {
            "name": {"type": "string", "description": "One or two word style name"},
            "description": {"type": "string", "description": "Exactly 3 sentences, under 60 words, second person, plain text"},
            "palette": {
                "type": "array",
                "description": "Exactly five hex colours like #2F2A26, light to dark",
                "items": {"type": "string"}
            }
        },
        "required": ["name", "description", "palette"],
        "additionalProperties": False
    };
}


def _clean_palette(raw: any) -> list[str] {
    colours: list[str] = [];
    if not isinstance(raw, list) { return colours; }
    for value in raw {
        text = str(value).strip().upper();
        if len(text) == 7 and text.startswith("#") and all([c in "0123456789ABCDEF" for c in text[1:]]) {
            colours.append(text);
        }
        if len(colours) == 5 { break; }
    }
    return colours;
}


def:pub discover_style(summary: str) -> StyleIdentity {
    api_key = _dev_setting("ANTHROPIC_API_KEY");
    if not api_key {
        raise ValueError("ANTHROPIC_API_KEY is not set on the Jac server.");
    }
    if not summary.strip() {
        raise ValueError("Nothing to go on yet.");
    }
    payload = {
        "model": _dev_setting("CLAUDE_MODEL", "claude-opus-5-5"),
        "max_tokens": 450,
        "fallbacks": "default",
        "system": IDENTITY_SYSTEM_PROMPT,
        "output_config": {
            "effort": "low",
            "format": {"type": "json_schema", "schema": _identity_schema()}
        },
        "messages": [{"role": "user", "content": "Style quiz summary:\n" + summary.strip()}]
    };

    last_error = "";
    for attempt in range(3) {
        try {
            response_data = _send_claude_request(payload, api_key);
            if response_data.get("stop_reason") == "refusal" {
                raise ValueError("Claude declined to describe this style.");
            }
            for raw_block in response_data.get("content", []) as list {
                block = raw_block as dict[str, any];
                if block.get("type") == "text" and block.get("text") {
                    parsed = json.loads(block.get("text") as str) as dict[str, any];
                    return StyleIdentity(
                        name=str(parsed.get("name", "")).strip(),
                        description=str(parsed.get("description", "")).strip(),
                        palette=_clean_palette(parsed.get("palette", []))
                    );
                }
            }
            raise RuntimeError("Claude returned an empty reply.");
        } except HTTPError as e {
            error_body = e.read().decode("utf-8", errors="replace");
            last_error = "Claude request failed (HTTP " + str(e.code) + "). " + error_body[:300];
            if e.code not in [408, 429, 500, 502, 503, 504, 529] {
                raise RuntimeError(last_error);
            }
        } except URLError as e {
            last_error = "Could not reach Claude: " + str(e.reason);
        }
        if attempt < 2 {
            time.sleep(min(4.0, float(2 ** attempt)) + random.uniform(0.0, 0.5));
        }
    }
    raise RuntimeError("The stylist is temporarily unavailable. " + last_error);
}
