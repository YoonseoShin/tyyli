"""Typed local data API backed by SQLite on mobile."""
import from .storage_backend {
    clear_payload,
    delete_clothing_payload,
    load_payload,
    save_clothing_payload,
    save_outfit_payload,
    save_profile_payload
}


obj:pub StyleProfile {
    has preferred_styles: list[str] = [],
        preferred_colors: list[str] = [],
        occasions: list[str] = [],
        inspiration: str = "",
        mbti: str = "",
        zodiac: str = "",
        shop_section: str = "",
        height: str = "",
        weight: str = "",
        top_size: str = "",
        bottom_size: str = "",
        shoe_size: str = "",
        body_shape: str = "",
        units: str = "imperial",
        bust: str = "",
        waist: str = "",
        hips: str = "",
        brand_sizes: list[str] = [],
        temperature_unit: str = "F",
        favorite_stores: list[str] = [],
        favorite_brands: list[str] = [];
}


obj:pub ClothingItem {
    has clothing_item_id: str,
        name: str,
        category: str,
        colors: list[str] = [],
        seasons: list[str] = [],
        style_tags: list[str] = [],
        occasions: list[str] = [],
        warmth: int = 0,
        waterproof: bool = False,
        description: str = "",
        image_path: str = "",
        source_image_url: str = "",
        source_product_url: str = "",
        brand: str = "",
        price: str = "",
        original_image_path: str = "",
        lookup_status: str = "",
        lookup_note: str = "",
        created_at: str = "";
}


obj:pub OutfitRecommendation {
    has clothing_item_ids: list[str] = [],
        reason: str = "",
        created_at: str = "";
}


obj:pub LocalUserData {
    has profile: StyleProfile | None = None,
        clothes: list[ClothingItem] = [],
        latest_outfit: OutfitRecommendation | None = None;
}


def _string_value(payload: dict[str, any], key: str, fallback: str = "") -> str {
    value = payload.get(key, fallback);
    return value if isinstance(value, str) else fallback;
}


def _string_list(payload: dict[str, any], key: str) -> list[str] {
    value = payload.get(key, []);
    return value as list[str] if isinstance(value, list) else [];
}


def _int_value(payload: dict[str, any], key: str, fallback: int = 0) -> int {
    value = payload.get(key, fallback);
    return int(value) if isinstance(value, (int, float)) else fallback;
}


def _bool_value(payload: dict[str, any], key: str) -> bool {
    value = payload.get(key, False);
    return bool(value) if isinstance(value, (bool, int)) else False;
}


def _profile_from_payload(payload: dict[str, any]) -> StyleProfile {
    return StyleProfile(
        preferred_styles=_string_list(payload, "preferred_styles"),
        preferred_colors=_string_list(payload, "preferred_colors"),
        occasions=_string_list(payload, "occasions"),
        inspiration=_string_value(payload, "inspiration"),
        mbti=_string_value(payload, "mbti"),
        zodiac=_string_value(payload, "zodiac"),
        shop_section=_string_value(payload, "shop_section"),
        height=_string_value(payload, "height"),
        weight=_string_value(payload, "weight"),
        top_size=_string_value(payload, "top_size"),
        bottom_size=_string_value(payload, "bottom_size"),
        shoe_size=_string_value(payload, "shoe_size"),
        body_shape=_string_value(payload, "body_shape"),
        units=_string_value(payload, "units", "imperial") or "imperial",
        bust=_string_value(payload, "bust"),
        waist=_string_value(payload, "waist"),
        hips=_string_value(payload, "hips"),
        brand_sizes=_string_list(payload, "brand_sizes"),
        temperature_unit=_string_value(payload, "temperature_unit", "F") or "F",
        favorite_stores=_string_list(payload, "favorite_stores"),
        favorite_brands=_string_list(payload, "favorite_brands")
    );
}


