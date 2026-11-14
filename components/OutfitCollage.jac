"""Sticker-style outfit board made from the user's own clothing photos.

Each piece sits where it would on a flat-lay: the top up high, the bottom to
the lower right, shoes at the lower left, the bag on the left, small
accessories in the top corner. Callers can keep the sticker card treatment,
show the photo without an added background, or (`framed`) show each photo at
its own proportions as a soft rounded print.

Every image is the item's closet photo (`garment_photo_uri`). A photo that is
missing or fails to load shows an empty "Photo unavailable" state; nothing is
ever substituted for the user's garment.
"""
import from "@jac/mobui" { Image, Pressable, Text, View }
import from .AppIcon { AppIcon }
import from ..photo_storage { resolve_clothing_image_uri }
import from ..storage { ClothingItem }
import from ..ui.kit { C, ui }


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


# The garment as the user photographed it. "Find online" can replace an item's
# photo with a shop photo of a similar product (keeping the user's own in
# `original_image_path`); outfits always show the user's own photo, or the
# stored photo when there was no swap. "" when the item has no photo.
def:pub garment_photo_uri(item: ClothingItem) -> str {
    path = item.original_image_path or item.image_path;
    return resolve_clothing_image_uri(path) if path else "";
}


def _slot_key(item: ClothingItem, has_outer: bool) -> str {
    if item.category == "Top" and has_outer { return "TopWithOuter"; }
    if item.category in SLOTS { return item.category; }
    return "Other";
}


def _layer(item: ClothingItem) -> int {
    return LAYERS.index(item.category) if item.category in LAYERS else len(LAYERS);
}


def _share(value: str) -> float {
    return float(value.replace("%", "")) / 100.0;
}


# The photo's rectangle inside its slot when fitted whole ("contain"):
# [left, top, width, height] in points, or [] until the board width and the
# photo's natural size are known.
def _fit_rect(slot: dict[str, str], board_width: float, board_height: float, size: list[float]) -> list[float] {
    if board_width <= 0 or len(size) != 2 or size[0] <= 0 or size[1] <= 0 {
        return [];
    }
    slot_w = _share(slot["width"]) * board_width;
    slot_h = _share(slot["height"]) * board_height;
    scale = min(slot_w / size[0], slot_h / size[1]);
    width = size[0] * scale;
    height = size[1] * scale;
    return [(slot_w - width) / 2.0, (slot_h - height) / 2.0, width, height];
}


# Number markers sit on the photo's top-left corner, or the slot's corner until
# the photo has been measured.
def _marker_spot(rect: list[float]) -> dict[str, float] {
    if not rect { return {"left": 2.0, "top": 2.0}; }
    return {"left": max(0.0, rect[0] - 6.0), "top": max(0.0, rect[1] - 6.0)};
}


def:pub OutfitCollage(
    items: list[ClothingItem],
    compact: bool = False,
    height: int = 0,
    on_item_press: Callable[[ClothingItem], None] | None = None,
    background_color: str = "",
    item_cards: bool = True,
    numbered: bool = False,
    framed: bool = False
) -> JsxElement {
    # Measurements for numbered markers and framed photos, and photos that
    # failed to load.
    has board_width: float = 0.0,
        photo_sizes: dict[str, list[float]] = {},
        failed_ids: list[str] = [];
    measuring = numbered or framed;
    has_outer = any([i.category == "Outerwear" for i in items]);
    # Marker numbers follow the order of `items`, so a list drawn from the same
    # `items` (Outfit Picks' "In this look") shows the same numbers.
    number_of = {i.clothing_item_id: n + 1 for (n, i) in enumerate(items)};
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

    def remember_size(item_id: str, event: any) {
        source: any = event.nativeEvent.source if event and event.nativeEvent else None;
        if measuring and source and source.width and source.height and item_id not in photo_sizes {
            # Copy, then subscript: a `{name: value}` literal here would compile
            # to the literal key "name" on the client.
            updated: dict[str, list[float]] = {**photo_sizes};
            updated[item_id] = [float(source.width), float(source.height)];
            photo_sizes = updated;
        }
    }

    def mark_failed(item_id: str) {
        if item_id not in failed_ids { failed_ids = failed_ids + [item_id]; }
    }

    def photo(item: ClothingItem, rect: list[float]) -> JsxElement {
        uri = garment_photo_uri(item);
        if not uri or item.clothing_item_id in failed_ids {
            return <View style={ui.photoMissing} accessibilityLabel={item.name + ", photo unavailable"}>
                <AppIcon name="image-off-outline" size={18 if compact else 22} color={C.text_secondary}/>
                {(<Text style={[ui.textMicro, {"textAlign": "center"}]} numberOfLines={2}>Photo unavailable</Text>) if not compact else None}
            </View>;
        }
        if framed and rect {
            return <View style={[ui.photoFrame, {"left": rect[0], "top": rect[1], "width": rect[2], "height": rect[3]}]}>
                <View style={ui.photoInner}>
                    <Image source={{"uri": uri}} style={{"width": "100%", "height": "100%"}} resizeMode="cover" onError={lambda { mark_failed(item.clothing_item_id); }}/>
                </View>
            </View>;
        }
        return <Image
            source={{"uri": uri}}
            style={{"width": "100%", "height": "100%", "borderRadius": (9 if compact else 12) if item_cards else 0}}
            resizeMode="contain"
            onLoad={lambda (e: any) { remember_size(item.clothing_item_id, e); }}
            onError={lambda { mark_failed(item.clothing_item_id); }}
        />;
    }

    return <View onLayout={lambda (e: any) { if measuring { board_width = float(e.nativeEvent.layout.width); } }} style={{
        "height": board_height,
        "position": "relative",
        "overflow": "hidden",
        "borderRadius": 16 if compact else 20,
        "backgroundColor": background_color or C.board
    }}>
        {[
            <Pressable
                key={item.clothing_item_id}
                accessibilityRole={"button" if on_item_press is not None else "image"}
                accessibilityLabel={("Swap " if on_item_press is not None else "") + item.name}
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
                {photo(item, _fit_rect(SLOTS[_slot_key(item, has_outer)], board_width, float(board_height), photo_sizes.get(item.clothing_item_id, [])))}
                {(
                    <View style={[ui.boardMarker, _marker_spot(_fit_rect(SLOTS[_slot_key(item, has_outer)], board_width, float(board_height), photo_sizes.get(item.clothing_item_id, [])))]} pointerEvents="none">
                        <Text style={ui.boardMarkerText}>{str(number_of[item.clothing_item_id])}</Text>
                    </View>
                ) if numbered else None}
            </Pressable>
            for item in placed
        ]}
    </View>;
}
