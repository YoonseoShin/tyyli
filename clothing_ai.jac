"""Server-side Claude analysis that turns a clothing photo into styling metadata."""
import json;
import os;
import random;
import time;
import from urllib.error { HTTPError, URLError }
import from urllib.request { Request, urlopen }


obj:pub ClothingAnalysis {
    has name: str,
        category: str,
        colors: list[str] = [],
        style_tags: list[str] = [],
        occasions: list[str] = [],
        seasons: list[str] = [],
        warmth: int = 0,
        description: str = "";
}


def _analysis_schema -> dict[str, any] {
    return {
        "type": "object",
        "properties": {
            "name": {"type": "string"},
            "category": {
                "type": "string",
                "enum": ["Top", "Bottom", "Dress", "Outerwear", "Shoes", "Bag", "Accessory", "Other"]
            },
            "colors": {"type": "array", "items": {"type": "string"}},
            "style_tags": {"type": "array", "items": {"type": "string"}},
            "occasions": {"type": "array", "items": {"type": "string"}},
            "seasons": {
                "type": "array",
                "items": {"type": "string", "enum": ["spring", "summer", "fall", "winter"]}
            },
            "warmth": {"type": "integer", "minimum": 0, "maximum": 5},
            "description": {"type": "string"}
        },
        "required": [
            "name",
            "category",
            "colors",
            "style_tags",
            "occasions",
            "seasons",
            "warmth",
            "description"
        ],
        "additionalProperties": False
    };
}


def _image_content(image_data: str) -> dict[str, any] {
    if image_data.startswith("data:image/") {
        separator = image_data.find(",");
        if separator < 0 {
            raise ValueError("The image data URL is incomplete.");
        }

        header = image_data[:separator];
        mime_type = header[5:].split(";")[0];
        encoded_image = image_data[separator + 1:];
        if not encoded_image {
            raise ValueError("The selected image is empty.");
        }
        # Keep inline image requests small enough for the server and model API.
        if len(encoded_image) > 26000000 {
            raise ValueError("The selected image is too large for AI analysis.");
        }
        return {
            "type": "image",
            "data": encoded_image,
            "mime_type": mime_type
        };
    }

    if image_data.startswith(("http://", "https://")) {
        return {
            "type": "image",
            "uri": image_data,
            "mime_type": "image/jpeg"
        };
    }

    raise ValueError("Expected an image data URL or an http(s) image URL.");
}


def _string_list(value: any) -> list[str] {
    if not isinstance(value, list) {
        return [];
    }
    return [str(item) for item in value if item is not None];
}


def _dev_setting(name: str, fallback: str = "") -> str {
    # Shell variables win. Otherwise read the gitignored `.env` in the folder the
    # server was started from, so developers don't have to export keys each time.
    value = os.environ.get(name, "").strip();
    if value {
        return value;
    }
    env_path = os.path.join(os.getcwd(), ".env");
    if os.path.exists(env_path) {
        with open(env_path, encoding="utf-8") as env_file {
            for line in env_file {
                stripped = line.strip();
                if not stripped or stripped.startswith("#") or "=" not in stripped {
                    continue;
                }
                key = stripped.split("=", 1)[0].strip();
                if key == name {
                    found = stripped.split("=", 1)[1].strip().strip('"').strip("'");
                    if found {
                        return found;
                    }
                }
            }
        }
    }
    return fallback;
}



def _claude_schema -> dict[str, any] {
    # Claude's structured outputs reject minimum/maximum on integers; the
    # prompt states the 0-5 range and _analysis_from_metadata clamps it.
    schema = _analysis_schema();
    schema["properties"]["warmth"] = {"type": "integer"};
    return schema;
}


def _claude_image_content(image_data: str) -> dict[str, any] {
    # Parse and validate the app image, then shape it as a Claude image block.
    block = _image_content(image_data);
    if "uri" in block {
        return {"type": "image", "source": {"type": "url", "url": block["uri"]}};
    }
    return {
        "type": "image",
        "source": {
            "type": "base64",
            "media_type": block["mime_type"],
            "data": block["data"]
        }
    };
}


