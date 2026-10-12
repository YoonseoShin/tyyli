"""Closet screen: add clothing photos to app storage, analyze them with AI, delete them."""
import from "@jac/mobui" { Image, Platform, Pressable, ScrollView, StyleSheet, Text, TextInput, View }
import from "expo-image-picker" {
    launchCameraAsync,
    launchImageLibraryAsync,
    requestCameraPermissionsAsync
}
import type from "expo-image-picker" { ImagePickerResult }
import from .clothes_service { save_selected_search_result }
import from .clothing_ai { ClothingAnalysis, analyze_clothing_image }
import from .photo_storage {
    delete_clothing_photo,
    describe_photo_storage,
    persist_clothing_photo,
    read_clothing_image_data,
    resolve_clothing_image_uri
}
import from .storage {
    ClothingItem,
    LocalUserData,
    delete_clothing_item,
    load_local_data,
    save_clothing_item
}


glob test_styles = StyleSheet.create({
    "screen": {"flex": 1, "backgroundColor": "#F7F4EF"},
    "content": {"padding": 24, "gap": 16, "maxWidth": 560, "width": "100%", "alignSelf": "center"},
    "title": {"fontSize": 30, "fontWeight": "bold", "color": "#28251F"},
    "description": {"fontSize": 15, "lineHeight": 22, "color": "#696258"},
    "card": {"padding": 16, "gap": 10, "borderRadius": 14, "backgroundColor": "#FFFEFC", "borderWidth": 1, "borderColor": "#E6E0D6"},
    "label": {"fontSize": 12, "fontWeight": "bold", "color": "#725747", "letterSpacing": 1},
    "value": {"fontSize": 16, "fontWeight": "bold", "lineHeight": 22, "color": "#28251F"},
    "storageLabel": {"fontSize": 12, "lineHeight": 17, "color": "#397554"},
    "storageMissing": {"color": "#9B4A43"},
    "metadataGrid": {"gap": 4},
    "metadataValue": {"fontSize": 14, "lineHeight": 20, "color": "#504A43"},
    "metadataNote": {"fontSize": 14, "lineHeight": 20, "color": "#8A8178", "fontStyle": "italic"},
    "row": {"flexDirection": "row", "gap": 10},
    "flexButton": {"flex": 1},
    "preview": {"width": "100%", "height": 260, "borderRadius": 12, "backgroundColor": "#EEE7DE"},
    "input": {"flex": 1, "borderWidth": 1, "borderColor": "#D8D0C6", "borderRadius": 10, "paddingVertical": 12, "paddingHorizontal": 12, "fontSize": 14, "color": "#28251F", "backgroundColor": "#FFFFFF"},
    "button": {"paddingVertical": 14, "paddingHorizontal": 16, "borderRadius": 12, "backgroundColor": "#725747", "alignItems": "center", "justifyContent": "center"},
    "buttonText": {"fontSize": 15, "fontWeight": "bold", "color": "#FFFFFF"},
    "smallButton": {"paddingVertical": 8, "paddingHorizontal": 12, "borderRadius": 9, "backgroundColor": "#EEE7DE"},
    "smallButtonText": {"fontSize": 13, "fontWeight": "bold", "color": "#28251F"},
    "deleteButton": {"backgroundColor": "#9B4A43"},
    "deleteButtonText": {"color": "#FFFFFF"},
    "status": {"fontSize": 13, "lineHeight": 19, "color": "#696258"}
});


def new_clothing_item_id(source: str) -> str {
    return source + "-" + str(Date.now()) + "-" + str(Math.floor(Math.random() * 1000000));
}


def is_analyzed(item: ClothingItem) -> bool {
    return item.category != "Uncategorized" or len(item.colors) > 0;
}


def join_or_dash(values: list[str]) -> str {
    return ", ".join(values) if values else "-";
}


