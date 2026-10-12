"""Native adapter that copies clothing photos into app-owned storage."""
import from "expo-file-system/legacy" {
    copyAsync,
    deleteAsync,
    documentDirectory,
    downloadAsync,
    getInfoAsync,
    makeDirectoryAsync,
    readAsStringAsync
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
    result = await downloadAsync(source_url, download_uri);
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
