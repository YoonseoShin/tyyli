"""Add, analyze and delete closet items.

Same flow as `storage_test.jac`, packaged as functions so any screen can use
it: the photo is copied into app storage, the record is saved to the local
database, and AI metadata is filled in afterwards.
"""
import from "@jac/mobui" { Platform }
import from "expo-image-picker" {
    launchCameraAsync,
    launchImageLibraryAsync,
    requestCameraPermissionsAsync
}
import type from "expo-image-picker" { ImagePickerResult }
import from ..clothes_service { save_selected_search_result }
import from ..clothing_ai { ClothingAnalysis, analyze_clothing_image }
import from ..photo_storage {
    delete_clothing_photo,
    persist_clothing_photo,
    read_clothing_image_data
}
import from ..storage {
    ClothingItem,
    delete_clothing_item,
    save_clothing_item
}


def:pub new_clothing_item_id(source: str) -> str {
    return source + "-" + str(Date.now()) + "-" + str(Math.floor(Math.random() * 1000000));
}


def:pub is_analyzed(item: ClothingItem) -> bool {
    return item.category != "Uncategorized" or len(item.colors) > 0;
}


async def:pub save_picked_photos(result: ImagePickerResult, source: str) -> list[ClothingItem] {
    if result.canceled or result.assets is None or not result.assets {
        return [];
    }
    new_items: list[ClothingItem] = [];
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
        item = ClothingItem(
            clothing_item_id=item_id,
            name=source + " photo",
            category="Uncategorized",
            image_path=saved_uri,
            created_at=str(Date.now())
        );
        try {
            await save_clothing_item(item);
            new_items.append(item);
        } except Exception {
            await delete_clothing_photo(saved_uri);
            raise;
        }
    }
    return new_items;
}


async def:pub add_from_gallery -> list[ClothingItem] {
    result = await launchImageLibraryAsync({
        "allowsMultipleSelection": True,
        "selectionLimit": 0,
        "quality": 0.8,
        "base64": Platform.OS == "web"
    });
    return await save_picked_photos(result, "Gallery");
}


async def:pub add_from_camera -> list[ClothingItem] {
    if Platform.OS != "web" {
        permission = await requestCameraPermissionsAsync();
        if not permission.granted {
            raise Exception("Camera permission is required.");
        }
    }
    result = await launchCameraAsync({
        "allowsEditing": False,
        "quality": 0.8,
        "base64": Platform.OS == "web"
    });
    return await save_picked_photos(result, "Camera");
}


async def:pub add_from_url(image_url: str) -> list[ClothingItem] {
    # Later: scraped product images will be passed in here.
    item_id = new_clothing_item_id("url");
    saved_item = await save_selected_search_result(
        clothing_item_id=item_id,
        title="Downloaded item",
        image_url=image_url.strip(),
        category="Uncategorized",
        created_at=str(Date.now())
    );
    if saved_item is None {
        raise Exception("Could not save the downloaded image.");
    }
    return [saved_item];
}


async def:pub analyze_item(item: ClothingItem) {
    image_data = await read_clothing_image_data(item.image_path);
    result: ClothingAnalysis = await analyze_clothing_image(image_data);
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
}


async def:pub remove_item(item: ClothingItem) {
    await delete_clothing_item(item.clothing_item_id);
    try {
        await delete_clothing_photo(item.image_path);
    } except Exception {}
}
