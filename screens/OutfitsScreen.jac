"""Outfit Picks (DESIGN_SYSTEM.md 8.2): the look on a soft board, the stylist's
note, actions, the pieces in the look, and the detailed reasons on request.
"""
import from "@jac/mobui" { Image, Modal, Pressable, ScrollView, Text, View, useWindowDimensions }
import from ..components.AppIcon { AppIcon }
import from ..components.AuraBackground { AuraBackground }
import from ..components.Button { Button }
import from ..components.ClosetThumb { ClosetThumb }
import from ..components.LookItemRow { LookItemRow }
import from ..components.OutfitCard { items_for }
import from ..components.OutfitCollage { OutfitCollage, garment_photo_uri }
import from ..components.OutfitInsights { OutfitInsights }
import from ..components.ScreenHeader { ScreenHeader }
import from ..components.StylistNote { StylistNote }
import from ..components.TabSelector { TabSelector }
import from ..models { Outfit, WeatherInfo }
import from ..services.outfit_service { apply_swaps }
import from ..services.weather_service { to_unit }
import from ..storage { ClothingItem }
import from ..ui.kit { C, S, ui }
import from ..ui.materials { BOARD_BG }


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
    },
    WEEKDAYS: list[str] = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
    MONTHS: list[str] = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];


def today_caption -> str {
    now = new(Date);
    return str(WEEKDAYS[int(now.getDay())]) + ", " + str(now.getDate()) + " " + str(MONTHS[int(now.getMonth())]);
}


