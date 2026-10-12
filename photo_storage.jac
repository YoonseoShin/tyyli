"""Browser adapter for clothing photos used by the minimal web test."""


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
    return;
}


async def:pub persist_clothing_photo(
    source_uri: str,
    base64_data: str,
    mime_type: str,
    clothing_item_id: str,
    width: int = 0,
    height: int = 0
) -> str {
    if base64_data {
        return f"data:{mime_type};base64,{base64_data}";
    }
    return source_uri;
}


async def:pub download_clothing_photo(
    source_url: str,
    clothing_item_id: str
) -> str {
    return source_url;
}


def:pub resolve_clothing_image_uri(image_path: str) -> str {
    return image_path;
}


async def:pub delete_clothing_photo(image_path: str) {
    return;
}


async def:pub read_clothing_image_data(image_path: str) -> str {
    # Web stores photos as data URLs (or remote URLs), which the AI can read directly.
    return image_path;
}


async def:pub describe_photo_storage(image_path: str) -> str {
    if image_path.startswith("data:") {
        return "Stored in browser storage (" + str(int(len(image_path) * 3 / 4 / 1024)) + " KB)";
    }
    return "Linked from " + image_path;
}
