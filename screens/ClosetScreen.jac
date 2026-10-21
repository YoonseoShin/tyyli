"""My closet: add clothes, browse them as a grid, open one to see its metadata.

Finding pictures online: "Find online" reverse-image-searches the whole photo,
"Crop & search" lets the user box one item in the photo first, and "Search by
name" / the closet's web search look products up by text.
"""
import from "@jac/mobui" { Image, Pressable, ScrollView, Text, TextInput, View }
import from ..components.Button { Busy, Button }
import from ..photo_storage { get_clothing_image_size, resolve_clothing_image_uri }
import from ..product_lookup { ProductCandidate }
import from ..services.wardrobe_actions {
    add_from_camera,
    add_from_candidate,
    add_from_gallery,
    add_from_url,
    analyze_item,
    find_online,
    find_online_cropped,
    is_analyzed,
    remove_item,
    search_online,
    use_candidate,
    use_original_photo
}
import from ..storage { ClothingItem }
import from ..ui.kit { C, ui }


glob MIN_CROP_PX: int = 24,
     MAX_CROP_HEIGHT: int = 440;


def or_dash(values: list[str]) -> str {
    return ", ".join(values) if values else "-";
}


def lookup_heading(status: str) -> str {
    if status == "matched" { return "Found online: "; }
    if status == "picked" { return "Picked by you: "; }
    return "Closest-looking picture online: ";
}