def _send_claude_request(payload: dict[str, any], api_key: str) -> dict[str, any] {
    request = Request(
        "https://api.anthropic.com/v1/messages",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
            # Lets a safety-classifier decline re-run on Anthropic's fallback model.
            "anthropic-beta": "server-side-fallback-2026-07-01"
        },
        method="POST"
    );
    with urlopen(request, timeout=90) as response {
        return json.loads(response.read().decode("utf-8")) as dict[str, any];
    }
}


def _claude_response_text(response_data: dict[str, any]) -> str {
    if response_data.get("stop_reason") == "refusal" {
        raise ValueError("Claude declined to analyze this photo.");
    }
    for raw_block in response_data.get("content", []) as list {
        block = raw_block as dict[str, any];
        if block.get("type") == "text" and block.get("text") {
            return block.get("text") as str;
        }
    }
    raise ValueError("Claude returned no clothing metadata.");
}


def _analysis_from_metadata(metadata: dict[str, any]) -> ClothingAnalysis {
    warmth = int(metadata.get("warmth", 0));
    warmth = max(0, min(5, warmth));
    return ClothingAnalysis(
        name=str(metadata.get("name", "Clothing item")),
        category=str(metadata.get("category", "Other")),
        colors=_string_list(metadata.get("colors", [])),
        style_tags=_string_list(metadata.get("style_tags", [])),
        occasions=_string_list(metadata.get("occasions", [])),
        seasons=_string_list(metadata.get("seasons", [])),
        warmth=warmth,
        description=str(metadata.get("description", ""))
    );
}


glob ANALYSIS_PROMPT: str = (
    "Analyze the single main clothing item in this photo for a personal styling app. "
    "If several items are visible, describe the most prominent one. Use short English values. "
    "Name visible colors from most dominant to least dominant. Rate warmth from 1 (very light) to "
    "5 (very warm), but use 0 "
    "for items that add no warmth, such as bags, jewellery, belts, sunglasses, and other non-wearable "
    "accessories (a scarf or hat does add warmth). "
    "Describe material, pattern, fit, and styling details in one concise sentence."
);


def _analyze_with_claude(image_data: str) -> ClothingAnalysis {
    api_key = _dev_setting("ANTHROPIC_API_KEY");
    if not api_key {
        raise ValueError(
            "ANTHROPIC_API_KEY is not set on the Jac server. "
            "Add it to .env in the project folder (see .env.example) or export it, then restart the server."
        );
    }
    model = _dev_setting("CLAUDE_MODEL", "claude-opus-5-5");
    payload = {
        "model": model,
        "max_tokens": 1024,
        "fallbacks": "default",
        "output_config": {
            # Short, well-defined task: low effort keeps it fast and cheap.
            "effort": "low",
            "format": {"type": "json_schema", "schema": _claude_schema()}
        },
        "messages": [
            {
                "role": "user",
                "content": [
                    _claude_image_content(image_data),
                    {"type": "text", "text": ANALYSIS_PROMPT}
                ]
            }
        ]
    };

    last_error = "";
    for attempt in range(3) {
        try {
            response_data = _send_claude_request(payload, api_key);
            metadata = json.loads(_claude_response_text(response_data)) as dict[str, any];
            return _analysis_from_metadata(metadata);
        } except HTTPError as e {
            error_body = e.read().decode("utf-8", errors="replace");
            last_error = (
                "Claude request failed for " + model + " (HTTP " + str(e.code) + "). "
                + error_body[:500]
            );
            if e.code not in [408, 429, 500, 502, 503, 504, 529] {
                raise RuntimeError(last_error);
            }
        } except URLError as e {
            last_error = "Could not reach Claude: " + str(e.reason);
        } except TimeoutError {
            last_error = "Claude took too long to answer.";
        }
        if attempt < 2 {
            time.sleep(min(4.0, float(2 ** attempt)) + random.uniform(0.0, 0.5));
        }
    }
    raise RuntimeError(
        "Claude is temporarily unavailable after automatic retries. "
        "Please tap Analyze again in a moment. " + last_error
    );
}


def:pub analyze_clothing_image(image_data: str) -> ClothingAnalysis {
    return _analyze_with_claude(image_data);
}