def _clothing_from_payload(payload: dict[str, any]) -> ClothingItem {
    return ClothingItem(
        clothing_item_id=_string_value(payload, "clothing_item_id"),
        name=_string_value(payload, "name", "Clothing item"),
        category=_string_value(payload, "category", "Uncategorized"),
        colors=_string_list(payload, "colors"),
        seasons=_string_list(payload, "seasons"),
        style_tags=_string_list(payload, "style_tags"),
        occasions=_string_list(payload, "occasions"),
        warmth=_int_value(payload, "warmth"),
        waterproof=_bool_value(payload, "waterproof"),
        description=_string_value(payload, "description"),
        image_path=_string_value(payload, "image_path"),
        source_image_url=_string_value(payload, "source_image_url"),
        source_product_url=_string_value(payload, "source_product_url"),
        brand=_string_value(payload, "brand"),
        price=_string_value(payload, "price"),
        original_image_path=_string_value(payload, "original_image_path"),
        lookup_status=_string_value(payload, "lookup_status"),
        lookup_note=_string_value(payload, "lookup_note"),
        created_at=_string_value(payload, "created_at")
    );
}


def _outfit_from_payload(payload: dict[str, any]) -> OutfitRecommendation {
    return OutfitRecommendation(
        clothing_item_ids=_string_list(payload, "clothing_item_ids"),
        reason=_string_value(payload, "reason"),
        created_at=_string_value(payload, "created_at")
    );
}


async def:pub load_local_data -> LocalUserData {
    payload: dict[str, any] = await load_payload();
    profile: StyleProfile | None = None;
    raw_profile = payload.get("profile");
    # Web storage returns plain JSON objects, which `isinstance(x, dict)` rejects
    # in the client runtime, so check for presence instead.
    if raw_profile is not None {
        profile = _profile_from_payload(raw_profile as dict[str, any]);
    }

    clothes: list[ClothingItem] = [];
    raw_clothes = payload.get("clothes", []);
    if isinstance(raw_clothes, list) {
        for raw_item in raw_clothes {
            if raw_item is not None {
                clothes.append(_clothing_from_payload(raw_item as dict[str, any]));
            }
        }
    }

    latest_outfit: OutfitRecommendation | None = None;
    raw_outfit = payload.get("latest_outfit");
    if raw_outfit is not None {
        latest_outfit = _outfit_from_payload(raw_outfit as dict[str, any]);
    }
    return LocalUserData(
        profile=profile,
        clothes=clothes,
        latest_outfit=latest_outfit
    );
}


async def:pub save_profile(profile: StyleProfile) -> LocalUserData {
    await save_profile_payload({
        "preferred_styles": profile.preferred_styles,
        "preferred_colors": profile.preferred_colors,
        "occasions": profile.occasions,
        "inspiration": profile.inspiration,
        "mbti": profile.mbti,
        "zodiac": profile.zodiac,
        "shop_section": profile.shop_section,
        "height": profile.height,
        "weight": profile.weight,
        "top_size": profile.top_size,
        "bottom_size": profile.bottom_size,
        "shoe_size": profile.shoe_size,
        "body_shape": profile.body_shape,
        "units": profile.units,
        "bust": profile.bust,
        "waist": profile.waist,
        "hips": profile.hips,
        "brand_sizes": profile.brand_sizes,
        "temperature_unit": profile.temperature_unit,
        "favorite_stores": profile.favorite_stores,
        "favorite_brands": profile.favorite_brands
    });
    return await load_local_data();
}


async def:pub save_clothing_item(item: ClothingItem) -> LocalUserData {
    await save_clothing_payload({
        "clothing_item_id": item.clothing_item_id,
        "name": item.name,
        "category": item.category,
        "colors": item.colors,
        "seasons": item.seasons,
        "style_tags": item.style_tags,
        "occasions": item.occasions,
        "warmth": item.warmth,
        "waterproof": item.waterproof,
        "description": item.description,
        "image_path": item.image_path,
        "source_image_url": item.source_image_url,
        "source_product_url": item.source_product_url,
        "brand": item.brand,
        "price": item.price,
        "original_image_path": item.original_image_path,
        "lookup_status": item.lookup_status,
        "lookup_note": item.lookup_note,
        "created_at": item.created_at
    });
    return await load_local_data();
}


async def:pub delete_clothing_item(clothing_item_id: str) -> LocalUserData {
    await delete_clothing_payload(clothing_item_id);
    return await load_local_data();
}


async def:pub save_latest_outfit(outfit: OutfitRecommendation) -> LocalUserData {
    await save_outfit_payload({
        "clothing_item_ids": outfit.clothing_item_ids,
        "reason": outfit.reason,
        "created_at": outfit.created_at
    });
    return await load_local_data();
}


async def:pub clear_local_data {
    await clear_payload();
}