def:pub ClosetScreen(clothes: list[ClothingItem], on_changed: Callable[[], None]) -> JsxElement {
    has status: str = "",
        image_url: str = "",
        analyzing_ids: list[str] = [],
        looking_up_ids: list[str] = [],
        alt_item_id: str = "",
        alt_heading: str = "",
        alt_candidates: list[ProductCandidate] = [],
        name_query: str = "",
        show_name_search: bool = False,
        web_query: str = "",
        web_results: list[ProductCandidate] = [],
        web_searching: bool = False,
        crop_mode: bool = False,
        crop_image_w: int = 0,
        crop_image_h: int = 0,
        crop_area_w: float = 0.0,
        crop_x0: float = 0.0,
        crop_y0: float = 0.0,
        crop_x1: float = 0.0,
        crop_y1: float = 0.0,
        last_crop_item: str = "",
        last_crop_box: list[float] = [],
        selected_id: str = "";

    async def analyze(item: ClothingItem) {
        analyzing_ids = analyzing_ids + [item.clothing_item_id];
        status = "Analyzing " + item.name + " with AI...";
        timeout_id = setTimeout(
            lambda {
                analyzing_ids = [i for i in analyzing_ids if i != item.clothing_item_id];
                status = "AI analysis timed out. Check the server connection and try again.";
            },
            75000
        );
        try {
            await analyze_item(item);
            status = "Analyzed " + item.name + ".";
        } except Exception as e {
            status = "AI analysis failed: " + str(e);
        } finally {
            clearTimeout(timeout_id);
            analyzing_ids = [i for i in analyzing_ids if i != item.clothing_item_id];
        }
        on_changed();
    }

    # Reverse image search; `box` is (left, top, width, height) as fractions of the
    # photo, or empty for the whole photo. A box drawn earlier for this item is
    # reused by "Search again" until "Search whole photo" clears it.
    async def find_product(item: ClothingItem, box: list[float] = []) {
        if not box and last_crop_item == item.clothing_item_id {
            box = last_crop_box;
        }
        looking_up_ids = looking_up_ids + [item.clothing_item_id];
        status = ("Searching the web for the boxed part of " if box else "Searching the web for ") + item.name + "...";
        timeout_id = setTimeout(
            lambda {
                looking_up_ids = [i for i in looking_up_ids if i != item.clothing_item_id];
                status = "Product lookup timed out. Check the server connection and try again.";
            },
            180000
        );
        try {
            result = (await find_online_cropped(item, box[0], box[1], box[2], box[3])) if box else (await find_online(item));
            # The chosen picture is first; the rest are offered as alternatives.
            alt_item_id = item.clothing_item_id;
            alt_heading = "Not the right picture? Tap a closer one:";
            alt_candidates = result.candidates[1:] if result.matched else result.candidates;
            if result.match_type == "exact" {
                status = "Found it on " + result.source + ".";
            } elif result.match_type == "similar" {
                status = "Found the closest-looking picture on " + result.source + ".";
            } else {
                status = "No close picture found. " + result.note;
            }
        } except Exception as e {
            status = "Product lookup failed: " + str(e);
        } finally {
            clearTimeout(timeout_id);
            looking_up_ids = [i for i in looking_up_ids if i != item.clothing_item_id];
        }
        on_changed();
    }

    async def search_by_name(item: ClothingItem) {
        query = name_query.strip();
        if not query {
            status = "Type what the item is, e.g. 'aritzia super puff navy'.";
            return;
        }
        looking_up_ids = looking_up_ids + [item.clothing_item_id];
        status = "Searching for '" + query + "'...";
        try {
            results = await search_online(query);
            alt_item_id = item.clothing_item_id;
            alt_heading = "Tap the picture to use for this item:";
            alt_candidates = results;
            status = (str(len(results)) + " pictures found.") if results else "Nothing found for '" + query + "'.";
        } except Exception as e {
            status = "Search failed: " + str(e);
        } finally {
            looking_up_ids = [i for i in looking_up_ids if i != item.clothing_item_id];
        }
    }

    async def pick_candidate(item: ClothingItem, cand: ProductCandidate) {
        looking_up_ids = looking_up_ids + [item.clothing_item_id];
        status = "Downloading the picture from " + cand.source + "...";
        try {
            await use_candidate(item, cand);
            alt_candidates = [c for c in alt_candidates if c.image != cand.image];
            status = "Using the picture from " + cand.source + ".";
        } except Exception as e {
            status = "Could not use that picture: " + str(e);
        } finally {
            looking_up_ids = [i for i in looking_up_ids if i != item.clothing_item_id];
        }
        on_changed();
    }

    async def revert_photo(item: ClothingItem) {
        try {
            await use_original_photo(item);
            status = "Showing your own photo again.";
        } except Exception as e {
            status = "Could not restore the photo: " + str(e);
        }
        on_changed();
    }

    # --- Crop & search ---
    async def start_crop(item: ClothingItem) {
        crop_x0 = 0.0; crop_y0 = 0.0; crop_x1 = 0.0; crop_y1 = 0.0;
        crop_image_w = 0;
        crop_image_h = 0;
        crop_mode = True;
        status = "";
        try {
            size = await get_clothing_image_size(item.original_image_path or item.image_path);
            crop_image_w = size["width"];
            crop_image_h = size["height"];
        } except Exception {}
    }

    def crop_box_size -> list[float] {
        # Displayed size of the photo inside the crop area, keeping its aspect ratio.
        if crop_area_w <= 0 { return [0.0, 0.0]; }
        ratio = (crop_image_h / crop_image_w) if crop_image_w > 0 and crop_image_h > 0 else 1.0;
        w = crop_area_w;
        h = w * ratio;
        if h > MAX_CROP_HEIGHT {
            h = MAX_CROP_HEIGHT;
            w = h / ratio;
        }
        return [w, h];
    }

    async def search_crop(item: ClothingItem) {
        size = crop_box_size();
        left = Math.min(crop_x0, crop_x1);
        top = Math.min(crop_y0, crop_y1);
        width = Math.abs(crop_x1 - crop_x0);
        height = Math.abs(crop_y1 - crop_y0);
        if size[0] <= 0 or width < MIN_CROP_PX or height < MIN_CROP_PX {
            status = "Drag a box around the item first.";
            return;
        }
        crop_mode = False;
        last_crop_item = item.clothing_item_id;
        last_crop_box = [left / size[0], top / size[1], width / size[0], height / size[1]];
        await find_product(item, last_crop_box);
    }

    # --- Adding items ---
    async def handle_new(new_items: list[ClothingItem]) {
        if not new_items {
            status = "Nothing added.";
            return;
        }
        status = str(len(new_items)) + " item(s) added. Analyzing...";
        on_changed();
        for item in new_items {
            await analyze(item);
        }
    }

    async def add(source: str) {
        try {
            status = "Adding...";
            if source == "camera" {
                await handle_new(await add_from_camera());
            } elif source == "gallery" {
                await handle_new(await add_from_gallery());
            } else {
                if not image_url.strip() {
                    status = "Paste an image URL first.";
                    return;
                }
                new_items = await add_from_url(image_url);
                image_url = "";
                await handle_new(new_items);
            }
        } except Exception as e {
            status = "Could not add: " + str(e);
        }
    }

    async def search_web {
        query = web_query.strip();
        if not query {
            status = "Type what to look for, e.g. 'levi's trucker jacket'.";
            return;
        }
        web_searching = True;
        status = "Searching for '" + query + "'...";
        try {
            web_results = await search_online(query);
            status = (str(len(web_results)) + " pictures found. Tap one to add it.") if web_results else "Nothing found for '" + query + "'.";
        } except Exception as e {
            status = "Search failed: " + str(e);
        } finally {
            web_searching = False;
        }
    }

    async def add_result(cand: ProductCandidate) {
        try {
            web_searching = True;
            status = "Adding the picture from " + cand.source + "...";
            new_items = await add_from_candidate(cand);
            web_results = [];
            web_query = "";
            web_searching = False;
            await handle_new(new_items);
        } except Exception as e {
            web_searching = False;
            status = "Could not add: " + str(e);
        }
    }

    async def delete_item(item: ClothingItem) {
        try {
            await remove_item(item);
            selected_id = "";
            status = "Deleted " + item.name + ".";
            on_changed();
        } except Exception as e {
            status = "Could not delete: " + str(e);
        }
    }

    selected = [c for c in clothes if c.clothing_item_id == selected_id];

    # Crop & search: box one item in the photo, then reverse-image-search just that part.
    if selected and crop_mode {
        item = selected[0];
        box = crop_box_size();
        return <View style={ui.screen}>
            <View style={ui.page}>
                <Text style={ui.title}>Box the item to search</Text>
                <Text style={ui.muted}>Drag your finger across the photo to draw a box around one piece of clothing.</Text>
                <View
                    style={{"width": "100%", "alignItems": "center"}}
                    onLayout={lambda (e: any) { crop_area_w = e.nativeEvent.layout.width; }}
                >
                    {(
                        <View
                            style={{"width": box[0], "height": box[1], "backgroundColor": C.soft, "borderRadius": 12, "overflow": "hidden"}}
                            onTouchStart={lambda (e: any) {
                                crop_x0 = e.nativeEvent.locationX;
                                crop_y0 = e.nativeEvent.locationY;
                                crop_x1 = crop_x0;
                                crop_y1 = crop_y0;
                            }}
                            onTouchMove={lambda (e: any) {
                                crop_x1 = Math.max(0.0, Math.min(box[0], e.nativeEvent.locationX));
                                crop_y1 = Math.max(0.0, Math.min(box[1], e.nativeEvent.locationY));
                            }}
                            onTouchEnd={lambda (e: any) {
                                crop_x1 = Math.max(0.0, Math.min(box[0], e.nativeEvent.locationX));
                                crop_y1 = Math.max(0.0, Math.min(box[1], e.nativeEvent.locationY));
                            }}
                        >
                            <Image
                                source={{"uri": resolve_clothing_image_uri(item.original_image_path or item.image_path)}}
                                style={{"width": "100%", "height": "100%"}}
                                resizeMode="contain"
                            />
                            {(
                                <View
                                    pointerEvents="none"
                                    style={{
                                        "position": "absolute",
                                        "left": Math.min(crop_x0, crop_x1),
                                        "top": Math.min(crop_y0, crop_y1),
                                        "width": Math.abs(crop_x1 - crop_x0),
                                        "height": Math.abs(crop_y1 - crop_y0),
                                        "borderWidth": 2,
                                        "borderColor": C.accent,
                                        "backgroundColor": "rgba(255,255,255,0.25)"
                                    }}
                                />
                            ) if crop_x1 != crop_x0 or crop_y1 != crop_y0 else None}
                        </View>
                    ) if box[0] > 0 else None}
                </View>
                <View style={ui.row}>
                    <Button label="Cancel" kind="ghost" on_press={lambda { crop_mode = False; }}/>
                    <Button label="Search this area" on_press={lambda { search_crop(item); }}/>
                </View>
                {(<Text style={ui.muted}>{status}</Text>) if status else None}
            </View>
        </View>;
    }

    # Item detail
    if selected {
        item = selected[0];
        busy = item.clothing_item_id in looking_up_ids;
        cropped = last_crop_item == item.clothing_item_id and last_crop_box;
        return <ScrollView
            style={ui.screen}
            contentContainerStyle={ui.page}
            keyboardShouldPersistTaps="handled"
            automaticallyAdjustKeyboardInsets={True}
        >
            <Pressable onPress={lambda { selected_id = ""; }}>
                <Text style={ui.link}>← Closet</Text>
            </Pressable>
            <Image source={{"uri": resolve_clothing_image_uri(item.image_path)}} style={ui.thumbLarge} resizeMode="contain"/>
            <Text style={ui.title}>{item.name}</Text>
            {(<Busy label={status or "Working..."}/>) if busy or item.clothing_item_id in analyzing_ids else None}
            {(<Text style={ui.muted}>Analyzing with AI...</Text>) if item.clothing_item_id in analyzing_ids else (
                <View style={ui.card}>
                    <Text style={ui.body}>{"Type: " + item.category}</Text>
                    <Text style={ui.body}>{"Colors: " + or_dash(item.colors)}</Text>
                    <Text style={ui.body}>{"Mood: " + or_dash(item.style_tags)}</Text>
                    <Text style={ui.body}>{"Best for: " + or_dash(item.occasions)}</Text>
                    <Text style={ui.body}>{"Seasons: " + or_dash(item.seasons)}</Text>
                    {(<Text style={ui.body}>{"Warmth: " + str(item.warmth) + "/5" + (" · Waterproof" if item.waterproof else "")}</Text>) if item.warmth > 0 else (
                        (<Text style={ui.body}>Waterproof</Text>) if item.waterproof else None
                    )}
                    {(<Text style={ui.muted}>{item.description}</Text>) if item.description else None}
                </View>
            ) if is_analyzed(item) else (<Text style={ui.muted}>Not analyzed yet.</Text>)}
            {(
                <View style={ui.card}>
                    <Text style={ui.body}>{lookup_heading(item.lookup_status) + item.name}</Text>
                    {(<Text style={ui.body}>{"Brand: " + item.brand}</Text>) if item.brand else None}
                    {(<Text style={ui.body}>{"Price: " + item.price}</Text>) if item.price else None}
                    {(<Text style={ui.muted} numberOfLines={2}>{item.source_product_url}</Text>) if item.source_product_url else None}
                    {(<Text style={ui.muted}>{item.lookup_note}</Text>) if item.lookup_note else None}
                    {(<Text style={ui.muted}>Your own photo is kept; tap "Use my photo" to switch back.</Text>) if item.original_image_path else None}
                </View>
            ) if item.lookup_status in ["matched", "similar", "picked"] and not busy else (
                <View style={ui.card}>
                    {(<Text style={ui.body}>{"Brand: " + item.brand}</Text>) if item.brand else None}
                    <Text style={ui.muted}>{"No close picture found online. " + item.lookup_note}</Text>
                </View>
            ) if item.lookup_status == "no_match" and not busy else None}
            {(
                <View style={ui.card}>
                    <Text style={ui.body}>{alt_heading}</Text>
                    <ScrollView horizontal={True} showsHorizontalScrollIndicator={False}>
                        <View style={ui.row}>
                            {[
                                <Pressable key={cand.image} onPress={lambda { pick_candidate(item, cand); }}>
                                    <Image source={{"uri": cand.thumbnail}} style={ui.thumb} resizeMode="cover"/>
                                </Pressable>
                                for cand in alt_candidates
                            ]}
                        </View>
                    </ScrollView>
                </View>
            ) if alt_item_id == item.clothing_item_id and alt_candidates and not busy else None}
            <View style={ui.row}>
                <Button
                    label={"Re-analyze" if is_analyzed(item) else "Analyze"}
                    kind="ghost"
                    disabled={item.clothing_item_id in analyzing_ids or busy}
                    busy={item.clothing_item_id in analyzing_ids}
                    on_press={lambda { analyze(item); }}
                />
                <Button
                    label={("Search again (boxed area)" if cropped else "Search again") if item.lookup_status else "Find online"}
                    kind="ghost"
                    disabled={busy}
                    busy={busy}
                    on_press={lambda { find_product(item); }}
                />
            </View>
            {(<Pressable onPress={lambda { last_crop_item = ""; last_crop_box = []; }}>
                <Text style={ui.link}>Search the whole photo instead</Text>
            </Pressable>) if cropped and not busy else None}
            <View style={ui.row}>
                <Button label="Crop & search" kind="ghost" disabled={busy} on_press={lambda { start_crop(item); }}/>
                <Button label="Search by name" kind="ghost" disabled={busy} on_press={lambda { show_name_search = not show_name_search; }}/>
            </View>
            {(
                <View style={ui.row}>
                    <TextInput
                        style={ui.input}
                        value={name_query}
                        onChangeText={lambda (t: str) { name_query = t; }}
                        placeholder="e.g. aritzia super puff navy"
                        autoCapitalize="none"
                        autoCorrect={False}
                        returnKeyType="search"
                        onSubmitEditing={lambda { search_by_name(item); }}
                    />
                    <Button label="Search" grow={False} disabled={busy} busy={busy} on_press={lambda { search_by_name(item); }}/>
                </View>
            ) if show_name_search else None}
            <View style={ui.row}>
                {(<Button label="Use my photo" kind="ghost" disabled={busy} on_press={lambda { revert_photo(item); }}/>) if item.original_image_path else None}
                <Button label="Delete" kind="danger" disabled={busy} on_press={lambda { delete_item(item); }}/>
            </View>
            {(<Text style={ui.muted}>{status}</Text>) if status and not busy else None}
        </ScrollView>;
    }

    # Grid
    return <ScrollView
        style={ui.screen}
        contentContainerStyle={ui.page}
        keyboardShouldPersistTaps="handled"
        automaticallyAdjustKeyboardInsets={True}
    >
        <Text style={ui.title}>My closet</Text>
        <Text style={ui.muted}>{str(len(clothes)) + " item(s)"}</Text>

        <View style={ui.card}>
            <View style={ui.row}>
                <Button label="Take photo" on_press={lambda { add("camera"); }}/>
                <Button label="From gallery" on_press={lambda { add("gallery"); }}/>
            </View>
            <View style={ui.row}>
                <TextInput
                    style={ui.input}
                    value={web_query}
                    onChangeText={lambda (t: str) { web_query = t; }}
                    placeholder="Search the web, e.g. levi's trucker jacket"
                    autoCapitalize="none"
                    autoCorrect={False}
                    returnKeyType="search"
                    onSubmitEditing={lambda { search_web(); }}
                />
                <Button label="Search" grow={False} disabled={web_searching} busy={web_searching} on_press={lambda { search_web(); }}/>
            </View>
            <View style={ui.row}>
                <TextInput
                    style={ui.input}
                    value={image_url}
                    onChangeText={lambda (t: str) { image_url = t; }}
                    placeholder="Image URL (for testing)"
                    autoCapitalize="none"
                    autoCorrect={False}
                />
                <Button label="Save" grow={False} on_press={lambda { add("url"); }}/>
            </View>
            {(<Busy label={status}/>) if web_searching else ((<Text style={ui.muted}>{status}</Text>) if status else None)}
        </View>

        {(
            <View style={ui.card}>
                <View style={ui.rowBetween}>
                    <Text style={ui.body}>Tap a picture to add it to your closet</Text>
                    <Pressable onPress={lambda { web_results = []; }}>
                        <Text style={ui.link}>Clear</Text>
                    </Pressable>
                </View>
                <View style={[ui.wrap, {"justifyContent": "space-between"}]}>
                    {[
                        <Pressable key={cand.image} style={ui.gridItem} onPress={lambda { add_result(cand); }}>
                            <Image source={{"uri": cand.thumbnail}} style={ui.gridImage} resizeMode="cover"/>
                            <Text style={ui.muted} numberOfLines={2}>{cand.title or cand.source}</Text>
                        </Pressable>
                        for cand in web_results
                    ]}
                </View>
            </View>
        ) if web_results else None}

        {(<Text style={ui.muted}>Your closet is empty. Add your first item above.</Text>) if not clothes else None}
        <View style={[ui.wrap, {"justifyContent": "space-between"}]}>
            {[
                <Pressable key={item.clothing_item_id} style={ui.gridItem} onPress={lambda { selected_id = item.clothing_item_id; }}>
                    <Image source={{"uri": resolve_clothing_image_uri(item.image_path)}} style={ui.gridImage} resizeMode="cover"/>
                    <Text style={ui.body} numberOfLines={1}>{item.name}</Text>
                    <Text style={ui.muted}>{"Analyzing..." if item.clothing_item_id in analyzing_ids else item.category}</Text>
                </Pressable>
                for item in clothes
            ]}
        </View>
    </ScrollView>;
}
