"""Outfit Picks: a roomy sticker-board look with context and closet swaps."""
import from "@jac/mobui" { Image, Modal, Pressable, ScrollView, Text, View, useWindowDimensions }
import from ..components.AppIcon { AppIcon }
import from ..components.Button { Button }
import from ..components.OutfitCard { items_for }
import from ..components.OutfitCollage { OutfitCollage }
import from ..components.OutfitInsights { OutfitInsights }
import from ..models { Outfit, WeatherInfo }
import from ..photo_storage { resolve_clothing_image_uri }
import from ..services.outfit_service { apply_swaps }
import from ..services.weather_service { to_unit }
import from ..storage { ClothingItem }
import from ..ui.kit { C, ui }


glob SWAP_TABS: list[list[any]] = [
    ["Tops", ["Top"]],
    ["Bottoms", ["Bottom"]],
    ["Dresses", ["Dress"]],
    ["Outerwear", ["Outerwear"]],
    ["Shoes", ["Shoes"]],
    ["Bags", ["Bag"]],
    ["Accessories", ["Accessory"]]
],
    SWAP_TITLES: dict[str, str] = {
        "Tops": "Swap top",
        "Bottoms": "Swap bottom",
        "Dresses": "Swap dress",
        "Outerwear": "Swap outerwear",
        "Shoes": "Swap shoes",
        "Bags": "Swap bag",
        "Accessories": "Swap accessory"
    };