# One tab label per pick: the plan it is for ("All day", an event title), made
# unique because labels double as keys.
def look_labels(picks: list[Outfit]) -> list[str] {
    labels: list[str] = [];
    for pick in picks {
        base = pick.event_title or pick.style_name or "Look";
        label = base;
        n = 2;
        while label in labels {
            label = base + " " + str(n);
            n = n + 1;
        }
        labels.append(label);
    }
    return labels;
}


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
        return <ScreenHeader title="Outfit Picks" subtitle={today_caption()} on_back={lambda { on_back(); }}>
            {(
                <View style={ui.glassChip} accessibilityLabel={"Weather " + temp_label + ((", " + weather.condition) if weather is not None and weather.condition else "")}>
                    <AppIcon name="weather-partly-cloudy" size={18} color={C.text_secondary}/>
                    <Text style={[ui.textLabel, ui.w600]}>{temp_label}</Text>
                    {(<Text style={[ui.textLabel, ui.w400, {"color": C.text_secondary, "maxWidth": 120}]} numberOfLines={1}>{weather.condition}</Text>) if weather is not None and weather.condition else None}
                </View>
            ) if temp_label else None}
        </ScreenHeader>;
    }

    if not picks {
        return <View style={ui.screen}>
            <AuraBackground/>
            <ScrollView style={ui.flex1} contentContainerStyle={ui.pageSoft}>
                {header()}
                <View style={ui.glassPanel}>
                    <Text style={ui.textH2}>No looks yet</Text>
                    <Text style={ui.textBody}>Add and analyze at least a top and a bottom in your closet, then generate today's picks from Home.</Text>
                </View>
            </ScrollView>
        </View>;
    }

    index = selected if selected < len(picks) else 0;
    base = picks[index];
    active_swaps = swap_ids if swaps_for == base.outfit_id else [];
    outfit = apply_swaps(base, clothes, active_swaps);
    items = items_for(outfit, clothes);
    # Pieces of a saved pick that were since deleted from the closet. They are
    # not drawn (there is no photo to show), and the screen says so.
    closet_ids = [c.clothing_item_id for c in clothes];
    missing_count = len([item_id for item_id in outfit.clothing_item_ids if item_id not in closet_ids]);
    worn = worn_today_key != "" and worn_today_key == ",".join(sorted(outfit.clothing_item_ids));
    swapped = sorted(outfit.clothing_item_ids) != sorted(base.clothing_item_ids);
    labels = look_labels(picks);
    active_tabs = [tab for tab in SWAP_TABS if any([item.category in tab[1] for item in items])];
    if not active_tabs {
        active_tabs = [SWAP_TABS[0]];
    }
    active_tab_names = [tab[0] for tab in active_tabs];
    effective_swap_tab = swap_tab if swap_tab in active_tab_names else active_tabs[0][0];
    tab_categories: list[str] = [tab[1] for tab in active_tabs if tab[0] == effective_swap_tab][0];
    # Keep the original pick's item first, followed by the alternatives.
    ai_choices = [item for item in clothes if item.category in tab_categories and item.clothing_item_id in base.clothing_item_ids];
    other_choices = [item for item in clothes if item.category in tab_categories and item.clothing_item_id not in base.clothing_item_ids];
    swap_choices = ai_choices + other_choices;
    # The board fills the content width; its height follows, within limits that
    # keep it usable on an iPhone SE and calm on a large phone.
    board_width: float = min(560.0, float(viewport.width)) - float(2 * S.xl);
    board_height = int(min(420.0, max(300.0, board_width * 1.12)));

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

    def select_look(label: str) {
        if label in labels {
            swap_ids = [];
            swaps_for = "";
            on_select(labels.index(label));
        }
    }

    return <View style={ui.screen}>
        <AuraBackground/>
        <ScrollView style={ui.flex1} contentContainerStyle={ui.pageSoft} showsVerticalScrollIndicator={False}>
            {header()}

            {(<TabSelector options={labels} selected={labels[index]} on_select={lambda (label: str) { select_look(label); }} scroll={len(picks) > 2}/>) if len(picks) > 1 else None}

            <View style={[ui.boardFrame, {"height": board_height}]}>
                <View style={[ui.boardClip, ui.flex1]}>
                    <Image source={{"uri": BOARD_BG}} style={ui.fill} resizeMode="stretch" accessibilityElementsHidden={True} importantForAccessibility="no"/>
                    <OutfitCollage
                        items={items}
                        height={board_height - 2}
                        background_color="transparent"
                        item_cards={False}
                        numbered={True}
                        framed={True}
                        on_item_press={lambda (item: ClothingItem) { open_swap(item); }}
                    />
                </View>
            </View>
            {#* The hint sits under the board so it never covers a closet photo. *#}
            <View style={[ui.row, {"gap": 6, "marginTop": -6, "paddingHorizontal": S.xs}]} accessibilityElementsHidden={True} importantForAccessibility="no-hide-descendants">
                <AppIcon name="gesture-tap" size={15} color={C.text_secondary}/>
                <Text style={ui.textCaption}>Tap a piece on the board to swap it</Text>
            </View>

            <StylistNote outfit={outfit} swapped={swapped} on_reset={lambda { reset_all_swaps(); }}/>

            <View style={ui.row}>
                <Button
                    label="Regenerate"
                    kind="secondary"
                    icon="refresh"
                    grow={False}
                    busy={regenerating}
                    disabled={regenerating}
                    on_press={lambda { swap_ids = []; swaps_for = ""; on_regenerate(); }}
                />
                {(
                    <Button label="Saved to History" kind="secondary" icon="check" icon_color={C.success} on_press={lambda { on_wear(outfit); }}/>
                ) if worn else (
                    <Button label="Wearing today" icon="check" on_press={lambda { on_wear(outfit); }}/>
                )}
            </View>

            <View style={ui.glass}>
                <View style={[ui.rowBetween, {"paddingHorizontal": S.xl, "paddingTop": S.xl, "paddingBottom": S.xs}]}>
                    <Text style={ui.textH2} accessibilityRole="header">In this look</Text>
                    <Text style={ui.textCaption}>{str(len(items)) + (" piece" if len(items) == 1 else " pieces")}</Text>
                </View>
                {[
                    <View key={item.clothing_item_id}>
                        {(<View style={[ui.hairline, {"marginLeft": 106, "marginRight": S.xl}]}/>) if n > 0 else None}
                        <LookItemRow
                            item={item}
                            number={n + 1}
                            swapped={item.clothing_item_id not in base.clothing_item_ids}
                            on_swap={lambda { open_swap(item); }}
                        />
                    </View>
                    for (n, item) in enumerate(items)
                ]}
                {(
                    <View style={[ui.row, {"marginHorizontal": S.xl, "marginTop": S.xs, "padding": S.md, "borderRadius": 16, "backgroundColor": C.glass_strong, "borderWidth": 1, "borderColor": C.keyword_edge}]} accessibilityLiveRegion="polite">
                        <AppIcon name="information-outline" size={17} color={C.text_secondary}/>
                        <Text style={[ui.textCaption, ui.flex1, {"color": C.primary_light}]}>{(str(missing_count) + (" piece" if missing_count == 1 else " pieces") + " from this look " + ("is" if missing_count == 1 else "are") + " no longer in your closet.")}</Text>
                    </View>
                ) if missing_count > 0 else None}
                <Text style={[ui.textCaption, {"paddingHorizontal": S.xl, "paddingTop": S.sm, "paddingBottom": 18}]}>{"Swapped pieces show on the board. Reset in the note to return to the original pick." if swapped else "Swap any piece for another from your closet."}</Text>
            </View>

            <OutfitInsights outfit={outfit} collapsible={True} initially_open={False} note={"These describe the original pick" if swapped else ""}/>
        </ScrollView>

        <Modal visible={swap_open} transparent={True} animationType="slide" onRequestClose={lambda { swap_open = False; }}>
            <Pressable style={{"flex": 1, "backgroundColor": C.overlay, "justifyContent": "flex-end"}} accessibilityLabel="Close" onPress={lambda { swap_open = False; }}>
                <Pressable style={[ui.sheet, {"maxHeight": viewport.height * 0.62}]} onPress={lambda { }}>
                    <View style={ui.sheetHandle}/>
                    <View style={ui.rowBetween}>
                        <Text style={ui.textH2} accessibilityRole="header">{SWAP_TITLES.get(effective_swap_tab, "Swap item")}</Text>
                        <Pressable accessibilityRole="button" accessibilityLabel="Reset to the original pick" hitSlop={{"top": 12, "bottom": 12, "left": 12, "right": 12}} onPress={lambda { reset_all_swaps(); }}>
                            <Text style={[ui.textLabel, ui.w600]}>Reset</Text>
                        </Pressable>
                    </View>
                    <TabSelector options={active_tab_names} selected={effective_swap_tab} on_select={lambda (tab_name: str) { swap_tab = tab_name; }} scroll={True}/>
                    {(<Text style={[ui.textBody, {"color": C.text_secondary}]}>No items in this category yet.</Text>) if not swap_choices else (
                        <ScrollView horizontal={True} showsHorizontalScrollIndicator={False}>
                            <View style={[ui.row, {"gap": S.md, "alignItems": "flex-start", "paddingVertical": S.xs}]}>
                                {[
                                    <ClosetThumb
                                        key={item.clothing_item_id}
                                        uri={garment_photo_uri(item)}
                                        size={96}
                                        label={item.name}
                                        selected={item.clothing_item_id in outfit.clothing_item_ids}
                                        badge={"Original" if item.clothing_item_id in base.clothing_item_ids else ""}
                                        on_press={lambda { swap_in(item); }}
                                    />
                                    for item in swap_choices
                                ]}
                            </View>
                        </ScrollView>
                    )}
                </Pressable>
            </Pressable>
        </Modal>
    </View>;
}
