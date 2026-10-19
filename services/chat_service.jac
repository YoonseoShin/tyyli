"""Styling chatbot.

PLACEHOLDER: canned replies so the chat screen works end to end. Replace
`send_chat_message` with a server `def:pub` that calls the LLM with the
conversation, closet metadata, style profile, weather and calendar.
"""
import from ..models { ChatMessage }
import from ..storage { ClothingItem }


async def:pub send_chat_message(history: list[ChatMessage], clothes: list[ClothingItem]) -> ChatMessage {
    last = history[len(history) - 1].text.lower() if history else "";
    if "wear" in last or "outfit" in last {
        text = "Check the Outfits tab for today's pick. Soon I'll be able to explain and adjust it right here.";
    } elif "closet" in last or "clothes" in last {
        text = "You have " + str(len(clothes)) + " item(s) in your closet.";
    } else {
        text = "I'm a placeholder for now. Ask me what to wear, and I'll answer properly once the AI stylist is connected.";
    }
    return ChatMessage(role="assistant", text=text);
}
