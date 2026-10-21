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
    crop_clothing_image_for_search,
    delete_clothing_photo,
    download_clothing_photo,
    persist_clothing_photo,
    read_clothing_image_data,
    read_clothing_image_data_for_search,
    save_clothing_photo_data
}
import from ..product_lookup {
    ProductCandidate,
    ProductLookup,
    fetch_product_image,
    find_product_online,
    search_product_images
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
        brand=item.brand,
        price=item.price,
        original_image_path=item.original_image_path,
        lookup_status=item.lookup_status,
        lookup_note=item.lookup_note,
        created_at=item.created_at
    ));
}


async def:pub remove_item(item: ClothingItem) {
    await delete_clothing_item(item.clothing_item_id);
    try {
        await delete_clothing_photo(item.image_path);
    } except Exception {}
}


def _item_with(item: ClothingItem, changes: dict[str, any]) -> ClothingItem {
    return ClothingItem(
        clothing_item_id=item.clothing_item_id,
        name=changes.get("name", item.name),
        category=item.category,
        colors=item.colors,
        seasons=item.seasons,
        style_tags=item.style_tags,
        occasions=item.occasions,
        warmth=item.warmth,
        waterproof=item.waterproof,
        description=item.description,
        image_path=changes.get("image_path", item.image_path),
        source_image_url=changes.get("source_image_url", item.source_image_url),
        source_product_url=changes.get("source_product_url", item.source_product_url),
        brand=changes.get("brand", item.brand),
        price=changes.get("price", item.price),
        original_image_path=changes.get("original_image_path", item.original_image_path),
        lookup_status=changes.get("lookup_status", item.lookup_status),
        lookup_note=changes.get("lookup_note", item.lookup_note),
        created_at=item.created_at
    );
}


# Stores a product photo as `photo_id` in app storage. The phone downloads the
# full-size image directly first (it passes shop CDNs' browser checks); when
# that fails the server fetches it, falling back to the search thumbnail.
# Returns the stored path, or "" when nothing could be fetched.
async def _store_product_photo(photo_id: str, image_url: str, thumbnail_url: str) -> str {
    if image_url and Platform.OS != "web" {
        try {
            return await download_clothing_photo(image_url, photo_id);
        } except Exception {}
    }
    data_url: str = await fetch_product_image(image_url, thumbnail_url);
    if not data_url {
        return "";
    }
    return await save_clothing_photo_data(data_url, photo_id);
}


# Swap the item's photo for a product photo found online, keeping the user's own
# photo so `use_original_photo` can undo it.
async def _apply_product_photo(item: ClothingItem, cand: ProductCandidate, changes: dict[str, any]) -> bool {
    new_image_path = await _store_product_photo(item.clothing_item_id + "-product", cand.image, cand.thumbnail);
    if not new_image_path {
        return False;
    }
    original = item.original_image_path or item.image_path;
    changes["price"] = cand.price;
    changes["image_path"] = new_image_path;
    changes["original_image_path"] = original if new_image_path != original else "";
    changes["source_image_url"] = cand.image;
    changes["source_product_url"] = cand.link;
    return True;
}


# Google Lens-style lookup: find shop photos that look like the item, let Claude
# pick the closest clean one, and use it as the closet photo. Brand/product are
# filled in when a logo or listing makes them clear.
# `image_data` lets the caller pass a cropped version of the photo; otherwise the
# user's own photo is searched (the original, even after a product-photo swap).
async def:pub find_online(item: ClothingItem, image_data: str = "") -> ProductLookup {
    if not image_data {
        image_data = await read_clothing_image_data_for_search(item.original_image_path or item.image_path);
    }
    result: ProductLookup = await find_product_online(image_data);

    identified_name = (result.brand + " " + result.product_name).strip() if result.product_name else "";
    changes: dict[str, any] = {
        "name": identified_name or item.name,
        "brand": result.brand or item.brand,
        "lookup_note": result.note
    };
    if not result.matched or result.match_type == "none" or not result.candidates {
        changes["lookup_status"] = "no_match";
        await save_clothing_item(_item_with(item, changes));
        return result;
    }

    chosen = result.candidates[0];
    if await _apply_product_photo(item, chosen, changes) {
        changes["lookup_status"] = "matched" if result.match_type == "exact" else "similar";
    } else {
        changes["lookup_status"] = "no_match";
        changes["lookup_note"] = result.note + " (The product photo could not be downloaded.)";
    }
    await save_clothing_item(_item_with(item, changes));
    return result;
}


# Turns a listing title like "Amazon.com: Yeokou Women Trench - 42% Off | Editorialist"
# into an item name.
def:pub listing_name(title: str, source: str) -> str {
    name = title.split(" | ")[0].strip();
    if name.lower().startswith("amazon.com:") {
        name = name[11:].strip();
    }
    pieces = [p.strip() for p in name.split(" - ")];
    pieces = [p for p in pieces if p and "% off" not in p.lower() and p.lower() != source.lower()];
    if pieces {
        name = " - ".join(pieces);
    }
    return name[:80] if name else source;
}


# The user picked one of the search results as the right picture: it becomes the
# item's photo and name.
async def:pub use_candidate(item: ClothingItem, cand: ProductCandidate) {
    changes: dict[str, any] = {
        "name": listing_name(cand.title, cand.source) if cand.title else item.name,
        "lookup_note": "Picked by you from the search results."
    };
    if not await _apply_product_photo(item, cand, changes) {
        raise Exception("That product photo could not be downloaded.");
    }
    changes["lookup_status"] = "picked";
    await save_clothing_item(_item_with(item, changes));
}


# Undo a product-photo swap and show the user's own photo again.
async def:pub use_original_photo(item: ClothingItem) {
    if not item.original_image_path or item.original_image_path == item.image_path {
        return;
    }
    product_photo = item.image_path;
    await save_clothing_item(_item_with(item, {
        "image_path": item.original_image_path,
        "original_image_path": ""
    }));
    try {
        await delete_clothing_photo(product_photo);
    } except Exception {}
}


# Reverse image search on just the part of the photo the user boxed (fractions 0..1).
async def:pub find_online_cropped(item: ClothingItem, left: float, top: float, width: float, height: float) -> ProductLookup {
    image_data = await crop_clothing_image_for_search(item.original_image_path or item.image_path, left, top, width, height);
    return await find_online(item, image_data);
}


# Text search for product photos ("aritzia super puff navy").
async def:pub search_online(query: str) -> list[ProductCandidate] {
    results: list[ProductCandidate] = await search_product_images(query.strip());
    return results;
}


# Add a closet item straight from a web search result; the caller analyzes it.
async def:pub add_from_candidate(cand: ProductCandidate) -> list[ClothingItem] {
    item_id = new_clothing_item_id("web");
    image_path = await _store_product_photo(item_id, cand.image, cand.thumbnail);
    if not image_path {
        raise Exception("That picture could not be downloaded.");
    }
    item = ClothingItem(
        clothing_item_id=item_id,
        name=cand.title or "Web item",
        category="Uncategorized",
        image_path=image_path,
        source_image_url=cand.image,
        source_product_url=cand.link,
        price=cand.price,
        lookup_status="matched",
        lookup_note="Added from a web search (" + cand.source + ").",
        created_at=str(Date.now())
    );
    try {
        await save_clothing_item(item);
    } except Exception {
        await delete_clothing_photo(image_path);
        raise;
    }
    return [item];
}
