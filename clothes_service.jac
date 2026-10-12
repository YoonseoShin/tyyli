"""Application service for saving a selected product-search result."""
import from .photo_storage { delete_clothing_photo, download_clothing_photo }
import from .storage { ClothingItem, save_clothing_item }


async def:pub save_selected_search_result(
    clothing_item_id: str,
    title: str,
    image_url: str,
    category: str,
    product_url: str = "",
    created_at: str = ""
) -> ClothingItem | None {
    image_path = await download_clothing_photo(image_url, clothing_item_id);
    item = ClothingItem(
        clothing_item_id=clothing_item_id,
        name=title,
        category=category,
        image_path=image_path,
        source_image_url=image_url,
        source_product_url=product_url,
        created_at=created_at
    );
    try {
        await save_clothing_item(item);
    } except Exception {
        # Avoid leaving an orphaned file if the SQLite write fails.
        await delete_clothing_photo(image_path);
        return None;
    }
    return item;
}