def:pub StorageTestScreen -> JsxElement {
    has local_data: LocalUserData = LocalUserData(),
        status: str = "Loading...",
        remote_image_url: str = "",
        analyzing_ids: list[str] = [],
        storage_info: dict[str, str] = {};

    async def refresh_data {
        try {
            local_data = await load_local_data();
            info: dict[str, str] = {};
            for item in local_data.clothes {
                try {
                    info[item.clothing_item_id] = await describe_photo_storage(item.image_path);
                } except Exception as e {
                    info[item.clothing_item_id] = "Could not check file: " + str(e);
                }
            }
            storage_info = info;
            if status == "Loading..." {
                status = "";
            }
        } except Exception as e {
            status = "Could not load data: " + str(e);
        }
    }

    async def analyze_item(item: ClothingItem) {
        analyzing_ids = analyzing_ids + [item.clothing_item_id];
        try {
            status = "Reading photo from app storage...";
            image_data = await read_clothing_image_data(item.image_path);
            status = "Sending photo to AI...";
            result: ClothingAnalysis = await analyze_clothing_image(image_data);
            status = "AI metadata received. Saving...";
            await save_clothing_item(ClothingItem(
                clothing_item_id=item.clothing_item_id,
                name=result.name or item.name,
                category=result.category or "Other",
                colors=result.colors,
                seasons=result.seasons,
                style_tags=result.style_tags,
                occasions=result.occasions,
                warmth=result.warmth,
                waterproof=result.waterproof,
                description=result.description,
                image_path=item.image_path,
                source_image_url=item.source_image_url,
                source_product_url=item.source_product_url,
                created_at=item.created_at
            ));
            await refresh_data();
            status = "AI analysis complete for " + (result.name or item.name) + ".";
        } except Exception as e {
            status = "AI analysis failed for " + item.name + ": " + str(e);
        }
        analyzing_ids = [i for i in analyzing_ids if i != item.clothing_item_id];
    }

    async def analyze_new_items(new_ids: list[str]) {
        for item in local_data.clothes {
            if item.clothing_item_id in new_ids {
                await analyze_item(item);
            }
        }
    }

    async def save_picked_photos(result: ImagePickerResult, source: str) {
        if result.canceled or result.assets is None or not result.assets {
            status = "No photo selected.";
            return;
        }

        status = "Saving " + str(len(result.assets)) + " photo(s)...";
        new_ids: list[str] = [];
        for asset in result.assets {
            item_id = new_clothing_item_id(source.lower());
            saved_uri = await persist_clothing_photo(
                asset.uri,
                asset.base64 or "",
                asset.mimeType or "image/jpeg",
                item_id,
                asset.width or 0,
                asset.height or 0
            );
            try {
                await save_clothing_item(ClothingItem(
                    clothing_item_id=item_id,
                    name=source + " photo",
                    category="Uncategorized",
                    image_path=saved_uri,
                    created_at=str(Date.now())
                ));
                new_ids.append(item_id);
            } except Exception {
                await delete_clothing_photo(saved_uri);
                raise;
            }
        }
        await refresh_data();
        status = str(len(new_ids)) + " photo(s) saved. Analyzing with AI...";
        await analyze_new_items(new_ids);
        if status.endswith("Analyzing with AI...") {
            status = str(len(new_ids)) + " photo(s) saved and analyzed.";
        }
    }

    async def save_remote_image {
        if not remote_image_url {
            status = "Paste an image URL first.";
            return;
        }

        try {
            status = "Downloading image...";
            item_id = new_clothing_item_id("url");
            saved_item = await save_selected_search_result(
                clothing_item_id=item_id,
                title="Downloaded item",
                image_url=remote_image_url.strip(),
                category="Uncategorized",
                created_at=str(Date.now())
            );
            if saved_item is None {
                status = "Could not save the downloaded image.";
                return;
            }
            remote_image_url = "";
            await refresh_data();
            status = "Image saved. Analyzing with AI...";
            await analyze_new_items([item_id]);
            if status.endswith("Analyzing with AI...") {
                status = "Image saved and analyzed.";
            }
        } except Exception as e {
            status = "Could not download image: " + str(e);
        }
    }

    async def choose_photo {
        try {
            status = "Opening gallery...";
            result = await launchImageLibraryAsync({
                "allowsMultipleSelection": True,
                "selectionLimit": 0,
                "quality": 0.8,
                "base64": Platform.OS == "web"
            });
            await save_picked_photos(result, "Gallery");
        } except Exception as e {
            status = "Could not choose a photo: " + str(e);
        }
    }

    async def take_photo {
        try {
            status = "Opening camera...";
            if Platform.OS != "web" {
                permission = await requestCameraPermissionsAsync();
                if not permission.granted {
                    status = "Camera permission is required.";
                    return;
                }
            }

            result = await launchCameraAsync({
                "allowsEditing": False,
                "quality": 0.8,
                "base64": Platform.OS == "web"
            });
            await save_picked_photos(result, "Camera");
        } except Exception as e {
            status = "Could not take a photo: " + str(e);
        }
    }

    async def delete_item(item: ClothingItem) {
        try {
            await delete_clothing_item(item.clothing_item_id);
            try {
                await delete_clothing_photo(item.image_path);
            } except Exception {}
            await refresh_data();
            status = "Deleted " + item.name + ".";
        } except Exception as e {
            status = "Could not delete: " + str(e);
        }
    }

    async can with entry {
        await refresh_data();
    }

    return <ScrollView style={test_styles.screen} contentContainerStyle={test_styles.content}>
        <Text style={test_styles.title}>My closet</Text>
        <Text style={test_styles.description}>{str(len(local_data.clothes)) + " item(s) saved in this app's private storage."}</Text>

        <View style={test_styles.card}>
            <Text style={test_styles.label}>ADD CLOTHES</Text>
            <View style={test_styles.row}>
                <Pressable style={[test_styles.button, test_styles.flexButton]} onPress={lambda { take_photo(); }}>
                    <Text style={test_styles.buttonText}>Take photo</Text>
                </Pressable>
                <Pressable style={[test_styles.button, test_styles.flexButton]} onPress={lambda { choose_photo(); }}>
                    <Text style={test_styles.buttonText}>From gallery</Text>
                </Pressable>
            </View>
            <View style={test_styles.row}>
                <TextInput
                    style={test_styles.input}
                    value={remote_image_url}
                    onChangeText={lambda (value: str) { remote_image_url = value; }}
                    placeholder="Image URL"
                    autoCapitalize="none"
                    autoCorrect={False}
                />
                <Pressable style={test_styles.button} onPress={lambda { save_remote_image(); }}>
                    <Text style={test_styles.buttonText}>Save</Text>
                </Pressable>
            </View>
            {(<Text style={test_styles.status}>{status}</Text>) if status else None}
        </View>

        {[
            <View key={item.clothing_item_id} style={test_styles.card}>
                {(<Image source={{"uri": resolve_clothing_image_uri(item.image_path)}} style={test_styles.preview} resizeMode="contain" />) if item.image_path else None}
                <Text style={test_styles.value}>{item.name}</Text>
                <Text style={[test_styles.storageLabel, test_styles.storageMissing] if storage_info.get(item.clothing_item_id, "").startswith("Missing") else test_styles.storageLabel}>
                    {storage_info.get(item.clothing_item_id, "Checking storage...")}
                </Text>
                {(<Text style={test_styles.metadataNote}>Analyzing with AI...</Text>) if item.clothing_item_id in analyzing_ids else (
                    <View style={test_styles.metadataGrid}>
                        <Text style={test_styles.metadataValue}>{"Type: " + item.category}</Text>
                        <Text style={test_styles.metadataValue}>{"Colors: " + join_or_dash(item.colors)}</Text>
                        <Text style={test_styles.metadataValue}>{"Mood: " + join_or_dash(item.style_tags)}</Text>
                        <Text style={test_styles.metadataValue}>{"Best for: " + join_or_dash(item.occasions)}</Text>
                        <Text style={test_styles.metadataValue}>{"Seasons: " + join_or_dash(item.seasons) + "  ·  Warmth " + str(item.warmth) + "/5" + ("  ·  Waterproof" if item.waterproof else "")}</Text>
                        {(<Text style={test_styles.metadataNote}>{item.description}</Text>) if item.description else None}
                    </View>
                ) if is_analyzed(item) else (<Text style={test_styles.metadataNote}>Not analyzed yet.</Text>)}
                <View style={test_styles.row}>
                    <Pressable style={test_styles.smallButton} onPress={lambda { analyze_item(item); }}>
                        <Text style={test_styles.smallButtonText}>{"Re-analyze" if is_analyzed(item) else "Analyze"}</Text>
                    </Pressable>
                    <Pressable style={[test_styles.smallButton, test_styles.deleteButton]} onPress={lambda { delete_item(item); }}>
                        <Text style={[test_styles.smallButtonText, test_styles.deleteButtonText]}>Delete</Text>
                    </Pressable>
                </View>
            </View>
            for item in local_data.clothes
        ]}
    </ScrollView>;
}
