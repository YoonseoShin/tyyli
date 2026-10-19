"""My closet: add clothes, browse them as a grid, open one to see its metadata."""
import from "@jac/mobui" { Image, Pressable, ScrollView, Text, TextInput, View }
import from ..photo_storage { resolve_clothing_image_uri }
import from ..services.wardrobe_actions {
    add_from_camera,
    add_from_gallery,
    add_from_url,
    analyze_item,
    is_analyzed,
    remove_item
}
import from ..storage { ClothingItem }
import from ..ui.kit { ui }


def or_dash(values: list[str]) -> str {
    return ", ".join(values) if values else "-";
}


def:pub ClosetScreen(clothes: list[ClothingItem], on_changed: Callable[[], None]) -> JsxElement {
    has status: str = "",
        image_url: str = "",
        analyzing_ids: list[str] = [],
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

    # Item detail
    if selected {
        item = selected[0];
        return <ScrollView style={ui.screen} contentContainerStyle={ui.page}>
            <Pressable onPress={lambda { selected_id = ""; }}>
                <Text style={ui.link}>← Closet</Text>
            </Pressable>
            <Image source={{"uri": resolve_clothing_image_uri(item.image_path)}} style={ui.thumbLarge} resizeMode="contain"/>
            <Text style={ui.title}>{item.name}</Text>
            {(<Text style={ui.muted}>Analyzing with AI...</Text>) if item.clothing_item_id in analyzing_ids else (
                <View style={ui.card}>
                    <Text style={ui.body}>{"Type: " + item.category}</Text>
                    <Text style={ui.body}>{"Colors: " + or_dash(item.colors)}</Text>
                    <Text style={ui.body}>{"Mood: " + or_dash(item.style_tags)}</Text>
                    <Text style={ui.body}>{"Best for: " + or_dash(item.occasions)}</Text>
                    <Text style={ui.body}>{"Seasons: " + or_dash(item.seasons)}</Text>
                    <Text style={ui.body}>{"Warmth: " + str(item.warmth) + "/5" + (" · Waterproof" if item.waterproof else "")}</Text>
                    {(<Text style={ui.muted}>{item.description}</Text>) if item.description else None}
                </View>
            ) if is_analyzed(item) else (<Text style={ui.muted}>Not analyzed yet.</Text>)}
            <View style={ui.row}>
                <Pressable
                    style={[ui.button, ui.buttonGhost, ui.flex1]}
                    disabled={item.clothing_item_id in analyzing_ids}
                    onPress={lambda { analyze(item); }}
                >
                    <Text style={[ui.buttonText, ui.buttonGhostText]}>{"Re-analyze" if is_analyzed(item) else "Analyze"}</Text>
                </Pressable>
                <Pressable style={[ui.button, ui.buttonDanger, ui.flex1]} onPress={lambda { delete_item(item); }}>
                    <Text style={ui.buttonText}>Delete</Text>
                </Pressable>
            </View>
            {(<Text style={ui.muted}>{status}</Text>) if status else None}
        </ScrollView>;
    }

    # Grid
    return <ScrollView style={ui.screen} contentContainerStyle={ui.page}>
        <Text style={ui.title}>My closet</Text>
        <Text style={ui.muted}>{str(len(clothes)) + " item(s)"}</Text>

        <View style={ui.card}>
            <View style={ui.row}>
                <Pressable style={[ui.button, ui.flex1]} onPress={lambda { add("camera"); }}>
                    <Text style={ui.buttonText}>Take photo</Text>
                </Pressable>
                <Pressable style={[ui.button, ui.flex1]} onPress={lambda { add("gallery"); }}>
                    <Text style={ui.buttonText}>From gallery</Text>
                </Pressable>
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
                <Pressable style={ui.button} onPress={lambda { add("url"); }}>
                    <Text style={ui.buttonText}>Save</Text>
                </Pressable>
            </View>
            {(<Text style={ui.muted}>{status}</Text>) if status else None}
        </View>

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
