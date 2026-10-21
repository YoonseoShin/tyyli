"""Native adapter that copies clothing photos into app-owned storage."""
import from "expo-file-system/legacy" {
    copyAsync,
    deleteAsync,
    documentDirectory,
    downloadAsync,
    getInfoAsync,
    makeDirectoryAsync,
    readAsStringAsync,
    writeAsStringAsync
}
import from "expo-image-manipulator" { manipulateAsync }


glob MAX_IMAGE_EDGE = 1280,
     IMAGE_COMPRESSION = 0.7;


def mime_type_for_path(image_path: str) -> str {
    lowered = image_path.lower();
    if lowered.endswith(".png") { return "image/png"; }
    if lowered.endswith(".webp") { return "image/webp"; }
    if lowered.endswith(".heic") { return "image/heic"; }
    return "image/jpeg";
}


def file_extension(mime_type: str) -> str {
    if "png" in mime_type { return ".png"; }
    if "webp" in mime_type { return ".webp"; }
    if "heic" in mime_type or "heif" in mime_type { return ".heic"; }
    return ".jpg";
}


async def copy_optimized_photo(
    source_uri: str,
    destination_uri: str,
    width: int,
    height: int
) {
    actions: list[dict[str, any]] = [];
    if width > MAX_IMAGE_EDGE or height > MAX_IMAGE_EDGE {
        if width >= height {
            actions = [{"resize": {"width": MAX_IMAGE_EDGE}}];
        } else {
            actions = [{"resize": {"height": MAX_IMAGE_EDGE}}];
        }
    }

    optimized = await manipulateAsync(
        source_uri,
        actions,
        {"compress": IMAGE_COMPRESSION, "format": "jpeg"}
    );
    await copyAsync({"from": optimized.uri, "to": destination_uri});
    await deleteAsync(optimized.uri, {"idempotent": True});
}


async def:pub persist_clothing_photo(
    source_uri: str,
    base64_data: str,
    mime_type: str,
    clothing_item_id: str,
    width: int = 0,
    height: int = 0
) -> str {
    if documentDirectory is None {
        raise Exception("App document storage is unavailable.");
    }

    relative_path = "images/" + clothing_item_id + ".jpg";
    images_directory = documentDirectory + "images/";
    await makeDirectoryAsync(images_directory, {"intermediates": True});
    destination_uri = documentDirectory + relative_path;
    await deleteAsync(destination_uri, {"idempotent": True});
    await copy_optimized_photo(source_uri, destination_uri, width, height);
    return relative_path;
}


async def:pub download_clothing_photo(
    source_url: str,
    clothing_item_id: str
) -> str {
    if documentDirectory is None {
        raise Exception("App document storage is unavailable.");
    }

    relative_path = "images/" + clothing_item_id + ".jpg";
    images_directory = documentDirectory + "images/";
    await makeDirectoryAsync(images_directory, {"intermediates": True});
    destination_uri = documentDirectory + relative_path;
    download_uri = documentDirectory + "images/" + clothing_item_id + "-source" + file_extension(source_url.lower());
    await deleteAsync(destination_uri, {"idempotent": True});
    await deleteAsync(download_uri, {"idempotent": True});
    # Browser-like headers: shop CDNs refuse anonymous downloads.
    result = await downloadAsync(source_url, download_uri, {
        "headers": {
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1",
            "Accept": "image/webp,image/avif,image/*,*/*;q=0.8"
        }
    });
    if result.status < 200 or result.status >= 300 {
        await deleteAsync(download_uri, {"idempotent": True});
        raise Exception("Image download failed with HTTP " + str(result.status));
    }
    try {
        await copy_optimized_photo(download_uri, destination_uri, 0, 0);
    } finally {
        await deleteAsync(download_uri, {"idempotent": True});
    }
    return relative_path;
}


def:pub resolve_clothing_image_uri(image_path: str) -> str {
    if not image_path or image_path.startswith("http") or image_path.startswith("data:") or image_path.startswith("file:") {
        return image_path;
    }
    if documentDirectory is None {
        return image_path;
    }
    return documentDirectory + image_path;
}


async def:pub delete_clothing_photo(image_path: str) {
    if not image_path or image_path.startswith("http") or image_path.startswith("data:") {
        return;
    }

    image_uri = resolve_clothing_image_uri(image_path);
    await deleteAsync(image_uri, {"idempotent": True});
}


async def:pub read_clothing_image_data(image_path: str) -> str {
    if not image_path or image_path.startswith("http") or image_path.startswith("data:") {
        return image_path;
    }
    base64_data = await readAsStringAsync(resolve_clothing_image_uri(image_path), {"encoding": "base64"});
    return "data:" + mime_type_for_path(image_path) + ";base64," + base64_data;
}