def:pub OutfitsScreen(
    picks: list[Outfit],
    selected: int,
    clothes: list[ClothingItem],
    weather: WeatherInfo | None,
    temperature_unit: str,
    worn_today_key: str,
    regenerating: bool,
    on_select: Callable[[int], None],
    on_regenerate: Callable[[], None],
    on_wear: Callable[[Outfit], None],
    on_back: Callable[[], None]
) -> JsxElement {
    has swap_ids: list[str] = [],
        swaps_for: str = "",
        swap_tab: str = "Tops",
        swap_open: bool = False;

    viewport = useWindowDimensions();
    unit = "C" if temperature_unit == "C" else "F";
    temp_label = (str(to_unit(weather.temperature_f, unit)) + "°" + unit) if weather is not None else "";

    def header -> JsxElement {
        return <View style={ui.rowBetween}>
            <View style={[ui.row, {"gap": 12}]}>
                <Pressable style={ui.iconButton} onPress={lambda { on_back(); }}>
                    <AppIcon name="chevron-left" size={22} color={C.ink}/>
                </Pressable>
                <View style={{"flexDirection": "row", "alignItems": "baseline", "gap": 8, "flex": 1}}>
                    <Text style={{"fontSize": 22, "fontWeight": "bold", "color": C.ink}}>Outfit Picks</Text>
                    {(<Text style={{"fontSize": 11, "fontWeight": "bold", "color": C.muted}} numberOfLines={1}>{temp_label + ((" · " + weather.condition) if weather is not None and weather.condition else "")}</Text>) if temp_label else None}
                </View>
            </View>
        </View>;
    }

    if not picks {
        return <ScrollView style={ui.screen} contentContainerStyle={ui.page}>
            {header()}
            <View style={ui.card}>
                <Text style={ui.body}>No outfits yet. Add and analyze at least a top and a bottom in your closet.</Text>
            </View>
        </ScrollView>;
    }

    index = selected if selected < len(picks) else 0;
    base = picks[index];
    active_swaps = swap_ids if swaps_for == base.outfit_id else [];
    outfit = apply_swaps(base, clothes, active_swaps);
    items = items_for(outfit, clothes);
    worn = worn_today_key != "" and worn_today_key == ",".join(sorted(outfit.clothing_item_ids));
    active_tabs = [tab for tab in SWAP_TABS if any([item.category in tab[1] for item in items])];
    if not active_tabs {
        active_tabs = [SWAP_TABS[0]];
    }
    active_tab_names = [tab[0] for tab in active_tabs];
    effective_swap_tab = swap_tab if swap_tab in active_tab_names else active_tabs[0][0];
    tab_categories: list[str] = [tab[1] for tab in active_tabs if tab[0] == effective_swap_tab][0];
    # Keep the original AI-picked item first, followed by the alternatives.
    ai_choices = [item for item in clothes if item.category in tab_categories and item.clothing_item_id in base.clothing_item_ids];
    other_choices = [item for item in clothes if item.category in tab_categories and item.clothing_item_id not in base.clothing_item_ids];
    swap_choices = ai_choices + other_choices;
    def open_swap(item: ClothingItem) {
        matching_tabs = [tab[0] for tab in SWAP_TABS if item.category in tab[1]];
        if matching_tabs { swap_tab = matching_tabs[0]; }
        swap_open = True;
    }

    def swap_in(item: ClothingItem) {
        current = swap_ids if swaps_for == base.outfit_id else [];
        swaps_for = base.outfit_id;
        same_category_swaps = [swap_id for swap_id in current if any([c.clothing_item_id == swap_id and c.category == item.category for c in clothes])];
        kept = [swap_id for swap_id in current if swap_id not in same_category_swaps];
        swap_ids = kept if item.clothing_item_id in base.clothing_item_ids else kept + [item.clothing_item_id];
    }

    def reset_all_swaps {
        swap_ids = [];
        swaps_for = "";
    }

    return <ScrollView style={ui.screen} contentContainerStyle={[ui.page, {"gap": 10}]}>
        {header()}

        <ScrollView horizontal={True} showsHorizontalScrollIndicator={False}>
            <View style={ui.row}>
                {[
                    <Pressable key={pick.outfit_id} style={[ui.chipOutline, {"backgroundColor": C.dark, "borderColor": C.dark} if pick_number == index else {}]} onPress={lambda { swap_ids = []; swaps_for = ""; on_select(pick_number); }}>
                        <Text style={[ui.chipText, ui.chipTextOn] if pick_number == index else ui.chipText}>{pick.style_name}</Text>
                    </Pressable>
                    for (pick_number, pick) in enumerate(picks)
                ]}
            </View>
        </ScrollView>

        <View style={[ui.card, {"padding": 10, "gap": 8}]}>
            <View style={ui.rowBetween}>
                <View style={[ui.row, {"gap": 5}]}>
                    <AppIcon name="gesture-tap" size={14} color={C.muted}/>
                    <Text style={ui.small}>Tap an item to swap it</Text>
                </View>
                <View style={{"paddingVertical": 5, "paddingHorizontal": 10, "borderRadius": 999, "backgroundColor": C.soft}}>
                    <Text style={{"fontSize": 11, "fontWeight": "bold", "color": C.ink}}>{("AI style score: " if outfit.outfit_id.startswith("ai-outfit-") else "Style score: ") + str(outfit.confidence)}</Text>
                </View>
            </View>
            <OutfitCollage items={items} height={260} background_color="transparent" item_cards={False} on_item_press={lambda (item: ClothingItem) { open_swap(item); }}/>
        </View>

        <View style={ui.row}>
            <Button
                label="Regenerate"
                kind="ghost"
                grow={False}
                busy={regenerating}
                disabled={regenerating}
                on_press={lambda { swap_ids = []; swaps_for = ""; on_regenerate(); }}
            />
            <Pressable style={[ui.button, ui.flex1, {"backgroundColor": C.sage_ink} if worn else {}]} onPress={lambda { on_wear(outfit); }}>
                <View style={[ui.row, {"gap": 7}]}>
                    <AppIcon name="check" size={17} color={C.accent_text}/>
                    <Text style={ui.buttonText}>{"Saved to History" if worn else "Wearing Today"}</Text>
                </View>
            </Pressable>
        </View>

        <OutfitInsights outfit={outfit}/>

        <Modal visible={swap_open} transparent={True} animationType="slide" onRequestClose={lambda { swap_open = False; }}>
            <Pressable style={{"flex": 1, "backgroundColor": "transparent", "justifyContent": "flex-end"}} onPress={lambda { swap_open = False; }}>
                <View style={{"maxHeight": viewport.height * 0.58, "paddingTop": 10, "paddingHorizontal": 16, "paddingBottom": 30, "gap": 14, "borderTopLeftRadius": 26, "borderTopRightRadius": 26, "backgroundColor": C.surface}}>
                    <View style={{"alignSelf": "center", "width": 44, "height": 5, "borderRadius": 999, "backgroundColor": C.line}}/>
                    <View style={ui.rowBetween}>
                        <Text style={{"fontSize": 22, "fontWeight": "bold", "color": C.ink}}>{SWAP_TITLES.get(effective_swap_tab, "Swap item")}</Text>
                        <Pressable onPress={lambda { reset_all_swaps(); }}>
                            <Text style={ui.link}>Reset</Text>
                        </Pressable>
                    </View>
                    <ScrollView horizontal={True} showsHorizontalScrollIndicator={False}>
                        <View style={ui.row}>
                            {[
                                <Pressable key={tab[0]} style={[ui.chipOutline, {"paddingVertical": 6, "paddingHorizontal": 12}, {"backgroundColor": C.dark, "borderColor": C.dark} if tab[0] == effective_swap_tab else {}]} onPress={lambda { swap_tab = tab[0]; }}>
                                    <Text style={[{"fontSize": 12, "color": C.ink}, ui.chipTextOn] if tab[0] == effective_swap_tab else {"fontSize": 12, "color": C.ink}}>{tab[0]}</Text>
                                </Pressable>
                                for tab in active_tabs
                            ]}
                        </View>
                    </ScrollView>
                    {(<Text style={ui.muted}>No items in this category yet.</Text>) if not swap_choices else (
                        <ScrollView horizontal={True} showsHorizontalScrollIndicator={False}>
                            <View style={[ui.row, {"gap": 12, "alignItems": "flex-start"}]}>
                                {[
                                    <Pressable key={item.clothing_item_id} style={{"width": 92, "gap": 5}} onPress={lambda { swap_in(item); }}>
                                        <View style={{"width": 92, "height": 104, "padding": 5, "borderRadius": 16, "backgroundColor": "#FFFFFF", "borderWidth": 2, "borderColor": C.ink if item.clothing_item_id in outfit.clothing_item_ids else C.line}}>
                                            <Image source={{"uri": resolve_clothing_image_uri(item.image_path)}} style={{"width": "100%", "height": "100%", "borderRadius": 12, "backgroundColor": "#FFFFFF"}} resizeMode="contain"/>
                                            {(
                                                <View style={{"position": "absolute", "left": 5, "top": 5, "paddingVertical": 3, "paddingHorizontal": 6, "borderRadius": 999, "backgroundColor": C.sage}}>
                                                    <Text style={{"fontSize": 8, "fontWeight": "bold", "letterSpacing": 0.4, "color": C.sage_ink}}>AI PICK</Text>
                                                </View>
                                            ) if item.clothing_item_id in base.clothing_item_ids else None}
                                            {(<View style={{"position": "absolute", "right": 5, "top": 5, "width": 21, "height": 21, "borderRadius": 999, "alignItems": "center", "justifyContent": "center", "backgroundColor": C.sage_ink}}><AppIcon name="check" size={14} color={C.accent_text}/></View>) if item.clothing_item_id in outfit.clothing_item_ids else None}
                                        </View>
                                        <Text style={{"fontSize": 12, "fontWeight": "bold", "color": C.ink}} numberOfLines={2}>{item.name}</Text>
                                    </Pressable>
                                    for item in swap_choices
                                ]}
                            </View>
                        </ScrollView>
                    )}
                </View>
            </Pressable>
        </Modal>
    </ScrollView>;
}
