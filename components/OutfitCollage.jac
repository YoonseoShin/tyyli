"""Sticker-style outfit board made from the user's own clothing photos.

Each piece sits where it would on a flat-lay: the top up high, the bottom to
the lower right, shoes at the lower left, the bag on the left, small
accessories in the top corner. Callers can keep the sticker card treatment or
show the original image without an added background.
"""
import from "@jac/mobui" { Image, Pressable, View }
import from ..photo_storage { resolve_clothing_image_uri }
import from ..storage { ClothingItem }
import from ..ui.kit { C }


# Slot per category: position and size as a share of the board.
glob SLOTS: dict[str, dict[str, str]] = {
    "Outerwear": {"left": "4%", "top": "5%", "width": "44%", "height": "50%"},
    "Top": {"left": "24%", "top": "4%", "width": "48%", "height": "42%"},
    "TopWithOuter": {"left": "36%", "top": "6%", "width": "40%", "height": "38%"},
    "Dress": {"left": "26%", "top": "4%", "width": "46%", "height": "78%"},
    "Bottom": {"right": "8%", "top": "40%", "width": "36%", "height": "56%"},
    "Bag": {"left": "5%", "top": "46%", "width": "32%", "height": "24%"},
    "Shoes": {"left": "8%", "bottom": "5%", "width": "34%", "height": "22%"},
    "Accessory": {"right": "5%", "top": "5%", "width": "22%", "height": "18%"},
    "Other": {"right": "6%", "bottom": "5%", "width": "24%", "height": "20%"}
},
    # Back-to-front drawing order, so smaller pieces land on top.
    LAYERS: list[str] = ["Outerwear", "Dress", "Top", "Bottom", "Bag", "Shoes", "Accessory", "Other"];


def _slot_key(item: ClothingItem, has_outer: bool) -> str {
    if item.category == "Top" and has_outer { return "TopWithOuter"; }
    if item.category in SLOTS { return item.category; }
    return "Other";
}


def _layer(item: ClothingItem) -> int {
    return LAYERS.index(item.category) if item.category in LAYERS else len(LAYERS);
}


def:pub OutfitCollage(
    items: list[ClothingItem],
    compact: bool = False,
    height: int = 0,
    on_item_press: Callable[[ClothingItem], None] | None = None,
    background_color: str = "",
    item_cards: bool = True
) -> JsxElement {
    has_outer = any([i.category == "Outerwear" for i in items]);
    # One piece per slot; later pieces of the same slot are skipped.
    placed: list[ClothingItem] = [];
    used: list[str] = [];
    for item in sorted(items, key=lambda (i: ClothingItem) -> int { return _layer(i); }) {
        key = _slot_key(item, has_outer);
        if key in used { continue; }
        used.append(key);
        placed.append(item);
    }
    board_height = height if height > 0 else (170 if compact else 320);
    sticker_edge = 3 if compact else 5;
    return <View style={{
        "height": board_height,
        "position": "relative",
        "overflow": "hidden",
        "borderRadius": 16 if compact else 20,
        "backgroundColor": background_color or C.board
    }}>
        {[
            <Pressable
                key={item.clothing_item_id}
                disabled={on_item_press is None}
                onPress={lambda { if on_item_press is not None { on_item_press(item); } }}
                style={[
                {
                    "position": "absolute",
                    "padding": sticker_edge if item_cards else 0,
                    "borderRadius": (12 if compact else 16) if item_cards else 0,
                    "backgroundColor": "#FFFFFF" if item_cards else "transparent",
                    "shadowColor": "#3B2A1F" if item_cards else "transparent",
                    "shadowOpacity": 0.16 if item_cards else 0,
                    "shadowRadius": 6 if item_cards else 0,
                    "shadowOffset": {"width": 0, "height": 3 if item_cards else 0},
                    "elevation": 3 if item_cards else 0
                },
                SLOTS[_slot_key(item, has_outer)]
            ]}>
                <Image
                    source={{"uri": resolve_clothing_image_uri(item.image_path)}}
                    style={{"width": "100%", "height": "100%", "borderRadius": (9 if compact else 12) if item_cards else 0}}
                    resizeMode="contain"
                />
            </Pressable>
            for item in placed
        ]}
    </View>;
}
