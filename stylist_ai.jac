"""Server-side styling chat: Claude answers with the user's closet, style profile,
weather and plans in context.

The client builds a plain-text `context` block (so this module never imports the
device storage code) and sends the recent conversation. Claude replies with text
plus the ids of any closet items it put together as an outfit, so the chat can
show their photos.
"""
import json;
import random;
import time;
import from urllib.error { HTTPError, URLError }
import from .clothing_ai { _dev_setting, _send_claude_request }


obj:pub StylistTurn {
    has role: str = "user",
        text: str = "";
}


obj:pub StylistReply {
    has text: str = "",
        clothing_item_ids: list[str] = [];
}


glob MAX_HISTORY_TURNS: int = 20,
     STYLIST_SYSTEM_PROMPT: str = (
         "You are Tyyli's personal stylist: warm, specific, and brief, like a friend with great taste "
         "texting back. You know the user's closet, style profile, today's weather and upcoming plans "
         "from the context block. When they ask what to wear, build the outfit from items that are "
         "actually in their closet, name each piece the way the closet lists it, and say in a sentence "
         "or two why it works for the occasion and weather. Offer one outfit by default (two if they ask "
         "for options), and mention one easy swap. If the closet lacks something essential, say so and "
         "suggest what kind of piece to add. For general style questions (how to style an item, what "
         "to buy, colour pairing, packing) answer directly and practically. Keep replies under 120 "
         "words unless the user asks for detail. Use plain text, no markdown headings or tables; short "
         "dashes for lists are fine. Return the closet ids of the items in the outfit you recommend in "
         "clothing_item_ids (empty when you are not recommending specific closet items)."
     );


def _reply_schema -> dict[str, any] {
    return {
        "type": "object",
        "properties": {
            "reply": {"type": "string", "description": "The message to show the user"},
            "clothing_item_ids": {
                "type": "array",
                "items": {"type": "string"},
                "description": "Ids of closet items used in the recommended outfit, from the context block"
            }
        },
        "required": ["reply", "clothing_item_ids"],
        "additionalProperties": False
    };
}


def:pub chat_with_stylist(history: list[StylistTurn], context: str) -> StylistReply {
    api_key = _dev_setting("ANTHROPIC_API_KEY");
    if not api_key {
        raise ValueError(
            "ANTHROPIC_API_KEY is not set on the Jac server. "
            "Add it to .env in the project folder (see .env.example) or export it, then restart the server."
        );
    }
    turns = [t for t in history if t.text.strip()][-MAX_HISTORY_TURNS:];
    if not turns {
        raise ValueError("Nothing to reply to.");
    }
    # Claude requires the conversation to start with a user turn and alternate.
    messages: list[dict[str, any]] = [];
    for turn in turns {
        role = "assistant" if turn.role == "assistant" else "user";
        if messages and messages[-1]["role"] == role {
            messages[-1]["content"] = messages[-1]["content"] + "\n\n" + turn.text.strip();
        } else {
            messages.append({"role": role, "content": turn.text.strip()});
        }
    }
    if messages[0]["role"] != "user" {
        messages = messages[1:];
    }
    if not messages {
        raise ValueError("Nothing to reply to.");
    }

    payload = {
        "model": _dev_setting("CLAUDE_MODEL", "claude-opus-5-5"),
        "max_tokens": 1200,
        "fallbacks": "default",
        "system": STYLIST_SYSTEM_PROMPT + "\n\n<context>\n" + context.strip() + "\n</context>",
        "output_config": {
            "effort": "medium",
            "format": {"type": "json_schema", "schema": _reply_schema()}
        },
        "messages": messages
    };

    last_error = "";
    for attempt in range(3) {
        try {
            response_data = _send_claude_request(payload, api_key);
            if response_data.get("stop_reason") == "refusal" {
                return StylistReply(text="I can't help with that one, but ask me anything about your outfits.");
            }
            for raw_block in response_data.get("content", []) as list {
                block = raw_block as dict[str, any];
                if block.get("type") == "text" and block.get("text") {
                    parsed = json.loads(block.get("text") as str) as dict[str, any];
                    ids = parsed.get("clothing_item_ids", []);
                    return StylistReply(
                        text=str(parsed.get("reply", "")).strip(),
                        clothing_item_ids=[str(i) for i in ids] if isinstance(ids, list) else []
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
    raise RuntimeError("The stylist is temporarily unavailable. Please try again in a moment. " + last_error);
}