async def:pub describe_photo_storage(image_path: str) -> str {
    if not image_path or image_path.startswith("http") or image_path.startswith("data:") {
        return "Not stored in app storage";
    }
    info = await getInfoAsync(resolve_clothing_image_uri(image_path));
    if not info.exists {
        return "Missing file: " + image_path;
    }
    return "App storage: " + image_path + " (" + str(int(info.size / 1024)) + " KB)";
}


async def:pub read_clothing_image_data_for_search(image_path: str) -> str {
    # Reverse image search uploads must stay under 500 KB, so send a smaller JPEG.
    if not image_path or image_path.startswith("http") or image_path.startswith("data:") {
        return image_path;
    }
    optimized = await manipulateAsync(
        resolve_clothing_image_uri(image_path),
        [{"resize": {"width": 900}}],
        {"compress": 0.6, "format": "jpeg", "base64": True}
    );
    base64_data = optimized.base64 or "";
    await deleteAsync(optimized.uri, {"idempotent": True});
    if not base64_data {
        return await read_clothing_image_data(image_path);
    }
    return "data:image/jpeg;base64," + base64_data;
}


async def:pub save_clothing_photo_data(data_url: str, clothing_item_id: str) -> str {
    # Stores an image data URL (e.g. a product photo fetched by the server) as the
    # item's JPEG in app storage and returns the relative path.
    if documentDirectory is None {
        raise Exception("App document storage is unavailable.");
    }
    separator = data_url.find(",");
    if not data_url.startswith("data:image/") or separator < 0 {
        raise Exception("The product image data is incomplete.");
    }
    mime_type = data_url[5:separator].split(";")[0];
    base64_data = data_url[separator + 1:];
    relative_path = "images/" + clothing_item_id + ".jpg";
    images_directory = documentDirectory + "images/";
    await makeDirectoryAsync(images_directory, {"intermediates": True});
    destination_uri = documentDirectory + relative_path;
    download_uri = documentDirectory + "images/" + clothing_item_id + "-source" + file_extension(mime_type);
    await deleteAsync(destination_uri, {"idempotent": True});
    await deleteAsync(download_uri, {"idempotent": True});
    await writeAsStringAsync(download_uri, base64_data, {"encoding": "base64"});
    try {
        await copy_optimized_photo(download_uri, destination_uri, 0, 0);
    } finally {
        await deleteAsync(download_uri, {"idempotent": True});
    }
    return relative_path;
}


async def:pub get_clothing_image_size(image_path: str) -> dict[str, int] {
    # Pixel size of a stored photo (used to map a crop box drawn on screen).
    probe = await manipulateAsync(resolve_clothing_image_uri(image_path), [], {"compress": 0.1, "format": "jpeg"});
    size = {"width": int(probe.width or 0), "height": int(probe.height or 0)};
    await deleteAsync(probe.uri, {"idempotent": True});
    return size;
}


async def:pub crop_clothing_image_for_search(
    image_path: str,
    left: float,
    top: float,
    width: float,
    height: float
) -> str {
    # Crops a stored photo (box given as fractions 0..1 of the image) and returns
    # a small JPEG data URL for reverse image search.
    size = await get_clothing_image_size(image_path);
    if size["width"] <= 0 or size["height"] <= 0 {
        return await read_clothing_image_data_for_search(image_path);
    }
    x0 = Math.max(0.0, Math.min(0.98, left));
    y0 = Math.max(0.0, Math.min(0.98, top));
    w = Math.max(0.02, Math.min(1.0 - x0, width));
    h = Math.max(0.02, Math.min(1.0 - y0, height));
    crop_width = int(w * size["width"]);
    crop_height = int(h * size["height"]);
    actions: list[dict[str, any]] = [{
        "crop": {
            "originX": int(x0 * size["width"]),
            "originY": int(y0 * size["height"]),
            "width": crop_width,
            "height": crop_height
        }
    }];
    if crop_width > 900 {
        actions.append({"resize": {"width": 900}});
    }
    optimized = await manipulateAsync(
        resolve_clothing_image_uri(image_path),
        actions,
        {"compress": 0.6, "format": "jpeg", "base64": True}
    );
    base64_data = optimized.base64 or "";
    await deleteAsync(optimized.uri, {"idempotent": True});
    if not base64_data {
        return await read_clothing_image_data_for_search(image_path);
    }
    return "data:image/jpeg;base64," + base64_data;
}
